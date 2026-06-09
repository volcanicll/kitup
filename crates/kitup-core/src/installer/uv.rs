//! uv 包管理器适配器

use crate::installer::PackageManager;
use crate::tool::Tool;
use crate::version::parse_version;
use anyhow::Result;
use async_trait::async_trait;
use semver::Version;
use tokio::process::Command;

pub struct UvAdapter;

#[async_trait]
impl PackageManager for UvAdapter {
    fn name(&self) -> &str { "uv" }

    async fn is_installed(&self, tool: &Tool) -> bool {
        if let Some(ref pkg) = tool.uv_package {
            let output = Command::new("uv")
                .args(["tool", "list"])
                .output()
                .await;
            match output {
                Ok(output) if output.status.success() => {
                    String::from_utf8_lossy(&output.stdout).contains(pkg)
                }
                _ => false,
            }
        } else {
            false
        }
    }

    async fn local_version(&self, tool: &Tool) -> Result<Option<Version>> {
        if tool.uv_package.is_some() {
            let output = Command::new(tool.command)
                .args(["--version"])
                .output()
                .await;
            if let Ok(output) = output {
                if output.status.success() {
                    return Ok(parse_version(&String::from_utf8_lossy(&output.stdout)));
                }
            }
        }
        Ok(None)
    }

    async fn latest_version(&self, _tool: &Tool) -> Result<Option<Version>> {
        Ok(None) // 通过 GitHub 获取
    }

    async fn update(&self, tool: &Tool) -> Result<()> {
        if let Some(ref pkg) = tool.uv_package {
            let status = Command::new("uv")
                .args(["tool", "upgrade", pkg])
                .status()
                .await?;
            if !status.success() {
                anyhow::bail!("uv tool upgrade failed for {}", pkg);
            }
        }
        Ok(())
    }

    async fn install(&self, tool: &Tool) -> Result<()> {
        if let Some(ref pkg) = tool.uv_package {
            let status = Command::new("uv")
                .args(["tool", "install", pkg])
                .status()
                .await?;
            if !status.success() {
                anyhow::bail!("uv tool install failed for {}", pkg);
            }
        }
        Ok(())
    }
}
