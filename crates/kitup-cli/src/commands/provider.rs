//! provider 子命令

use crate::args::ProviderAction;
use crate::output;
use anyhow::Result;
use owo_colors::OwoColorize;

pub fn run(action: ProviderAction) -> anyhow::Result<()> {
    let rt = tokio::runtime::Runtime::new()?;
    rt.block_on(async { run_async(action).await })
}

async fn run_async(action: ProviderAction) -> anyhow::Result<()> {
    match action {
        ProviderAction::List => list_providers().await,
        ProviderAction::Switch { name, tool } => switch_provider(&name, tool).await,
        ProviderAction::Test { name } => test_provider(name).await,
        ProviderAction::Add {
            name,
            api_base,
            api_key_env,
            priority,
        } => add_provider(&name, &api_base, api_key_env.as_deref(), priority).await,
        ProviderAction::Remove { name } => remove_provider(&name).await,
    }
}

async fn list_providers() -> Result<()> {
    let config = kitup_provider::ProviderConfig::load()?;

    println!();
    println!("  {} Providers", output::symbols::BULLET.cyan());
    println!("  {}", "─".repeat(50));

    if config.list().is_empty() {
        println!("  No providers configured.");
        println!("  Run {} to add one.", "kitup provider add --name ... --api-base ...".bold());
    } else {
        for provider in config.list() {
            let status_icon = match provider.health.status {
                kitup_provider::ProviderHealth::Ok => "✓".to_string(),
                kitup_provider::ProviderHealth::Degraded => "⚡".to_string(),
                kitup_provider::ProviderHealth::Down => "✗".to_string(),
                kitup_provider::ProviderHealth::Unknown => "○".to_string(),
            };

            let latency = provider
                .health
                .latency_ms
                .map(|ms| format!("{}ms", ms))
                .unwrap_or_else(|| "-".to_string());

            println!(
                "  {} {:<20} {:<35} {:<10} P{}",
                status_icon,
                provider.name.bold(),
                provider.api_base.dimmed(),
                latency,
                provider.priority,
            );
        }
    }

    println!();
    Ok(())
}

async fn switch_provider(name: &str, tool: Option<String>) -> Result<()> {
    let config = kitup_provider::ProviderConfig::load()?;
    let provider = config
        .find(name)
        .ok_or_else(|| anyhow::anyhow!("Provider '{}' not found", name))?
        .clone();

    let api_key_env = provider
        .api_key_env
        .clone()
        .unwrap_or_default();

    // 根据工具选择适配器
    let tools_to_switch: Vec<&str> = if let Some(ref t) = tool {
        vec![t.as_str()]
    } else if provider.tools.is_empty() {
        vec!["claude", "codex", "gemini"]
    } else {
        provider.tools.iter().map(|s| s.as_str()).collect()
    };

    println!();
    println!(
        "  {} Switching to {}...",
        output::symbols::SPINNER.cyan(),
        name.bold()
    );

    for tool_name in &tools_to_switch {
        let result: Result<(), anyhow::Error> = match *tool_name {
            "claude" => {
                let adapter = kitup_provider::provider::ClaudeAdapter;
                kitup_provider::provider::ConfigAdapter::switch_provider(
                    &adapter,
                    &provider.api_base,
                    &api_key_env,
                    provider.model_override.as_deref(),
                )
                .await
            }
            "codex" => {
                let adapter = kitup_provider::provider::CodexAdapter;
                kitup_provider::provider::ConfigAdapter::switch_provider(
                    &adapter,
                    &provider.api_base,
                    &api_key_env,
                    None,
                )
                .await
            }
            "gemini" => {
                let adapter = kitup_provider::provider::GeminiAdapter;
                kitup_provider::provider::ConfigAdapter::switch_provider(
                    &adapter,
                    &provider.api_base,
                    &api_key_env,
                    None,
                )
                .await
            }
            _ => {
                eprintln!("  {} Unknown tool: {}", output::symbols::CROSS.red(), tool_name);
                continue;
            }
        };

        match result {
            Ok(()) => println!(
                "  {} {} switched to {}",
                output::symbols::CHECK.green(),
                tool_name.bold(),
                name.green()
            ),
            Err(e) => eprintln!(
                "  {} {} switch failed: {}",
                output::symbols::CROSS.red(),
                tool_name,
                e.to_string().red()
            ),
        }
    }

    println!();
    Ok(())
}

async fn test_provider(name: Option<String>) -> Result<()> {
    let config = kitup_provider::ProviderConfig::load()?;

    let endpoints: Vec<(String, String)> = if let Some(name) = name {
        let provider = config
            .find(&name)
            .ok_or_else(|| anyhow::anyhow!("Provider '{}' not found", name))?;
        vec![(provider.name.clone(), provider.api_base.clone())]
    } else {
        config
            .list()
            .iter()
            .filter(|p| p.enabled)
            .map(|p| (p.name.clone(), p.api_base.clone()))
            .collect()
    };

    if endpoints.is_empty() {
        println!("  No providers to test.");
        return Ok(());
    }

    println!();
    println!(
        "  {} Testing {} provider{}...",
        "⟳".cyan(),
        endpoints.len().to_string().bold(),
        if endpoints.len() > 1 { "s" } else { "" }
    );
    println!();

    let results = kitup_health::checker::check_endpoints(
        &endpoints
            .iter()
            .map(|(n, u)| (n.as_str(), u.as_str()))
            .collect::<Vec<_>>(),
        10,
    )
    .await;

    for result in &results {
        let status = match (&result.latency_ms, &result.error) {
            (Some(ms), None) if *ms < 200 => format!("{} {} OK", output::symbols::CHECK.green(), ms.to_string().green()),
            (Some(ms), None) => format!("{} {}ms", "⚡".yellow(), ms.to_string().yellow()),
            (_, Some(e)) => format!("{} {}", output::symbols::CROSS.red(), e.red()),
            _ => "unknown".to_string(),
        };

        println!(
            "  {:<20} {:<35} {}",
            result.name.bold(),
            result.endpoint.dimmed(),
            status,
        );
    }

    // 推荐
    if let Some(best) = results.iter().find(|r| r.error.is_none()) {
        println!();
        println!(
            "  {} Recommended: {} ({}ms)",
            output::symbols::BULLET.cyan(),
            best.name.green(),
            best.latency_ms.unwrap_or(0),
        );
    }

    println!();
    Ok(())
}

async fn add_provider(
    name: &str,
    api_base: &str,
    api_key_env: Option<&str>,
    priority: u32,
) -> Result<()> {
    let mut config = kitup_provider::ProviderConfig::load()?;

    // 检查重复
    if config.find(name).is_some() {
        anyhow::bail!("Provider '{}' already exists", name);
    }

    let provider = kitup_provider::Provider {
        id: format!("prov-{}", chrono::Utc::now().timestamp_millis()),
        name: name.to_string(),
        api_base: api_base.to_string(),
        api_key_env: api_key_env.map(|s| s.to_string()),
        model_override: None,
        headers: std::collections::HashMap::new(),
        priority,
        enabled: true,
        tools: vec![],
        health: kitup_provider::HealthStatus::default(),
    };

    config.add(provider)?;
    println!(
        "  {} Added provider {} ({})",
        output::symbols::CHECK.green(),
        name.bold(),
        api_base.dimmed()
    );
    Ok(())
}

async fn remove_provider(name: &str) -> Result<()> {
    let mut config = kitup_provider::ProviderConfig::load()?;
    if config.remove(name)? {
        println!(
            "  {} Removed provider {}",
            output::symbols::CHECK.green(),
            name.bold()
        );
    } else {
        println!(
            "  {} Provider '{}' not found",
            output::symbols::CROSS.red(),
            name
        );
    }
    Ok(())
}
