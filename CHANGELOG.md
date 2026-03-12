# Changelog

## 0.0.11 - 2026-03-12

### Features
- add Kimi CLI, Cline CLI, and Qwen Code support across the CLI and website
- add a unified installed entrypoint (`kitup` / `kitup.bat`) while keeping platform-specific bootstrap installers
- add Windows-native package manager support for Chocolatey and Scoop in the PowerShell implementation

### Fixes
- preserve the active binary selected by `PATH` when determining install method and update source
- fix restore path handling and version-source normalization for standalone tools
- align installer/download links, website copy, and supported-tool matrices with the current project structure

### Testing
- add repeatable regression coverage for PATH priority, restore flow, unified entrypoint dispatch, and new-tool support
