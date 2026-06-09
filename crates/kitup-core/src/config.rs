//! 配置管理

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub version: u32,
    #[serde(default = "default_parallel_jobs")]
    pub parallel_jobs: usize,
    #[serde(default)]
    pub auto_backup: bool,
    #[serde(default)]
    pub auto_install_missing: bool,
    #[serde(default)]
    pub verbose: bool,
    #[serde(default)]
    pub exclude_tools: Vec<String>,
    #[serde(default = "default_true")]
    pub detect_new_tools: bool,
    #[serde(default = "default_changelog_count")]
    pub changelog_count: usize,
    #[serde(default = "default_action")]
    pub default_action: String,
    #[serde(default = "default_self_update_ttl")]
    pub self_update_ttl_secs: u64,
}

fn default_parallel_jobs() -> usize { 3 }
fn default_true() -> bool { true }
fn default_changelog_count() -> usize { 3 }
fn default_action() -> String { "tui".to_string() }
fn default_self_update_ttl() -> u64 { 86400 }

impl Default for Config {
    fn default() -> Self {
        Self {
            version: 2,
            parallel_jobs: default_parallel_jobs(),
            auto_backup: false,
            auto_install_missing: false,
            verbose: false,
            exclude_tools: vec![],
            detect_new_tools: true,
            changelog_count: 3,
            default_action: "tui".to_string(),
            self_update_ttl_secs: 86400,
        }
    }
}

impl Config {
    pub fn config_dir() -> Result<PathBuf> {
        let dirs = directories::ProjectDirs::from("com", "kitup", "kitup")
            .ok_or_else(|| anyhow::anyhow!("无法确定配置目录"))?;
        Ok(dirs.config_dir().to_path_buf())
    }

    pub fn config_path() -> Result<PathBuf> {
        Ok(Self::config_dir()?.join("config.json"))
    }

    pub fn load() -> Result<Self> {
        let v2_path = Self::config_path()?;
        let v1_path = dirs_v1()?.join("config.json");

        if v2_path.exists() {
            let content = std::fs::read_to_string(&v2_path)?;
            let mut config: Config = serde_json::from_str(&content)?;
            config.version = 2;
            return Ok(config);
        }

        if v1_path.exists() {
            return Self::migrate_v1(&v1_path);
        }

        Ok(Self::default())
    }

    fn migrate_v1(v1_path: &PathBuf) -> Result<Self> {
        let content = std::fs::read_to_string(v1_path)?;
        let v1: serde_json::Value = serde_json::from_str(&content)?;

        let config = Config {
            version: 2,
            parallel_jobs: v1.get("parallel_jobs").and_then(|v| v.as_u64()).unwrap_or(3) as usize,
            auto_backup: v1.get("auto_backup").and_then(|v| v.as_bool()).unwrap_or(false),
            auto_install_missing: v1.get("auto_install_missing").and_then(|v| v.as_bool()).unwrap_or(false),
            verbose: v1.get("verbose").and_then(|v| v.as_bool()).unwrap_or(false),
            exclude_tools: v1.get("exclude_tools")
                .and_then(|v| v.as_str())
                .map(|s| s.split(',').map(|t| t.trim().to_string()).collect())
                .unwrap_or_default(),
            detect_new_tools: v1.get("detect_new_tools").and_then(|v| v.as_bool()).unwrap_or(true),
            changelog_count: v1.get("changelog_count").and_then(|v| v.as_u64()).unwrap_or(3) as usize,
            default_action: "tui".to_string(),
            self_update_ttl_secs: 86400,
        };

        config.save()?;
        tracing::info!("已从 v1 配置迁移到 v2 格式");
        Ok(config)
    }

    pub fn save(&self) -> Result<()> {
        let dir = Self::config_dir()?;
        std::fs::create_dir_all(&dir)?;
        let path = Self::config_path()?;
        let content = serde_json::to_string_pretty(self)?;
        std::fs::write(&path, content)?;
        Ok(())
    }

    pub fn init() -> Result<PathBuf> {
        let dir = Self::config_dir()?;
        std::fs::create_dir_all(&dir)?;
        let path = Self::config_path()?;
        if !path.exists() {
            let config = Self::default();
            config.save()?;
        }
        Ok(path)
    }
}

fn dirs_v1() -> Result<PathBuf> {
    Ok(PathBuf::from(
        std::env::var("HOME")
            .or_else(|_| std::env::var("USERPROFILE"))
            .unwrap_or_else(|_| ".".to_string()),
    ).join(".kitup"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = Config::default();
        assert_eq!(config.version, 2);
        assert_eq!(config.parallel_jobs, 3);
        assert!(config.detect_new_tools);
    }

    #[test]
    fn test_config_serialization() {
        let config = Config::default();
        let json = serde_json::to_string(&config).unwrap();
        let parsed: Config = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.parallel_jobs, config.parallel_jobs);
    }
}
