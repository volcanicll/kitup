//! changelog 子命令

use kitup_core::tool::{Tool, TOOL_REGISTRY};
use owo_colors::OwoColorize;

pub fn run(tool_name: Option<String>, all: bool) -> anyhow::Result<()> {
    let rt = tokio::runtime::Runtime::new()?;
    rt.block_on(async { run_async(tool_name, all).await })
}

async fn run_async(tool_name: Option<String>, all: bool) -> anyhow::Result<()> {
    let config = kitup_core::config::Config::load()?;

    if all {
        for tool in TOOL_REGISTRY {
            if config.exclude_tools.contains(&tool.name.to_string()) {
                continue;
            }
            if let Err(e) = show_changelog(tool, config.changelog_count).await {
                eprintln!("  {} {}: {}", "✗".red(), tool.name, e);
            }
        }
    } else {
        let name = tool_name
            .ok_or_else(|| anyhow::anyhow!("Please specify a tool name or use --all"))?;
        let tool = Tool::find_by_name(&name)
            .ok_or_else(|| anyhow::anyhow!("Unknown tool: {}", name))?;
        show_changelog(tool, config.changelog_count).await?;
    }

    Ok(())
}

async fn show_changelog(tool: &Tool, count: usize) -> anyhow::Result<()> {
    let repo = tool
        .github_repo
        .ok_or_else(|| anyhow::anyhow!("{} has no GitHub repository", tool.name))?;

    let url = format!(
        "https://api.github.com/repos/{}/releases?per_page={}",
        repo, count
    );

    let client = reqwest::Client::new();
    let response = client
        .get(&url)
        .header("User-Agent", "kitup")
        .send()
        .await?;

    if !response.status().is_success() {
        anyhow::bail!("GitHub API returned: {}", response.status());
    }

    let releases: Vec<serde_json::Value> = response.json().await?;

    println!();
    println!(
        "  {} {} — Recent Changes",
        "●".cyan(),
        tool.name.bold()
    );
    println!("  {}", "─".repeat(50));

    for release in &releases {
        let tag = release
            .get("tag_name")
            .and_then(|v| v.as_str())
            .unwrap_or("unknown");
        let date = release
            .get("published_at")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        let body = release
            .get("body")
            .and_then(|v| v.as_str())
            .unwrap_or("No description");

        println!();
        println!("  {} {}", tag.green().bold(), date.dimmed());

        let plain = body
            .lines()
            .take(10)
            .map(|line| {
                line.trim()
                    .trim_start_matches("### ")
                    .trim_start_matches("## ")
                    .replace("**", "")
                    .replace("__", "")
                    .replace('`', "")
            })
            .filter(|line| !line.is_empty() && line != "---")
            .collect::<Vec<_>>()
            .join("\n    ");

        println!("    {}", plain);
    }

    println!();
    Ok(())
}
