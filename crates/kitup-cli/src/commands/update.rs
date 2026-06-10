//! update 子命令

use crate::output;
use indicatif::{MultiProgress, ProgressBar, ProgressStyle};
use kitup_core::config::Config;
use kitup_core::installer;
use kitup_core::pin::PinnedVersions;
use kitup_core::tool::TOOL_REGISTRY;
use owo_colors::OwoColorize;
use std::sync::Arc;
use std::time::Instant;
use tokio::sync::Semaphore;

pub fn run(
    tools: Vec<String>,
    all: bool,
    install: bool,
    dry_run: bool,
    force: bool,
    parallel: usize,
) -> anyhow::Result<()> {
    let rt = tokio::runtime::Runtime::new()?;
    rt.block_on(async { run_async(tools, all, install, dry_run, force, parallel).await })
}

async fn run_async(
    tool_names: Vec<String>,
    all: bool,
    install: bool,
    dry_run: bool,
    force: bool,
    parallel: usize,
) -> anyhow::Result<()> {
    let config = Config::load()?;
    let _pins = PinnedVersions::load()?;
    let start = Instant::now();

    let targets: Vec<_> = if all || tool_names.is_empty() {
        TOOL_REGISTRY
            .iter()
            .filter(|t| !config.exclude_tools.contains(&t.name.to_string()))
            .collect()
    } else {
        tool_names
            .iter()
            .filter_map(|name| {
                let tool = kitup_core::tool::Tool::find_by_name(name);
                if tool.is_none() {
                    eprintln!(
                        "  {} Unknown tool: {}",
                        output::symbols::CROSS.red(),
                        name.bold()
                    );
                }
                tool
            })
            .collect()
    };

    if targets.is_empty() {
        println!("  No tools to update.");
        return Ok(());
    }

    println!();
    println!(
        "  {} Updating {} tool{}...",
        "⟳".cyan(),
        targets.len().to_string().bold(),
        if targets.len() > 1 { "s" } else { "" }
    );
    println!();

    let semaphore = Arc::new(Semaphore::new(parallel));
    let mut handles = Vec::new();
    let multi = Arc::new(MultiProgress::new());

    for tool in targets {
        let tool_name = tool.name.to_string();
        let sem = semaphore.clone();
        let multi = multi.clone();

        let handle = tokio::spawn(async move {
            let _permit = sem.acquire().await.unwrap();

            let pb = multi.add(ProgressBar::new_spinner());
            pb.set_style(
                ProgressStyle::with_template("{spinner:.green} {msg}")
                    .unwrap()
                    .tick_strings(&["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]),
            );
            pb.set_message(format!("{} checking...", tool_name));

            // 检查固定
            if let Ok(Some(pinned_ver)) = PinnedVersions::get_pinned(&tool_name) {
                if !force {
                    pb.finish_with_message(format!(
                        "  {} {} pinned at {}",
                        output::symbols::PIN.yellow(),
                        tool_name.bold(),
                        pinned_ver.dimmed()
                    ));
                    return (tool_name, pinned_ver.clone(), pinned_ver, "pinned".to_string(), true);
                }
            }

            // 检测安装方式
            let method_info = installer::detect_install_method(tool).await;

            if method_info.is_none() {
                if install && tool.npm_package.is_some() && !dry_run {
                    let adapter = kitup_core::installer::npm::NpmAdapter;
                    pb.set_message(format!("{} installing...", tool_name));
                    match kitup_core::installer::PackageManager::install(&adapter, tool).await {
                        Ok(()) => {
                            pb.finish_with_message(format!(
                                "  {} {} installed",
                                output::symbols::CHECK.green(),
                                tool_name.bold(),
                            ));
                            return (tool_name, "-".into(), "installed".into(), "npm".into(), true);
                        }
                        Err(e) => {
                            pb.finish_with_message(format!(
                                "  {} {} failed: {}",
                                output::symbols::CROSS.red(),
                                tool_name.bold(),
                                e.to_string().red()
                            ));
                            return (tool_name, "-".into(), e.to_string(), "npm".into(), false);
                        }
                    }
                }
                pb.finish_with_message(format!(
                    "  {} {} not installed",
                    output::symbols::PIN.dimmed(),
                    tool_name,
                ));
                return (tool_name, "-".into(), "not installed".into(), "-".into(), true);
            }

            let (method, adapter) = method_info.unwrap();
            let method_str = method.to_string();

            let local_ver = adapter
                .local_version(tool)
                .await
                .unwrap_or(None)
                .map(|v| v.to_string())
                .unwrap_or_else(|| "?".to_string());

            let latest_ver = adapter
                .latest_version(tool)
                .await
                .unwrap_or(None)
                .map(|v| v.to_string())
                .unwrap_or_else(|| local_ver.clone());

            if !force && local_ver == latest_ver {
                pb.finish_with_message(format!(
                    "  {} {} {} ({})",
                    output::symbols::CHECK.green(),
                    tool_name.bold(),
                    local_ver.dimmed(),
                    method_str.dimmed(),
                ));
                return (tool_name, local_ver.clone(), local_ver, method_str, true);
            }

            if dry_run {
                pb.finish_with_message(format!(
                    "  {} {} {} → {} ({}) [dry-run]",
                    output::symbols::ARROW_UP.yellow(),
                    tool_name.bold(),
                    local_ver.dimmed(),
                    latest_ver.green(),
                    method_str.dimmed(),
                ));
                return (tool_name, local_ver, latest_ver, method_str, true);
            }

            pb.set_message(format!(
                "{} {} → {} ({})",
                output::symbols::SPINNER.cyan(),
                local_ver,
                latest_ver.green(),
                method_str
            ));

            match adapter.update(tool).await {
                Ok(()) => {
                    pb.finish_with_message(format!(
                        "  {} {} {} → {} ({})",
                        output::symbols::CHECK.green(),
                        tool_name.bold(),
                        local_ver.dimmed(),
                        latest_ver.green(),
                        method_str.dimmed(),
                    ));
                    (tool_name, local_ver, latest_ver, method_str, true)
                }
                Err(e) => {
                    pb.finish_with_message(format!(
                        "  {} {} failed: {}",
                        output::symbols::CROSS.red(),
                        tool_name.bold(),
                        e.to_string().red()
                    ));
                    (tool_name, local_ver, e.to_string(), method_str, false)
                }
            }
        });

        handles.push(handle);
    }

    let mut results = Vec::new();
    for handle in handles {
        if let Ok(result) = handle.await {
            results.push(result);
        }
    }

    let elapsed = start.elapsed();
    println!();
    println!(
        "{}",
        output::format_update_summary(
            &results
                .iter()
                .map(|(n, o, v, m, s)| (n.clone(), o.clone(), v.clone(), m.clone(), *s))
                .collect::<Vec<_>>(),
            elapsed,
        )
    );
    println!();

    Ok(())
}
