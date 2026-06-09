use clap::{Parser, Subcommand};

/// A unified updater for AI coding assistants
#[derive(Parser)]
#[command(name = "kitup", version, about)]
pub struct Cli {
    /// Enable verbose output
    #[arg(short, long)]
    pub verbose: bool,

    #[command(subcommand)]
    pub command: Option<Commands>,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Open interactive TUI dashboard (default when no command given)
    Tui,
    /// Check status of all tools
    Status {
        #[arg(long)]
        json: bool,
    },
    /// Update tools
    Update {
        tools: Vec<String>,
        #[arg(short, long)]
        all: bool,
        #[arg(short, long)]
        install: bool,
        #[arg(short, long)]
        dry_run: bool,
        #[arg(short, long)]
        force: bool,
        #[arg(short, long, default_value = "3")]
        parallel: usize,
    },
    /// Pin a tool to a specific version
    Pin {
        tool: String,
        version: String,
    },
    /// Remove version pin for a tool
    Unpin {
        tool: String,
    },
    /// Show changelog for a tool
    Changelog {
        tool: Option<String>,
        #[arg(long)]
        all: bool,
    },
    /// Run diagnostics
    Doctor {
        #[arg(long)]
        fix: bool,
        #[arg(short, long)]
        verbose: bool,
    },
    /// Manage API providers
    Provider {
        #[command(subcommand)]
        action: ProviderAction,
    },
    /// Show configuration
    Config,
    /// Generate shell completions
    Completions {
        shell: clap_complete::Shell,
    },
    /// Update kitup itself
    #[command(name = "self-update")]
    SelfUpdate,
}

#[derive(Subcommand)]
pub enum ProviderAction {
    /// List all providers
    List,
    /// Switch to a provider
    Switch {
        /// Provider name
        name: String,
        /// Tool to switch (default: all)
        #[arg(short, long)]
        tool: Option<String>,
    },
    /// Test provider connectivity and latency
    Test {
        /// Provider name (omit to test all)
        name: Option<String>,
    },
    /// Add a new provider
    Add {
        #[arg(long)]
        name: String,
        #[arg(long)]
        api_base: String,
        #[arg(long)]
        api_key_env: Option<String>,
        #[arg(long, default_value = "1")]
        priority: u32,
    },
    /// Remove a provider
    Remove {
        name: String,
    },
}
