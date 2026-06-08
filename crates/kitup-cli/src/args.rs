use clap::{Parser, Subcommand};

/// A unified updater for AI coding assistants
#[derive(Parser)]
#[command(name = "kitup", version, about)]
pub struct Cli {
    /// Enable verbose output
    #[arg(short, long)]
    pub verbose: bool,

    /// Subcommand
    #[command(subcommand)]
    pub command: Option<Commands>,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Check status of all tools
    Status {
        /// Output in JSON format
        #[arg(long)]
        json: bool,
    },
    /// Update tools
    Update {
        /// Tool names to update
        tools: Vec<String>,
        /// Update all installed tools
        #[arg(short, long)]
        all: bool,
        /// Also install missing tools
        #[arg(short, long)]
        install: bool,
        /// Preview without making changes
        #[arg(short, long)]
        dry_run: bool,
        /// Force update even if up to date
        #[arg(short, long)]
        force: bool,
        /// Number of parallel jobs
        #[arg(short, long, default_value = "3")]
        parallel: usize,
    },
    /// Pin a tool to a specific version
    Pin {
        /// Tool name
        tool: String,
        /// Version to pin
        version: String,
    },
    /// Remove version pin for a tool
    Unpin {
        /// Tool name
        tool: String,
    },
    /// Show changelog for a tool
    Changelog {
        /// Tool name (use --all for all tools)
        tool: Option<String>,
        /// Show changelog for all tools
        #[arg(long)]
        all: bool,
    },
    /// Run diagnostics
    Doctor {
        /// Auto-fix issues
        #[arg(long)]
        fix: bool,
        /// Verbose diagnostics
        #[arg(short, long)]
        verbose: bool,
    },
    /// Show or manage configuration
    Config,
    /// Generate shell completions
    Completions {
        /// Shell type
        shell: clap_complete::Shell,
    },
    /// Update kitup itself
    #[command(name = "self-update")]
    SelfUpdate,
}
