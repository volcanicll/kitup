//! doctor 子命令

use kitup_core::installer;
use kitup_core::tool::TOOL_REGISTRY;
use owo_colors::OwoColorize;

pub fn run(fix: bool, verbose: bool) -> anyhow::Result<()> {
    let rt = tokio::runtime::Runtime::new()?;
    rt.block_on(async { run_async(fix, verbose).await })
}

async fn run_async(fix: bool, verbose: bool) -> anyhow::Result<()> {
    println!();
    println!("  {} Running diagnostics...", "⟳".cyan());
    println!();

    let mut issues = 0u32;
    let mut fixable = 0u32;
    let mut passed = 0u32;

    // 1. 配置文件
    match kitup_core::config::Config::load() {
        Ok(_) => {
            if verbose {
                println!(
                    "  {} Configuration OK ({})",
                    "✓".green(),
                    kitup_core::config::Config::config_path()?
                        .to_string_lossy()
                );
            }
            passed += 1;
        }
        Err(e) => {
            println!("  {} Configuration error: {}", "✗".red(), e);
            issues += 1;
            if fix {
                match kitup_core::config::Config::init() {
                    Ok(path) => {
                        println!("  {} Created default config: {}", "✓".green(), path.to_string_lossy());
                        fixable += 1;
                    }
                    Err(e2) => println!("  {} Failed to create config: {}", "✗".red(), e2),
                }
            }
        }
    }

    // 2. 工具检查
    for tool in TOOL_REGISTRY {
        match which::which(tool.command) {
            Ok(path) => {
                if verbose {
                    println!(
                        "  {} {} found at {}",
                        "✓".green(),
                        tool.name.bold(),
                        path.to_string_lossy().dimmed()
                    );
                }
                passed += 1;

                // 多安装检测
                let all_methods = installer::detect_all_install_methods(tool).await;
                if all_methods.len() > 1 {
                    println!(
                        "  {} {} has {} installations: {}",
                        "⚡".yellow(),
                        tool.name.bold(),
                        all_methods.len().to_string().yellow(),
                        all_methods.iter().map(|m| m.to_string()).collect::<Vec<_>>().join(", ")
                    );
                    issues += 1;
                    println!("     └─ 建议: 清理旧安装，保留一个即可");
                }
            }
            Err(_) => {
                if verbose {
                    println!("  {} {} not installed", "○".dimmed(), tool.name);
                }
            }
        }
    }

    // 3. 包管理器
    for (cmd, name) in [("npm", "npm"), ("brew", "Homebrew"), ("pipx", "pipx"), ("uv", "uv")] {
        if which::which(cmd).is_ok() {
            if verbose {
                println!("  {} {} available", "✓".green(), name);
            }
            passed += 1;
        } else if verbose {
            println!("  {} {} not found", "○".dimmed(), name);
        }
    }

    // 4. 网络连通性
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(5))
        .build()?;

    for (url, name) in [
        ("https://registry.npmjs.org/", "npm registry"),
        ("https://api.github.com/", "GitHub API"),
    ] {
        match client.get(url).header("User-Agent", "kitup").send().await {
            Ok(resp) => {
                println!("  {} {} reachable ({})", "✓".green(), name, resp.status().as_u16());
                passed += 1;
            }
            Err(e) => {
                println!("  {} {} unreachable: {}", "✗".red(), name, e.to_string().red());
                issues += 1;
            }
        }
    }

    // 摘要
    println!();
    if issues == 0 {
        println!("  {} All {} checks passed", "✓".green().bold(), passed);
    } else {
        println!(
            "  {} {} issue{} found, {} can be auto-fixed{}",
            if fixable > 0 { "⚡".to_string() } else { "✗".to_string() },
            issues.to_string().yellow(),
            if issues > 1 { "s" } else { "" },
            fixable.to_string().green(),
            if fixable > 0 && !fix {
                format!(" — run {} to fix", "kitup doctor --fix".bold())
            } else {
                String::new()
            }
        );
    }
    println!();

    Ok(())
}
