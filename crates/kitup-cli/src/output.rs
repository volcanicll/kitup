//! 输出格式化工具函数

use comfy_table::{modifiers::UTF8_ROUND_CORNERS, presets::UTF8_FULL, Cell, Color, Table};
use kitup_core::installer::ToolStatus;
use owo_colors::OwoColorize;

pub mod symbols {
    pub const CHECK: &str = "✓";
    pub const CROSS: &str = "✗";
    pub const ARROW_UP: &str = "↑";
    pub const BULLET: &str = "●";
    pub const PIN: &str = "⚑";
    pub const SPINNER: &str = "⟳";
}

pub fn format_status_table(statuses: &[ToolStatus]) -> String {
    let mut table = Table::new();
    table
        .load_preset(UTF8_FULL)
        .apply_modifier(UTF8_ROUND_CORNERS)
        .set_header(vec![
            Cell::new("Tool"),
            Cell::new("Installed"),
            Cell::new("Latest"),
            Cell::new("Method"),
            Cell::new("Status"),
        ]);

    for status in statuses {
        let name = status.tool_name.clone();
        let installed = status
            .local_version
            .as_ref()
            .map(|v| v.to_string())
            .unwrap_or_else(|| "-".to_string());

        let latest = status
            .latest_version
            .as_ref()
            .map(|v| v.to_string())
            .unwrap_or_else(|| "-".to_string());

        let method = status
            .method
            .as_ref()
            .map(|m| m.to_string())
            .unwrap_or_else(|| "-".to_string());

        let (status_text, color) = if !status.installed {
            ("not installed".to_string(), Color::DarkGrey)
        } else if status.needs_update {
            ("update available".to_string(), Color::Yellow)
        } else {
            ("up to date".to_string(), Color::Green)
        };

        let status_cell = if status.multiple_installs {
            Cell::new(format!("{} ⚡ 2+ installs", status_text)).fg(Color::Magenta)
        } else {
            Cell::new(status_text).fg(color)
        };

        table.add_row(vec![
            Cell::new(name),
            Cell::new(installed),
            Cell::new(latest),
            Cell::new(method),
            status_cell,
        ]);
    }

    table.to_string()
}

pub fn format_status_json(statuses: &[ToolStatus]) -> serde_json::Value {
    let tools: Vec<serde_json::Value> = statuses
        .iter()
        .map(|s| {
            serde_json::json!({
                "name": s.tool_name,
                "installed": s.installed,
                "local_version": s.local_version.as_ref().map(|v| v.to_string()),
                "latest_version": s.latest_version.as_ref().map(|v| v.to_string()),
                "method": s.method.as_ref().map(|m| m.to_string()),
                "status": if !s.installed { "not_installed" }
                          else if s.needs_update { "update_available" }
                          else { "up_to_date" },
                "path": s.path.as_ref().map(|p| p.to_string_lossy().to_string()),
                "multiple_installs": s.multiple_installs,
            })
        })
        .collect();

    serde_json::json!({
        "kitup_version": env!("CARGO_PKG_VERSION"),
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "tools": tools,
    })
}

pub fn format_update_summary(
    results: &[(String, String, String, String, bool)],
    total_time: std::time::Duration,
) -> String {
    let mut lines = Vec::new();
    let mut updated = 0u32;
    let mut failed = 0u32;
    let mut skipped = 0u32;

    for (name, old_ver, new_ver, method, success) in results {
        if !success {
            failed += 1;
            lines.push(format!(
                "  {} {} {} ({})",
                symbols::CROSS.red(),
                name.bold(),
                new_ver.red(),
                method.dimmed()
            ));
        } else if old_ver == new_ver {
            skipped += 1;
            lines.push(format!(
                "  {} {} {} ({})",
                symbols::CHECK.green(),
                name.bold(),
                old_ver.dimmed(),
                method.dimmed()
            ));
        } else {
            updated += 1;
            lines.push(format!(
                "  {} {} {} → {} ({})",
                symbols::CHECK.green(),
                name.bold(),
                old_ver.dimmed(),
                new_ver.green(),
                method.dimmed()
            ));
        }
    }

    lines.push(String::new());
    lines.push(format!(
        "  {} Updated: {} │ Skipped: {} │ Failed: {} │ Time: {:.1}s",
        symbols::BULLET.cyan(),
        updated.to_string().green(),
        skipped.to_string().yellow(),
        failed.to_string().red(),
        total_time.as_secs_f64(),
    ));

    lines.join("\n")
}
