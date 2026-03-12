# Kitup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub release](https://img.shields.io/github/release/volcanicll/kitup.svg)](https://github.com/volcanicll/kitup/releases)

A unified, cross-platform updater for AI coding assistants. Keep all your AI programming tools up to date with a single command.

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

| Tool | npm | Homebrew | pipx/uv | Standalone |
|------|-----|----------|---------|------------|
| [Claude Code](https://claude.ai/code) | ✅ | ✅ | ❌ | ✅ |
| [OpenCode](https://opencode.ai) | ✅ | ✅ | ❌ | ✅ |
| [Codex (OpenAI)](https://github.com/openai/codex) | ✅ | ✅ | ❌ | ✅ |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | ✅ | ✅ | ❌ | ❌ |
| [Goose (Block)](https://github.com/block/goose) | ❌ | ✅ | ❌ | ✅ |
| [Aider](https://github.com/Aider-AI/aider) | ❌ | ✅ | ✅ | ✅ |

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
