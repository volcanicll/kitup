# Kitup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub release](https://img.shields.io/github/release/volcanicll/kitup.svg)](https://github.com/volcanicll/kitup/releases)

A unified, cross-platform updater for AI coding assistants. Keep all your AI programming tools up to date with a single command, while preserving the package manager and binary you actually use on `PATH`.

## 🚀 Quick Start

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/volcanicll/kitup/main/packages/cli/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/volcanicll/kitup/main/packages/cli/install.ps1 | iex
```

## 📦 Monorepo Structure

This is a monorepo containing the following packages:

| Package | Description | Path |
|---------|-------------|------|
| `@kitup/cli` | CLI tool for updating AI coding assistants | [`packages/cli`](./packages/cli) |
| `@kitup/website` | Official website and documentation | [`packages/website`](./packages/website) |

## 🛠️ Supported AI Tools

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

## ✨ What Changed

- Unified CLI entrypoint: installers now place a single `kitup` command in your PATH and dispatch to the platform-specific implementation internally.
- Platform-specific bootstrap: the initial installer still uses `install.sh` on Unix-like systems and `install.ps1` on Windows, but both install the same user-facing `kitup` command.
- PATH-aware updates: when multiple installations exist, `kitup` now prefers the binary currently selected by your shell instead of blindly updating another package-manager copy.
- In-use upgrade notice: when users run `kitup`, it checks whether `kitup` itself has a newer release and prints an upgrade command if needed.
- Windows-native package managers: the PowerShell implementation now supports Chocolatey and Scoop in addition to npm, pipx, uv, and official installers.
- Regression coverage: `packages/cli` now ships repeatable shell regression tests for PATH priority, restore flow, and entrypoint dispatch.

## 🧪 Validation

From [`packages/cli`](./packages/cli), run:

```bash
npm test
```

This executes shell syntax checks, regression tests, and PowerShell syntax validation when `pwsh` is available.

## 📖 Documentation

- [CLI Documentation](./packages/cli/README.md)
- [Website](./packages/website/README.md)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](./packages/cli/LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by the installation scripts of [Claude Code](https://claude.ai), [OpenCode](https://opencode.ai), and [Aider](https://aider.chat)
- Thanks to all the AI tool developers for making amazing coding assistants
