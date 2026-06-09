//! pipx 包管理器适配器

use crate::installer::PackageManager;
use crate::tool::Tool;
use crate::version::parse_version;
use anyhow::Result;
use async_trait::async_trait;
use semver::Version;
use tokio::process::Command;

pub struct PipxAdapter;

#[async_trait]
impl PackageManager for PipxAdapter {
    fn name(&self) -> &str { "pipx" }

    async fn is_installed(&self, tool: &Tool) -> bool {
        if let Some(ref pkg) = tool.pipx_package {
            let output = Command::new("pipx")
                .args(["list"])
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
        let output = Command::new(tool.command)
            .args(["--version"])
            .output()
            .await;
        match output {
            Ok(o) if o.status.success() => Ok(parse_version(&String::from_utf8_lossy(&o.stdout))),
            _ => Ok(None),
        }
    }

    async fn latest_version(&self, _tool: &Tool) -> Result<Option<Version>> {
        Ok(None) // pipx 无直接查询，通过 GitHub 获取
    }

    async fn update(&self, tool: &Tool) -> Result<()> {
        if let Some(ref pkg) = tool.pipx_package {
            let status = Command::new("pipx")
                .args(["upgrade", pkg])
                .status()
                .await?;
            if !status.success() {
                anyhow::bail!("pipx upgrade failed for {}", pkg);
            }
        }
        Ok(())
    }

    async fn install(&self, tool: &Tool) -> Result<()> {
        if let Some(ref pkg) = tool.pipx_package {
            let status = Command::new("pipx")
                .args(["install", pkg])
                .status()
                .await?;
            if !status.success() {
                anyhow::bail!("pipx install failed for {}", pkg);
            }
        }
        Ok(())
    }
}
