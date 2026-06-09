//! kitup-provider: 供应商配置管理
//!
//! 管理多个 API 供应商配置，支持一键切换和故障转移

pub mod adapter;
pub mod failover;
pub mod provider;

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// API 供应商配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Provider {
    pub id: String,
    pub name: String,
    pub api_base: String,
    #[serde(default)]
    pub api_key_env: Option<String>,
    #[serde(default)]
    pub model_override: Option<String>,
    #[serde(default)]
    pub headers: HashMap<String, String>,
    pub priority: u32,
    #[serde(default = "default_true")]
    pub enabled: bool,
    #[serde(default)]
    pub tools: Vec<String>,
    #[serde(default)]
    pub health: HealthStatus,
}

fn default_true() -> bool { true }

/// 供应商健康状态
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct HealthStatus {
    #[serde(default)]
    pub last_check: Option<String>,
    #[serde(default)]
    pub latency_ms: Option<u64>,
    #[serde(default)]
    pub status: ProviderHealth,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Default)]
pub enum ProviderHealth {
    #[default]
    Unknown,
    Ok,
    Degraded,
    Down,
}

/// 供应商配置文件
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ProviderConfig {
    #[serde(default)]
    pub providers: Vec<Provider>,
}

impl ProviderConfig {
    /// 获取配置文件路径
    pub fn config_path() -> Result<std::path::PathBuf> {
        let dir = kitup_core::config::Config::config_dir()?;
        Ok(dir.join("providers.json"))
    }

    /// 加载配置
    pub fn load() -> Result<Self> {
        let path = Self::config_path()?;
        if !path.exists() {
            return Ok(Self::default());
        }
        let content = std::fs::read_to_string(&path)?;
        let config: Self = serde_json::from_str(&content)?;
        Ok(config)
    }

    /// 保存配置
    pub fn save(&self) -> Result<()> {
        let path = Self::config_path()?;
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let content = serde_json::to_string_pretty(self)?;
        std::fs::write(&path, content)?;
        Ok(())
    }

    /// 列出所有供应商
    pub fn list(&self) -> &[Provider] {
        &self.providers
    }

    /// 添加供应商
    pub fn add(&mut self, provider: Provider) -> Result<()> {
        self.providers.push(provider);
        self.save()
    }

    /// 删除供应商
    pub fn remove(&mut self, name: &str) -> Result<bool> {
        let len_before = self.providers.len();
        self.providers.retain(|p| p.name != name);
        if self.providers.len() < len_before {
            self.save()?;
            Ok(true)
        } else {
            Ok(false)
        }
    }

    /// 按名称查找
    pub fn find(&self, name: &str) -> Option<&Provider> {
        self.providers.iter().find(|p| p.name == name)
    }

    /// 获取指定工具的供应商列表（按优先级排序）
    pub fn providers_for_tool(&self, tool_name: &str) -> Vec<&Provider> {
        let mut providers: Vec<_> = self
            .providers
            .iter()
            .filter(|p| p.enabled && (p.tools.is_empty() || p.tools.contains(&tool_name.to_string())))
            .collect();
        providers.sort_by_key(|p| p.priority);
        providers
    }

    /// 导出为 JSON
    pub fn export_json(&self) -> Result<String> {
        Ok(serde_json::to_string_pretty(self)?)
    }

    /// 从 JSON 导入
    pub fn import_json(json: &str) -> Result<Self> {
        let config: Self = serde_json::from_str(json)?;
        Ok(config)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_provider_config_default() {
        let config = ProviderConfig::default();
        assert!(config.providers.is_empty());
    }

    #[test]
    fn test_provider_serialization() {
        let provider = Provider {
            id: "test-1".to_string(),
            name: "test-provider".to_string(),
            api_base: "https://api.example.com".to_string(),
            api_key_env: Some("API_KEY".to_string()),
            model_override: None,
            headers: HashMap::new(),
            priority: 1,
            enabled: true,
            tools: vec!["claude".to_string()],
            health: HealthStatus::default(),
        };

        let json = serde_json::to_string(&provider).unwrap();
        assert!(json.contains("test-provider"));

        let parsed: Provider = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.name, "test-provider");
        assert_eq!(parsed.priority, 1);
    }
}
