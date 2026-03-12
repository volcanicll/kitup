# kitup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A unified, cross-platform updater for AI coding assistants. Keep all your AI programming tools up to date with a single command.

## Supported AI Tools

| Tool | npm | Homebrew | pipx/uv | Chocolatey / Scoop | Standalone |
|------|-----|----------|---------|---------------------|------------|
| [Claude Code](https://claude.ai/code) | ✅ | ✅ | ❌ | ❌ | ✅ |
| [OpenCode](https://opencode.ai) | ✅ | ✅ | ❌ | ✅ | ✅ |
| [Codex (OpenAI)](https://github.com/openai/codex) | ✅ | ✅ | ❌ | ✅ | ✅ |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | ✅ | ✅ | ❌ | ✅ | ❌ |
| [Kimi CLI](https://github.com/MoonshotAI/kimi-cli) | ❌ | ❌ | ✅ | ❌ | ❌ |
| [Cline CLI](https://docs.cline.bot/cline-cli/installation) | ✅ | ❌ | ❌ | ❌ | ❌ |
| [Qwen Code](https://github.com/QwenLM/qwen-code) | ✅ | ✅ | ❌ | ❌ | ✅ |
| [Goose (Block)](https://github.com/block/goose) | ❌ | ✅ | ❌ | ❌ | ✅ |
| [Aider](https://github.com/Aider-AI/aider) | ❌ | ✅ | ✅ | ❌ | ✅ |

## Entrypoint Design

Installers now place a single `kitup` entry command in your PATH:

- macOS / Linux: `kitup` dispatches to `kitup.sh`
- Windows: `kitup.bat` dispatches to `kitup.ps1`

This keeps the platform-specific logic separate while giving users one stable command surface.

The bootstrap installer is still platform-specific:

- Unix-like systems start from `install.sh`
- Windows starts from `install.ps1`

After installation, the command users run is unified as `kitup`.

## kitup Self-Update Notice

When users run `kitup`, the CLI checks whether a newer `kitup` release is available and prints an upgrade command if needed.

- The check only happens while the user is actively using `kitup`
- Results are cached locally for 24 hours to avoid repeated network calls
- Set `KITUP_SKIP_SELF_UPDATE_CHECK=1` to disable the notice

## Installation

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/volcanicll/kitup/main/packages/cli/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/volcanicll/kitup/main/packages/cli/install.ps1 | iex
```

## Usage

### Check Status

View the status of all supported AI tools:

```bash
kitup --status
```

Output example:
```
AI Tools Status

Tool         Installed  Method       Local Version   Latest Version
----         ---------  ------       -------------   --------------
claude       Yes        npm          0.2.45          0.2.46
opencode     Yes        brew         1.2.3           1.2.4
codex        No         -            -               -
gemini       Yes        npm          0.32.1          0.32.1
goose        No         -            -               -
aider        Yes        pipx         0.75.2          0.76.0
```

### Update All Installed Tools

```bash
kitup --all
```

### Update Specific Tools

```bash
kitup claude codex aider
```

### Install Missing Tools

Update all installed tools and install missing ones:

```bash
kitup --all --install
```

Or install specific tools:

```bash
kitup claude --install
```

### Preview Changes (Dry Run)

See what would be updated without making changes:

```bash
kitup --all --dry-run
```

### Backup Configuration

Backup your AI tool configurations before updating:

```bash
kitup --all --backup
```

Restore from the last backup:

```bash
kitup --restore
```

## Command Line Options

```
Options:
  -h, --help          Show help message
  -v, --version       Show version information
  -l, --list          List all supported AI tools
  -s, --status        Show status of all tools
  -a, --all           Update all installed tools
  -i, --install       Install missing tools
  -n, --dry-run       Show what would be done without making changes
  -f, --force         Force update even if already at latest version
  -b, --backup        Backup configuration before updating
      --restore       Restore configuration from last backup
  --verbose           Enable verbose output
```

## How It Works

1. **Detection**: The updater detects which AI tools are installed on your system
2. **Method Identification**: It identifies how the currently active binary on your `PATH` was installed
3. **Version Check**: It compares your local version with the latest version from the matching source first
4. **Smart Update**: It updates using the same installation method, instead of switching package managers underneath you

### Installation Method Detection

The updater automatically detects how each tool was installed:

- **npm**: Checks `npm list -g <package>`
- **Homebrew**: Checks `brew list <formula>`
- **Chocolatey**: Checks `choco list --local-only --exact <package>`
- **Scoop**: Checks `scoop list <package>`
- **pipx**: Checks `pipx list`
- **uv**: Checks `uv tool list`
- **Standalone**: Detected by installation path or as fallback

When duplicate installs exist, `kitup` prefers the command currently resolved by your shell `PATH`.

## Requirements

- **macOS**: macOS 10.15+ with bash/zsh
- **Linux**: Any modern distribution with bash
- **Windows**: Windows 10+ with PowerShell 5.1+ or PowerShell Core

### Optional Dependencies

- `jq` - Improves Homebrew JSON parsing, but is no longer required
- `curl` or `wget` - For downloading updates

## Uninstallation

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/volcanicll/kitup/main/packages/cli/install.sh | bash -s -- --uninstall
```

Or manually:

```bash
rm ~/.local/bin/kitup
rm ~/.local/bin/kitup.sh
```

### Windows

```powershell
irm https://raw.githubusercontent.com/volcanicll/kitup/main/packages/cli/install.ps1 | iex -Args @('--uninstall')
```

Or manually remove from `%LOCALAPPDATA%\kitup`.

## GitHub API Rate Limits

If you encounter GitHub API rate limits, set a GitHub token:

```bash
export GITHUB_TOKEN=your_token_here
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by the installation scripts of [Claude Code](https://claude.ai), [OpenCode](https://opencode.ai), and [Aider](https://aider.chat)
- Thanks to all the AI tool developers for making amazing coding assistants

---

## 中文说明

### 安装

**macOS / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/volcanicll/kitup/main/packages/cli/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/volcanicll/kitup/main/packages/cli/install.ps1 | iex
```

### 基本用法

```bash
# 查看所有AI工具状态
kitup --status

# 更新所有已安装的工具
kitup --all

# 更新指定工具
kitup claude codex

# 更新所有工具并安装缺失的
kitup --all --install

# 模拟运行（不实际执行）
kitup --all --dry-run
```

### 支持的AI编程工具

- **Claude Code** - Anthropic 的AI编程助手
- **OpenCode** - 开源AI编程工具
- **Codex** - OpenAI 的代码生成工具
- **Gemini CLI** - Google 的AI命令行工具
- **Goose** - Block 的开源AI代理
- **Aider** - 终端AI结对编程工具
