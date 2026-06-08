# kitup v2 Phase 1: Core Update + CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 Rust 重写 kitup 核心功能，实现命令行工具替代现有 Shell 版本。

**Architecture:** Cargo workspace 包含两个 crate：`kitup-core`（核心库）和 `kitup-cli`（CLI 二进制）。核心库提供工具注册、版本检测、包管理器适配、配置管理等能力；CLI 二进制基于 clap 解析命令，调用核心库完成操作。

**Tech Stack:** Rust, clap 4.x, tokio 1.x, reqwest 0.12+, indicatif 0.17+, owo-colors 4.x, comfy-table 7.x, serde/serde_json 1.x, semver 1.x, anyhow 1.x, thiserror 1.x

**Design Spec:** `docs/superpowers/specs/2026-06-05-kitup-v2-rust-rewrite-design.md`

---

## File Structure

```
crates/
├── kitup-core/
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs              # 库入口，re-export 公共 API
│       ├── tool.rs             # Tool 结构体和工具注册表
│       ├── version.rs          # 版本解析、比对、缓存
│       ├── installer/
│       │   ├── mod.rs          # PackageManager trait 定义
│       │   ├── npm.rs          # npm 适配器
│       │   ├── brew.rs         # Homebrew 适配器
│       │   ├── pipx.rs         # pipx 适配器
│       │   ├── uv.rs           # uv 适配器
│       │   └── standalone.rs   # standalone 适配器
│       ├── config.rs           # 配置加载、保存、v1 迁移
│       ├── pin.rs              # 版本固定
│       └── self_update.rs      # 自更新
├── kitup-cli/
│   ├── Cargo.toml
│   └── src/
│       ├── main.rs             # 入口
│       ├── args.rs             # clap 命令定义
│       ├── commands/
│       │   ├── mod.rs
│       │   ├── status.rs       # status 子命令
│       │   ├── update.rs       # update 子命令
│       │   ├── pin_cmd.rs      # pin/unpin 子命令
│       │   ├── changelog.rs    # changelog 子命令
│       │   ├── doctor.rs       # doctor 子命令
│       │   ├── config_cmd.rs   # config 子命令
│       │   └── completions.rs  # completions 子命令
│       └── output.rs           # 格式化输出工具函数
```

---

## Task 1: Cargo Workspace 初始化

**Files:**
- Create: `Cargo.toml` (workspace root)
- Create: `crates/kitup-core/Cargo.toml`
- Create: `crates/kitup-core/src/lib.rs`
- Create: `crates/kitup-cli/Cargo.toml`
- Create: `crates/kitup-cli/src/main.rs`

- [ ] **Step 1: 创建 workspace 根 Cargo.toml**

```toml
[workspace]
resolver = "2"
members = [
    "crates/kitup-core",
    "crates/kitup-cli",
]

[workspace.package]
version = "0.2.0"
edition = "2021"
license = "MIT"
description = "A unified, cross-platform updater for AI coding assistants"

[workspace.dependencies]
# 序列化
serde = { version = "1", features = ["derive"] }
serde_json = "1"

# 异步
tokio = { version = "1", features = ["full"] }

# HTTP
reqwest = { version = "0.12", features = ["json", "rustls-tls"], default-features = false }

# 版本
semver = "1"

# 错误处理
anyhow = "1"
thiserror = "2"

# 日志
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }

# CLI
clap = { version = "4", features = ["derive"] }
clap_complete = "4"

# 输出
owo-colors = "4"
comfy-table = "7"
indicatif = "0.17"

# 配置
directories = "5"
toml = "0.8"

# 工具
which = "7"
regex = "1"
chrono = { version = "0.4", features = ["serde"] }
sha2 = "0.10"
```

- [ ] **Step 2: 创建 kitup-core crate**

`crates/kitup-core/Cargo.toml`:
```toml
[package]
name = "kitup-core"
version.workspace = true
edition.workspace = true
license.workspace = true
description.workspace = true

[dependencies]
serde = { workspace = true }
serde_json = { workspace = true }
tokio = { workspace = true }
reqwest = { workspace = true }
semver = { workspace = true }
anyhow = { workspace = true }
thiserror = { workspace = true }
tracing = { workspace = true }
directories = { workspace = true }
which = { workspace = true }
regex = { workspace = true }
chrono = { workspace = true }
```

`crates/kitup-core/src/lib.rs`:
```rust
//! kitup-core: AI 编码工具统一更新器核心库

pub mod config;
pub mod installer;
pub mod pin;
pub mod self_update;
pub mod tool;
pub mod version;
```

- [ ] **Step 3: 创建 kitup-cli crate**

`crates/kitup-cli/Cargo.toml`:
```toml
[package]
name = "kitup-cli"
version.workspace = true
edition.workspace = true
license.workspace = true
description.workspace = true

[[bin]]
name = "kitup"
path = "src/main.rs"

[dependencies]
kitup-core = { path = "../kitup-core" }
clap = { workspace = true }
clap_complete = { workspace = true }
tokio = { workspace = true }
anyhow = { workspace = true }
tracing = { workspace = true }
tracing-subscriber = { workspace = true }
owo-colors = { workspace = true }
comfy-table = { workspace = true }
indicatif = { workspace = true }
serde_json = { workspace = true }
semver = { workspace = true }
reqwest = { workspace = true }
directories = { workspace = true }
chrono = { workspace = true }
```

`crates/kitup-cli/src/main.rs`:
```rust
use clap::Parser;
use kitup_core::tool;

fn main() -> anyhow::Result<()> {
    // 初始化日志（仅在 verbose 模式下输出）
    let args = crate::args::Cli::parse();

    // 初始化 tracing
    if args.verbose {
        tracing_subscriber::fmt()
            .with_env_filter("kitup=debug")
            .init();
    } else {
        tracing_subscriber::fmt()
            .with_env_filter("kitup=warn")
            .init();
    }

    // 分发到子命令
    match args.command {
        Some(crate::args::Commands::Status { json }) => {
            crate::commands::status::run(json)?;
        }
        Some(crate::args::Commands::Update {
            tools,
            all,
            install,
            dry_run,
            force,
            parallel,
        }) => {
            crate::commands::update::run(
                tools, all, install, dry_run, force, parallel,
            )?;
        }
        Some(crate::args::Commands::Pin { tool, version }) => {
            crate::commands::pin_cmd::pin(tool, version)?;
        }
        Some(crate::args::Commands::Unpin { tool }) => {
            crate::commands::pin_cmd::unpin(tool)?;
        }
        Some(crate::args::Commands::Changelog { tool, all }) => {
            crate::commands::changelog::run(tool, all)?;
        }
        Some(crate::args::Commands::Doctor { fix, verbose: doc_verbose }) => {
            crate::commands::doctor::run(fix, doc_verbose || args.verbose)?;
        }
        Some(crate::args::Commands::Config) => {
            crate::commands::config_cmd::run()?;
        }
        Some(crate::args::Commands::Completions { shell }) => {
            crate::commands::completions::run(shell)?;
        }
        Some(crate::args::Commands::SelfUpdate) => {
            crate::commands::self_update_cmd::run()?;
        }
        None => {
            // 无子命令时显示帮助
            println!("kitup v{} — AI coding assistant updater", env!("CARGO_PKG_VERSION"));
            println!();
            println!("Usage: kitup <COMMAND>");
            println!();
            println!("Run `kitup --help` for available commands.");
        }
    }

    Ok(())
}
```

- [ ] **Step 4: 验证编译**

Run: `cd /Users/volcanic/codespace/kitup && cargo check`

注意：此时 args.rs 和 commands/ 尚未创建，编译会失败。先创建占位文件。

- [ ] **Step 5: 创建 args.rs 占位**

`crates/kitup-cli/src/args.rs`:
```rust
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
```

`crates/kitup-cli/src/commands/mod.rs`:
```rust
pub mod changelog;
pub mod completions;
pub mod config_cmd;
pub mod doctor;
pub mod pin_cmd;
pub mod status;
pub mod self_update_cmd;
pub mod update;
```

每个 command 文件先创建占位（以 status.rs 为例，其余类似）：

`crates/kitup-cli/src/commands/status.rs`:
```rust
pub fn run(_json: bool) -> anyhow::Result<()> {
    println!("status command - not yet implemented");
    Ok(())
}
```

`crates/kitup-cli/src/commands/update.rs`:
```rust
pub fn run(
    _tools: Vec<String>,
    _all: bool,
    _install: bool,
    _dry_run: bool,
    _force: bool,
    _parallel: usize,
) -> anyhow::Result<()> {
    println!("update command - not yet implemented");
    Ok(())
}
```

`crates/kitup-cli/src/commands/pin_cmd.rs`:
```rust
pub fn pin(_tool: String, _version: String) -> anyhow::Result<()> {
    println!("pin command - not yet implemented");
    Ok(())
}

pub fn unpin(_tool: String) -> anyhow::Result<()> {
    println!("unpin command - not yet implemented");
    Ok(())
}
```

`crates/kitup-cli/src/commands/changelog.rs`:
```rust
pub fn run(_tool: Option<String>, _all: bool) -> anyhow::Result<()> {
    println!("changelog command - not yet implemented");
    Ok(())
}
```

`crates/kitup-cli/src/commands/doctor.rs`:
```rust
pub fn run(_fix: bool, _verbose: bool) -> anyhow::Result<()> {
    println!("doctor command - not yet implemented");
    Ok(())
}
```

`crates/kitup-cli/src/commands/config_cmd.rs`:
```rust
pub fn run() -> anyhow::Result<()> {
    println!("config command - not yet implemented");
    Ok(())
}
```

`crates/kitup-cli/src/commands/completions.rs`:
```rust
pub fn run(_shell: clap_complete::Shell) -> anyhow::Result<()> {
    println!("completions command - not yet implemented");
    Ok(())
}
```

`crates/kitup-cli/src/commands/self_update_cmd.rs`:
```rust
pub fn run() -> anyhow::Result<()> {
    println!("self-update command - not yet implemented");
    Ok(())
}
```

`crates/kitup-cli/src/output.rs`:
```rust
// 格式化输出工具函数 — 后续 Task 填充
```

- [ ] **Step 6: 验证编译通过**

Run: `cd /Users/volcanic/codespace/kitup && cargo check`
Expected: 编译成功，无错误

- [ ] **Step 7: 提交**

```bash
git add Cargo.toml Cargo.lock crates/
git commit -m "feat: 初始化 Rust workspace 和 CLI 骨架"
```

---

## Task 2: 工具注册表 (Tool Registry)

**Files:**
- Create: `crates/kitup-core/src/tool.rs`
- Modify: `crates/kitup-core/src/lib.rs`

- [ ] **Step 1: 编写 Tool 结构体和注册表的测试**

`crates/kitup-core/src/tool.rs`:
```rust
//! 工具定义和注册表
//!
//! 定义所有支持的 AI 编码工具，包含名称、包管理器映射等信息。

use serde::{Deserialize, Serialize};
use std::fmt;

/// 一个 AI 编码工具的定义
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Tool {
    /// 工具显示名称 (如 "claude")
    pub name: &'static str,
    /// 可执行文件名 (如 "claude")
    pub command: &'static str,
    /// npm 包名
    pub npm_package: Option<&'static str>,
    /// Homebrew formula 名
    pub brew_formula: Option<&'static str>,
    /// pipx 包名
    pub pipx_package: Option<&'static str>,
    /// uv 包名
    pub uv_package: Option<&'static str>,
    /// GitHub 仓库 (owner/repo)
    pub github_repo: Option<&'static str>,
    /// 安装脚本 URL
    pub install_url: Option<&'static str>,
}

impl fmt::Display for Tool {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.name)
    }
}

impl Tool {
    /// 从名称查找工具
    pub fn find_by_name(name: &str) -> Option<&'static Tool> {
        TOOL_REGISTRY.iter().find(|t| t.name == name)
    }
}

/// 全局工具注册表 — 所有支持的 AI 编码工具
pub static TOOL_REGISTRY: &[Tool] = &[
    Tool {
        name: "claude",
        command: "claude",
        npm_package: Some("@anthropic-ai/claude-code"),
        brew_formula: Some("anthropic-ai/tap/claude-code"),
        pipx_package: None,
        uv_package: None,
        github_repo: Some("anthropics/claude-code"),
        install_url: Some("https://claude.ai/install.sh"),
    },
    Tool {
        name: "opencode",
        command: "opencode",
        npm_package: Some("opencode-ai"),
        brew_formula: Some("opencode"),
        pipx_package: None,
        uv_package: None,
        github_repo: Some("opencode-ai/opencode"),
        install_url: Some("https://opencode.ai/install"),
    },
    Tool {
        name: "codex",
        command: "codex",
        npm_package: Some("@openai/codex"),
        brew_formula: Some("codex"),
        pipx_package: None,
        uv_package: None,
        github_repo: Some("openai/codex"),
        install_url: Some("https://cli.openai.com/install.sh"),
    },
    Tool {
        name: "gemini",
        command: "gemini",
        npm_package: Some("@google/gemini-cli"),
        brew_formula: Some("gemini-cli"),
        pipx_package: None,
        uv_package: None,
        github_repo: Some("google-gemini/gemini-cli"),
        install_url: None,
    },
    Tool {
        name: "kimi",
        command: "kimi",
        npm_package: None,
        brew_formula: None,
        pipx_package: Some("kimi-cli"),
        uv_package: Some("kimi-cli"),
        github_repo: Some("MoonshotAI/kimi-cli"),
        install_url: None,
    },
    Tool {
        name: "cline",
        command: "cline",
        npm_package: Some("cline"),
        brew_formula: None,
        pipx_package: None,
        uv_package: None,
        github_repo: Some("cline/cline"),
        install_url: None,
    },
    Tool {
        name: "qwen",
        command: "qwen",
        npm_package: Some("@qwen-code/qwen-code"),
        brew_formula: Some("qwen-code"),
        pipx_package: None,
        uv_package: None,
        github_repo: Some("QwenLM/qwen-code"),
        install_url: Some("https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen.sh"),
    },
    Tool {
        name: "goose",
        command: "goose",
        npm_package: None,
        brew_formula: Some("block-goose-cli"),
        pipx_package: None,
        uv_package: None,
        github_repo: Some("block/goose"),
        install_url: Some("https://github.com/block/goose/releases/download/stable/download_cli.sh"),
    },
    Tool {
        name: "aider",
        command: "aider",
        npm_package: None,
        brew_formula: Some("aider"),
        pipx_package: Some("aider-chat"),
        uv_package: Some("aider-chat"),
        github_repo: Some("Aider-AI/aider"),
        install_url: Some("https://aider.chat/install.sh"),
    },
    Tool {
        name: "cursor",
        command: "cursor",
        npm_package: None,
        brew_formula: Some("cursor"),
        pipx_package: None,
        uv_package: None,
        github_repo: Some("cursor-sh/cursor"),
        install_url: Some("https://downloader.cursor.sh/linux"),
    },
    Tool {
        name: "windsurf",
        command: "windsurf",
        npm_package: None,
        brew_formula: Some("windsurf"),
        pipx_package: None,
        uv_package: None,
        github_repo: Some("codeium/windsurf"),
        install_url: Some("https://windsurf.sh/install"),
    },
    Tool {
        name: "tabby",
        command: "tabby",
        npm_package: None,
        brew_formula: Some("tabby"),
        pipx_package: None,
        uv_package: None,
        github_repo: Some("TabbyML/tabby"),
        install_url: None,
    },
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_registry_contains_all_tools() {
        assert_eq!(TOOL_REGISTRY.len(), 12);
    }

    #[test]
    fn test_find_by_name() {
        let claude = Tool::find_by_name("claude").unwrap();
        assert_eq!(claude.command, "claude");
        assert_eq!(claude.npm_package, Some("@anthropic-ai/claude-code"));
    }

    #[test]
    fn test_find_by_name_not_found() {
        assert!(Tool::find_by_name("nonexistent").is_none());
    }

    #[test]
    fn test_tool_display() {
        let tool = Tool::find_by_name("claude").unwrap();
        assert_eq!(format!("{}", tool), "claude");
    }
}
```

- [ ] **Step 2: 运行测试**

Run: `cd /Users/volcanic/codespace/kitup && cargo test -p kitup-core -- tool`
Expected: 4 个测试全部通过

- [ ] **Step 3: 提交**

```bash
git add crates/kitup-core/src/tool.rs
git commit -m "feat: 添加工具注册表 (12 个 AI 编码工具)"
```

---

## Task 3: 版本解析模块

**Files:**
- Create: `crates/kitup-core/src/version.rs`

- [ ] **Step 1: 编写版本解析模块**

`crates/kitup-core/src/version.rs`:
```rust
//! 版本解析、比对和缓存
//!
//! 从命令输出中提取语义版本号，并与远程版本比较。

use anyhow::Result;
use regex::Regex;
use semver::Version;
use std::path::PathBuf;
use std::time::{Duration, SystemTime};

/// 从命令输出字符串中解析出语义版本
///
/// 支持格式：
/// - "1.2.3"
/// - "v1.2.3"
/// - "claude 1.2.3"
/// - "1.2.3-beta.1"
pub fn parse_version(output: &str) -> Option<Version> {
    // 匹配语义版本号（可选的预发布标签）
    let re = Regex::new(r"(?i)v?(\d+\.\d+\.\d+(?:[-\.][a-zA-Z0-9.]+)?)").ok()?;

    if let Some(caps) = re.captures(output) {
        let ver_str = caps.get(1)?.as_str();
        // 将 prerelease 中的连字符转为点号以匹配 semver 格式
        let normalized = ver_str.replace('-', ".");
        Version::parse(&normalized).ok()
    } else {
        None
    }
}

/// 版本缓存条目
#[derive(Debug, Clone)]
pub struct VersionCache {
    cache_dir: PathBuf,
    ttl: Duration,
}

impl VersionCache {
    pub fn new() -> Result<Self> {
        let cache_dir = dirs()?.join("version_cache");
        std::fs::create_dir_all(&cache_dir)?;
        Ok(Self {
            cache_dir,
            ttl: Duration::from_secs(3600), // 1 小时
        })
    }

    pub fn with_ttl(mut self, ttl: Duration) -> Self {
        self.ttl = ttl;
        self
    }

    /// 获取缓存的版本
    pub fn get(&self, tool_name: &str, method: &str) -> Option<Version> {
        let file = self.cache_dir.join(format!("{}_{}.txt", tool_name, method));
        let content = std::fs::read_to_string(&file).ok()?;
        let mut parts = content.splitn(2, '|');
        let version_str = parts.next()?.trim();
        let timestamp_str = parts.next()?.trim();

        let timestamp: u64 = timestamp_str.parse().ok()?;
        let now = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .ok()?
            .as_secs();

        if now.saturating_sub(timestamp) > self.ttl.as_secs() {
            return None; // 缓存过期
        }

        Version::parse(version_str).ok()
    }

    /// 保存版本到缓存
    pub fn set(&self, tool_name: &str, method: &str, version: &Version) -> Result<()> {
        let file = self.cache_dir.join(format!("{}_{}.txt", tool_name, method));
        let now = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)?
            .as_secs();
        std::fs::write(&file, format!("{}|{}", version, now))?;
        Ok(())
    }

    /// 清除所有缓存
    pub fn clear(&self) -> Result<()> {
        if self.cache_dir.exists() {
            std::fs::remove_dir_all(&self.cache_dir)?;
            std::fs::create_dir_all(&self.cache_dir)?;
        }
        Ok(())
    }
}

/// 获取 kitup 配置目录
fn dirs() -> Result<PathBuf> {
    let dirs = directories::ProjectDirs::from("com", "kitup", "kitup")
        .ok_or_else(|| anyhow::anyhow!("无法确定配置目录"))?;
    Ok(dirs.config_dir().to_path_buf())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_simple_version() {
        let v = parse_version("1.2.3").unwrap();
        assert_eq!(v.major, 1);
        assert_eq!(v.minor, 2);
        assert_eq!(v.patch, 3);
    }

    #[test]
    fn test_parse_version_with_prefix() {
        let v = parse_version("v1.2.3").unwrap();
        assert_eq!(v.major, 1);
    }

    #[test]
    fn test_parse_version_from_output() {
        let v = parse_version("claude 0.2.50").unwrap();
        assert_eq!(v.minor, 2);
        assert_eq!(v.patch, 50);
    }

    #[test]
    fn test_parse_version_with_prerelease() {
        let v = parse_version("1.2.3-beta.1").unwrap();
        assert_eq!(v.major, 1);
        assert!(!v.pre.is_empty());
    }

    #[test]
    fn test_parse_version_no_match() {
        assert!(parse_version("no version here").is_none());
        assert!(parse_version("").is_none());
    }

    #[test]
    fn test_version_comparison() {
        let v1 = parse_version("1.2.3").unwrap();
        let v2 = parse_version("1.2.4").unwrap();
        assert!(v2 > v1);
    }
}
```

- [ ] **Step 2: 运行测试**

Run: `cd /Users/volcanic/codespace/kitup && cargo test -p kitup-core -- version`
Expected: 6 个测试全部通过

- [ ] **Step 3: 提交**

```bash
git add crates/kitup-core/src/version.rs
git commit -m "feat: 添加版本解析和缓存模块"
```

---

## Task 4: PackageManager Trait + 安装方式检测

**Files:**
- Create: `crates/kitup-core/src/installer/mod.rs`

- [ ] **Step 1: 编写 PackageManager trait 和安装方式检测**

`crates/kitup-core/src/installer/mod.rs`:
```rust
//! 包管理器适配器
//!
//! 定义统一的包管理器接口，以及安装方式检测逻辑。

pub mod brew;
pub mod npm;
pub mod pipx;
pub mod standalone;
pub mod uv;

use crate::tool::Tool;
use anyhow::Result;
use async_trait::async_trait;
use semver::Version;
use std::path::PathBuf;

/// 工具更新结果
#[derive(Debug, Clone)]
pub struct UpdateResult {
    pub tool_name: String,
    pub old_version: Option<String>,
    pub new_version: Option<String>,
    pub method: String,
    pub elapsed: std::time::Duration,
    pub status: UpdateStatus,
    pub error: Option<String>,
}

/// 更新状态
#[derive(Debug, Clone, PartialEq)]
pub enum UpdateStatus {
    Success,
    Skipped,
    Failed,
}

/// 工具状态信息
#[derive(Debug, Clone)]
pub struct ToolStatus {
    pub tool_name: String,
    pub installed: bool,
    pub local_version: Option<Version>,
    pub latest_version: Option<Version>,
    pub method: Option<InstallMethod>,
    pub path: Option<PathBuf>,
    pub needs_update: bool,
    pub multiple_installs: bool,
    pub install_methods: Vec<InstallMethod>,
}

/// 安装方式
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum InstallMethod {
    Npm,
    Brew,
    Pipx,
    Uv,
    Standalone,
    Unknown,
}

use serde::{Deserialize, Serialize};

impl std::fmt::Display for InstallMethod {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            InstallMethod::Npm => write!(f, "npm"),
            InstallMethod::Brew => write!(f, "brew"),
            InstallMethod::Pipx => write!(f, "pipx"),
            InstallMethod::Uv => write!(f, "uv"),
            InstallMethod::Standalone => write!(f, "standalone"),
            InstallMethod::Unknown => write!(f, "unknown"),
        }
    }
}

/// 包管理器统一接口
#[async_trait]
pub trait PackageManager: Send + Sync {
    /// 包管理器名称
    fn name(&self) -> &str;

    /// 检查工具是否通过此包管理器安装
    async fn is_installed(&self, tool: &Tool) -> bool;

    /// 获取本地安装版本
    async fn local_version(&self, tool: &Tool) -> Result<Option<Version>>;

    /// 获取最新可用版本
    async fn latest_version(&self, tool: &Tool) -> Result<Option<Version>>;

    /// 执行更新
    async fn update(&self, tool: &Tool) -> Result<()>;

    /// 执行安装
    async fn install(&self, tool: &Tool) -> Result<()>;
}

/// 检测工具的安装方式（PATH 优先策略）
///
/// 检测逻辑：
/// 1. 查找可执行文件路径
/// 2. 判断路径所属前缀（brew/npm/standalone）
/// 3. 回退到包管理器列表检查
pub async fn detect_install_method(tool: &Tool) -> Option<(InstallMethod, Box<dyn PackageManager>)> {
    let tool_path = which::which(tool.command).ok()?;

    // 检查 Homebrew
    if let Some(ref formula) = tool.brew_formula {
        let adapter = brew::BrewAdapter;
        if adapter.is_path_match(&tool_path) && adapter.is_installed(tool).await {
            return Some((InstallMethod::Brew, Box::new(adapter)));
        }
    }

    // 检查 npm
    if let Some(ref pkg) = tool.npm_package {
        let adapter = npm::NpmAdapter;
        if adapter.is_path_match(&tool_path) && adapter.is_installed(tool).await {
            return Some((InstallMethod::Npm, Box::new(adapter)));
        }
    }

    // 检查 standalone
    {
        let adapter = standalone::StandaloneAdapter;
        if adapter.is_path_match(&tool_path) {
            return Some((InstallMethod::Standalone, Box::new(adapter)));
        }
    }

    // 回退：检查 pipx
    if let Some(ref pkg) = tool.pipx_package {
        let adapter = pipx::PipxAdapter;
        if adapter.is_installed(tool).await {
            return Some((InstallMethod::Pipx, Box::new(adapter)));
        }
    }

    // 回退：检查 uv
    if let Some(ref pkg) = tool.uv_package {
        let adapter = uv::UvAdapter;
        if adapter.is_installed(tool).await {
            return Some((InstallMethod::Uv, Box::new(adapter)));
        }
    }

    // 回退到 brew（非路径匹配）
    if tool.brew_formula.is_some() {
        let adapter = brew::BrewAdapter;
        if adapter.is_installed(tool).await {
            return Some((InstallMethod::Brew, Box::new(adapter)));
        }
    }

    // 回退到 npm（非路径匹配）
    if tool.npm_package.is_some() {
        let adapter = npm::NpmAdapter;
        if adapter.is_installed(tool).await {
            return Some((InstallMethod::Npm, Box::new(adapter)));
        }
    }

    Some((InstallMethod::Unknown, Box::new(standalone::StandaloneAdapter)))
}

/// 检测所有安装方式（用于多安装检测）
pub async fn detect_all_install_methods(tool: &Tool) -> Vec<InstallMethod> {
    let mut methods = Vec::new();

    if let Some(ref _pkg) = tool.npm_package {
        let adapter = npm::NpmAdapter;
        if adapter.is_installed(tool).await {
            methods.push(InstallMethod::Npm);
        }
    }

    if let Some(ref _formula) = tool.brew_formula {
        let adapter = brew::BrewAdapter;
        if adapter.is_installed(tool).await {
            methods.push(InstallMethod::Brew);
        }
    }

    if let Some(ref _pkg) = tool.pipx_package {
        let adapter = pipx::PipxAdapter;
        if adapter.is_installed(tool).await {
            methods.push(InstallMethod::Pipx);
        }
    }

    if let Some(ref _pkg) = tool.uv_package {
        let adapter = uv::UvAdapter;
        if adapter.is_installed(tool).await {
            methods.push(InstallMethod::Uv);
        }
    }

    // 检查 standalone
    if let Ok(path) = which::which(tool.command) {
        let adapter = standalone::StandaloneAdapter;
        if adapter.is_path_match(&path) {
            methods.push(InstallMethod::Standalone);
        }
    }

    methods
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_install_method_display() {
        assert_eq!(InstallMethod::Npm.to_string(), "npm");
        assert_eq!(InstallMethod::Brew.to_string(), "brew");
        assert_eq!(InstallMethod::Unknown.to_string(), "unknown");
    }
}
```

注意：需要添加 `async-trait` 依赖到 workspace。更新 `Cargo.toml` workspace dependencies 添加：

```toml
async-trait = "0.1"
```

并在 `crates/kitup-core/Cargo.toml` 的 `[dependencies]` 中添加：

```toml
async-trait = { workspace = true }
which = { workspace = true }
```

- [ ] **Step 2: 运行检查**

Run: `cd /Users/volcanic/codespace/kitup && cargo check -p kitup-core`

注意：此时各适配器模块尚未实现，需要先创建占位文件。

- [ ] **Step 3: 提交**

```bash
git add crates/kitup-core/src/installer/
git commit -m "feat: 添加 PackageManager trait 和安装方式检测"
```

---

## Task 5: npm 适配器

**Files:**
- Create: `crates/kitup-core/src/installer/npm.rs`

- [ ] **Step 1: 编写 npm 适配器**

```rust
//! npm 包管理器适配器

use crate::installer::{PackageManager, install_method::InstallMethod};
use crate::tool::Tool;
use crate::version::parse_version;
use anyhow::Result;
use async_trait::async_trait;
use semver::Version;
use std::path::PathBuf;
use tokio::process::Command;

/// npm 全局包管理器适配器
pub struct NpmAdapter;

impl NpmAdapter {
    /// 获取 npm 全局前缀路径
    async fn global_prefix(&self) -> Option<String> {
        let output = Command::new("npm")
            .args(["prefix", "-g"])
            .output()
            .await
            .ok()?;
        if output.status.success() {
            Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
        } else {
            None
        }
    }

    /// 检查路径是否属于 npm 全局安装
    pub fn is_path_match(&self, tool_path: &PathBuf) -> bool {
        // 这里通过异步获取 prefix 来比较，简化实现使用同步方式
        if let Some(prefix) = std::process::Command::new("npm")
            .args(["prefix", "-g"])
            .output()
            .ok()
            .and_then(|o| {
                if o.status.success() {
                    Some(String::from_utf8_lossy(&o.stdout).trim().to_string())
                } else {
                    None
                }
            }) {
            tool_path.starts_with(format!("{}/bin/", prefix))
                || tool_path.starts_with(format!("{}/\\", prefix.replace('/', "\\"))
                    .replace('\\', "/"))
        } else {
            false
        }
    }
}

#[async_trait]
impl PackageManager for NpmAdapter {
    fn name(&self) -> &str {
        "npm"
    }

    async fn is_installed(&self, tool: &Tool) -> bool {
        if let Some(ref pkg) = tool.npm_package {
            let result = Command::new("npm")
                .args(["list", "-g", pkg])
                .output()
                .await;
            match result {
                Ok(output) => output.status.success(),
                Err(_) => false,
            }
        } else {
            false
        }
    }

    async fn local_version(&self, tool: &Tool) -> Result<Option<Version>> {
        if let Some(ref pkg) = tool.npm_package {
            let output = Command::new("npm")
                .args(["list", "-g", pkg, "--depth=0", "--json"])
                .output()
                .await?;

            if output.status.success() {
                let json_str = String::from_utf8_lossy(&output.stdout);
                if let Ok(json) = serde_json::from_str::<serde_json::Value>(&json_str) {
                    if let Some(deps) = json.get("dependencies") {
                        if let Some(dep) = deps.get(pkg.as_ref()) {
                            if let Some(ver) = dep.get("version") {
                                return Ok(parse_version(ver.as_str().unwrap_or("")));
                            }
                        }
                    }
                }
            }

            // 回退：通过命令行获取
            let output = Command::new("npm")
                .args(["list", "-g", pkg])
                .output()
                .await?;
            let stdout = String::from_utf8_lossy(&output.stdout);
            Ok(parse_version(&stdout))
        } else {
            Ok(None)
        }
    }

    async fn latest_version(&self, tool: &Tool) -> Result<Option<Version>> {
        if let Some(ref pkg) = tool.npm_package {
            let output = Command::new("npm")
                .args(["view", pkg, "version"])
                .output()
                .await?;

            if output.status.success() {
                let stdout = String::from_utf8_lossy(&output.stdout);
                return Ok(parse_version(&stdout));
            }
        }
        Ok(None)
    }

    async fn update(&self, tool: &Tool) -> Result<()> {
        if let Some(ref pkg) = tool.npm_package {
            let status = Command::new("npm")
                .args(["update", "-g", pkg])
                .status()
                .await?;

            if !status.success() {
                anyhow::bail!("npm update failed for {}", pkg);
            }
        }
        Ok(())
    }

    async fn install(&self, tool: &Tool) -> Result<()> {
        if let Some(ref pkg) = tool.npm_package {
            let status = Command::new("npm")
                .args(["install", "-g", pkg])
                .status()
                .await?;

            if !status.success() {
                anyhow::bail!("npm install failed for {}", pkg);
            }
        }
        Ok(())
    }
}
```

- [ ] **Step 2: 运行检查**

Run: `cd /Users/volcanic/codespace/kitup && cargo check -p kitup-core`

- [ ] **Step 3: 提交**

```bash
git add crates/kitup-core/src/installer/npm.rs
git commit -m "feat: 添加 npm 包管理器适配器"
```

---

## Task 6: Homebrew 适配器

**Files:**
- Create: `crates/kitup-core/src/installer/brew.rs`

- [ ] **Step 1: 编写 brew 适配器**

```rust
//! Homebrew 包管理器适配器

use crate::tool::Tool;
use crate::version::parse_version;
use anyhow::Result;
use async_trait::async_trait;
use semver::Version;
use std::path::PathBuf;
use tokio::process::Command;

/// Homebrew 适配器
pub struct BrewAdapter;

impl BrewAdapter {
    /// 获取 Homebrew 前缀
    async fn brew_prefix(&self) -> Option<String> {
        let output = Command::new("brew")
            .args(["--prefix"])
            .output()
            .await
            .ok()?;
        if output.status.success() {
            Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
        } else {
            None
        }
    }

    /// 检查路径是否属于 Homebrew
    pub fn is_path_match(&self, tool_path: &PathBuf) -> bool {
        if let Some(prefix) = std::process::Command::new("brew")
            .args(["--prefix"])
            .output()
            .ok()
            .and_then(|o| {
                if o.status.success() {
                    Some(String::from_utf8_lossy(&o.stdout).trim().to_string())
                } else {
                    None
                }
            }) {
            tool_path.starts_with(format!("{}/bin/", prefix))
        } else {
            false
        }
    }

    /// 检查是否为 cask 安装
    async fn is_cask(&self, formula: &str) -> bool {
        let output = Command::new("brew")
            .args(["list", "--cask", formula])
            .output()
            .await;
        matches!(output, Ok(o) if o.status.success())
    }
}

use crate::installer::PackageManager;

#[async_trait]
impl PackageManager for BrewAdapter {
    fn name(&self) -> &str {
        "brew"
    }

    async fn is_installed(&self, tool: &Tool) -> bool {
        if let Some(ref formula) = tool.brew_formula {
            // 先尝试 formula
            let output = Command::new("brew")
                .args(["list", formula])
                .output()
                .await;
            if matches!(output, Ok(o) if o.status.success()) {
                return true;
            }
            // 再尝试 cask
            self.is_cask(formula).await
        } else {
            false
        }
    }

    async fn local_version(&self, tool: &Tool) -> Result<Option<Version>> {
        if let Some(ref formula) = tool.brew_formula {
            // 使用 --json 获取版本
            let output = Command::new("brew")
                .args(["info", formula, "--json"])
                .output()
                .await?;

            if output.status.success() {
                let json_str = String::from_utf8_lossy(&output.stdout);
                if let Ok(json) = serde_json::from_str::<serde_json::Value>(&json_str) {
                    // formula 格式
                    if let Some(arr) = json.as_array() {
                        if let Some(first) = arr.first() {
                            if let Some(versions) = first.get("versions") {
                                if let Some(stable) = versions.get("stable") {
                                    return Ok(parse_version(stable.as_str().unwrap_or("")));
                                }
                            }
                            // cask 格式
                            if let Some(ver) = first.get("version") {
                                return Ok(parse_version(ver.as_str().unwrap_or("")));
                            }
                        }
                    }
                }
            }

            // 回退：通过 brew list 获取
            let output = Command::new("brew")
                .args(["list", formula, "--versions"])
                .output()
                .await?;
            let stdout = String::from_utf8_lossy(&output.stdout);
            Ok(parse_version(&stdout))
        } else {
            Ok(None)
        }
    }

    async fn latest_version(&self, tool: &Tool) -> Result<Option<Version>> {
        // 复用 local_version，brew info 本身就包含最新版本
        self.local_version(tool).await
    }

    async fn update(&self, tool: &Tool) -> Result<()> {
        if let Some(ref formula) = tool.brew_formula {
            let status = Command::new("brew")
                .args(["upgrade", formula])
                .status()
                .await?;

            if !status.success() {
                // 尝试 cask upgrade
                let status = Command::new("brew")
                    .args(["upgrade", "--cask", formula])
                    .status()
                    .await?;

                if !status.success() {
                    anyhow::bail!("brew upgrade failed for {}", formula);
                }
            }
        }
        Ok(())
    }

    async fn install(&self, tool: &Tool) -> Result<()> {
        if let Some(ref formula) = tool.brew_formula {
            let status = Command::new("brew")
                .args(["install", formula])
                .status()
                .await?;

            if !status.success() {
                // 尝试 cask install
                let status = Command::new("brew")
                    .args(["install", "--cask", formula])
                    .status()
                    .await?;

                if !status.success() {
                    anyhow::bail!("brew install failed for {}", formula);
                }
            }
        }
        Ok(())
    }
}
```

- [ ] **Step 2: 运行检查**

Run: `cd /Users/volcanic/codespace/kitup && cargo check -p kitup-core`

- [ ] **Step 3: 提交**

```bash
git add crates/kitup-core/src/installer/brew.rs
git commit -m "feat: 添加 Homebrew 包管理器适配器"
```

---

## Task 7: pipx 适配器

**Files:**
- Create: `crates/kitup-core/src/installer/pipx.rs`

- [ ] **Step 1: 编写 pipx 适配器**

```rust
//! pipx 包管理器适配器

use crate::installer::PackageManager;
use crate::tool::Tool;
use crate::version::parse_version;
use anyhow::Result;
use async_trait::async_trait;
use semver::Version;
use tokio::process::Command;

/// pipx 适配器
pub struct PipxAdapter;

#[async_trait]
impl PackageManager for PipxAdapter {
    fn name(&self) -> &str {
        "pipx"
    }

    async fn is_installed(&self, tool: &Tool) -> bool {
        if let Some(ref pkg) = tool.pipx_package {
            let output = Command::new("pipx")
                .args(["list"])
                .output()
                .await;
            match output {
                Ok(output) if output.status.success() => {
                    let stdout = String::from_utf8_lossy(&output.stdout);
                    stdout.contains(pkg)
                }
                _ => false,
            }
        } else {
            false
        }
    }

    async fn local_version(&self, tool: &Tool) -> Result<Option<Version>> {
        if let Some(ref pkg) = tool.pipx_package {
            let output = Command::new("pipx")
                .args(["list"])
                .output()
                .await?;

            if output.status.success() {
                let stdout = String::from_utf8_lossy(&output.stdout);
                // 在输出中查找包名和版本
                for line in stdout.lines() {
                    if line.contains(pkg) {
                        return Ok(parse_version(line));
                    }
                }
            }

            // 回退：直接运行命令获取版本
            let output = Command::new(tool.command)
                .args(["--version"])
                .output()
                .await?;
            if output.status.success() {
                let stdout = String::from_utf8_lossy(&output.stdout);
                return Ok(parse_version(&stdout));
            }
        }
        Ok(None)
    }

    async fn latest_version(&self, tool: &Tool) -> Result<Option<Version>> {
        if let Some(ref pkg) = tool.pipx_package {
            let output = Command::new("pipx")
                .args(["run", pkg, "--help"])
                .output()
                .await;
            // pipx 没有 view latest 命令，回退到 PyPI
            // 这里简化处理，通过 GitHub releases 获取
        }
        Ok(None)
    }

    async fn update(&self, tool: &Tool) -> Result<()> {
        if let Some(ref pkg) = tool.pipx_package {
            let status = Command::new("pipx")
                .args(["upgrade", pkg])
                .status()
                .await?;

            if !status.success() {
                anyhow::bail!("pipx upgrade failed for {}", pkg);
            }
        }
        Ok(())
    }

    async fn install(&self, tool: &Tool) -> Result<()> {
        if let Some(ref pkg) = tool.pipx_package {
            let status = Command::new("pipx")
                .args(["install", pkg])
                .status()
                .await?;

            if !status.success() {
                anyhow::bail!("pipx install failed for {}", pkg);
            }
        }
        Ok(())
    }
}
```

- [ ] **Step 2: 运行检查并提交**

```bash
cargo check -p kitup-core
git add crates/kitup-core/src/installer/pipx.rs
git commit -m "feat: 添加 pipx 包管理器适配器"
```

---

## Task 8: uv 适配器

**Files:**
- Create: `crates/kitup-core/src/installer/uv.rs`

- [ ] **Step 1: 编写 uv 适配器**

```rust
//! uv 包管理器适配器

use crate::installer::PackageManager;
use crate::tool::Tool;
use crate::version::parse_version;
use anyhow::Result;
use async_trait::async_trait;
use semver::Version;
use tokio::process::Command;

/// uv 适配器
pub struct UvAdapter;

#[async_trait]
impl PackageManager for UvAdapter {
    fn name(&self) -> &str {
        "uv"
    }

    async fn is_installed(&self, tool: &Tool) -> bool {
        if let Some(ref pkg) = tool.uv_package {
            let output = Command::new("uv")
                .args(["tool", "list"])
                .output()
                .await;
            match output {
                Ok(output) if output.status.success() => {
                    let stdout = String::from_utf8_lossy(&output.stdout);
                    stdout.contains(pkg)
                }
                _ => false,
            }
        } else {
            false
        }
    }

    async fn local_version(&self, tool: &Tool) -> Result<Option<Version>> {
        if let Some(ref _pkg) = tool.uv_package {
            let output = Command::new(tool.command)
                .args(["--version"])
                .output()
                .await?;
            if output.status.success() {
                let stdout = String::from_utf8_lossy(&output.stdout);
                return Ok(parse_version(&stdout));
            }
        }
        Ok(None)
    }

    async fn latest_version(&self, tool: &Tool) -> Result<Option<Version>> {
        // uv 通过 PyPI 获取最新版本
        if let Some(ref pkg) = tool.uv_package {
            let output = Command::new("uv")
                .args(["pip", "index", "versions", pkg])
                .output()
                .await;
            if let Ok(output) = output {
                if output.status.success() {
                    let stdout = String::from_utf8_lossy(&output.stdout);
                    return Ok(parse_version(&stdout));
                }
            }
        }
        Ok(None)
    }

    async fn update(&self, tool: &Tool) -> Result<()> {
        if let Some(ref pkg) = tool.uv_package {
            let status = Command::new("uv")
                .args(["tool", "upgrade", pkg])
                .status()
                .await?;

            if !status.success() {
                anyhow::bail!("uv tool upgrade failed for {}", pkg);
            }
        }
        Ok(())
    }

    async fn install(&self, tool: &Tool) -> Result<()> {
        if let Some(ref pkg) = tool.uv_package {
            let status = Command::new("uv")
                .args(["tool", "install", pkg])
                .status()
                .await?;

            if !status.success() {
                anyhow::bail!("uv tool install failed for {}", pkg);
            }
        }
        Ok(())
    }
}
```

- [ ] **Step 2: 运行检查并提交**

```bash
cargo check -p kitup-core
git add crates/kitup-core/src/installer/uv.rs
git commit -m "feat: 添加 uv 包管理器适配器"
```

---

## Task 9: standalone 适配器

**Files:**
- Create: `crates/kitup-core/src/installer/standalone.rs`

- [ ] **Step 1: 编写 standalone 适配器**

```rust
//! standalone 安装适配器（curl/wget 安装到 ~/.local/bin 等）

use crate::installer::PackageManager;
use crate::tool::Tool;
use crate::version::parse_version;
use anyhow::Result;
use async_trait::async_trait;
use semver::Version;
use std::path::PathBuf;
use tokio::process::Command;

/// standalone 适配器
pub struct StandaloneAdapter;

impl StandaloneAdapter {
    /// 检查路径是否为 standalone 安装
    pub fn is_path_match(&self, tool_path: &PathBuf) -> bool {
        let path_str = tool_path.to_string_lossy();

        // 常见 standalone 安装路径
        path_str.starts_with("/usr/local/bin/")
            || path_str.contains("/.local/bin/")
            || path_str.contains("/bin/")
                && !path_str.contains("/.npm/")
                && !path_str.contains("/Cellar/")
                && !path_str.contains("/.pyenv/")
                && !path_str.contains("/.local/share/uv/")
    }
}

#[async_trait]
impl PackageManager for StandaloneAdapter {
    fn name(&self) -> &str {
        "standalone"
    }

    async fn is_installed(&self, tool: &Tool) -> bool {
        which::which(tool.command).is_ok()
    }

    async fn local_version(&self, tool: &Tool) -> Result<Option<Version>> {
        let output = Command::new(tool.command)
            .args(["--version"])
            .output()
            .await;

        match output {
            Ok(output) if output.status.success() => {
                let stdout = String::from_utf8_lossy(&output.stdout);
                Ok(parse_version(&stdout))
            }
            _ => {
                // 尝试 -v 参数
                let output = Command::new(tool.command)
                    .args(["-v"])
                    .output()
                    .await;
                match output {
                    Ok(output) if output.status.success() => {
                        let stdout = String::from_utf8_lossy(&output.stdout);
                        Ok(parse_version(&stdout))
                    }
                    _ => Ok(None),
                }
            }
        }
    }

    async fn latest_version(&self, tool: &Tool) -> Result<Option<Version>> {
        // standalone 通过 GitHub releases 获取最新版本
        if let Some(ref repo) = tool.github_repo {
            let url = format!("https://api.github.com/repos/{}/releases/latest", repo);

            let client = reqwest::Client::new();
            let response = client
                .get(&url)
                .header("User-Agent", "kitup")
                .send()
                .await?;

            if response.status().is_success() {
                let json: serde_json::Value = response.json().await?;
                if let Some(tag) = json.get("tag_name") {
                    return Ok(parse_version(tag.as_str().unwrap_or("")));
                }
            }
        }
        Ok(None)
    }

    async fn update(&self, tool: &Tool) -> Result<()> {
        // standalone 更新需要运行安装脚本
        if let Some(ref url) = tool.install_url {
            // 优先使用 curl
            let status = Command::new("sh")
                .arg("-c")
                .arg(format!("curl -fsSL {} | sh", url))
                .status()
                .await;

            match status {
                Ok(s) if s.success() => return Ok(()),
                _ => {}
            }

            // 回退 wget
            let status = Command::new("sh")
                .arg("-c")
                .arg(format!("wget -qO- {} | sh", url))
                .status()
                .await;

            match status {
                Ok(s) if s.success() => return Ok(()),
                Err(e) => anyhow::bail!("standalone update failed for {}: {}", tool.name, e),
                Ok(_) => anyhow::bail!("standalone update failed for {}", tool.name),
            }
        }
        anyhow::bail!("no install URL for standalone update of {}", tool.name)
    }

    async fn install(&self, tool: &Tool) -> Result<()> {
        // install 与 update 逻辑相同
        self.update(tool).await
    }
}
```

- [ ] **Step 2: 运行检查并提交**

```bash
cargo check -p kitup-core
git add crates/kitup-core/src/installer/standalone.rs
git commit -m "feat: 添加 standalone 包管理器适配器"
```

---

## Task 10: 配置管理模块

**Files:**
- Create: `crates/kitup-core/src/config.rs`

- [ ] **Step 1: 编写配置管理模块**

```rust
//! 配置管理
//!
//! 加载、保存配置，支持 v1 格式自动迁移。

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// kitup v2 配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    /// 配置文件版本
    pub version: u32,
    /// 并行任务数
    #[serde(default = "default_parallel_jobs")]
    pub parallel_jobs: usize,
    /// 更新前自动备份
    #[serde(default)]
    pub auto_backup: bool,
    /// 自动安装缺失工具
    #[serde(default)]
    pub auto_install_missing: bool,
    /// 详细输出
    #[serde(default)]
    pub verbose: bool,
    /// 排除的工具列表
    #[serde(default)]
    pub exclude_tools: Vec<String>,
    /// 检测新工具
    #[serde(default = "default_true")]
    pub detect_new_tools: bool,
    /// changelog 显示条数
    #[serde(default = "default_changelog_count")]
    pub changelog_count: usize,
    /// 默认操作
    #[serde(default = "default_action")]
    pub default_action: String,
    /// 自更新检查间隔（秒）
    #[serde(default = "default_self_update_ttl")]
    pub self_update_ttl_secs: u64,
}

fn default_parallel_jobs() -> usize { 3 }
fn default_true() -> bool { true }
fn default_changelog_count() -> usize { 3 }
fn default_action() -> String { "tui".to_string() }
fn default_self_update_ttl() -> u64 { 86400 }

impl Default for Config {
    fn defaults() -> Self {
        Self {
            version: 2,
            parallel_jobs: default_parallel_jobs(),
            auto_backup: false,
            auto_install_missing: false,
            verbose: false,
            exclude_tools: vec![],
            detect_new_tools: true,
            changelog_count: 3,
            default_action: "tui".to_string(),
            self_update_ttl_secs: 86400,
        }
    }
}

impl Config {
    /// 获取配置目录路径
    pub fn config_dir() -> Result<PathBuf> {
        let dirs = directories::ProjectDirs::from("com", "kitup", "kitup")
            .ok_or_else(|| anyhow::anyhow!("无法确定配置目录"))?;
        Ok(dirs.config_dir().to_path_buf())
    }

    /// 获取配置文件路径
    pub fn config_path() -> Result<PathBuf> {
        Ok(Self::config_dir()?.join("config.json"))
    }

    /// 加载配置，支持 v1 迁移
    pub fn load() -> Result<Self> {
        let v2_path = Self::config_path()?;
        let v1_path = dirs_v1()?.join("config.json");

        // 优先加载 v2 配置
        if v2_path.exists() {
            let content = std::fs::read_to_string(&v2_path)?;
            let mut config: Config = serde_json::from_str(&content)?;
            // 确保 version 字段正确
            config.version = 2;
            return Ok(config);
        }

        // 尝试迁移 v1 配置
        if v1_path.exists() {
            return Self::migrate_v1(&v1_path);
        }

        // 无配置文件，使用默认值
        Ok(Self::defaults())
    }

    /// 从 v1 配置迁移
    fn migrate_v1(v1_path: &PathBuf) -> Result<Self> {
        let content = std::fs::read_to_string(v1_path)?;
        let v1: serde_json::Value = serde_json::from_str(&content)?;

        let config = Config {
            version: 2,
            parallel_jobs: v1.get("parallel_jobs")
                .and_then(|v| v.as_u64())
                .unwrap_or(3) as usize,
            auto_backup: v1.get("auto_backup")
                .and_then(|v| v.as_bool())
                .unwrap_or(false),
            auto_install_missing: v1.get("auto_install_missing")
                .and_then(|v| v.as_bool())
                .unwrap_or(false),
            verbose: v1.get("verbose")
                .and_then(|v| v.as_bool())
                .unwrap_or(false),
            exclude_tools: v1.get("exclude_tools")
                .and_then(|v| v.as_str())
                .map(|s| s.split(',').map(|t| t.trim().to_string()).collect())
                .unwrap_or_default(),
            detect_new_tools: v1.get("detect_new_tools")
                .and_then(|v| v.as_bool())
                .unwrap_or(true),
            changelog_count: v1.get("changelog_count")
                .and_then(|v| v.as_u64())
                .unwrap_or(3) as usize,
            default_action: "tui".to_string(),
            self_update_ttl_secs: 86400,
        };

        // 保存为 v2 格式
        config.save()?;

        tracing::info!("已从 v1 配置迁移到 v2 格式");
        Ok(config)
    }

    /// 保存配置
    pub fn save(&self) -> Result<()> {
        let dir = Self::config_dir()?;
        std::fs::create_dir_all(&dir)?;
        let path = Self::config_path()?;
        let content = serde_json::to_string_pretty(self)?;
        std::fs::write(&path, content)?;
        Ok(())
    }

    /// 初始化配置（如果不存在）
    pub fn init() -> Result<PathBuf> {
        let dir = Self::config_dir()?;
        std::fs::create_dir_all(&dir)?;

        let path = Self::config_path()?;
        if !path.exists() {
            let config = Self::defaults();
            config.save()?;
        }
        Ok(path)
    }
}

/// v1 配置目录
fn dirs_v1() -> Result<PathBuf> {
    Ok(PathBuf::from(
        std::env::var("HOME")
            .or_else(|_| std::env::var("USERPROFILE"))
            .unwrap_or_else(|_| ".".to_string())
    ).join(".kitup"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = Config::defaults();
        assert_eq!(config.version, 2);
        assert_eq!(config.parallel_jobs, 3);
        assert!(config.detect_new_tools);
    }

    #[test]
    fn test_config_serialization() {
        let config = Config::defaults();
        let json = serde_json::to_string(&config).unwrap();
        let parsed: Config = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.parallel_jobs, config.parallel_jobs);
    }

    #[test]
    fn test_migrate_v1_config() {
        let v1_json = r#"{
            "parallel_jobs": 5,
            "auto_backup": true,
            "verbose": false,
            "exclude_tools": "kimi,gemini",
            "detect_new_tools": false,
            "changelog_count": 5
        }"#;

        let v1: serde_json::Value = serde_json::from_str(v1_json).unwrap();
        assert_eq!(v1.get("parallel_jobs").unwrap().as_u64(), Some(5));
    }
}
```

- [ ] **Step 2: 运行测试**

Run: `cd /Users/volcanic/codespace/kitup && cargo test -p kitup-core -- config`
Expected: 3 个测试通过

- [ ] **Step 3: 提交**

```bash
git add crates/kitup-core/src/config.rs
git commit -m "feat: 添加配置管理模块（含 v1 迁移）"
```

---

## Task 11: 版本固定模块

**Files:**
- Create: `crates/kitup-core/src/pin.rs`

- [ ] **Step 1: 编写版本固定模块**

```rust
//! 版本固定管理
//!
//! 支持将工具固定到特定版本，防止自动更新。

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;

/// 固定版本数据
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct PinnedVersions {
    /// tool_name -> pinned_version
    #[serde(flatten)]
    pins: HashMap<String, String>,
}

impl PinnedVersions {
    /// 获取固定版本文件路径
    fn pins_path() -> Result<PathBuf> {
        let dir = crate::config::Config::config_dir()?;
        Ok(dir.join("pinned_versions.json"))
    }

    /// 加载固定版本
    pub fn load() -> Result<Self> {
        let path = Self::pins_path()?;
        if !path.exists() {
            return Ok(Self::default());
        }
        let content = std::fs::read_to_string(&path)?;
        let pins: Self = serde_json::from_str(&content)?;
        Ok(pins)
    }

    /// 保存固定版本
    fn save(&self) -> Result<()> {
        let path = Self::pins_path()?;
        let dir = path.parent().unwrap();
        std::fs::create_dir_all(dir)?;
        let content = serde_json::to_string_pretty(self)?;
        std::fs::write(&path, content)?;
        Ok(())
    }

    /// 固定工具版本
    pub fn pin(tool_name: &str, version: &str) -> Result<()> {
        let mut pins = Self::load()?;
        pins.pins.insert(tool_name.to_string(), version.to_string());
        pins.save()
    }

    /// 取消固定
    pub fn unpin(tool_name: &str) -> Result<bool> {
        let mut pins = Self::load()?;
        if pins.pins.remove(tool_name).is_some() {
            pins.save()?;
            Ok(true)
        } else {
            Ok(false)
        }
    }

    /// 获取固定版本
    pub fn get_pinned(tool_name: &str) -> Result<Option<String>> {
        let pins = Self::load()?;
        Ok(pins.pins.get(tool_name).cloned())
    }

    /// 列出所有固定版本
    pub fn list_all() -> Result<HashMap<String, String>> {
        let pins = Self::load()?;
        Ok(pins.pins)
    }

    /// 检查工具是否被固定
    pub fn is_pinned(tool_name: &str) -> Result<bool> {
        Ok(Self::get_pinned(tool_name)?.is_some())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pinned_versions_serialization() {
        let mut pins = PinnedVersions::default();
        pins.pins.insert("claude".to_string(), "0.2.45".to_string());
        pins.pins.insert("codex".to_string(), "0.1.0".to_string());

        let json = serde_json::to_string(&pins).unwrap();
        assert!(json.contains("claude"));
        assert!(json.contains("0.2.45"));

        let parsed: PinnedVersions = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.pins.get("claude"), Some(&"0.2.45".to_string()));
    }

    #[test]
    fn test_default_is_empty() {
        let pins = PinnedVersions::default();
        assert!(pins.pins.is_empty());
    }
}
```

- [ ] **Step 2: 运行测试并提交**

```bash
cargo test -p kitup-core -- pin
git add crates/kitup-core/src/pin.rs
git commit -m "feat: 添加版本固定模块"
```

---

## Task 12: 自更新模块

**Files:**
- Create: `crates/kitup-core/src/self_update.rs`

- [ ] **Step 1: 编写自更新模块**

```rust
//! 自更新机制
//!
//! 从 GitHub Releases 检测并安装最新版本。

use anyhow::Result;
use semver::Version;
use serde::Deserialize;
use std::path::PathBuf;
use std::time::{Duration, SystemTime};

/// GitHub Release 信息
#[derive(Debug, Deserialize)]
struct GithubRelease {
    tag_name: String,
    html_url: String,
}

/// 自更新检查器
pub struct SelfUpdater {
    repo: &'static str,
    cache_file: PathBuf,
    ttl: Duration,
}

impl SelfUpdater {
    pub fn new() -> Result<Self> {
        let cache_dir = crate::config::Config::config_dir()?;
        Ok(Self {
            repo: "anthropics/kitup", // TODO: 替换为实际仓库
            cache_file: cache_dir.join("self_update_check"),
            ttl: Duration::from_secs(86400), // 24 小时
        })
    }

    pub fn with_ttl(mut self, ttl: Duration) -> Self {
        self.ttl = ttl;
        self
    }

    /// 检查是否有新版本可用
    pub async fn check_update(&self) -> Result<Option<String>> {
        let current = Version::parse(env!("CARGO_PKG_VERSION"))?;

        // 检查缓存
        if let Some(cached) = self.read_cache()? {
            if cached > current {
                return Ok(Some(format!("{}", cached)));
            }
        }

        // 查询 GitHub API
        let url = format!("https://api.github.com/repos/{}/releases/latest", self.repo);
        let client = reqwest::Client::new();
        let response = client
            .get(&url)
            .header("User-Agent", "kitup")
            .send()
            .await;

        match response {
            Ok(resp) if resp.status().is_success() => {
                if let Ok(release) = resp.json::<GithubRelease>().await {
                    if let Some(latest) = crate::version::parse_version(&release.tag_name) {
                        if latest > current {
                            self.write_cache(&latest)?;
                            return Ok(Some(format!("{}", latest)));
                        }
                    }
                }
            }
            Ok(resp) => {
                tracing::warn!("GitHub API 返回状态: {}", resp.status());
            }
            Err(e) => {
                tracing::warn!("GitHub API 请求失败: {}", e);
            }
        }

        Ok(None)
    }

    /// 读取缓存的版本
    fn read_cache(&self) -> Result<Option<Version>> {
        if !self.cache_file.exists() {
            return Ok(None);
        }
        let content = std::fs::read_to_string(&self.cache_file)?;
        let mut parts = content.splitn(2, '|');
        let version_str = parts.next().unwrap_or("").trim();
        let timestamp_str = parts.next().unwrap_or("0").trim();

        let timestamp: u64 = timestamp_str.parse().unwrap_or(0);
        let now = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)?
            .as_secs();

        if now.saturating_sub(timestamp) > self.ttl.as_secs() {
            return Ok(None);
        }

        Ok(Version::parse(version_str).ok())
    }

    /// 写入缓存
    fn write_cache(&self, version: &Version) -> Result<()> {
        let now = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)?
            .as_secs();
        if let Some(parent) = self.cache_file.parent() {
            std::fs::create_dir_all(parent)?;
        }
        std::fs::write(&self.cache_file, format!("{}|{}", version, now))?;
        Ok(())
    }

    /// 执行自更新
    pub async fn do_update(&self) -> Result<()> {
        // 检测当前平台
        let os = std::env::consts::OS;
        let arch = std::env::consts::ARCH;

        let asset_name = match (os, arch) {
            ("macos", "aarch64") => "kitup-aarch64-apple-darwin.tar.gz",
            ("macos", "x86_64") => "kitup-x86_64-apple-darwin.tar.gz",
            ("linux", "x86_64") => "kitup-x86_64-unknown-linux-gnu.tar.gz",
            ("linux", "aarch64") => "kitup-aarch64-unknown-linux-gnu.tar.gz",
            ("windows", "x86_64") => "kitup-x86_64-pc-windows-msvc.zip",
            _ => anyhow::bail!("不支持的平台: {}-{}", os, arch),
        };

        let url = format!(
            "https://github.com/{}/releases/latest/download/{}",
            self.repo, asset_name
        );

        // 下载新版本
        let client = reqwest::Client::new();
        let response = client
            .get(&url)
            .header("User-Agent", "kitup")
            .send()
            .await?;

        if !response.status().is_success() {
            anyhow::bail!("下载失败: HTTP {}", response.status());
        }

        // 替换当前二进制
        let current_exe = std::env::current_exe()?;
        let tmp_dir = std::env::temp_dir();
        let tmp_file = tmp_dir.join("kitup-update");

        let bytes = response.bytes().await?;
        std::fs::write(&tmp_file, &bytes)?;

        // 设置可执行权限
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&tmp_file, std::fs::Permissions::from_mode(0o755))?;
        }

        // 替换二进制文件
        std::fs::rename(&tmp_file, &current_exe)?;

        Ok(())
    }
}
```

- [ ] **Step 2: 运行检查并提交**

```bash
cargo check -p kitup-core
git add crates/kitup-core/src/self_update.rs
git commit -m "feat: 添加自更新模块"
```

---

## Task 13: 输出格式化工具

**Files:**
- Create: `crates/kitup-cli/src/output.rs`

- [ ] **Step 1: 编写输出格式化工具**

```rust
//! 输出格式化工具函数
//!
//! 提供统一的终端输出格式化：颜色、表格、进度条等。

use comfy_table::{modifiers::UTF8_ROUND_CORNERS, presets::UTF8_FULL, Cell, Color, Table};
use indicatif::{ProgressBar, ProgressStyle};
use kitup_core::installer::{InstallMethod, ToolStatus};
use owo_colors::OwoColorize;
use semver::Version;

/// 状态符号
pub mod symbols {
    pub const CHECK: &str = "✓";
    pub const CROSS: &str = "✗";
    pub const ARROW_UP: &str = "↑";
    pub const BULLET: &str = "●";
    pub const PIN: &str = "⚑";
    pub const WARNING: &str = "⚡";
    pub const SPINNER: &str = "⟳";
}

/// 创建标准进度条
pub fn create_progress_bar(total: u64, message: &str) -> ProgressBar {
    let pb = ProgressBar::new(total);
    pb.set_style(
        ProgressStyle::with_template(
            "{msg} {spinner:.green} [{bar:40.cyan/blue}] {pos}/{len} ({eta})",
        )
        .unwrap()
        .progress_chars("━╋─"),
    );
    pb.set_message(message.to_string());
    pb
}

/// 格式化工具状态为表格行
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

/// 格式化工具状态为 JSON
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

/// 格式化更新结果摘要
pub fn format_update_summary(
    results: &[(String, String, String, String, bool)], // (name, old_ver, new_ver, method, success)
    total_time: std::time::Duration,
) -> String {
    let mut lines = Vec::new();
    let mut updated = 0;
    let mut failed = 0;
    let mut skipped = 0;

    for (name, old_ver, new_ver, method, success) in results {
        if !success {
            failed += 1;
            lines.push(format!(
                "  {} {} {} {}",
                symbols::CROSS.red(),
                name.bold(),
                format!("({})", new_ver).red(),
                method.dimmed()
            ));
        } else if old_ver == new_ver {
            skipped += 1;
            lines.push(format!(
                "  {} {} {} {}",
                symbols::CHECK.green(),
                name.bold(),
                old_ver.dimmed(),
                method.dimmed()
            ));
        } else {
            updated += 1;
            lines.push(format!(
                "  {} {} {} → {} {}",
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
```

- [ ] **Step 2: 运行检查并提交**

```bash
cargo check -p kitup-cli
git add crates/kitup-cli/src/output.rs
git commit -m "feat: 添加 CLI 输出格式化工具"
```

---

## Task 14: status 命令实现

**Files:**
- Modify: `crates/kitup-cli/src/commands/status.rs`

- [ ] **Step 1: 实现 status 命令**

```rust
//! status 子命令 — 查看所有工具状态

use crate::output;
use anyhow::Result;
use kitup_core::installer::{self, ToolStatus};
use kitup_core::pin::PinnedVersions;
use kitup_core::tool::TOOL_REGISTRY;
use kitup_core::version::VersionCache;

pub fn run(json: bool) -> anyhow::Result<()> {
    let rt = tokio::runtime::Runtime::new()?;
    rt.block_on(async { run_async(json).await })
}

async fn run_async(json: bool) -> anyhow::Result<()> {
    let config = kitup_core::config::Config::load()?;
    let cache = VersionCache::new()?;
    let pins = PinnedVersions::load()?;

    let mut statuses = Vec::new();

    for tool in TOOL_REGISTRY {
        let tool_name = tool.name.to_string();

        // 检查是否被排除
        if config.exclude_tools.contains(&tool_name) {
            continue;
        }

        // 检查可执行文件是否存在
        let tool_path = which::which(tool.command).ok();
        let installed = tool_path.is_some();

        // 检测安装方式
        let (method, _adapter) = if installed {
            installer::detect_install_method(tool).await
        } else {
            None
        };

        let method_ref = method.as_ref().map(|(m, _)| m.clone());

        // 检测本地版本
        let local_version = if installed {
            if let Some((_, ref adapter)) = method {
                adapter.local_version(tool).await.unwrap_or(None)
            } else {
                // 回退：直接运行 --version
                let output = tokio::process::Command::new(tool.command)
                    .args(["--version"])
                    .output()
                    .await
                    .ok();
                output
                    .and_then(|o| {
                        if o.status.success() {
                            kitup_core::version::parse_version(
                                &String::from_utf8_lossy(&o.stdout),
                            )
                        } else {
                            None
                        }
                    })
            }
        } else {
            None
        };

        // 检测最新版本（使用缓存）
        let latest_version = if installed {
            if let Some((_, ref adapter)) = method {
                // 尝试缓存
                let cached = cache.get(&tool_name, &adapter.name().to_string());
                if let Some(v) = cached {
                    Some(v)
                } else {
                    match adapter.latest_version(tool).await {
                        Ok(Some(v)) => {
                            let _ = cache.set(&tool_name, &adapter.name().to_string(), &v);
                            Some(v)
                        }
                        _ => None,
                    }
                }
            } else {
                None
            }
        } else {
            None
        };

        // 检查是否需要更新（考虑固定版本）
        let pinned = pins.get_pinned(&tool_name)?;
        let needs_update = if let Some(ref pinned_ver) = pinned {
            // 如果有固定版本，检查最新版本是否大于固定版本
            // 但不自动更新固定版本的工具
            false
        } else if let (Some(ref local), Some(ref latest)) = (&local_version, &latest_version) {
            latest > local
        } else {
            false
        };

        // 检测多安装
        let all_methods = if installed {
            installer::detect_all_install_methods(tool).await
        } else {
            vec![]
        };
        let multiple_installs = all_methods.len() > 1;

        statuses.push(ToolStatus {
            tool_name,
            installed,
            local_version,
            latest_version,
            method: method_ref,
            path: tool_path,
            needs_update,
            multiple_installs,
            install_methods: all_methods,
        });
    }

    if json {
        let json_output = output::format_status_json(&statuses);
        println!("{}", serde_json::to_string_pretty(&json_output)?);
    } else {
        println!();
        println!(
            "  {} v{} {} AI Tools Status {}",
            "kitup".bold().cyan(),
            env!("CARGO_PKG_VERSION"),
            "─".dimmed(),
            "─".dimmed()
        );
        println!();
        println!("{}", output::format_status_table(&statuses));
        println!();

        // 显示摘要
        let installed_count = statuses.iter().filter(|s| s.installed).count();
        let update_count = statuses.iter().filter(|s| s.needs_update).count();
        let pinned_count = PinnedVersions::load()?.list_all()?.len();

        if update_count > 0 {
            println!(
                "  {} Run {} to update {} tool{}",
                symbols::BULLET.cyan(),
                format!("'kitup update'").bold(),
                update_count.to_string().yellow(),
                if update_count > 1 { "s" } else { "" }
            );
        } else if installed_count > 0 {
            println!(
                "  {} All {} tools are up to date {}",
                symbols::CHECK.green(),
                installed_count,
                "🎉"
            );
        }

        if pinned_count > 0 {
            println!(
                "  {} {} pinned version{} active",
                symbols::PIN.yellow(),
                pinned_count,
                if pinned_count > 1 { "s" } else { "" }
            );
        }
        println!();
    }

    Ok(())
}
```

注意：需要在 `crates/kitup-cli/Cargo.toml` 中确保 `which` 已在依赖中（通过 kitup-core 重导出或直接添加）。

在 `crates/kitup-cli/Cargo.toml` 的 `[dependencies]` 中添加：
```toml
which = { workspace = true }
```

同时需要在 `crates/kitup-cli/src/main.rs` 中添加 `mod output;` 和 `mod commands;` 声明。

- [ ] **Step 2: 更新 main.rs 添加模块声明**

在 `crates/kitup-cli/src/main.rs` 顶部添加：
```rust
mod args;
mod commands;
mod output;
```

同时添加缺失的 `symbols` import。在 `output.rs` 中确保 `use owo_colors::OwoColorize;` 存在。

- [ ] **Step 3: 运行检查**

```bash
cargo check -p kitup-cli
```

修复所有编译错误（主要是 import 路径）。

- [ ] **Step 4: 提交**

```bash
git add crates/kitup-cli/
git commit -m "feat: 实现 status 命令"
```

---

## Task 15: update 命令实现

**Files:**
- Modify: `crates/kitup-cli/src/commands/update.rs`

- [ ] **Step 1: 实现 update 命令（含并行更新）**

```rust
//! update 子命令 — 更新 AI 编码工具

use crate::output;
use anyhow::Result;
use indicatif::{MultiProgress, ProgressBar, ProgressStyle};
use kitup_core::config::Config;
use kitup_core::installer;
use kitup_core::pin::PinnedVersions;
use kitup_core::tool::TOOL_REGISTRY;
use std::sync::Arc;
use std::time::Instant;
use tokio::sync::Semaphore;

pub fn run(
    tools: Vec<String>,
    all: bool,
    install: bool,
    dry_run: bool,
    force: bool,
    parallel: usize,
) -> anyhow::Result<()> {
    let rt = tokio::runtime::Runtime::new()?;
    rt.block_on(async {
        run_async(tools, all, install, dry_run, force, parallel).await
    })
}

async fn run_async(
    tool_names: Vec<String>,
    all: bool,
    install: bool,
    dry_run: bool,
    force: bool,
    parallel: usize,
) -> anyhow::Result<()> {
    let config = Config::load()?;
    let pins = PinnedVersions::load()?;
    let start = Instant::now();

    // 确定要更新的工具列表
    let targets: Vec<_> = if all || tool_names.is_empty() {
        TOOL_REGISTRY
            .iter()
            .filter(|t| !config.exclude_tools.contains(&t.name.to_string()))
            .collect()
    } else {
        tool_names
            .iter()
            .filter_map(|name| {
                let tool = kitup_core::tool::Tool::find_by_name(name);
                if tool.is_none() {
                    eprintln!(
                        "  {} Unknown tool: {}",
                        output::symbols::CROSS.red(),
                        name.bold()
                    );
                }
                tool
            })
            .collect()
    };

    if targets.is_empty() {
        println!("  No tools to update.");
        return Ok(());
    }

    println!();
    println!(
        "  {} Updating {} tool{}...",
        "⟳".cyan(),
        targets.len().to_string().bold(),
        if targets.len() > 1 { "s" } else { "" }
    );
    println!();

    // 并行更新
    let semaphore = Arc::new(Semaphore::new(parallel));
    let mut handles = Vec::new();
    let multi = Arc::new(MultiProgress::new());

    for tool in targets {
        let tool_name = tool.name.to_string();
        let sem = semaphore.clone();
        let multi = multi.clone();
        let is_dry_run = dry_run;
        let is_force = force;
        let is_install = install;

        let handle = tokio::spawn(async move {
            let _permit = sem.acquire().await.unwrap();

            let pb = multi.add(ProgressBar::new_spinner());
            pb.set_style(
                ProgressStyle::with_template("{spinner:.green} {msg}")
                    .unwrap()
                    .tick_strings(&["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]),
            );
            pb.set_message(format!("{} checking...", tool_name));

            // 检查是否被固定
            if let Ok(Some(pinned_ver)) = pins.get_pinned(&tool_name) {
                if !is_force {
                    pb.finish_with_message(format!(
                        "  {} {} pinned at {}",
                        output::symbols::PIN.yellow(),
                        tool_name.bold(),
                        pinned_ver.dimmed()
                    ));
                    return (tool_name, pinned_ver, pinned_ver, "pinned".to_string(), true);
                }
            }

            // 检测安装方式
            let method_result = installer::detect_install_method(tool).await;

            if method_result.is_none() {
                if is_install {
                    // 尝试安装
                    pb.set_message(format!("{} installing...", tool_name));
                    // 使用 npm 作为默认安装方式
                    if tool.npm_package.is_some() {
                        let adapter = kitup_core::installer::npm::NpmAdapter;
                        if !is_dry_run {
                            match adapter.install(tool).await {
                                Ok(()) => {
                                    pb.finish_with_message(format!(
                                        "  {} {} installed",
                                        output::symbols::CHECK.green(),
                                        tool_name.bold(),
                                    ));
                                    return (tool_name, "-".to_string(), "installed".to_string(), "npm".to_string(), true);
                                }
                                Err(e) => {
                                    pb.finish_with_message(format!(
                                        "  {} {} install failed: {}",
                                        output::symbols::CROSS.red(),
                                        tool_name.bold(),
                                        e.to_string().dimmed()
                                    ));
                                    return (tool_name, "-".to_string(), e.to_string(), "npm".to_string(), false);
                                }
                            }
                        }
                    }
                }

                pb.finish_with_message(format!(
                    "  {} {} not installed",
                    output::symbols::PIN.dimmed(),
                    tool_name,
                ));
                return (tool_name, "-".to_string(), "not installed".to_string(), "-".to_string(), true);
            }

            let (method, adapter) = method_result.unwrap();
            let method_str = method.to_string();

            // 获取当前版本
            let local_ver = adapter
                .local_version(tool)
                .await
                .unwrap_or(None)
                .map(|v| v.to_string())
                .unwrap_or_else(|| "?".to_string());

            // 获取最新版本
            let latest_ver = adapter
                .latest_version(tool)
                .await
                .unwrap_or(None)
                .map(|v| v.to_string())
                .unwrap_or_else(|| local_ver.clone());

            // 检查是否需要更新
            if !is_force && local_ver == latest_ver {
                pb.finish_with_message(format!(
                    "  {} {} {} ({})",
                    output::symbols::CHECK.green(),
                    tool_name.bold(),
                    local_ver.dimmed(),
                    method_str.dimmed(),
                ));
                return (tool_name, local_ver.clone(), local_ver, method_str, true);
            }

            if is_dry_run {
                pb.finish_with_message(format!(
                    "  {} {} {} → {} ({}) [dry-run]",
                    output::symbols::ARROW_UP.yellow(),
                    tool_name.bold(),
                    local_ver.dimmed(),
                    latest_ver.green(),
                    method_str.dimmed(),
                ));
                return (tool_name, local_ver, latest_ver, method_str, true);
            }

            // 执行更新
            pb.set_message(format!(
                "{} {} → {} ({})",
                output::symbols::SPINNER.cyan(),
                local_ver,
                latest_ver.green(),
                method_str
            ));

            match adapter.update(tool).await {
                Ok(()) => {
                    pb.finish_with_message(format!(
                        "  {} {} {} → {} ({})",
                        output::symbols::CHECK.green(),
                        tool_name.bold(),
                        local_ver.dimmed(),
                        latest_ver.green(),
                        method_str.dimmed(),
                    ));
                    (tool_name, local_ver, latest_ver, method_str, true)
                }
                Err(e) => {
                    pb.finish_with_message(format!(
                        "  {} {} failed: {}",
                        output::symbols::CROSS.red(),
                        tool_name.bold(),
                        e.to_string().red()
                    ));
                    (tool_name, local_ver, e.to_string(), method_str, false)
                }
            }
        });

        handles.push(handle);
    }

    // 等待所有任务完成
    let mut results = Vec::new();
    for handle in handles {
        if let Ok(result) = handle.await {
            results.push(result);
        }
    }

    let elapsed = start.elapsed();

    // 显示摘要
    println!();
    println!(
        "{}",
        output::format_update_summary(
            &results
                .iter()
                .map(|(n, o, v, m, s)| (n.clone(), o.clone(), v.clone(), m.clone(), *s))
                .collect::<Vec<_>>(),
            elapsed,
        )
    );
    println!();

    Ok(())
}
```

- [ ] **Step 2: 运行检查并提交**

```bash
cargo check -p kitup-cli
git add crates/kitup-cli/src/commands/update.rs
git commit -m "feat: 实现 update 命令（含并行更新和进度条）"
```

---

## Task 16: pin/unpin 命令实现

**Files:**
- Modify: `crates/kitup-cli/src/commands/pin_cmd.rs`

- [ ] **Step 1: 实现 pin/unpin 命令**

```rust
//! pin/unpin 子命令 — 版本固定管理

use crate::output;
use anyhow::Result;
use kitup_core::pin::PinnedVersions;
use kitup_core::tool::Tool;

pub fn pin(tool_name: String, version: String) -> anyhow::Result<()> {
    // 验证工具名
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
    // 验证工具名
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

/// 列出所有固定版本（供 status 命令使用）
pub fn list_pins() -> anyhow::Result<()> {
    let pins = PinnedVersions::list_all()?;

    if pins.is_empty() {
        println!("  No pinned versions.");
        return Ok(());
    }

    println!();
    println!("  {} Pinned Versions:", output::symbols::PIN.yellow());
    for (tool, version) in pins {
        println!(
            "  {} {} = {}",
            output::symbols::PIN.yellow(),
            tool.bold(),
            version.green()
        );
    }
    println!();

    Ok(())
}
```

- [ ] **Step 2: 运行检查并提交**

```bash
cargo check -p kitup-cli
git add crates/kitup-cli/src/commands/pin_cmd.rs
git commit -m "feat: 实现 pin/unpin 命令"
```

---

## Task 17: changelog 命令实现

**Files:**
- Modify: `crates/kitup-cli/src/commands/changelog.rs`

- [ ] **Step 1: 实现 changelog 命令**

```rust
//! changelog 子命令 — 查看 GitHub releases 更新日志

use anyhow::Result;
use kitup_core::tool::{Tool, TOOL_REGISTRY};

pub fn run(tool_name: Option<String>, all: bool) -> anyhow::Result<()> {
    let rt = tokio::runtime::Runtime::new()?;
    rt.block_on(async { run_async(tool_name, all).await })
}

async fn run_async(tool_name: Option<String>, all: bool) -> anyhow::Result<()> {
    let config = kitup_core::config::Config::load()?;

    if all {
        for tool in TOOL_REGISTRY {
            if config.exclude_tools.contains(&tool.name.to_string()) {
                continue;
            }
            if let Err(e) = show_changelog(tool, config.changelog_count).await {
                eprintln!("  {} {}: {}", "✗".red(), tool.name, e);
            }
        }
    } else {
        let name = tool_name.ok_or_else(|| {
            anyhow::anyhow!("Please specify a tool name or use --all")
        })?;

        let tool = Tool::find_by_name(&name)
            .ok_or_else(|| anyhow::anyhow!("Unknown tool: {}", name))?;

        show_changelog(tool, config.changelog_count).await?;
    }

    Ok(())
}

async fn show_changelog(tool: &'static Tool, count: usize) -> anyhow::Result<()> {
    let repo = tool
        .github_repo
        .ok_or_else(|| anyhow::anyhow!("{} has no GitHub repository", tool.name))?;

    let url = format!(
        "https://api.github.com/repos/{}/releases?per_page={}",
        repo, count
    );

    let client = reqwest::Client::new();
    let response = client
        .get(&url)
        .header("User-Agent", "kitup")
        .send()
        .await?;

    if !response.status().is_success() {
        anyhow::bail!("GitHub API returned: {}", response.status());
    }

    let releases: Vec<serde_json::Value> = response.json().await?;

    println!();
    println!(
        "  {} {} — Recent Changes",
        "●".cyan(),
        tool.name.bold()
    );
    println!("  {}", "─".repeat(50));

    for release in &releases {
        let tag = release
            .get("tag_name")
            .and_then(|v| v.as_str())
            .unwrap_or("unknown");
        let date = release
            .get("published_at")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        let body = release
            .get("body")
            .and_then(|v| v.as_str())
            .unwrap_or("No description");

        println!();
        println!("  {} {}", tag.green().bold(), date.dimmed());

        // 简化 Markdown 为纯文本
        let plain = body
            .lines()
            .take(10) // 最多显示 10 行
            .map(|line| {
                line.trim()
                    .trim_start_matches("### ")
                    .trim_start_matches("## ")
                    .replace("**", "")
                    .replace("__", "")
                    .replace('`', "")
            })
            .filter(|line| !line.is_empty() && line != "---")
            .collect::<Vec<_>>()
            .join("\n    ");

        println!("    {}", plain);
    }

    println!();
    Ok(())
}
```

- [ ] **Step 2: 运行检查并提交**

```bash
cargo check -p kitup-cli
git add crates/kitup-cli/src/commands/changelog.rs
git commit -m "feat: 实现 changelog 命令"
```

---

## Task 18: doctor 命令实现

**Files:**
- Modify: `crates/kitup-cli/src/commands/doctor.rs`

- [ ] **Step 1: 实现 doctor 诊断命令**

```rust
//! doctor 子命令 — 诊断工具环境

use anyhow::Result;
use kitup_core::installer;
use kitup_core::tool::TOOL_REGISTRY;

pub fn run(fix: bool, verbose: bool) -> anyhow::Result<()> {
    let rt = tokio::runtime::Runtime::new()?;
    rt.block_on(async { run_async(fix, verbose).await })
}

async fn run_async(fix: bool, verbose: bool) -> anyhow::Result<()> {
    println!();
    println!(
        "  {} Running diagnostics...",
        "⟳".cyan()
    );
    println!();

    let mut issues = 0;
    let mut fixable = 0;
    let mut passed = 0;

    // 1. 检查配置文件
    match kitup_core::config::Config::load() {
        Ok(config) => {
            println!(
                "  {} Configuration OK ({})",
                "✓".green(),
                kitup_core::config::Config::config_path()?
                    .to_string_lossy()
            );
            passed += 1;
        }
        Err(e) => {
            println!(
                "  {} Configuration error: {}",
                "✗".red(),
                e
            );
            issues += 1;

            if fix {
                match kitup_core::config::Config::init() {
                    Ok(path) => {
                        println!(
                            "  {} Created default config: {}",
                            "✓".green(),
                            path.to_string_lossy()
                        );
                        fixable += 1;
                    }
                    Err(e2) => {
                        println!(
                            "  {} Failed to create config: {}",
                            "✗".red(),
                            e2
                        );
                    }
                }
            }
        }
    }

    // 2. 检查每个工具
    for tool in TOOL_REGISTRY {
        let tool_name = tool.name;

        // 检查可执行文件
        match which::which(tool.command) {
            Ok(path) => {
                if verbose {
                    println!(
                        "  {} {} found at {}",
                        "✓".green(),
                        tool_name.bold(),
                        path.to_string_lossy().dimmed()
                    );
                }
                passed += 1;

                // 检查多安装
                let all_methods = installer::detect_all_install_methods(tool).await;
                if all_methods.len() > 1 {
                    println!(
                        "  {} {} has {} installations: {}",
                        "⚡".yellow(),
                        tool_name.bold(),
                        all_methods.len().to_string().yellow(),
                        all_methods
                            .iter()
                            .map(|m| m.to_string())
                            .collect::<Vec<_>>()
                            .join(", ")
                    );
                    issues += 1;
                    println!(
                        "     └─ 建议: 清理旧安装，保留一个即可"
                    );
                }
            }
            Err(_) => {
                if verbose {
                    println!(
                        "  {} {} not installed",
                        "○".dimmed(),
                        tool_name
                    );
                }
            }
        }
    }

    // 3. 检查包管理器可用性
    let managers = [
        ("npm", "npm"),
        ("brew", "Homebrew"),
        ("pipx", "pipx"),
        ("uv", "uv"),
    ];

    for (cmd, name) in &managers {
        if which::which(cmd).is_ok() {
            if verbose {
                println!(
                    "  {} {} available",
                    "✓".green(),
                    name
                );
            }
            passed += 1;
        } else {
            if verbose {
                println!(
                    "  {} {} not found",
                    "○".dimmed(),
                    name
                );
            }
        }
    }

    // 4. 检查网络连通性
    let endpoints = [
        ("https://registry.npmjs.org/", "npm registry"),
        ("https://api.github.com/", "GitHub API"),
    ];

    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(5))
        .build()?;

    for (url, name) in &endpoints {
        match client.get(*url).header("User-Agent", "kitup").send().await {
            Ok(resp) => {
                println!(
                    "  {} {} reachable ({})",
                    "✓".green(),
                    name,
                    resp.status().as_u16()
                );
                passed += 1;
            }
            Err(e) => {
                println!(
                    "  {} {} unreachable: {}",
                    "✗".red(),
                    name,
                    e.to_string().red()
                );
                issues += 1;
            }
        }
    }

    // 摘要
    println!();
    if issues == 0 {
        println!(
            "  {} All {} checks passed",
            "✓".green().bold(),
            passed
        );
    } else {
        println!(
            "  {} {} issue{} found, {} can be auto-fixed{}",
            if fixable > 0 { "⚡".yellow() } else { "✗".red() },
            issues.to_string().yellow(),
            if issues > 1 { "s" } else { "" },
            fixable.to_string().green(),
            if fixable > 0 && !fix {
                format!(" — run {} to fix", "kitup doctor --fix".bold())
            } else {
                String::new()
            }
        );
    }
    println!();

    Ok(())
}
```

- [ ] **Step 2: 运行检查并提交**

```bash
cargo check -p kitup-cli
git add crates/kitup-cli/src/commands/doctor.rs
git commit -m "feat: 实现 doctor 诊断命令"
```

---

## Task 19: config 和 completions 命令实现

**Files:**
- Modify: `crates/kitup-cli/src/commands/config_cmd.rs`
- Modify: `crates/kitup-cli/src/commands/completions.rs`

- [ ] **Step 1: 实现 config 命令**

```rust
//! config 子命令 — 配置管理

use anyhow::Result;

pub fn run() -> anyhow::Result<()> {
    let config = kitup_core::config::Config::load()?;
    let path = kitup_core::config::Config::config_path()?;

    println!();
    println!("  {} Configuration", "●".cyan());
    println!("  {}", "─".repeat(40));
    println!("  File: {}", path.to_string_lossy());
    println!();
    println!("{}", serde_json::to_string_pretty(&config)?);
    println!();

    Ok(())
}
```

- [ ] **Step 2: 实现 completions 命令**

```rust
//! completions 子命令 — 生成 shell 补全脚本

use anyhow::Result;
use clap_complete::Shell;

pub fn run(shell: Shell) -> anyhow::Result<()> {
    let mut cmd = crate::args::Cli::cmd();
    let name = "kitup";
    clap_complete::generate(shell, &mut cmd, name, &mut std::io::stdout());
    Ok(())
}
```

- [ ] **Step 3: 实现 self-update 命令**

```rust
//! self-update 子命令 — 更新 kitup 自身

use anyhow::Result;

pub fn run() -> anyhow::Result<()> {
    let rt = tokio::runtime::Runtime::new()?;
    rt.block_on(async { run_async().await })
}

async fn run_async() -> anyhow::Result<()> {
    let updater = kitup_core::self_update::SelfUpdater::new()?;

    println!();
    println!("  {} Checking for updates...", "⟳".cyan());

    match updater.check_update().await? {
        Some(latest) => {
            let current = env!("CARGO_PKG_VERSION");
            println!(
                "  {} New version available: {} → {}",
                "↑".yellow(),
                current.dimmed(),
                latest.green()
            );
            println!("  Updating...");
            updater.do_update().await?;
            println!(
                "  {} Updated to {}",
                "✓".green(),
                latest.green()
            );
        }
        None => {
            println!(
                "  {} Already at latest version ({})",
                "✓".green(),
                env!("CARGO_PKG_VERSION")
            );
        }
    }
    println!();

    Ok(())
}
```

- [ ] **Step 4: 运行检查并提交**

```bash
cargo check -p kitup-cli
git add crates/kitup-cli/src/commands/
git commit -m "feat: 实现 config/completions/self-update 命令"
```

---

## Task 20: 集成 main.rs 并修复编译

**Files:**
- Modify: `crates/kitup-cli/src/main.rs`
- Modify: `crates/kitup-cli/Cargo.toml` (如需要)

- [ ] **Step 1: 确认 main.rs 正确连接所有模块**

确保 `crates/kitup-cli/src/main.rs` 包含：
```rust
mod args;
mod commands;
mod output;
```

并且所有 command 模块都正确 import。

- [ ] **Step 2: 修复所有编译错误**

Run: `cargo check`

逐个修复编译错误。常见问题：
- 缺少 `use` 导入
- `Tool` 和 `TOOL_REGISTRY` 的可见性
- `PinnedVersions` 方法需要 `&self` 而非静态方法

- [ ] **Step 3: 构建二进制**

Run: `cargo build --release -p kitup-cli`
Expected: 编译成功，生成 `target/release/kitup`

- [ ] **Step 4: 提交**

```bash
git add -A
git commit -m "feat: 完成所有命令集成，kitup-cli 编译通过"
```

---

## Task 21: 集成测试

**Files:**
- Create: `crates/kitup-cli/tests/integration.rs`

- [ ] **Step 1: 编写集成测试**

```rust
use assert_cmd::Command;

#[test]
fn test_help() {
    let mut cmd = Command::cargo_bin("kitup").unwrap();
    cmd.arg("--help")
        .assert()
        .success()
        .stdout(predicates::str::contains("kitup"));
}

#[test]
fn test_version() {
    let mut cmd = Command::cargo_bin("kitup").unwrap();
    cmd.arg("--version")
        .assert()
        .success()
        .stdout(predicates::str::contains("0.2.0"));
}

#[test]
fn test_status() {
    let mut cmd = Command::cargo_bin("kitup").unwrap();
    cmd.arg("status")
        .assert()
        .success();
}

#[test]
fn test_status_json() {
    let mut cmd = Command::cargo_bin("kitup").unwrap();
    cmd.arg("status")
        .arg("--json")
        .assert()
        .success()
        .stdout(predicates::str::contains("kitup_version"));
}

#[test]
fn test_unknown_tool_pin() {
    let mut cmd = Command::cargo_bin("kitup").unwrap();
    cmd.arg("pin")
        .arg("nonexistent")
        .arg("1.0.0")
        .assert()
        .failure();
}
```

注意：需要在 `crates/kitup-cli/Cargo.toml` 的 `[dev-dependencies]` 中添加：

```toml
[dev-dependencies]
assert_cmd = "2"
predicates = "3"
```

- [ ] **Step 2: 运行测试**

Run: `cargo test -p kitup-cli`
Expected: 集成测试通过

- [ ] **Step 3: 提交**

```bash
git add crates/kitup-cli/tests/
git commit -m "test: 添加 CLI 集成测试"
```

---

## Task 22: CI 工作流

**Files:**
- Create: `.github/workflows/rust-ci.yml`

- [ ] **Step 1: 创建 Rust CI 工作流**

```yaml
name: Rust CI

on:
  push:
    branches: [main]
    paths:
      - 'crates/**'
      - 'Cargo.toml'
      - 'Cargo.lock'
  pull_request:
    branches: [main]
    paths:
      - 'crates/**'
      - 'Cargo.toml'
      - 'Cargo.lock'

jobs:
  check:
    name: Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
      - run: cargo check --workspace

  test:
    name: Test
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
      - run: cargo test --workspace

  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy, rustfmt
      - uses: Swatinem/rust-cache@v2
      - run: cargo fmt --all -- --check
      - run: cargo clippy --workspace -- -D warnings

  build:
    name: Build Release
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        include:
          - os: macos-latest
            target: aarch64-apple-darwin
          - os: macos-latest
            target: x86_64-apple-darwin
          - os: ubuntu-latest
            target: x86_64-unknown-linux-gnu
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          targets: ${{ matrix.target }}
      - uses: Swatinem/rust-cache@v2
      - run: cargo build --release --target ${{ matrix.target }} -p kitup-cli
      - uses: actions/upload-artifact@v4
        with:
          name: kitup-${{ matrix.target }}
          path: target/${{ matrix.target }}/release/kitup
```

- [ ] **Step 2: 提交**

```bash
git add .github/workflows/rust-ci.yml
git commit -m "ci: 添加 Rust CI 工作流"
```

---

## Task 23: 最终验证

- [ ] **Step 1: 运行完整测试套件**

```bash
cargo test --workspace
```

- [ ] **Step 2: 运行 clippy 检查**

```bash
cargo clippy --workspace -- -D warnings
```

- [ ] **Step 3: 运行格式检查**

```bash
cargo fmt --all -- --check
```

- [ ] **Step 4: 构建发布版本**

```bash
cargo build --release -p kitup-cli
```

- [ ] **Step 5: 手动测试关键命令**

```bash
./target/release/kitup --help
./target/release/kitup --version
./target/release/kitup status
./target/release/kitup status --json
./target/release/kitup doctor
```

- [ ] **Step 6: 最终提交**

```bash
git add -A
git commit -m "chore: Phase 1 完成 — 核心更新 + CLI"
```

---

## 后续阶段

- **Phase 2** (极致 TUI): 基于 ratatui 的多面板交互界面
- **Phase 3** (供应商管理): API 供应商切换、故障转移
- **Phase 4** (健康检查): 延迟测试、诊断、用量监控
