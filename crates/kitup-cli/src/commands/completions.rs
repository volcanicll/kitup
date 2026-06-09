//! completions 子命令

use anyhow::Result;
use clap::CommandFactory;

pub fn run(shell: clap_complete::Shell) -> anyhow::Result<()> {
    let mut cmd = crate::args::Cli::command();
    clap_complete::generate(shell, &mut cmd, "kitup", &mut std::io::stdout());
    Ok(())
}
