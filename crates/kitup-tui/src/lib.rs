//! kitup-tui: 极致 TUI 交互界面
//!
//! 基于 ratatui 的多面板交互式仪表盘

pub mod app;
pub mod dashboard;

use anyhow::Result;
use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::prelude::*;
use std::time::Duration;

/// 运行 TUI 主循环
pub fn run() -> Result<()> {
    // 设置终端
    enable_raw_mode()?;
    let mut stdout = std::io::stdout();
    crossterm::execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    // 初始化应用状态
    let mut app = app::App::new();

    // 在后台检测工具版本
    let (tx, rx) = std::sync::mpsc::channel();
    std::thread::spawn(move || {
        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(async {
            app::detect_all_tools(tx).await;
        });
    });

    // 主循环
    let (update_tx, update_rx) = std::sync::mpsc::channel();
    let result = run_app(&mut terminal, &mut app, &rx, &update_rx, update_tx);

    // 恢复终端
    disable_raw_mode()?;
    crossterm::execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    result
}

fn run_app(
    terminal: &mut Terminal<CrosstermBackend<std::io::Stdout>>,
    app: &mut app::App,
    rx: &std::sync::mpsc::Receiver<app::ToolUpdate>,
    update_rx: &std::sync::mpsc::Receiver<app::UpdateEvent>,
    update_tx: std::sync::mpsc::Sender<app::UpdateEvent>,
) -> Result<()> {
    loop {
        // 非阻塞接收版本检测结果
        loop {
            match rx.try_recv() {
                Ok(update) => app.apply_update(update),
                Err(std::sync::mpsc::TryRecvError::Empty) => break,
                Err(std::sync::mpsc::TryRecvError::Disconnected) => {
                    // 检测线程结束
                    app.detecting = false;
                    if app.tools.is_empty() {
                        app.status_message = "No tools detected".to_string();
                    } else {
                        let count = app.tools.len();
                        app.status_message = format!("Detected {} tool(s)", count);
                    }
                    break;
                }
            }
        }

        // 非阻塞接收更新进度
        while let Ok(event) = update_rx.try_recv() {
            app.apply_update_event(event);
        }

        // 渲染
        terminal.draw(|f| dashboard::render(f, app))?;

        // 处理输入
        if event::poll(Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    // 搜索模式下优先处理 Esc 退出搜索
                    if app.is_searching() {
                        match key.code {
                            KeyCode::Esc => app.stop_search(),
                            KeyCode::Char(c) => {
                                app.search_query.push(c);
                            }
                            KeyCode::Backspace => {
                                app.search_query.pop();
                            }
                            _ => {}
                        }
                        continue;
                    }

                    match key.code {
                        KeyCode::Char('q') | KeyCode::Esc => return Ok(()),
                        KeyCode::Up | KeyCode::Char('k') => app.move_up(),
                        KeyCode::Down | KeyCode::Char('j') => app.move_down(),
                        KeyCode::Char(' ') => app.toggle_selected(),
                        KeyCode::Char('a') => app.toggle_all(),
                        KeyCode::Char('u') => {
                            if app.tab == app::Tab::Tools {
                                if let Some(names) = app.prepare_update() {
                                    let tx = update_tx.clone();
                                    std::thread::spawn(move || {
                                        let rt = tokio::runtime::Runtime::new().unwrap();
                                        rt.block_on(async {
                                            app::update_tools(names, tx).await;
                                        });
                                    });
                                }
                            }
                        }
                        KeyCode::Enter => app.show_detail(),
                        KeyCode::Char('?') => app.toggle_help(),
                        KeyCode::Tab => app.next_tab(),
                        KeyCode::BackTab => app.prev_tab(),
                        KeyCode::Char('1') => app.set_tab(app::Tab::Tools),
                        KeyCode::Char('2') => app.set_tab(app::Tab::Providers),
                        KeyCode::Char('3') => app.set_tab(app::Tab::Health),
                        KeyCode::Char('/') => app.start_search(),
                        _ => {}
                    }
                }
            }
        }

        if app.should_quit() {
            return Ok(());
        }
    }
}
