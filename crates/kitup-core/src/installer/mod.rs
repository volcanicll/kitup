//! 包管理器适配器

pub mod brew;
pub mod npm;
pub mod pipx;
pub mod standalone;
pub mod uv;

use crate::tool::Tool;
use anyhow::Result;
use async_trait::async_trait;
use semver::Version;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// 安装方式
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum InstallMethod {
    Npm,
    Brew,
    Pipx,
    Uv,
    Standalone,
    Unknown,
}

impl std::fmt::Display for InstallMethod {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            InstallMethod::Npm => write!(f, "npm"),
            InstallMethod::Brew => write!(f, "brew"),
            InstallMethod::Pipx => write!(f, "pipx"),
            InstallMethod::Uv => write!(f, "uv"),
            InstallMethod::Standalone => write!(f, "standalone"),
            InstallMethod::Unknown => write!(f, "unknown"),
        }
    }
}

/// 工具状态信息
#[derive(Debug, Clone)]
pub struct ToolStatus {
    pub tool_name: String,
    pub installed: bool,
    pub local_version: Option<Version>,
    pub latest_version: Option<Version>,
    pub method: Option<InstallMethod>,
    pub path: Option<PathBuf>,
    pub needs_update: bool,
    pub multiple_installs: bool,
    pub install_methods: Vec<InstallMethod>,
}

/// 包管理器统一接口
#[async_trait]
pub trait PackageManager: Send + Sync {
    fn name(&self) -> &str;
    async fn is_installed(&self, tool: &Tool) -> bool;
    async fn local_version(&self, tool: &Tool) -> Result<Option<Version>>;
    async fn latest_version(&self, tool: &Tool) -> Result<Option<Version>>;
    async fn update(&self, tool: &Tool) -> Result<()>;
    async fn install(&self, tool: &Tool) -> Result<()>;
}

/// 检测工具的安装方式（PATH 优先策略）
pub async fn detect_install_method(tool: &Tool) -> Option<(InstallMethod, Box<dyn PackageManager>)> {
    let tool_path = which::which(tool.command).ok()?;

    if tool.brew_formula.is_some() {
        let adapter = brew::BrewAdapter;
        if adapter.is_path_match(&tool_path) && adapter.is_installed(tool).await {
            return Some((InstallMethod::Brew, Box::new(adapter)));
        }
    }

    if tool.npm_package.is_some() {
        let adapter = npm::NpmAdapter;
        if adapter.is_path_match(&tool_path) && adapter.is_installed(tool).await {
            return Some((InstallMethod::Npm, Box::new(adapter)));
        }
    }

    {
        let adapter = standalone::StandaloneAdapter;
        if adapter.is_path_match(&tool_path) {
            return Some((InstallMethod::Standalone, Box::new(adapter)));
        }
    }

    if tool.pipx_package.is_some() {
        let adapter = pipx::PipxAdapter;
        if adapter.is_installed(tool).await {
            return Some((InstallMethod::Pipx, Box::new(adapter)));
        }
    }

    if tool.uv_package.is_some() {
        let adapter = uv::UvAdapter;
        if adapter.is_installed(tool).await {
            return Some((InstallMethod::Uv, Box::new(adapter)));
        }
    }

    if tool.brew_formula.is_some() {
        let adapter = brew::BrewAdapter;
        if adapter.is_installed(tool).await {
            return Some((InstallMethod::Brew, Box::new(adapter)));
        }
    }

    if tool.npm_package.is_some() {
        let adapter = npm::NpmAdapter;
        if adapter.is_installed(tool).await {
            return Some((InstallMethod::Npm, Box::new(adapter)));
        }
    }

    Some((InstallMethod::Unknown, Box::new(standalone::StandaloneAdapter)))
}

/// 检测所有安装方式
pub async fn detect_all_install_methods(tool: &Tool) -> Vec<InstallMethod> {
    let mut methods = Vec::new();

    if tool.npm_package.is_some() && npm::NpmAdapter.is_installed(tool).await {
        methods.push(InstallMethod::Npm);
    }
    if tool.brew_formula.is_some() && brew::BrewAdapter.is_installed(tool).await {
        methods.push(InstallMethod::Brew);
    }
    if tool.pipx_package.is_some() && pipx::PipxAdapter.is_installed(tool).await {
        methods.push(InstallMethod::Pipx);
    }
    if tool.uv_package.is_some() && uv::UvAdapter.is_installed(tool).await {
        methods.push(InstallMethod::Uv);
    }
    if let Ok(path) = which::which(tool.command) {
        if standalone::StandaloneAdapter::is_path_match_static(&path) {
            methods.push(InstallMethod::Standalone);
        }
    }

    methods
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_install_method_display() {
        assert_eq!(InstallMethod::Npm.to_string(), "npm");
        assert_eq!(InstallMethod::Brew.to_string(), "brew");
        assert_eq!(InstallMethod::Unknown.to_string(), "unknown");
    }
}
