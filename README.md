# Kitup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub release](https://img.shields.io/github/release/volcanicll/kitup.svg)](https://github.com/volcanicll/kitup/releases)

A unified, cross-platform updater for AI coding assistants — now written in **Rust**.

Keep all your AI programming tools up to date with a single command, while preserving the package manager and binary you actually use on `PATH`.

## 🚀 Quick Start

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/volcanicll/kitup/main/packages/cli/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/volcanicll/kitup/main/packages/cli/install.ps1 | iex
```

### From Source

```bash
git clone https://github.com/volcanicll/kitup.git
cd kitup
cargo build --release
cp target/release/kitup /usr/local/bin/
```

## ✨ What's New in v0.2.0

**Complete Rust rewrite** — faster, more reliable, and packed with new features:

- **Interactive TUI**: Multi-panel dashboard with keyboard navigation (like lazygit). Run `kitup` with no arguments.
- **Provider Management**: Switch API providers for Claude/Codex/Gemini with `kitup provider switch`. Circuit breaker failover built in.
- **Health Checks**: Network diagnostics, endpoint latency testing, multi-install detection with `kitup doctor`.
- **Parallel Updates**: Concurrent tool updates with real-time progress bars and spinners.
- **Colored Tables**: Beautiful terminal output with `comfy-table` and `owo-colors`.
- **Version Pinning**: Pin tools to specific versions with `kitup pin/unpin`.
- **Changelog Viewer**: View GitHub release notes with `kitup changelog`.
- **Shell Completions**: Auto-generated for bash, zsh, fish with `kitup completions`.
- **Self-Update**: Built-in updater for kitup itself.
- **JSON Output**: Structured output for scripting with `--json` flag.
- **Zero Dependencies**: Single ~9MB binary, no runtime required.

## 📦 Supported AI Tools (12)

| Tool | npm | Homebrew | pipx/uv | Standalone |
|------|-----|----------|---------|------------|
| [Claude Code](https://claude.ai/code) | ✅ | ✅ | ❌ | ✅ |
| [OpenCode](https://opencode.ai) | ✅ | ✅ | ❌ | ✅ |
| [Codex (OpenAI)](https://github.com/openai/codex) | ✅ | ✅ | ❌ | ✅ |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | ✅ | ✅ | ❌ | ❌ |
| [Kimi CLI](https://github.com/MoonshotAI/kimi-cli) | ❌ | ❌ | ✅ | ❌ |
| [Cline CLI](https://docs.cline.bot/cline-cli/installation) | ✅ | ❌ | ❌ | ❌ |
| [Qwen Code](https://github.com/QwenLM/qwen-code) | ✅ | ✅ | ❌ | ✅ |
| [Goose (Block)](https://github.com/block/goose) | ❌ | ✅ | ❌ | ✅ |
| [Aider](https://github.com/Aider-AI/aider) | ❌ | ✅ | ✅ | ✅ |
| [Cursor CLI](https://github.com/cursor-sh/cursor) | ❌ | ✅ | ❌ | ✅ |
| [Windsurf CLI](https://github.com/codeium/windsurf) | ❌ | ✅ | ❌ | ✅ |
| [Tabby](https://github.com/TabbyML/tabby) | ❌ | ✅ | ❌ | ✅ |

## 🎮 Usage

```bash
# Interactive TUI dashboard
kitup

# Check status of all tools
kitup status
kitup status --json

# Update tools
kitup update                    # Update all installed tools
kitup update claude codex       # Update specific tools
kitup update --dry-run          # Preview without changes
kitup update --install          # Also install missing tools
kitup update --parallel 5       # Use 5 parallel jobs

# Version management
kitup pin claude 0.2.45         # Pin to a version
kitup unpin claude              # Remove pin
kitup changelog claude          # View release notes
kitup changelog --all           # All tools' changelogs

# Provider management
kitup provider list
kitup provider add --name my-provider --api-base https://api.example.com
kitup provider switch my-provider
kitup provider test

# Diagnostics
kitup doctor                    # Run health checks
kitup doctor --fix              # Auto-fix issues
kitup doctor --verbose          # Detailed output

# System
kitup config                    # View configuration
kitup completions bash          # Generate shell completions
kitup self-update               # Update kitup itself
```

## 🖥️ TUI Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `↑/k` | Move up |
| `↓/j` | Move down |
| `Space` | Toggle selection |
| `a` | Select/deselect all |
| `u` | Update selected tools |
| `Enter` | Show/hide detail panel |
| `Tab` | Next tab |
| `1/2/3` | Switch to Tools/Providers/Health |
| `/` | Start search |
| `?` | Toggle help |
| `q` | Quit |

## ⚙️ Configuration

Config file: `~/.config/kitup/config.json` (macOS: `~/Library/Application Support/com.kitup.kitup/config.json`)

```json
{
  "version": 2,
  "parallel_jobs": 3,
  "auto_backup": false,
  "detect_new_tools": true,
  "changelog_count": 3,
  "default_action": "tui"
}
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `KITUP_PARALLEL_JOBS` | Number of parallel update jobs | `3` |
| `KITUP_SKIP_SELF_UPDATE_CHECK` | Disable self-update check | - |
| `KITUP_VERSION_CACHE_TTL_SECONDS` | Version cache TTL | `3600` |

## 🏗️ Architecture

Built as a Cargo workspace with 5 crates:

```
crates/
├── kitup-core/      # Core library: tool registry, version detection, package manager adapters
├── kitup-cli/       # CLI binary: command parsing, formatted output, all subcommands
├── kitup-tui/       # Interactive TUI: ratatui-based multi-panel dashboard
├── kitup-provider/  # Provider management: API config switching, circuit breaker failover
└── kitup-health/    # Health checks: endpoint latency testing, system diagnostics
```

## 🧪 Testing

```bash
# Run all tests
cargo test --workspace

# Build release binary
cargo build --release
```

## 📖 Documentation

- [Architecture](./docs/ARCHITECTURE.md)
- [Contributing Guide](./CONTRIBUTING.md)
- [Design Spec](./docs/superpowers/specs/2026-06-05-kitup-v2-rust-rewrite-design.md)

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## 📄 License

MIT
