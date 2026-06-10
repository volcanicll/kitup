//! status 子命令

use crate::output;
use kitup_core::installer::{self, ToolStatus};
use kitup_core::pin::PinnedVersions;
use kitup_core::tool::TOOL_REGISTRY;
use kitup_core::version::VersionCache;
use owo_colors::OwoColorize;

pub fn run(json: bool) -> anyhow::Result<()> {
    let rt = tokio::runtime::Runtime::new()?;
    rt.block_on(async { run_async(json).await })
}

async fn run_async(json: bool) -> anyhow::Result<()> {
    let config = kitup_core::config::Config::load()?;
    let cache = VersionCache::new().ok();
    let _pins = PinnedVersions::load()?;

    let mut statuses = Vec::new();

    for tool in TOOL_REGISTRY {
        let tool_name = tool.name.to_string();
        if config.exclude_tools.contains(&tool_name) {
            continue;
        }

        let tool_path = which::which(tool.command).ok();
        let installed = tool_path.is_some();

        let method_info = if installed {
            installer::detect_install_method(tool).await
        } else {
            None
        };

        let method_ref = method_info.as_ref().map(|(m, _)| m.clone());

        let local_version = if installed {
            if let Some((_, ref adapter)) = method_info {
                adapter.local_version(tool).await.unwrap_or(None)
            } else {
                tokio::process::Command::new(tool.command)
                    .args(["--version"])
                    .output()
                    .await
                    .ok()
                    .and_then(|o| {
                        if o.status.success() {
                            kitup_core::version::parse_version(&String::from_utf8_lossy(&o.stdout))
                        } else {
                            None
                        }
                    })
            }
        } else {
            None
        };

        let latest_version = if installed {
            if let Some((_, ref adapter)) = method_info {
                if let Some(ref cache) = cache {
                    if let Some(v) = cache.get(&tool_name, adapter.name()) {
                        Some(v)
                    } else {
                        match adapter.latest_version(tool).await {
                            Ok(Some(v)) => {
                                let _ = cache.set(&tool_name, adapter.name(), &v);
                                Some(v)
                            }
                            _ => None,
                        }
                    }
                } else {
                    adapter.latest_version(tool).await.unwrap_or(None)
                }
            } else {
                None
            }
        } else {
            None
        };

        let pinned = PinnedVersions::get_pinned(&tool_name)?;
        let needs_update = if pinned.is_some() {
            false
        } else if let (Some(ref local), Some(ref latest)) = (&local_version, &latest_version) {
            latest > local
        } else {
            false
        };

        let all_methods = if installed {
            installer::detect_all_install_methods(tool).await
        } else {
            vec![]
        };

        statuses.push(ToolStatus {
            tool_name,
            installed,
            local_version,
            latest_version,
            method: method_ref,
            path: tool_path,
            needs_update,
            multiple_installs: all_methods.len() > 1,
            install_methods: all_methods,
        });
    }

    if json {
        let json_output = output::format_status_json(&statuses);
        println!("{}", serde_json::to_string_pretty(&json_output)?);
    } else {
        println!();
        println!(
            "  {} v{} {} AI Tools Status",
            "kitup".bold().cyan(),
            env!("CARGO_PKG_VERSION"),
            "─".dimmed()
        );
        println!();
        println!("{}", output::format_status_table(&statuses));
        println!();

        let installed_count = statuses.iter().filter(|s| s.installed).count();
        let update_count = statuses.iter().filter(|s| s.needs_update).count();

        if update_count > 0 {
            println!(
                "  {} Run {} to update {} tool{}",
                output::symbols::BULLET.cyan(),
                "kitup update".bold(),
                update_count.to_string().yellow(),
                if update_count > 1 { "s" } else { "" }
            );
        } else if installed_count > 0 {
            println!(
                "  {} All {} tools are up to date {}",
                output::symbols::CHECK.green(),
                installed_count,
                "🎉"
            );
        }
        println!();
    }

    Ok(())
}
