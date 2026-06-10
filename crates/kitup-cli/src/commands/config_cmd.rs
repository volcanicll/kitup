//! config 子命令

use owo_colors::OwoColorize;

pub fn run() -> anyhow::Result<()> {
    let config = kitup_core::config::Config::load()?;
    let path = kitup_core::config::Config::config_path()?;

    println!();
    println!("  {} Configuration", "●".cyan());
    println!("  {}", "─".repeat(40));
    println!("  File: {}", path.to_string_lossy());
    println!();
    println!("{}", serde_json::to_string_pretty(&config)?);
    println!();

    Ok(())
}
