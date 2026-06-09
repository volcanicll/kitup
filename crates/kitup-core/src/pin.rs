//! 版本固定管理

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct PinnedVersions {
    #[serde(flatten)]
    pins: HashMap<String, String>,
}

impl PinnedVersions {
    fn pins_path() -> Result<PathBuf> {
        let dir = crate::config::Config::config_dir()?;
        Ok(dir.join("pinned_versions.json"))
    }

    pub fn load() -> Result<Self> {
        let path = Self::pins_path()?;
        if !path.exists() {
            return Ok(Self::default());
        }
        let content = std::fs::read_to_string(&path)?;
        let pins: Self = serde_json::from_str(&content)?;
        Ok(pins)
    }

    fn save(&self) -> Result<()> {
        let path = Self::pins_path()?;
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let content = serde_json::to_string_pretty(self)?;
        std::fs::write(&path, content)?;
        Ok(())
    }

    pub fn pin(tool_name: &str, version: &str) -> Result<()> {
        let mut pins = Self::load()?;
        pins.pins.insert(tool_name.to_string(), version.to_string());
        pins.save()
    }

    pub fn unpin(tool_name: &str) -> Result<bool> {
        let mut pins = Self::load()?;
        if pins.pins.remove(tool_name).is_some() {
            pins.save()?;
            Ok(true)
        } else {
            Ok(false)
        }
    }

    pub fn get_pinned(tool_name: &str) -> Result<Option<String>> {
        Ok(Self::load()?.pins.get(tool_name).cloned())
    }

    pub fn list_all() -> Result<HashMap<String, String>> {
        Ok(Self::load()?.pins)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pinned_versions_serialization() {
        let mut pins = PinnedVersions::default();
        pins.pins.insert("claude".to_string(), "0.2.45".to_string());

        let json = serde_json::to_string(&pins).unwrap();
        assert!(json.contains("claude"));

        let parsed: PinnedVersions = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.pins.get("claude"), Some(&"0.2.45".to_string()));
    }
}
