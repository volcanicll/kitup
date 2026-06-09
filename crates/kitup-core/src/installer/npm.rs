//! npm 包管理器适配器

use crate::installer::PackageManager;
use crate::tool::Tool;
use crate::version::parse_version;
use anyhow::Result;
use async_trait::async_trait;
use semver::Version;
use std::path::PathBuf;
use tokio::process::Command;

/// npm 全局包管理器适配器
pub struct NpmAdapter;

impl NpmAdapter {
    fn global_prefix_sync() -> Option<String> {
        let output = std::process::Command::new("npm")
            .args(["prefix", "-g"])
            .output()
            .ok()?;
        if output.status.success() {
            Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
        } else {
            None
        }
    }

    pub fn is_path_match(&self, tool_path: &PathBuf) -> bool {
        if let Some(prefix) = Self::global_prefix_sync() {
            tool_path.starts_with(format!("{}/bin/", prefix))
                || tool_path.starts_with(format!("{}\\", prefix).replace('/', "\\"))
        } else {
            false
        }
    }
}

#[async_trait]
impl PackageManager for NpmAdapter {
    fn name(&self) -> &str { "npm" }

    async fn is_installed(&self, tool: &Tool) -> bool {
        if let Some(ref pkg) = tool.npm_package {
            Command::new("npm")
                .args(["list", "-g", pkg])
                .output()
                .await
                .map(|o| o.status.success())
                .unwrap_or(false)
        } else {
            false
        }
    }

    async fn local_version(&self, tool: &Tool) -> Result<Option<Version>> {
        if let Some(ref pkg) = tool.npm_package {
            let output = Command::new("npm")
                .args(["list", "-g", pkg, "--depth=0", "--json"])
                .output()
                .await?;

            if output.status.success() {
                let json_str = String::from_utf8_lossy(&output.stdout);
                if let Ok(json) = serde_json::from_str::<serde_json::Value>(&json_str) {
                    if let Some(ver) = json
                        .get("dependencies")
                        .and_then(|d| d.get(*pkg))
                        .and_then(|d| d.get("version"))
                        .and_then(|v| v.as_str())
                    {
                        return Ok(parse_version(ver));
                    }
                }
            }

            // 回退：命令行获取
            let output = Command::new("npm")
                .args(["list", "-g", pkg])
                .output()
                .await?;
            Ok(parse_version(&String::from_utf8_lossy(&output.stdout)))
        } else {
            Ok(None)
        }
    }

    async fn latest_version(&self, tool: &Tool) -> Result<Option<Version>> {
        if let Some(ref pkg) = tool.npm_package {
            let output = Command::new("npm")
                .args(["view", pkg, "version"])
                .output()
                .await?;
            if output.status.success() {
                return Ok(parse_version(&String::from_utf8_lossy(&output.stdout)));
            }
        }
        Ok(None)
    }

    async fn update(&self, tool: &Tool) -> Result<()> {
        if let Some(ref pkg) = tool.npm_package {
            let status = Command::new("npm")
                .args(["update", "-g", pkg])
                .status()
                .await?;
            if !status.success() {
                anyhow::bail!("npm update failed for {}", pkg);
            }
        }
        Ok(())
    }

    async fn install(&self, tool: &Tool) -> Result<()> {
        if let Some(ref pkg) = tool.npm_package {
            let status = Command::new("npm")
                .args(["install", "-g", pkg])
                .status()
                .await?;
            if !status.success() {
                anyhow::bail!("npm install failed for {}", pkg);
            }
        }
        Ok(())
    }
}
