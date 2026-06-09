mod args;
mod commands;
mod output;

use clap::Parser;

fn main() -> anyhow::Result<()> {
    let cli = args::Cli::parse();

    if cli.verbose {
        tracing_subscriber::fmt()
            .with_env_filter("kitup=debug")
            .init();
    } else {
        tracing_subscriber::fmt()
            .with_env_filter("kitup=warn")
            .init();
    }

    match cli.command {
        // TUI 模式
        Some(args::Commands::Tui) | None => {
            run_tui()?;
        }

        // CLI 子命令
        Some(args::Commands::Status { json }) => {
            commands::status::run(json)?;
        }
        Some(args::Commands::Update {
            tools,
            all,
            install,
            dry_run,
            force,
            parallel,
        }) => {
            commands::update::run(tools, all, install, dry_run, force, parallel)?;
        }
        Some(args::Commands::Pin { tool, version }) => {
            commands::pin_cmd::pin(tool, version)?;
        }
        Some(args::Commands::Unpin { tool }) => {
            commands::pin_cmd::unpin(tool)?;
        }
        Some(args::Commands::Changelog { tool, all }) => {
            commands::changelog::run(tool, all)?;
        }
        Some(args::Commands::Doctor { fix, verbose: doc_verbose }) => {
            commands::doctor::run(fix, doc_verbose || cli.verbose)?;
        }
        Some(args::Commands::Provider { action }) => {
            commands::provider::run(action)?;
        }
        Some(args::Commands::Config) => {
            commands::config_cmd::run()?;
        }
        Some(args::Commands::Completions { shell }) => {
            commands::completions::run(shell)?;
        }
        Some(args::Commands::SelfUpdate) => {
            commands::self_update_cmd::run()?;
        }
    }

    Ok(())
}

fn run_tui() -> anyhow::Result<()> {
    let rt = tokio::runtime::Runtime::new()?;
    rt.block_on(async {
        // 在 tokio runtime 中运行 TUI（后台检测需要 async）
        kitup_tui::run()
    })
}
