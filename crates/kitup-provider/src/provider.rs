//! 供应商配置文件适配器
//!
//! 各 AI 工具有不同的配置文件格式，适配器提供统一的读写接口

use anyhow::Result;
use async_trait::async_trait;
use serde_json::Value;
use std::path::PathBuf;

/// 配置文件适配器 trait
#[allow(clippy::double_must_use)]
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
    fn tool_name(&self) -> &str {
        "claude"
    }

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

        // Persist via the env map so the setting survives restarts; the
        // previous set_var() call only affected the kitup process itself.
        let env = json
            .as_object_mut()
            .ok_or_else(|| anyhow::anyhow!("settings.json 顶层必须是 JSON 对象"))?
            .entry("env")
            .or_insert_with(|| Value::Object(serde_json::Map::new()));
        if let Some(env_map) = env.as_object_mut() {
            env_map.insert(
                "ANTHROPIC_BASE_URL".to_string(),
                Value::String(api_base.to_string()),
            );
        }

        kitup_core::atomic_write(&path, &serde_json::to_string_pretty(&json)?)?;

        Ok(())
    }
}

/// Gemini 配置适配器
pub struct GeminiAdapter;

#[async_trait]
impl ConfigAdapter for GeminiAdapter {
    fn tool_name(&self) -> &str {
        "gemini"
    }

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
        // Gemini CLI reads dotenv-style settings from ~/.gemini/.env.
        let path = self
            .config_path()?
            .parent()
            .map(|p| p.join(".env"))
            .ok_or_else(|| anyhow::anyhow!("无法确定 .env 路径"))?;
        let mut content = if path.exists() {
            std::fs::read_to_string(&path)?
        } else {
            String::new()
        };
        upsert_env_line(&mut content, "GEMINI_API_BASE", api_base);
        kitup_core::atomic_write(&path, &content)?;
        Ok(())
    }
}

/// Codex 配置适配器
pub struct CodexAdapter;

#[async_trait]
impl ConfigAdapter for CodexAdapter {
    fn tool_name(&self) -> &str {
        "codex"
    }

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
        // Codex reads base URL from config.toml's model_provider section;
        // write it as a top-level comment-style key the CLI documents for
        // custom endpoints via OPENAI_BASE_URL passthrough in .env instead.
        let env_path = self
            .config_path()?
            .parent()
            .map(|p| p.join(".env"))
            .ok_or_else(|| anyhow::anyhow!("无法确定 .env 路径"))?;
        let mut content = if env_path.exists() {
            std::fs::read_to_string(&env_path)?
        } else {
            String::new()
        };
        upsert_env_line(&mut content, "OPENAI_BASE_URL", api_base);
        kitup_core::atomic_write(&env_path, &content)?;
        Ok(())
    }
}

/// Replace or append a KEY=value line in dotenv-style content.
fn upsert_env_line(content: &mut String, key: &str, value: &str) {
    let mut found = false;
    let mut lines: Vec<String> = content
        .lines()
        .map(|line| {
            if line.trim_start().starts_with(&format!("{}=", key)) {
                found = true;
                format!("{}={}", key, value)
            } else {
                line.to_string()
            }
        })
        .collect();
    if !found {
        lines.push(format!("{}={}", key, value));
    }
    *content = lines.join("\n");
    if !content.ends_with('\n') {
        content.push('\n');
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_upsert_env_line_appends() {
        let mut content = String::from("FOO=1\n");
        upsert_env_line(&mut content, "BAR", "https://x.example");
        assert!(content.contains("BAR=https://x.example"));
    }

    #[test]
    fn test_upsert_env_line_replaces() {
        let mut content = String::from("OPENAI_BASE_URL=https://old\nFOO=1\n");
        upsert_env_line(&mut content, "OPENAI_BASE_URL", "https://new");
        assert!(content.contains("OPENAI_BASE_URL=https://new"));
        assert!(!content.contains("https://old"));
        assert!(content.contains("FOO=1"));
    }
}
