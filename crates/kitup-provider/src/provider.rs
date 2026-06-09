//! 供应商配置文件适配器
//!
//! 各 AI 工具有不同的配置文件格式，适配器提供统一的读写接口

use anyhow::Result;
use async_trait::async_trait;
use serde_json::Value;
use std::path::PathBuf;

/// 配置文件适配器 trait
#[async_trait]
pub trait ConfigAdapter: Send + Sync {
    /// 工具名称
    fn tool_name(&self) -> &str;

    /// 配置文件路径
    fn config_path(&self) -> Result<PathBuf>;

    /// 读取当前供应商信息
    async fn read_current_provider(&self) -> Result<CurrentProvider>;

    /// 切换供应商
    async fn switch_provider(
        &self,
        api_base: &str,
        api_key_env: &str,
        model_override: Option<&str>,
    ) -> Result<()>;

    /// 备份当前配置
    async fn backup_config(&self) -> Result<PathBuf> {
        let path = self.config_path()?;
        if !path.exists() {
            anyhow::bail!("Config file not found: {:?}", path);
        }

        let backup_dir = kitup_core::config::Config::config_dir()?.join("backups");
        std::fs::create_dir_all(&backup_dir)?;

        let timestamp = chrono::Utc::now().format("%Y%m%d_%H%M%S");
        let backup_name = format!("{}_{}.json", self.tool_name(), timestamp);
        let backup_path = backup_dir.join(&backup_name);

        std::fs::copy(&path, &backup_path)?;
        Ok(backup_path)
    }
}

/// 当前供应商信息
#[derive(Debug, Clone)]
pub struct CurrentProvider {
    pub api_base: Option<String>,
    pub api_key_env: Option<String>,
    pub model: Option<String>,
}

/// Claude 配置适配器
pub struct ClaudeAdapter;

#[async_trait]
impl ConfigAdapter for ClaudeAdapter {
    fn tool_name(&self) -> &str { "claude" }

    fn config_path(&self) -> Result<PathBuf> {
        let home = std::env::var("HOME")
            .or_else(|_| std::env::var("USERPROFILE"))
            .unwrap_or_else(|_| ".".to_string());
        Ok(PathBuf::from(home).join(".claude/settings.json"))
    }

    async fn read_current_provider(&self) -> Result<CurrentProvider> {
        let path = self.config_path()?;
        if !path.exists() {
            return Ok(CurrentProvider {
                api_base: None,
                api_key_env: Some("ANTHROPIC_API_KEY".to_string()),
                model: None,
            });
        }

        let content = std::fs::read_to_string(&path)?;
        let json: Value = serde_json::from_str(&content)?;

        Ok(CurrentProvider {
            api_base: json
                .get("apiBaseUrl")
                .and_then(|v| v.as_str())
                .map(|s| s.to_string()),
            api_key_env: Some("ANTHROPIC_API_KEY".to_string()),
            model: json
                .get("model")
                .and_then(|v| v.as_str())
                .map(|s| s.to_string()),
        })
    }

    async fn switch_provider(
        &self,
        api_base: &str,
        _api_key_env: &str,
        model_override: Option<&str>,
    ) -> Result<()> {
        self.backup_config().await?;

        let path = self.config_path()?;
        let mut json = if path.exists() {
            let content = std::fs::read_to_string(&path)?;
            serde_json::from_str::<Value>(&content)?
        } else {
            serde_json::json!({})
        };

        json["apiBaseUrl"] = Value::String(api_base.to_string());
        if let Some(model) = model_override {
            json["model"] = Value::String(model.to_string());
        }

        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        std::fs::write(&path, serde_json::to_string_pretty(&json)?)?;

        // 设置环境变量
        std::env::set_var("ANTHROPIC_BASE_URL", api_base);

        Ok(())
    }
}

/// Gemini 配置适配器
pub struct GeminiAdapter;

#[async_trait]
impl ConfigAdapter for GeminiAdapter {
    fn tool_name(&self) -> &str { "gemini" }

    fn config_path(&self) -> Result<PathBuf> {
        let home = std::env::var("HOME")
            .or_else(|_| std::env::var("USERPROFILE"))
            .unwrap_or_else(|_| ".".to_string());
        Ok(PathBuf::from(home).join(".gemini/settings.json"))
    }

    async fn read_current_provider(&self) -> Result<CurrentProvider> {
        Ok(CurrentProvider {
            api_base: None,
            api_key_env: Some("GEMINI_API_KEY".to_string()),
            model: None,
        })
    }

    async fn switch_provider(
        &self,
        api_base: &str,
        _api_key_env: &str,
        _model_override: Option<&str>,
    ) -> Result<()> {
        self.backup_config().await?;
        std::env::set_var("GEMINI_API_BASE", api_base);
        Ok(())
    }
}

/// Codex 配置适配器
pub struct CodexAdapter;

#[async_trait]
impl ConfigAdapter for CodexAdapter {
    fn tool_name(&self) -> &str { "codex" }

    fn config_path(&self) -> Result<PathBuf> {
        let home = std::env::var("HOME")
            .or_else(|_| std::env::var("USERPROFILE"))
            .unwrap_or_else(|_| ".".to_string());
        Ok(PathBuf::from(home).join(".codex/config.json"))
    }

    async fn read_current_provider(&self) -> Result<CurrentProvider> {
        Ok(CurrentProvider {
            api_base: None,
            api_key_env: Some("OPENAI_API_KEY".to_string()),
            model: None,
        })
    }

    async fn switch_provider(
        &self,
        api_base: &str,
        _api_key_env: &str,
        _model_override: Option<&str>,
    ) -> Result<()> {
        self.backup_config().await?;
        std::env::set_var("OPENAI_BASE_URL", api_base);
        Ok(())
    }
}
