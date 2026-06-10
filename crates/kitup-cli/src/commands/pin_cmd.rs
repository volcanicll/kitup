//! pin/unpin 子命令

use crate::output;
use kitup_core::pin::PinnedVersions;
use kitup_core::tool::Tool;
use owo_colors::OwoColorize;

pub fn pin(tool_name: String, version: String) -> anyhow::Result<()> {
    if Tool::find_by_name(&tool_name).is_none() {
        anyhow::bail!("Unknown tool: {}", tool_name);
    }
    PinnedVersions::pin(&tool_name, &version)?;
    println!(
        "  {} Pinned {} to {}",
        output::symbols::PIN.yellow(),
        tool_name.bold(),
        version.green()
    );
    Ok(())
}

pub fn unpin(tool_name: String) -> anyhow::Result<()> {
    if Tool::find_by_name(&tool_name).is_none() {
        anyhow::bail!("Unknown tool: {}", tool_name);
    }
    let removed = PinnedVersions::unpin(&tool_name)?;
    if removed {
        println!(
            "  {} Unpinned {}",
            output::symbols::CHECK.green(),
            tool_name.bold()
        );
    } else {
        println!(
            "  {} {} was not pinned",
            output::symbols::BULLET.dimmed(),
            tool_name
        );
    }
    Ok(())
}
