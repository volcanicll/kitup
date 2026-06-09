//! 自更新机制

use anyhow::Result;
use semver::Version;
use serde::Deserialize;
use std::path::PathBuf;
use std::time::{Duration, SystemTime};

#[derive(Debug, Deserialize)]
struct GithubRelease {
    tag_name: String,
}

pub struct SelfUpdater {
    repo: &'static str,
    cache_file: PathBuf,
    ttl: Duration,
}

impl SelfUpdater {
    pub fn new() -> Result<Self> {
        let cache_dir = crate::config::Config::config_dir()?;
        Ok(Self {
            repo: "volcanicll/kitup",
            cache_file: cache_dir.join("self_update_check"),
            ttl: Duration::from_secs(86400),
        })
    }

    pub async fn check_update(&self) -> Result<Option<String>> {
        let current = Version::parse(env!("CARGO_PKG_VERSION"))?;

        if let Some(cached) = self.read_cache()? {
            if let Ok(cached_ver) = Version::parse(&cached) {
                if cached_ver > current {
                    return Ok(Some(cached));
                }
            }
        }

        let url = format!(
            "https://api.github.com/repos/{}/releases/latest",
            self.repo
        );
        let client = reqwest::Client::new();
        let response = client
            .get(&url)
            .header("User-Agent", "kitup")
            .send()
            .await;

        match response {
            Ok(resp) if resp.status().is_success() => {
                if let Ok(release) = resp.json::<GithubRelease>().await {
                    if let Some(latest) = crate::version::parse_version(&release.tag_name) {
                        if latest > current {
                            self.write_cache(&latest.to_string())?;
                            return Ok(Some(latest.to_string()));
                        }
                    }
                }
            }
            Ok(resp) => tracing::warn!("GitHub API 返回状态: {}", resp.status()),
            Err(e) => tracing::warn!("GitHub API 请求失败: {}", e),
        }

        Ok(None)
    }

    fn read_cache(&self) -> Result<Option<String>> {
        if !self.cache_file.exists() {
            return Ok(None);
        }
        let content = std::fs::read_to_string(&self.cache_file)?;
        let mut parts = content.splitn(2, '|');
        let version_str = parts.next().unwrap_or("").trim().to_string();
        let timestamp_str = parts.next().unwrap_or("0").trim();

        let timestamp: u64 = timestamp_str.parse().unwrap_or(0);
        let now = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)?
            .as_secs();

        if now.saturating_sub(timestamp) > self.ttl.as_secs() {
            return Ok(None);
        }

        Ok(if version_str.is_empty() { None } else { Some(version_str) })
    }

    fn write_cache(&self, version: &str) -> Result<()> {
        let now = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)?
            .as_secs();
        if let Some(parent) = self.cache_file.parent() {
            std::fs::create_dir_all(parent)?;
        }
        std::fs::write(&self.cache_file, format!("{}|{}", version, now))?;
        Ok(())
    }

    pub async fn do_update(&self) -> Result<()> {
        let os = std::env::consts::OS;
        let arch = std::env::consts::ARCH;

        let asset_name = match (os, arch) {
            ("macos", "aarch64") => "kitup-aarch64-apple-darwin.tar.gz",
            ("macos", "x86_64") => "kitup-x86_64-apple-darwin.tar.gz",
            ("linux", "x86_64") => "kitup-x86_64-unknown-linux-gnu.tar.gz",
            ("linux", "aarch64") => "kitup-aarch64-unknown-linux-gnu.tar.gz",
            ("windows", "x86_64") => "kitup-x86_64-pc-windows-msvc.zip",
            _ => anyhow::bail!("不支持的平台: {}-{}", os, arch),
        };

        let url = format!(
            "https://github.com/{}/releases/latest/download/{}",
            self.repo, asset_name
        );

        let client = reqwest::Client::new();
        let response = client
            .get(&url)
            .header("User-Agent", "kitup")
            .send()
            .await?;

        if !response.status().is_success() {
            anyhow::bail!("下载失败: HTTP {}", response.status());
        }

        let current_exe = std::env::current_exe()?;
        let tmp_dir = std::env::temp_dir();
        let tmp_file = tmp_dir.join("kitup-update");

        let bytes = response.bytes().await?;
        std::fs::write(&tmp_file, &bytes)?;

        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&tmp_file, std::fs::Permissions::from_mode(0o755))?;
        }

        std::fs::rename(&tmp_file, &current_exe)?;
        Ok(())
    }
}
