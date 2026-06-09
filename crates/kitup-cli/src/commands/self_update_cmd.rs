//! self-update 子命令

use anyhow::Result;
use owo_colors::OwoColorize;

pub fn run() -> anyhow::Result<()> {
    let rt = tokio::runtime::Runtime::new()?;
    rt.block_on(async { run_async().await })
}

async fn run_async() -> anyhow::Result<()> {
    let updater = kitup_core::self_update::SelfUpdater::new()?;

    println!();
    println!("  {} Checking for updates...", "⟳".cyan());

    match updater.check_update().await? {
        Some(latest) => {
            let current = env!("CARGO_PKG_VERSION");
            println!(
                "  {} New version available: {} → {}",
                "↑".yellow(),
                current.dimmed(),
                latest.green()
            );
            println!("  Updating...");
            updater.do_update().await?;
            println!("  {} Updated to {}", "✓".green(), latest.green());
        }
        None => {
            println!(
                "  {} Already at latest version ({})",
                "✓".green(),
                env!("CARGO_PKG_VERSION")
            );
        }
    }
    println!();

    Ok(())
}
