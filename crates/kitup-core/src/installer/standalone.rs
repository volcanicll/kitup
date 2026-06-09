//! standalone 安装适配器

use crate::installer::PackageManager;
use crate::tool::Tool;
use crate::version::parse_version;
use anyhow::Result;
use async_trait::async_trait;
use semver::Version;
use std::path::PathBuf;
use tokio::process::Command;

pub struct StandaloneAdapter;

impl StandaloneAdapter {
    pub fn is_path_match_static(tool_path: &PathBuf) -> bool {
        let path_str = tool_path.to_string_lossy();
        path_str.starts_with("/usr/local/bin/")
            || path_str.contains("/.local/bin/")
            || path_str.contains("/bin/")
    }

    pub fn is_path_match(&self, tool_path: &PathBuf) -> bool {
        Self::is_path_match_static(tool_path)
    }
}

#[async_trait]
impl PackageManager for StandaloneAdapter {
    fn name(&self) -> &str { "standalone" }

    async fn is_installed(&self, tool: &Tool) -> bool {
        which::which(tool.command).is_ok()
    }

    async fn local_version(&self, tool: &Tool) -> Result<Option<Version>> {
        let output = Command::new(tool.command)
            .args(["--version"])
            .output()
            .await;
        match output {
            Ok(o) if o.status.success() => Ok(parse_version(&String::from_utf8_lossy(&o.stdout))),
            _ => {
                let output = Command::new(tool.command)
                    .args(["-v"])
                    .output()
                    .await;
                match output {
                    Ok(o) if o.status.success() => {
                        Ok(parse_version(&String::from_utf8_lossy(&o.stdout)))
                    }
                    _ => Ok(None),
                }
            }
        }
    }

    async fn latest_version(&self, tool: &Tool) -> Result<Option<Version>> {
        if let Some(ref repo) = tool.github_repo {
            let url = format!("https://api.github.com/repos/{}/releases/latest", repo);
            let client = reqwest::Client::new();
            let response = client
                .get(&url)
                .header("User-Agent", "kitup")
                .send()
                .await?;

            if response.status().is_success() {
                let json: serde_json::Value = response.json().await?;
                if let Some(tag) = json.get("tag_name").and_then(|v| v.as_str()) {
                    return Ok(parse_version(tag));
                }
            }
        }
        Ok(None)
    }

    async fn update(&self, tool: &Tool) -> Result<()> {
        if let Some(ref url) = tool.install_url {
            let status = Command::new("sh")
                .arg("-c")
                .arg(format!("curl -fsSL {} | sh", url))
                .status()
                .await;

            match status {
                Ok(s) if s.success() => return Ok(()),
                _ => {}
            }

            let status = Command::new("sh")
                .arg("-c")
                .arg(format!("wget -qO- {} | sh", url))
                .status()
                .await;

            match status {
                Ok(s) if s.success() => return Ok(()),
                Err(e) => anyhow::bail!("standalone update failed for {}: {}", tool.name, e),
                Ok(_) => anyhow::bail!("standalone update failed for {}", tool.name),
            }
        }
        anyhow::bail!("no install URL for standalone update of {}", tool.name)
    }

    async fn install(&self, tool: &Tool) -> Result<()> {
        self.update(tool).await
    }
}
