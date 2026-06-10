//! TUI 应用状态管理

use kitup_core::installer::{detect_all_install_methods, detect_install_method};
use kitup_core::pin::PinnedVersions;
use kitup_core::tool::{Tool, TOOL_REGISTRY};
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

/// 工具更新进度事件
#[derive(Debug)]
pub enum UpdateEvent {
    /// 单个工具更新完成（成功/失败/跳过），附带刷新后的状态
    ToolDone {
        name: String,
        result: ToolUpdateResult,
        refreshed: ToolUpdate,
    },
    /// 全部更新完成
    Done { updated: usize, failed: usize },
}

/// 单个工具的更新结果
#[derive(Debug)]
pub enum ToolUpdateResult {
    Updated,
    Failed(String),
    Skipped(String),
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
    pub detecting: bool,
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
        Self {
            tab: Tab::Tools,
            tools: Vec::new(),
            cursor: 0,
            selected: Vec::new(),
            detecting: true,
            show_help: false,
            show_detail: false,
            searching: false,
            search_query: String::new(),
            updating: false,
            update_progress: String::new(),
            should_quit: false,
            status_message: "Detecting tools...".to_string(),
        }
    }

    pub fn move_up(&mut self) {
        if self.cursor > 0 {
            self.cursor -= 1;
        }
    }

    pub fn move_down(&mut self) {
        if !self.tools.is_empty() && self.cursor < self.tools.len() - 1 {
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

    /// 准备更新选中的工具，返回待更新工具名列表
    pub fn prepare_update(&mut self) -> Option<Vec<String>> {
        if self.updating {
            self.status_message = "Update already in progress".to_string();
            return None;
        }

        let selected_tools: Vec<_> = self
            .tools
            .iter()
            .enumerate()
            .filter(|(i, t)| self.selected[*i] && t.installed)
            .map(|(_, t)| t.name.clone())
            .collect();

        if selected_tools.is_empty() {
            self.status_message =
                "No tools selected — use Space on installed tools first".to_string();
            return None;
        }

        self.updating = true;
        self.update_progress = format!("Updating {} tool(s)...", selected_tools.len());
        self.status_message = self.update_progress.clone();
        Some(selected_tools)
    }

    pub fn apply_update_event(&mut self, event: UpdateEvent) {
        match event {
            UpdateEvent::ToolDone { name, result, refreshed } => {
                // 刷新该工具的显示状态
                self.apply_update(refreshed);
                // 更新进度文字
                match result {
                    ToolUpdateResult::Updated => {
                        self.update_progress = format!("✓ {} updated", name);
                    }
                    ToolUpdateResult::Failed(e) => {
                        self.update_progress = format!("✗ {} failed: {}", name, e);
                    }
                    ToolUpdateResult::Skipped(reason) => {
                        self.update_progress = format!("- {}: {}", name, reason);
                    }
                }
                self.status_message = self.update_progress.clone();
            }
            UpdateEvent::Done { updated, failed } => {
                self.updating = false;
                self.update_progress.clear();
                if failed > 0 {
                    self.status_message =
                        format!("Done: {} updated, {} failed", updated, failed);
                } else if updated > 0 {
                    self.status_message = format!("Done: {} tool(s) updated", updated);
                } else {
                    self.status_message = "All tools are up to date".to_string();
                }
                // 清除选择状态
                for s in &mut self.selected {
                    *s = false;
                }
            }
        }
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

    /// 应用检测/刷新结果
    pub fn apply_update(&mut self, update: ToolUpdate) {
        if let Some(idx) = self.tools.iter().position(|t| t.name == update.tool_name) {
            // 已在列表中 → 刷新数据（更新后的重新检测）
            let tool = &mut self.tools[idx];
            tool.installed = update.installed;
            tool.local_version = update.local_version;
            tool.latest_version = update.latest_version;
            tool.method = update.method;
            tool.path = update.path;
            tool.needs_update = update.needs_update;
            tool.multiple_installs = update.multiple_installs;
            tool.loading = false;
        } else if update.installed {
            // 新检测到的已安装工具 → 追加到列表
            self.tools.push(ToolInfo {
                name: update.tool_name,
                installed: true,
                local_version: update.local_version,
                latest_version: update.latest_version,
                method: update.method,
                path: update.path,
                needs_update: update.needs_update,
                multiple_installs: update.multiple_installs,
                loading: false,
            });
            self.selected.push(false);
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
            .filter(|(_, t)| t.name.to_lowercase().contains(&self.search_query.to_lowercase()))
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

/// 异步并行检测所有工具版本（只发送已安装的工具）
pub async fn detect_all_tools(tx: std::sync::mpsc::Sender<ToolUpdate>) {
    let cache = VersionCache::new().ok();
    let pins = PinnedVersions::load().ok();

    // 并行检测所有工具，每个工具一个 tokio 任务
    let handles: Vec<_> = TOOL_REGISTRY
        .iter()
        .map(|tool| {
            let tx = tx.clone();
            let cache = cache.clone();
            let pins = pins.clone();
            tokio::spawn(async move {
                let update = detect_single_tool(tool, &cache, &pins).await;
                if update.installed {
                    let _ = tx.send(update);
                }
            })
        })
        .collect();

    // 等待所有检测完成
    for handle in handles {
        let _ = handle.await;
    }
}

/// 更新选中的工具
pub async fn update_tools(tool_names: Vec<String>, tx: std::sync::mpsc::Sender<UpdateEvent>) {
    let pins = PinnedVersions::load().ok();

    let mut updated = 0;
    let mut failed = 0;

    for name in tool_names {
        let Some(tool) = Tool::find_by_name(&name) else {
            continue;
        };

        // 检查 pinned
        if PinnedVersions::get_pinned(&name).ok().flatten().is_some() {
            let refresh = detect_single_tool(tool, &None, &pins).await;
            let _ = tx.send(UpdateEvent::ToolDone {
                name,
                result: ToolUpdateResult::Skipped("pinned".into()),
                refreshed: refresh,
            });
            continue;
        }

        // 获取安装方式对应的 adapter
        let method_info = detect_install_method(tool).await;
        let Some((_, adapter)) = method_info else {
            continue;
        };

        // 直接执行更新（不做版本比较，交给包管理器判断）
        let result = match adapter.update(tool).await {
            Ok(()) => {
                updated += 1;
                ToolUpdateResult::Updated
            }
            Err(e) => {
                failed += 1;
                ToolUpdateResult::Failed(e.to_string())
            }
        };

        // 更新后不使用缓存，强制重新检测
        let refresh = detect_single_tool(tool, &None, &pins).await;
        let _ = tx.send(UpdateEvent::ToolDone {
            name,
            result,
            refreshed: refresh,
        });
    }

    let _ = tx.send(UpdateEvent::Done { updated, failed });
}

async fn detect_single_tool(
    tool: &Tool,
    cache: &Option<VersionCache>,
    pins: &Option<PinnedVersions>,
) -> ToolUpdate {
    let tool_name = tool.name.to_string();
    let tool_path = which::which(tool.command).ok();
    let installed = tool_path.is_some();

    let (method_str, needs_update, local_ver, latest_ver, multi) = if installed {
        let method_info = detect_install_method(tool).await;
        let method_str = method_info.as_ref().map(|(m, _)| m.to_string());

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

        let pinned = pins
            .as_ref()
            .and_then(|_| PinnedVersions::get_pinned(&tool_name).ok().flatten());
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

    ToolUpdate {
        tool_name,
        installed,
        local_version: local_ver,
        latest_version: latest_ver,
        method: method_str,
        path: tool_path,
        needs_update,
        multiple_installs: multi,
    }
}
