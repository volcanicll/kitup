//! TUI 仪表盘主界面渲染

use crate::app::{App, Tab};
use ratatui::prelude::*;
use ratatui::widgets::*;

pub fn render(f: &mut Frame, app: &App) {
    let size = f.area();

    // 整体布局: 标题栏 | 主内容 | 操作栏 | 状态栏
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(1),  // 标题
            Constraint::Min(10),   // 主内容
            Constraint::Length(2),  // 操作栏
            Constraint::Length(1),  // 状态栏
        ])
        .split(size);

    // 标题栏
    render_title(f, app, chunks[0]);

    // 主内容区（根据 Tab 切换）
    match app.tab {
        Tab::Tools => render_tools_tab(f, app, chunks[1]),
        Tab::Providers => render_providers_tab(f, app, chunks[1]),
        Tab::Health => render_health_tab(f, app, chunks[1]),
    }

    // 操作栏
    render_actions(f, app, chunks[2]);

    // 状态栏
    render_status(f, app, chunks[3]);

    // 帮助弹窗
    if app.show_help {
        render_help_popup(f);
    }
}

fn render_title(f: &mut Frame, app: &App, area: Rect) {
    let version = env!("CARGO_PKG_VERSION");
    let active = match app.tab {
        Tab::Tools => 0,
        Tab::Providers => 1,
        Tab::Health => 2,
    };

    let tabs = Tabs::new(vec!["1:Tools", "2:Providers", "3:Health"])
        .select(active)
        .style(Style::default().fg(Color::Cyan))
        .highlight_style(Style::default().bold());

    let title = Line::from(vec![
        Span::styled(
            format!(" kitup v{} ", version),
            Style::default().bold().fg(Color::Cyan),
        ),
        Span::raw("  "),
        Span::styled("[q]uit [?]help", Style::default().fg(Color::DarkGray)),
    ]);

    let block = Block::default().title(title);
    f.render_widget(block, area);
}

fn render_tools_tab(f: &mut Frame, app: &App, area: Rect) {
    let show_detail = app.show_detail && !app.tools.is_empty();

    if show_detail {
        let chunks = Layout::default()
            .direction(Direction::Horizontal)
            .constraints([Constraint::Percentage(55), Constraint::Percentage(45)])
            .split(area);

        render_tools_list(f, app, chunks[0]);
        render_detail(f, app, chunks[1]);
    } else {
        render_tools_list(f, app, area);
    }
}

fn render_tools_list(f: &mut Frame, app: &App, area: Rect) {
    let items: Vec<ListItem> = app
        .tools
        .iter()
        .enumerate()
        .map(|(i, tool)| {
            let (icon, status, style) = if tool.loading {
                ("⟳", "loading...", Style::default().fg(Color::DarkGray))
            } else if !tool.installed {
                ("○", "not installed", Style::default().fg(Color::DarkGray))
            } else if tool.needs_update {
                let sel = if app.selected[i] { "◉" } else { "○" };
                (sel, "update available", Style::default().fg(Color::Yellow))
            } else {
                let sel = if app.selected[i] { "◉" } else { "○" };
                (sel, "up to date", Style::default().fg(Color::Green))
            };

            let version_str = match (&tool.local_version, &tool.latest_version) {
                (Some(l), Some(lat)) if tool.needs_update => format!("{} → {}", l, lat),
                (Some(l), _) => l.to_string(),
                _ => "-".to_string(),
            };

            let marker = if app.selected[i] && tool.installed { "◉" } else { icon };

            let line = Line::from(vec![
                Span::styled(format!(" {} ", marker), style),
                Span::styled(format!("{:<12}", tool.name), Style::default().bold()),
                Span::styled(format!("{:<20}", version_str), Style::default()),
                Span::styled(
                    format!("{:<10}", tool.method.as_deref().unwrap_or("-")),
                    Style::default().fg(Color::DarkGray),
                ),
                Span::styled(status, style),
            ]);

            let bg = if i == app.cursor {
                Style::default().bg(Color::DarkGray)
            } else {
                Style::default()
            };

            ListItem::new(line).style(bg)
        })
        .collect();

    let list = List::new(items).block(
        Block::default()
            .borders(Borders::ALL)
            .title(" Tools "),
    );

    f.render_widget(list, area);
}

fn render_detail(f: &mut Frame, app: &App, area: Rect) {
    let tool = &app.tools[app.cursor];

    let version = tool
        .local_version
        .as_ref()
        .map(|v| v.to_string())
        .unwrap_or_else(|| "-".to_string());

    let latest = tool
        .latest_version
        .as_ref()
        .map(|v| v.to_string())
        .unwrap_or_else(|| "-".to_string());

    let lines = vec![
        Line::from(Span::styled(
            format!(" {} ", tool.name),
            Style::default().bold().fg(Color::Cyan),
        )),
        Line::from(""),
        Line::from(vec![
            Span::raw("  Version:    "),
            Span::styled(version.clone(), Style::default()),
        ]),
        Line::from(vec![
            Span::raw("  Latest:     "),
            Span::styled(
                latest.clone(),
                if tool.needs_update {
                    Style::default().fg(Color::Yellow)
                } else {
                    Style::default().fg(Color::Green)
                },
            ),
        ]),
        Line::from(vec![
            Span::raw("  Method:     "),
            Span::styled(
                tool.method.as_deref().unwrap_or("-"),
                Style::default(),
            ),
        ]),
        Line::from(vec![
            Span::raw("  Path:       "),
            Span::styled(
                tool.path
                    .as_ref()
                    .map(|p| p.to_string_lossy().to_string())
                    .unwrap_or_else(|| "-".to_string()),
                Style::default().fg(Color::DarkGray),
            ),
        ]),
        Line::from(""),
        Line::from(Span::styled(
            "  [Enter] close detail",
            Style::default().fg(Color::DarkGray),
        )),
    ];

    let paragraph = Paragraph::new(lines).block(
        Block::default()
            .borders(Borders::ALL)
            .title(" Details "),
    );

    f.render_widget(paragraph, area);
}

fn render_providers_tab(f: &mut Frame, app: &App, area: Rect) {
    let lines = vec![
        Line::from(""),
        Line::from(Span::styled(
            "  Provider management will be available in a future update.",
            Style::default().fg(Color::Yellow),
        )),
        Line::from(""),
        Line::from("  Use CLI commands:"),
        Line::from(Span::raw("    kitup provider list")),
        Line::from(Span::raw("    kitup provider switch <name>")),
        Line::from(Span::raw("    kitup provider test")),
    ];

    let paragraph = Paragraph::new(lines).block(
        Block::default()
            .borders(Borders::ALL)
            .title(" Providers "),
    );
    f.render_widget(paragraph, area);
}

fn render_health_tab(f: &mut Frame, app: &App, area: Rect) {
    let lines = vec![
        Line::from(""),
        Line::from(Span::styled(
            "  Health check dashboard will be available in a future update.",
            Style::default().fg(Color::Yellow),
        )),
        Line::from(""),
        Line::from("  Use CLI commands:"),
        Line::from(Span::raw("    kitup doctor")),
        Line::from(Span::raw("    kitup doctor --fix")),
    ];

    let paragraph = Paragraph::new(lines).block(
        Block::default()
            .borders(Borders::ALL)
            .title(" Health "),
    );
    f.render_widget(paragraph, area);
}

fn render_actions(f: &mut Frame, app: &App, area: Rect) {
    let (installed, updates, selected) = app.stats();

    let actions = vec![
        Span::styled(
            " [u]pdate",
            if selected > 0 { Style::default().fg(Color::Green).bold() } else { Style::default().fg(Color::DarkGray) },
        ),
        Span::raw("  "),
        Span::styled("[a]ll", Style::default().fg(Color::Cyan)),
        Span::raw("  "),
        Span::styled("[Space]select", Style::default().fg(Color::Cyan)),
        Span::raw("  "),
        Span::styled("[Enter]detail", Style::default().fg(Color::Cyan)),
        Span::raw("  "),
        Span::styled("[/]search", Style::default().fg(Color::Cyan)),
        Span::raw("  "),
        Span::styled("[Tab]switch", Style::default().fg(Color::DarkGray)),
    ];

    let paragraph = Paragraph::new(Line::from(actions));
    f.render_widget(paragraph, area);
}

fn render_status(f: &mut Frame, app: &App, area: Rect) {
    let (installed, updates, selected) = app.stats();

    let status = Line::from(vec![
        Span::styled(
            format!(" ● {} installed", installed),
            Style::default().fg(Color::Green),
        ),
        Span::raw("  "),
        Span::styled(
            format!("↑ {} updates", updates),
            if updates > 0 { Style::default().fg(Color::Yellow) } else { Style::default().fg(Color::DarkGray) },
        ),
        Span::raw("  "),
        Span::styled(
            format!("◉ {} selected", selected),
            if selected > 0 { Style::default().fg(Color::Cyan) } else { Style::default().fg(Color::DarkGray) },
        ),
        Span::raw("  "),
        Span::styled(
            if app.searching { format!("search: {}", app.search_query) } else { String::new() },
            Style::default().fg(Color::Magenta),
        ),
    ]);

    let paragraph = Paragraph::new(status);
    f.render_widget(paragraph, area);
}

fn render_help_popup(f: &mut Frame) {
    let area = centered_rect(50, 60, f.area());

    let help_text = vec![
        Line::from(Span::styled(" Keyboard Shortcuts ", Style::default().bold().fg(Color::Cyan))),
        Line::from(""),
        Line::from("  ↑/k      Move up"),
        Line::from("  ↓/j      Move down"),
        Line::from("  Space    Toggle selection"),
        Line::from("  a        Select/deselect all"),
        Line::from("  u        Update selected tools"),
        Line::from("  Enter    Show/hide detail panel"),
        Line::from("  /        Start search"),
        Line::from("  Tab      Next tab"),
        Line::from("  1/2/3    Switch to Tools/Providers/Health"),
        Line::from("  ?        Toggle this help"),
        Line::from("  q/Esc    Quit"),
        Line::from(""),
        Line::from(Span::styled(" Press any key to close", Style::default().fg(Color::DarkGray))),
    ];

    let paragraph = Paragraph::new(help_text)
        .block(Block::default().borders(Borders::ALL).title(" Help "))
        .style(Style::default().bg(Color::Black));

    f.render_widget(Clear, area);
    f.render_widget(paragraph, area);
}

fn centered_rect(percent_x: u16, percent_y: u16, r: Rect) -> Rect {
    let popup_layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage((100 - percent_y) / 2),
            Constraint::Percentage(percent_y),
            Constraint::Percentage((100 - percent_y) / 2),
        ])
        .split(r);

    Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage((100 - percent_x) / 2),
            Constraint::Percentage(percent_x),
            Constraint::Percentage((100 - percent_x) / 2),
        ])
        .split(popup_layout[1])[1]
}
