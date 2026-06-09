//! 版本解析、比对和缓存

use anyhow::Result;
use regex::Regex;
use semver::Version;
use std::path::PathBuf;
use std::time::{Duration, SystemTime};

/// 从命令输出字符串中解析出语义版本
pub fn parse_version(output: &str) -> Option<Version> {
    let re = Regex::new(r"(?i)v?(\d+\.\d+\.\d+(?:[-\.][a-zA-Z0-9.]+)?)").ok()?;

    if let Some(caps) = re.captures(output) {
        let ver_str = caps.get(1)?.as_str();
        let normalized = ver_str.replace('-', ".");
        Version::parse(&normalized).ok()
    } else {
        None
    }
}

/// 获取 kitup 配置目录
pub fn config_dir() -> Result<PathBuf> {
    let dirs = directories::ProjectDirs::from("com", "kitup", "kitup")
        .ok_or_else(|| anyhow::anyhow!("无法确定配置目录"))?;
    Ok(dirs.config_dir().to_path_buf())
}

/// 版本缓存
#[derive(Debug, Clone)]
pub struct VersionCache {
    cache_dir: PathBuf,
    ttl: Duration,
}

impl VersionCache {
    pub fn new() -> Result<Self> {
        let cache_dir = config_dir()?.join("version_cache");
        std::fs::create_dir_all(&cache_dir)?;
        Ok(Self {
            cache_dir,
            ttl: Duration::from_secs(3600),
        })
    }

    pub fn get(&self, tool_name: &str, method: &str) -> Option<Version> {
        let file = self.cache_dir.join(format!("{}_{}.txt", tool_name, method));
        let content = std::fs::read_to_string(&file).ok()?;
        let mut parts = content.splitn(2, '|');
        let version_str = parts.next()?.trim();
        let timestamp_str = parts.next()?.trim();

        let timestamp: u64 = timestamp_str.parse().ok()?;
        let now = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .ok()?
            .as_secs();

        if now.saturating_sub(timestamp) > self.ttl.as_secs() {
            return None;
        }

        Version::parse(version_str).ok()
    }

    pub fn set(&self, tool_name: &str, method: &str, version: &Version) -> Result<()> {
        let file = self.cache_dir.join(format!("{}_{}.txt", tool_name, method));
        let now = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)?
            .as_secs();
        std::fs::write(&file, format!("{}|{}", version, now))?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_simple_version() {
        let v = parse_version("1.2.3").unwrap();
        assert_eq!(v.major, 1);
        assert_eq!(v.minor, 2);
        assert_eq!(v.patch, 3);
    }

    #[test]
    fn test_parse_version_with_prefix() {
        let v = parse_version("v1.2.3").unwrap();
        assert_eq!(v.major, 1);
    }

    #[test]
    fn test_parse_version_from_output() {
        let v = parse_version("claude 0.2.50").unwrap();
        assert_eq!(v.minor, 2);
        assert_eq!(v.patch, 50);
    }

    #[test]
    fn test_parse_version_no_match() {
        assert!(parse_version("no version here").is_none());
        assert!(parse_version("").is_none());
    }

    #[test]
    fn test_version_comparison() {
        let v1 = parse_version("1.2.3").unwrap();
        let v2 = parse_version("1.2.4").unwrap();
        assert!(v2 > v1);
    }
}
