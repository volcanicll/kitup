//! TUI 应用状态管理

use kitup_core::installer::{detect_all_install_methods, detect_install_method, ToolStatus};
use kitup_core::pin::PinnedVersions;
use kitup_core::tool::TOOL_REGISTRY;
use kitup_core::version::VersionCache;
use semver::Version;
use std::path::PathBuf;

/// 主标签页
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Tab {
    Tools,
    Providers,
    Health,
}

/// 工具版本异步更新消息
#[derive(Debug)]
pub struct ToolUpdate {
    pub tool_name: String,
    pub installed: bool,
    pub local_version: Option<Version>,
    pub latest_version: Option<Version>,
    pub method: Option<String>,
    pub path: Option<PathBuf>,
    pub needs_update: bool,
    pub multiple_installs: bool,
}

/// TUI 应用状态
pub struct App {
    pub tab: Tab,
    pub tools: Vec<ToolInfo>,
    pub cursor: usize,
    pub selected: Vec<bool>,
    pub show_help: bool,
    pub show_detail: bool,
    pub searching: bool,
    pub search_query: String,
    pub updating: bool,
    pub update_progress: String,
    pub should_quit: bool,
    pub status_message: String,
}

/// TUI 中显示的工具信息
#[derive(Debug, Clone)]
pub struct ToolInfo {
    pub name: String,
    pub installed: bool,
    pub local_version: Option<Version>,
    pub latest_version: Option<Version>,
    pub method: Option<String>,
    pub path: Option<PathBuf>,
    pub needs_update: bool,
    pub multiple_installs: bool,
    pub loading: bool,
}

impl App {
    pub fn new() -> Self {
        let mut tools = Vec::new();
        let mut selected = Vec::new();

        for tool in TOOL_REGISTRY {
            tools.push(ToolInfo {
                name: tool.name.to_string(),
                installed: false,
                local_version: None,
                latest_version: None,
                method: None,
                path: None,
                needs_update: false,
                multiple_installs: false,
                loading: true,
            });
            selected.push(false);
        }

        Self {
            tab: Tab::Tools,
            tools,
            cursor: 0,
            selected,
            show_help: false,
            show_detail: false,
            searching: false,
            search_query: String::new(),
            updating: false,
            update_progress: String::new(),
            should_quit: false,
            status_message: String::new(),
        }
    }

    pub fn move_up(&mut self) {
        if self.cursor > 0 {
            self.cursor -= 1;
        }
    }

    pub fn move_down(&mut self) {
        if self.cursor < self.tools.len() - 1 {
            self.cursor += 1;
        }
    }

    pub fn toggle_selected(&mut self) {
        let i = self.cursor;
        if i < self.tools.len() && self.tools[i].installed {
            self.selected[i] = !self.selected[i];
        }
    }

    pub fn toggle_all(&mut self) {
        let all_selected = self
            .tools
            .iter()
            .enumerate()
            .filter(|(_, t)| t.installed)
            .all(|(i, _)| self.selected[i]);

        for (i, tool) in self.tools.iter().enumerate() {
            if tool.installed {
                self.selected[i] = !all_selected;
            }
        }
    }

    pub fn start_update(&mut self) {
        let selected_tools: Vec<_> = self
            .tools
            .iter()
            .enumerate()
            .filter(|(i, t)| self.selected[*i] && t.installed)
            .map(|(_, t)| t.name.clone())
            .collect();

        if selected_tools.is_empty() {
            self.status_message = "No tools selected".to_string();
            return;
        }

        self.status_message = format!("Updating {} tools...", selected_tools.len());
        // 实际更新由外部调度
    }

    pub fn show_detail(&mut self) {
        self.show_detail = !self.show_detail;
    }

    pub fn toggle_help(&mut self) {
        self.show_help = !self.show_help;
    }

    pub fn next_tab(&mut self) {
        self.tab = match self.tab {
            Tab::Tools => Tab::Providers,
            Tab::Providers => Tab::Health,
            Tab::Health => Tab::Tools,
        };
    }

    pub fn prev_tab(&mut self) {
        self.tab = match self.tab {
            Tab::Tools => Tab::Health,
            Tab::Providers => Tab::Tools,
            Tab::Health => Tab::Providers,
        };
    }

    pub fn set_tab(&mut self, tab: Tab) {
        self.tab = tab;
    }

    pub fn start_search(&mut self) {
        self.searching = true;
        self.search_query.clear();
    }

    pub fn stop_search(&mut self) {
        self.searching = false;
        self.search_query.clear();
    }

    pub fn is_searching(&self) -> bool {
        self.searching
    }

    pub fn should_quit(&self) -> bool {
        self.should_quit
    }

    pub fn apply_update(&mut self, update: ToolUpdate) {
        if let Some(tool) = self.tools.iter_mut().find(|t| t.name == update.tool_name) {
            tool.installed = update.installed;
            tool.local_version = update.local_version;
            tool.latest_version = update.latest_version;
            tool.method = update.method;
            tool.path = update.path;
            tool.needs_update = update.needs_update;
            tool.multiple_installs = update.multiple_installs;
            tool.loading = false;
        }
    }

    /// 获取过滤后的工具列表（搜索模式）
    pub fn filtered_indices(&self) -> Vec<usize> {
        if self.search_query.is_empty() {
            return (0..self.tools.len()).collect();
        }
        self.tools
            .iter()
            .enumerate()
            .filter(|(_, t)| t.name.contains(&self.search_query.to_lowercase()))
            .map(|(i, _)| i)
            .collect()
    }

    /// 统计
    pub fn stats(&self) -> (usize, usize, usize) {
        let installed = self.tools.iter().filter(|t| t.installed).count();
        let updates = self.tools.iter().filter(|t| t.needs_update).count();
        let selected = self
            .tools
            .iter()
            .enumerate()
            .filter(|(i, t)| self.selected[*i] && t.installed)
            .count();
        (installed, updates, selected)
    }
}

/// 异步检测所有工具版本
pub async fn detect_all_tools(tx: std::sync::mpsc::Sender<ToolUpdate>) {
    let cache = VersionCache::new().ok();
    let pins = PinnedVersions::load().ok();

    for tool in TOOL_REGISTRY {
        let tool_name = tool.name.to_string();
        let tool_path = which::which(tool.command).ok();
        let installed = tool_path.is_some();

        let (method_str, needs_update, local_ver, latest_ver, multi) = if installed {
            let method_info = detect_install_method(tool).await;
            let method_str = method_info
                .as_ref()
                .map(|(m, _)| m.to_string());

            let local_ver = if let Some((_, ref adapter)) = method_info {
                adapter.local_version(tool).await.unwrap_or(None)
            } else {
                None
            };

            let latest_ver = if let Some((_, ref adapter)) = method_info {
                if let Some(ref cache) = cache {
                    if let Some(v) = cache.get(&tool_name, adapter.name()) {
                        Some(v)
                    } else {
                        adapter.latest_version(tool).await.unwrap_or(None)
                    }
                } else {
                    adapter.latest_version(tool).await.unwrap_or(None)
                }
            } else {
                None
            };

            let pinned = pins.as_ref().and_then(|p| PinnedVersions::get_pinned(&tool_name).ok().flatten());
            let needs = if pinned.is_some() {
                false
            } else if let (Some(ref l), Some(ref lat)) = (&local_ver, &latest_ver) {
                lat > l
            } else {
                false
            };

            let all_methods = detect_all_install_methods(tool).await;
            let multi = all_methods.len() > 1;

            (method_str, needs, local_ver, latest_ver, multi)
        } else {
            (None, false, None, None, false)
        };

        let _ = tx.send(ToolUpdate {
            tool_name,
            installed,
            local_version: local_ver,
            latest_version: latest_ver,
            method: method_str,
            path: tool_path,
            needs_update: needs_update,
            multiple_installs: multi,
        });
    }
}
