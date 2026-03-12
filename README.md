# AI Tools Updater

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A unified, cross-platform updater for AI coding assistants. Keep all your AI programming tools up to date with a single command.

## Supported AI Tools

| Tool | npm | Homebrew | pipx/uv | Standalone |
|------|-----|----------|---------|------------|
| [Claude Code](https://claude.ai/code) | ✅ | ✅ | ❌ | ✅ |
| [OpenCode](https://opencode.ai) | ✅ | ✅ | ❌ | ✅ |
| [Codex (OpenAI)](https://github.com/openai/codex) | ✅ | ✅ | ❌ | ✅ |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | ✅ | ✅ | ❌ | ❌ |
| [Goose (Block)](https://github.com/block/goose) | ❌ | ✅ | ❌ | ✅ |
| [Aider](https://github.com/Aider-AI/aider) | ❌ | ✅ | ✅ | ✅ |

## Installation

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/update-ai-tools/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/yourusername/update-ai-tools/main/install.ps1 | iex
```

## Usage

### Check Status

View the status of all supported AI tools:

```bash
update-ai-tools --status
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
update-ai-tools --all
```

### Update Specific Tools

```bash
update-ai-tools claude codex aider
```

### Install Missing Tools

Update all installed tools and install missing ones:

```bash
update-ai-tools --all --install
```

Or install specific tools:

```bash
update-ai-tools claude --install
```

### Preview Changes (Dry Run)

See what would be updated without making changes:

```bash
update-ai-tools --all --dry-run
```

### Backup Configuration

Backup your AI tool configurations before updating:

```bash
update-ai-tools --all --backup
```

Restore from the last backup:

```bash
update-ai-tools --restore
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
2. **Method Identification**: It identifies how each tool was installed (npm, Homebrew, pipx, uv, or standalone)
3. **Version Check**: Compares your local version with the latest available version
4. **Smart Update**: Uses the same installation method to update each tool

### Installation Method Detection

The updater automatically detects how each tool was installed:

- **npm**: Checks `npm list -g <package>`
- **Homebrew**: Checks `brew list <formula>`
- **pipx**: Checks `pipx list`
- **uv**: Checks `uv tool list`
- **Standalone**: Detected by installation path or as fallback

## Requirements

- **macOS**: macOS 10.15+ with bash/zsh
- **Linux**: Any modern distribution with bash
- **Windows**: Windows 10+ with PowerShell 5.1+ or PowerShell Core

### Optional Dependencies

- `jq` - For better JSON parsing (Homebrew version checks)
- `curl` or `wget` - For downloading updates

## Uninstallation

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/update-ai-tools/main/install.sh | bash -s -- --uninstall
```

Or manually:

```bash
rm ~/.local/bin/update-ai-tools
rm ~/.local/bin/update-ai-tools.sh
```

### Windows

```powershell
irm https://raw.githubusercontent.com/yourusername/update-ai-tools/main/install.ps1 | iex -Args @('--uninstall')
```

Or manually remove from `%LOCALAPPDATA%\update-ai-tools`.

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
curl -fsSL https://raw.githubusercontent.com/yourusername/update-ai-tools/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/yourusername/update-ai-tools/main/install.ps1 | iex
```

### 基本用法

```bash
# 查看所有AI工具状态
update-ai-tools --status

# 更新所有已安装的工具
update-ai-tools --all

# 更新指定工具
update-ai-tools claude codex

# 更新所有工具并安装缺失的
update-ai-tools --all --install

# 模拟运行（不实际执行）
update-ai-tools --all --dry-run
```

### 支持的AI编程工具

- **Claude Code** - Anthropic 的AI编程助手
- **OpenCode** - 开源AI编程工具
- **Codex** - OpenAI 的代码生成工具
- **Gemini CLI** - Google 的AI命令行工具
- **Goose** - Block 的开源AI代理
- **Aider** - 终端AI结对编程工具
