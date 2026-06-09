//! Homebrew 包管理器适配器

use crate::installer::PackageManager;
use crate::tool::Tool;
use crate::version::parse_version;
use anyhow::Result;
use async_trait::async_trait;
use semver::Version;
use std::path::PathBuf;
use tokio::process::Command;

pub struct BrewAdapter;

impl BrewAdapter {
    fn brew_prefix_sync() -> Option<String> {
        let output = std::process::Command::new("brew")
            .args(["--prefix"])
            .output()
            .ok()?;
        if output.status.success() {
            Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
        } else {
            None
        }
    }

    pub fn is_path_match(&self, tool_path: &PathBuf) -> bool {
        if let Some(prefix) = Self::brew_prefix_sync() {
            tool_path.starts_with(format!("{}/bin/", prefix))
        } else {
            false
        }
    }
}

#[async_trait]
impl PackageManager for BrewAdapter {
    fn name(&self) -> &str { "brew" }

    async fn is_installed(&self, tool: &Tool) -> bool {
        if let Some(ref formula) = tool.brew_formula {
            let output = Command::new("brew")
                .args(["list", formula])
                .output()
                .await;
            if matches!(output, Ok(o) if o.status.success()) {
                return true;
            }
            // 尝试 cask
            let output = Command::new("brew")
                .args(["list", "--cask", formula])
                .output()
                .await;
            matches!(output, Ok(o) if o.status.success())
        } else {
            false
        }
    }

    async fn local_version(&self, tool: &Tool) -> Result<Option<Version>> {
        if let Some(ref formula) = tool.brew_formula {
            let output = Command::new("brew")
                .args(["info", formula, "--json"])
                .output()
                .await?;

            if output.status.success() {
                let json_str = String::from_utf8_lossy(&output.stdout);
                if let Ok(json) = serde_json::from_str::<serde_json::Value>(&json_str) {
                    if let Some(arr) = json.as_array() {
                        if let Some(first) = arr.first() {
                            if let Some(stable) = first
                                .get("versions")
                                .and_then(|v| v.get("stable"))
                                .and_then(|v| v.as_str())
                            {
                                return Ok(parse_version(stable));
                            }
                            if let Some(ver) = first.get("version").and_then(|v| v.as_str()) {
                                return Ok(parse_version(ver));
                            }
                        }
                    }
                }
            }

            let output = Command::new("brew")
                .args(["list", formula, "--versions"])
                .output()
                .await?;
            Ok(parse_version(&String::from_utf8_lossy(&output.stdout)))
        } else {
            Ok(None)
        }
    }

    async fn latest_version(&self, tool: &Tool) -> Result<Option<Version>> {
        self.local_version(tool).await
    }

    async fn update(&self, tool: &Tool) -> Result<()> {
        if let Some(ref formula) = tool.brew_formula {
            let status = Command::new("brew")
                .args(["upgrade", formula])
                .status()
                .await?;
            if !status.success() {
                let status = Command::new("brew")
                    .args(["upgrade", "--cask", formula])
                    .status()
                    .await?;
                if !status.success() {
                    anyhow::bail!("brew upgrade failed for {}", formula);
                }
            }
        }
        Ok(())
    }

    async fn install(&self, tool: &Tool) -> Result<()> {
        if let Some(ref formula) = tool.brew_formula {
            let status = Command::new("brew")
                .args(["install", formula])
                .status()
                .await?;
            if !status.success() {
                let status = Command::new("brew")
                    .args(["install", "--cask", formula])
                    .status()
                    .await?;
                if !status.success() {
                    anyhow::bail!("brew install failed for {}", formula);
                }
            }
        }
        Ok(())
    }
}
