//! 工具定义和注册表

use serde::{Deserialize, Serialize};
use std::fmt;

/// 一个 AI 编码工具的定义
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Tool {
    pub name: &'static str,
    pub command: &'static str,
    pub npm_package: Option<&'static str>,
    pub brew_formula: Option<&'static str>,
    pub pipx_package: Option<&'static str>,
    pub uv_package: Option<&'static str>,
    pub github_repo: Option<&'static str>,
    pub install_url: Option<&'static str>,
}

impl fmt::Display for Tool {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.name)
    }
}

impl Tool {
    /// 从名称查找工具
    pub fn find_by_name(name: &str) -> Option<&'static Tool> {
        TOOL_REGISTRY.iter().find(|t| t.name == name)
    }
}

/// 全局工具注册表
pub static TOOL_REGISTRY: &[Tool] = &[
    Tool {
        name: "claude",
        command: "claude",
        npm_package: Some("@anthropic-ai/claude-code"),
        brew_formula: Some("anthropic-ai/tap/claude-code"),
        pipx_package: None,
        uv_package: None,
        github_repo: Some("anthropics/claude-code"),
        install_url: Some("https://claude.ai/install.sh"),
    },
    Tool {
        name: "opencode",
        command: "opencode",
        npm_package: Some("opencode-ai"),
        brew_formula: Some("opencode"),
        pipx_package: None,
        uv_package: None,
        github_repo: Some("opencode-ai/opencode"),
        install_url: Some("https://opencode.ai/install"),
    },
    Tool {
        name: "codex",
        command: "codex",
        npm_package: Some("@openai/codex"),
        brew_formula: Some("codex"),
        pipx_package: None,
        uv_package: None,
        github_repo: Some("openai/codex"),
        install_url: Some("https://cli.openai.com/install.sh"),
    },
    Tool {
        name: "gemini",
        command: "gemini",
        npm_package: Some("@google/gemini-cli"),
        brew_formula: Some("gemini-cli"),
        pipx_package: None,
        uv_package: None,
        github_repo: Some("google-gemini/gemini-cli"),
        install_url: None,
    },
    Tool {
        name: "kimi",
        command: "kimi",
        npm_package: None,
        brew_formula: None,
        pipx_package: Some("kimi-cli"),
        uv_package: Some("kimi-cli"),
        github_repo: Some("MoonshotAI/kimi-cli"),
        install_url: None,
    },
    Tool {
        name: "cline",
        command: "cline",
        npm_package: Some("cline"),
        brew_formula: None,
        pipx_package: None,
        uv_package: None,
        github_repo: Some("cline/cline"),
        install_url: None,
    },
    Tool {
        name: "qwen",
        command: "qwen",
        npm_package: Some("@qwen-code/qwen-code"),
        brew_formula: Some("qwen-code"),
        pipx_package: None,
        uv_package: None,
        github_repo: Some("QwenLM/qwen-code"),
        install_url: Some("https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen.sh"),
    },
    Tool {
        name: "goose",
        command: "goose",
        npm_package: None,
        brew_formula: Some("block-goose-cli"),
        pipx_package: None,
        uv_package: None,
        github_repo: Some("block/goose"),
        install_url: Some("https://github.com/block/goose/releases/download/stable/download_cli.sh"),
    },
    Tool {
        name: "aider",
        command: "aider",
        npm_package: None,
        brew_formula: Some("aider"),
        pipx_package: Some("aider-chat"),
        uv_package: Some("aider-chat"),
        github_repo: Some("Aider-AI/aider"),
        install_url: Some("https://aider.chat/install.sh"),
    },
    Tool {
        name: "cursor",
        command: "cursor",
        npm_package: None,
        brew_formula: Some("cursor"),
        pipx_package: None,
        uv_package: None,
        github_repo: Some("cursor-sh/cursor"),
        install_url: Some("https://downloader.cursor.sh/linux"),
    },
    Tool {
        name: "windsurf",
        command: "windsurf",
        npm_package: None,
        brew_formula: Some("windsurf"),
        pipx_package: None,
        uv_package: None,
        github_repo: Some("codeium/windsurf"),
        install_url: Some("https://windsurf.sh/install"),
    },
    Tool {
        name: "tabby",
        command: "tabby",
        npm_package: None,
        brew_formula: Some("tabby"),
        pipx_package: None,
        uv_package: None,
        github_repo: Some("TabbyML/tabby"),
        install_url: None,
    },
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_registry_contains_all_tools() {
        assert_eq!(TOOL_REGISTRY.len(), 12);
    }

    #[test]
    fn test_find_by_name() {
        let claude = Tool::find_by_name("claude").unwrap();
        assert_eq!(claude.command, "claude");
        assert_eq!(claude.npm_package, Some("@anthropic-ai/claude-code"));
    }

    #[test]
    fn test_find_by_name_not_found() {
        assert!(Tool::find_by_name("nonexistent").is_none());
    }

    #[test]
    fn test_tool_display() {
        let tool = Tool::find_by_name("claude").unwrap();
        assert_eq!(format!("{}", tool), "claude");
    }
}
