# kitup v2 — Rust 重写设计文档

> 日期: 2026-06-05
> 状态: 已批准
> 目标: 用 Rust 完全重写 kitup，将 CLI 体验提升到现代水平

---

## 1. 项目概述

### 1.1 背景

kitup v1 是一个基于 Shell 脚本的 AI 编码工具统一更新器，支持 Claude Code、Codex、Gemini CLI 等 12 种工具。虽然功能完善，但 Shell 脚本在以下方面存在天然瓶颈：

- **性能**: 版本检测涉及多次进程启动和网络请求，Shell 启动开销大
- **并发**: 并行更新依赖后台进程和文件通信，不够优雅
- **TUI**: 纯 ANSI 实现的 TUI 功能有限，缺少流畅动画和复杂布局
- **跨平台**: Bash/PowerShell 双版本维护成本高
- **扩展性**: 供应商配置管理、健康检查等功能在 Shell 中实现过于复杂

### 1.2 目标

用 Rust 重写 kitup，实现：

1. **核心更新功能** — 保持 v1 全部功能，提升性能和可靠性
2. **极致 TUI 体验** — 类 lazygit 的多面板交互界面
3. **供应商配置管理** — 一键切换 API 供应商，支持故障转移
4. **健康检查/诊断** — API 连通性测试、延迟测量、自动诊断修复

### 1.3 约束

- **单二进制分发**: 零运行时依赖，一个文件即用
- **跨平台**: macOS (Apple Silicon + Intel)、Linux (x64 + ARM)、Windows
- **向后兼容**: 配置文件格式兼容 v1，迁移无感
- **全球用户**: 默认英文界面，支持 i18n（中文优先翻译）

---

## 2. 技术架构

### 2.1 架构选择

**方案 A: 单二进制 + 内嵌 TUI**

所有功能编译进一个二进制文件，使用 `ratatui` 实现 TUI。不引入 daemon 或插件系统，保持简洁。

### 2.2 项目结构

```
kitup/
├── Cargo.toml                 # workspace root
├── crates/
│   ├── kitup-core/            # 核心库：工具注册、版本检测、包管理器适配
│   │   ├── src/
│   │   │   ├── lib.rs
│   │   │   ├── tool.rs        # 工具定义和注册表
│   │   │   ├── version.rs     # 版本检测和比对
│   │   │   ├── installer/     # 包管理器适配器
│   │   │   │   ├── mod.rs
│   │   │   │   ├── npm.rs
│   │   │   │   ├── brew.rs
│   │   │   │   ├── pipx.rs
│   │   │   │   ├── uv.rs
│   │   │   │   └── standalone.rs
│   │   │   ├── config.rs      # 配置管理
│   │   │   ├── pin.rs         # 版本固定
│   │   │   └── self_update.rs # 自更新
│   │   └── Cargo.toml
│   │
│   ├── kitup-provider/        # 供应商管理
│   │   ├── src/
│   │   │   ├── lib.rs
│   │   │   ├── provider.rs    # 供应商数据模型
│   │   │   ├── switcher.rs    # 配置文件切换
│   │   │   ├── failover.rs    # 故障转移队列
│   │   │   └── adapter/       # 各工具配置文件适配器
│   │   │       ├── mod.rs
│   │   │       ├── claude.rs
│   │   │       ├── codex.rs
│   │   │       └── gemini.rs
│   │   └── Cargo.toml
│   │
│   ├── kitup-health/          # 健康检查
│   │   ├── src/
│   │   │   ├── lib.rs
│   │   │   ├── checker.rs     # 健康检查引擎
│   │   │   ├── latency.rs     # 延迟测量
│   │   │   ├── doctor.rs      # 诊断系统
│   │   │   └── quota.rs       # 用量/配额查询
│   │   └── Cargo.toml
│   │
│   ├── kitup-tui/             # TUI 界面
│   │   ├── src/
│   │   │   ├── lib.rs
│   │   │   ├── app.rs         # 应用状态管理
│   │   │   ├── dashboard.rs   # 仪表盘主界面
│   │   │   ├── tools_panel.rs # 工具列表面板
│   │   │   ├── detail_panel.rs# 详情面板
│   │   │   ├── provider_panel.rs # 供应商面板
│   │   │   ├── health_panel.rs   # 健康面板
│   │   │   ├── components/    # 可复用 UI 组件
│   │   │   │   ├── mod.rs
│   │   │   │   ├── table.rs
│   │   │   │   ├── spinner.rs
│   │   │   │   ├── progress.rs
│   │   │   │   ├── popup.rs
│   │   │   │   └── search.rs
│   │   │   └── theme.rs       # 主题和颜色
│   │   └── Cargo.toml
│   │
│   └── kitup-cli/             # CLI 入口
│       ├── src/
│       │   ├── main.rs
│       │   ├── args.rs        # 命令行参数定义 (clap)
│       │   └── output.rs      # 非TUI输出格式化
│       └── Cargo.toml
│
├── docs/
├── .github/
└── README.md
```

### 2.3 关键 Rust 依赖

| 用途 | Crate | 版本 |
|------|-------|------|
| CLI 解析 | `clap` (derive) | 4.x |
| TUI 框架 | `ratatui` | 0.29+ |
| 异步运行时 | `tokio` (full) | 1.x |
| HTTP 客户端 | `reqwest` | 0.12+ |
| 进度条 | `indicatif` | 0.17+ |
| 颜色 | `owo-colors` | 4.x |
| 表格 | `comfy-table` | 7.x |
| 序列化 | `serde` / `serde_json` | 1.x |
| 版本解析 | `semver` | 1.x |
| 配置目录 | `directories` | 5.x |
| 自更新 | `self_update` | 0.39+ |
| Shell 补全 | `clap_complete` | 4.x |
| 加密存储 | `keyring` | 3.x |
| 日志 | `tracing` | 0.1.x |
| 错误处理 | `anyhow` / `thiserror` | latest |

### 2.4 数据流

```
用户输入 (CLI args / TUI 交互)
       │
       ▼
  kitup-cli (入口)
       │
       ├── 非交互模式 ──→ kitup-core ──→ 输出格式化 (colored/JSON/table)
       │
       └── 交互模式 ──→ kitup-tui
                           │
                           ├── kitup-core (工具管理)
                           ├── kitup-provider (供应商)
                           └── kitup-health (健康检查)
```

---

## 3. Phase 1: 核心更新 + CLI

### 3.1 命令结构

```bash
# 基础命令
kitup                          # 启动 TUI 仪表盘
kitup status                   # 查看所有工具状态
kitup status --json            # JSON 输出
kitup update                   # 更新所有已安装工具
kitup update <tool...>         # 更新指定工具
kitup update --install         # 更新并安装缺失工具
kitup update --dry-run         # 预览模式
kitup update --parallel 5      # 指定并发数
kitup update --force           # 强制更新

# 版本管理
kitup pin <tool> <version>     # 固定版本
kitup unpin <tool>             # 取消固定
kitup changelog <tool>         # 查看更新日志
kitup changelog --all          # 所有工具的更新日志

# 系统命令
kitup self-update              # 自更新
kitup config                   # 打开/显示配置
kitup completions <shell>      # 生成 Shell 补全 (bash/zsh/fish/elvish)
kitup --version                # 显示版本
kitup --help                   # 显示帮助
```

### 3.2 工具注册表

每个工具定义为 `Tool` 结构体：

```rust
struct Tool {
    name: &'static str,           // "claude"
    command: &'static str,        // "claude"
    npm_package: Option<&'static str>,
    brew_formula: Option<&'static str>,
    pipx_package: Option<&'static str>,
    uv_package: Option<&'static str>,
    github_repo: Option<&'static str>,
    install_url: Option<&'static str>,
    config_adapter: Option<ConfigAdapterType>, // 用于供应商切换
}
```

内置工具列表（与 v1 保持一致）：

| 工具 | npm | brew | pipx/uv | GitHub |
|------|-----|------|---------|--------|
| claude | `@anthropic-ai/claude-code` | `anthropic-ai/tap/claude-code` | - | `anthropics/claude-code` |
| opencode | `opencode-ai` | `opencode` | - | `opencode-ai/opencode` |
| codex | `@openai/codex` | `codex` | - | `openai/codex` |
| gemini | `@google/gemini-cli` | `gemini-cli` | - | `google-gemini/gemini-cli` |
| kimi | - | - | `kimi-cli` | `MoonshotAI/kimi-cli` |
| cline | `cline` | - | - | `cline/cline` |
| qwen | `@qwen-code/qwen-code` | `qwen-code` | - | `QwenLM/qwen-code` |
| goose | - | `block-goose-cli` | - | `block/goose` |
| aider | - | `aider` | `aider-chat` | `Aider-AI/aider` |
| cursor | - | `cursor` | - | `cursor-sh/cursor` |
| windsurf | - | `windsurf` | - | `codeium/windsurf` |
| tabby | - | `tabby` | - | `TabbyML/tabby` |

### 3.3 包管理器适配器

统一接口：

```rust
#[async_trait]
trait PackageManager: Send + Sync {
    /// 检查工具是否通过此包管理器安装
    async fn is_installed(&self, tool: &Tool) -> bool;

    /// 获取当前安装版本
    async fn local_version(&self, tool: &Tool) -> Result<Option<Version>>;

    /// 获取最新可用版本
    async fn latest_version(&self, tool: &Tool) -> Result<Option<Version>>;

    /// 执行更新
    async fn update(&self, tool: &Tool) -> Result<UpdateResult>;

    /// 执行安装
    async fn install(&self, tool: &Tool) -> Result<InstallResult>;

    /// 检测安装路径（用于 PATH 判断）
    fn detect_path(&self, tool: &Tool) -> Option<PathBuf>;
}
```

实现顺序：`NpmAdapter` → `BrewAdapter` → `UvAdapter` → `PipxAdapter` → `StandaloneAdapter`

### 3.4 安装方式检测逻辑

继承 v1 的 PATH 优先策略，但用 Rust 实现：

1. 查找 `tool.command` 的可执行文件路径
2. 判断路径所属前缀：
   - `brew --prefix/bin/` → Homebrew
   - `npm prefix -g/bin/` → npm global
   - `~/.local/bin/` 或 `~/bin/` → standalone
3. 回退到包管理器列表检查
4. 多安装时警告用户并建议清理

### 3.5 并发更新

使用 tokio 的并发任务：

```rust
async fn update_parallel(tools: Vec<&Tool>, jobs: usize) -> Vec<UpdateResult> {
    let semaphore = Arc::new(Semaphore::new(jobs));
    let mut handles = vec![];

    for tool in tools {
        let sem = semaphore.clone();
        handles.push(tokio::spawn(async move {
            let _permit = sem.acquire().await.unwrap();
            update_tool(tool).await
        }));
    }

    // 通过 mpsc channel 实时推送进度到 UI
    join_all(handles).await
}
```

### 3.6 配置管理

配置文件路径：`~/.config/kitup/config.json`（遵循 XDG 规范）

```json
{
  "version": 2,
  "parallel_jobs": 3,
  "auto_backup": false,
  "auto_install_missing": false,
  "verbose": false,
  "exclude_tools": [],
  "detect_new_tools": true,
  "changelog_count": 3,
  "default_action": "tui",
  "theme": "auto"
}
```

v1 配置自动迁移：启动时检测 v1 格式（`parallel_jobs` 为数字），自动转换并保存。

### 3.7 自更新

```rust
async fn check_self_update() -> Result<Option<String>> {
    let current = Version::parse(env!("CARGO_PKG_VERSION"))?;
    let latest = fetch_github_latest_version("kitup/kitup").await?;

    if latest > current {
        // 缓存检查结果（24h TTL）
        cache_update_check(&latest)?;

        if confirm_update(&latest)? {
            self_update::update(confirm)?;
        }
    }
    Ok(None)
}
```

### 3.8 输出格式化

**表格模式** (`kitup status`):

```
  Tool      Installed    Latest      Method      Status
  ──────────────────────────────────────────────────────
  claude    0.2.50       0.2.50      npm         ✓ up to date
  codex     0.1.0        0.2.0       npm         ↑ update available
  gemini    -            -           -           not installed
  kimi      1.0.0        1.0.0       uv          ✓ up to date  ⚡ 2 installs
```

**紧凑模式** (`kitup update` 进度):

```
Updating 3 tools... ━━━━━━━━━━━━━━━━━━ 67% 2/3
  ✓ claude  0.2.45 → 0.2.50  (npm)    2.1s
  ⟳ codex   updating...                 4.2s
  ○ gemini  queued
```

**JSON 模式** (`kitup status --json`):

```json
{
  "kitup_version": "0.2.0",
  "timestamp": "2026-06-05T15:30:00Z",
  "tools": [
    {
      "name": "claude",
      "installed": true,
      "local_version": "0.2.50",
      "latest_version": "0.2.50",
      "method": "npm",
      "status": "up_to_date",
      "path": "/usr/local/bin/claude"
    }
  ]
}
```

### 3.9 错误处理

结构化错误输出，参考 cc-switch 的 `format_skill_error` 模式：

```rust
struct KitupError {
    code: String,          // "UPDATE_FAILED"
    message: String,       // "Failed to update claude"
    context: String,       // "npm registry connection timeout (30s)"
    suggestion: String,    // "Check network or try --mirror"
    retryable: bool,
}
```

终端输出：
```
✗ Failed to update claude
  │
  ├─ 原因: npm registry connection timeout (30s)
  ├─ 建议: 检查网络连接或尝试 --mirror 参数
  └─ 重试: kitup update claude --retry 3
```

---

## 4. Phase 2: 极致 TUI

### 4.1 布局设计

采用类 lazygit 的多面板分区布局：

```
┌─ kitup v0.2.0 ── AI Tools Dashboard ──────────────── [q]uit [?]help ─┐
│                                                                        │
│  ┌─ Tools ──────────────────────────┐  ┌─ Details ──────────────────┐ │
│  │ ✓ claude    0.2.50  npm   latest │  │ claude                     │ │
│  │ ↑ codex     0.1→0.2   npm        │  │ Version: 0.2.50 (latest)   │ │
│  │ ✓ gemini    0.3.2   npm   latest │  │ Method:  npm global        │ │
│  │ ⚑ opencode  -        -           │  │ Path:    ~/.npm/.../claude │ │
│  │ ✓ aider     0.8.0   uv   latest  │  │ Size:    45.2 MB           │ │
│  │ ✓ goose     1.0.0   brew latest  │  │                            │ │
│  │ ↑ kimi      0.9→1.0  uv          │  │ Changelog:                 │ │
│  │                              [↑↓] │  │ v0.2.50 - Fix streaming.. │ │
│  └───────────────────────────────────┘  │ v0.2.49 - Add parallel..  │ │
│                                         └────────────────────────────┘ │
│                                                                        │
│  ┌─ Actions ────────────────────────────────────────────────────────┐ │
│  │ [u]pdate selected  [a]ll  [i]nstall missing  [d]ry-run  [r]etry │ │
│  └──────────────────────────────────────────────────────────────────┘ │
│                                                                        │
│  ● 3 installed │ ↑ 2 updates │ 4 available │ ↑ scroll │ Tab switch  │
└────────────────────────────────────────────────────────────────────────┘
```

### 4.2 面板说明

| 面板 | 宽度占比 | 功能 |
|------|----------|------|
| 工具列表 | 55% | 显示所有工具的状态、版本、安装方式 |
| 详情面板 | 45% | 选中工具的详细信息、changelog |
| 操作栏 | 100% | 快捷键操作提示 |
| 状态栏 | 100% | 底部统计信息 |

窄终端（<80 列）时自动隐藏详情面板，全屏显示工具列表。

### 4.3 快捷键系统

| 按键 | 功能 |
|------|------|
| `↑/k` | 上移光标 |
| `↓/j` | 下移光标 |
| `Space` | 切换选中 |
| `a` | 全选/取消全选 |
| `u` | 更新选中工具 |
| `i` | 安装缺失工具 |
| `d` | 预览更新（dry-run） |
| `r` | 重试失败的更新 |
| `Enter` | 展开详情 / 确认操作 |
| `Tab` | 切换面板焦点 |
| `/` | 进入搜索模式 |
| `?` | 显示帮助弹窗 |
| `q` | 退出 |
| `1-4` | 切换主标签页（工具/供应商/健康/配置） |

### 4.4 动画和视觉反馈

- **Spinner**: 工具版本检测中显示动画 spinner（⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏）
- **进度条**: 更新过程中显示 `indicatif` 风格的进度条
- **状态颜色**: ✓ 绿色成功、✗ 红色失败、↑ 黄色可更新、⚑ 灰色未安装
- **弹出通知**: 操作完成后底部弹出临时通知条
- **过渡动画**: 面板切换时的平滑过渡

### 4.5 异步数据加载

TUI 启动后立即显示工具列表（名称先加载），后台异步检测版本：

```rust
// 启动时
for tool in tools {
    let tx = tx.clone();
    tokio::spawn(async move {
        let version = detect_version(&tool).await;
        tx.send(VersionEvent { tool, version }).await;
    });
}

// TUI 通过 channel 接收版本信息，实时更新界面
```

### 4.6 模糊搜索

按 `/` 进入搜索模式，使用 `fuzzy-matcher` crate 进行模糊匹配：

```
  ┌─ Tools ──────────────────────────┐
  │ /cl                              │  ← 搜索框
  │ ✓ claude    0.2.50  npm   latest │  ← 匹配
  │ ⚑ cline     -        -           │  ← 匹配
  └──────────────────────────────────-┘
```

---

## 5. Phase 3: 供应商配置管理

### 5.1 数据模型

```rust
struct Provider {
    id: String,                  // UUID
    name: String,                // "anthropic-direct"
    api_base: String,            // "https://api.anthropic.com"
    api_key_env: Option<String>, // 环境变量名 "ANTHROPIC_API_KEY"
    api_key_value: Option<String>, // 加密存储的 key
    model_override: Option<String>,
    headers: HashMap<String, String>,
    priority: u32,               // 故障转移优先级 (1 = 最高)
    enabled: bool,
    tools: Vec<String>,          // 适用的工具列表
    health_status: Option<HealthStatus>,
}

struct HealthStatus {
    last_check: DateTime<Utc>,
    latency_ms: u64,
    status: HealthCheckStatus,   // Ok / Degraded / Down / Unknown
    http_status: Option<u16>,
}
```

### 5.2 命令设计

```bash
# 供应商 CRUD
kitup provider list                        # 列出所有供应商
kitup provider add                         # 交互式添加供应商
kitup provider add --name my-provider \
    --api-base https://api.example.com \
    --api-key $KEY                         # 命令行添加
kitup provider remove <name>               # 删除供应商
kitup provider edit <name>                 # 编辑供应商

# 切换和测试
kitup provider switch <name>               # 切换当前供应商
kitup provider switch <name> --tool claude # 只切换指定工具
kitup provider test                        # 测试所有供应商
kitup provider test <name>                 # 测试指定供应商

# 故障转移
kitup provider failover enable             # 启用故障转移
kitup provider failover disable            # 禁用故障转移
kitup provider failover status             # 查看故障转移状态

# 导入导出
kitup provider export > providers.json     # 导出配置
kitup provider import < providers.json     # 导入配置
```

### 5.3 配置文件适配器

每个 AI 工具有独立的配置文件格式，需要对应的适配器：

```rust
#[async_trait]
trait ConfigAdapter: Send + Sync {
    /// 工具名称
    fn tool_name(&self) -> &str;

    /// 配置文件路径
    fn config_path(&self) -> Result<PathBuf>;

    /// 读取当前供应商信息
    async fn read_current_provider(&self) -> Result<CurrentProvider>;

    /// 切换到指定供应商
    async fn switch_provider(&self, provider: &Provider) -> Result<()>;

    /// 备份当前配置
    async fn backup_config(&self) -> Result<PathBuf>;

    /// 验证配置是否生效
    async fn verify_config(&self) -> Result<bool>;
}
```

**Claude 配置适配器**：
- 配置路径: `~/.claude/settings.json` + 环境变量 `ANTHROPIC_API_KEY` / `ANTHROPIC_BASE_URL`
- 格式: JSON，修改 `apiConfiguration` 字段

**Codex 配置适配器**：
- 配置路径: `~/.codex/config.json` + 环境变量 `OPENAI_API_KEY` / `OPENAI_BASE_URL`
- 格式: JSON

**Gemini 配置适配器**：
- 配置路径: `~/.gemini/settings.json` + 环境变量 `GEMINI_API_KEY`
- 格式: JSON

### 5.4 故障转移机制

```rust
struct FailoverConfig {
    enabled: bool,
    providers: Vec<String>,    // 按优先级排序的供应商名称
    current_index: usize,      // 当前使用的供应商索引
    max_retries: u32,          // 切换前重试次数
    retry_delay: Duration,     // 重试间隔
    circuit_breaker: CircuitBreakerConfig,
}

struct CircuitBreakerConfig {
    failure_threshold: u32,    // 触发熔断的连续失败次数 (默认 3)
    reset_timeout: Duration,   // 熔断恢复时间 (默认 5 分钟)
}
```

故障转移流程：

1. 请求通过当前供应商发送
2. 连续失败达阈值 → 触发该供应商熔断
3. 自动切换到下一个优先级的可用供应商
4. 熔断的供应商在恢复时间后自动半开（允许一次尝试）
5. 所有供应商熔断 → 提示用户所有渠道不可用

### 5.5 API Key 安全存储

优先级：
1. **系统 keyring** (`keyring` crate) — 最安全
2. **加密文件** (`~/.config/kitup/keys.enc`) — keyring 不可用时的回退
3. **环境变量引用** — 只存储环境变量名，值由用户提供

---

## 6. Phase 4: 健康检查/诊断

### 6.1 诊断命令

```bash
kitup doctor                    # 全面诊断
kitup doctor --fix              # 自动修复可修复的问题
kitup doctor --verbose          # 详细输出
```

### 6.2 诊断检查项

| 类别 | 检查项 | 可自动修复 |
|------|--------|------------|
| 工具安装 | 二进制存在且可执行 | ✓ |
| 工具安装 | 版本号可正确获取 | ✗ |
| 工具安装 | 无多安装冲突 | ✓（提示清理） |
| 网络 | DNS 解析正常 | ✗ |
| 网络 | 可访问 npm/brew registry | ✗ |
| 网络 | 可访问 GitHub API | ✗ |
| 网络 | 代理配置正确 | ✓ |
| 配置 | 配置文件格式正确 | ✓ |
| 配置 | 配置文件权限安全 | ✓ |
| 供应商 | API 端点可达 | ✗ |
| 供应商 | API Key 有效 | ✗ |
| 供应商 | 响应延迟合理 | ✗ |
| 系统 | 磁盘空间充足 | ✗ |
| 系统 |Shell 环境正确 | ✓ |

### 6.3 诊断输出

```
kitup doctor

  Running diagnostics... ━━━━━━━━━━━━━━━━━━ 100%

  ✗ 2 issues found, 1 can be auto-fixed

  [ERROR] Multiple claude installations detected
    ├─ /usr/local/bin/claude (npm, v0.2.50)
    ├─ ~/.local/bin/claude (standalone, v0.2.45)
    └─ 建议: 运行 'kitup doctor --fix' 清理旧版本

  [WARN] npm registry connection slow (2.3s)
    └─ 建议: 考虑配置 npm 镜像: npm config set registry https://registry.npmmirror.com

  [OK]  All other checks passed (14/16)
```

### 6.4 供应商延迟测试

```bash
kitup provider test
```

输出格式：

```
  Testing 4 providers... ━━━━━━━━━━━━━━━━━━ 100%

  Provider            Endpoint                   Latency   Status
  ─────────────────────────────────────────────────────────────────
  anthropic-direct    api.anthropic.com          142ms     ✓ 200 OK
  openrouter          openrouter.ai/api/v1       89ms      ✓ 200 OK
  local-ollama        localhost:11434             3ms       ✓ 200 OK
  aws-bedrock         bedrock-runtime.us-west-2   timeout   ✗ Request timeout

  Recommended: openrouter (89ms) → anthropic-direct (142ms) → local-ollama (3ms*)
  * Local providers may not support all models
```

### 6.5 持续健康监控

在 TUI 模式下，后台定期执行健康检查（默认 5 分钟间隔），实时更新供应商状态：

- 🟢 正常 (< 200ms)
- 🟡 降级 (200ms - 1s)
- 🔴 不可用 (> 1s 或错误)
- ⚫ 未知 (未检测)

---

## 7. 交付计划

### 7.1 分阶段交付

| 阶段 | 内容 | 交付物 |
|------|------|--------|
| **Phase 1** | 核心更新 + CLI | 可用的命令行工具，替代 v1 |
| **Phase 2** | 极致 TUI | 交互式仪表盘 |
| **Phase 3** | 供应商管理 | API 配置切换功能 |
| **Phase 4** | 健康检查 | 诊断和测试功能 |

### 7.2 发布渠道

| 渠道 | 平台 | 格式 |
|------|------|------|
| GitHub Releases | macOS / Linux / Windows | tar.gz / zip |
| Homebrew | macOS / Linux | `brew install kitup` |
| Cargo | 全平台 | `cargo install kitup` |
| npm | 全平台 | `npm install -g kitup` (通过 node 包装) |

### 7.3 CI/CD

- GitHub Actions 自动构建多平台二进制
- PR 触发测试 + lint
- Tag 触发发布流程（构建 + 发布 GitHub Release + 推送 Homebrew tap）

---

## 8. 配置迁移

### 8.1 v1 → v2 自动迁移

启动时检测 `~/.kitup/config.json`（v1 路径）和 `~/.config/kitup/config.json`（v2 路径）：

1. 若只有 v1 配置 → 自动迁移到 v2 格式和路径
2. 若两者都存在 → 以 v2 为准
3. 版本固定文件 `pinned_versions` → 迁移到 v2 的 JSON 格式
4. 迁移完成显示一次性通知

### 8.2 配置兼容性

v2 配置文件增加 `version: 2` 字段，新增字段有默认值，确保向后兼容。

---

## 9. 测试策略

| 层级 | 工具 | 覆盖范围 |
|------|------|----------|
| 单元测试 | Rust 内置 | 工具注册、版本解析、配置管理 |
| 集成测试 | `assert_cmd` | CLI 命令行为 |
| TUI 测试 | `ratatui::backend::TestBackend` | 界面渲染快照 |
| E2E 测试 | Shell 脚本 | 完整更新流程（CI 中 mock 包管理器） |
