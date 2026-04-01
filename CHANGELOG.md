# Changelog

## 0.0.14 - 2026-04-01

### Fixes
- fix script exiting when GitHub API rate limit is exceeded
- fix `notify_self_update()` returning non-zero exit code causing `set -e` to terminate script
- fix `get_github_latest_version()` not handling API error responses properly

### Improvements
- prioritize `gh` CLI for version checks when available (uses authenticated requests, no rate limits)
- add proper error detection for GitHub API error messages (rate limit, repository not found, etc.)
- improve `null` response handling from `jq` when API returns errors
- add `|| true` to prevent command failures from exiting script under `set -e`

### Technical Details
- When GitHub API returns an error message (e.g., rate limit exceeded), the script now gracefully returns empty string instead of parsing error text as version
- `gh` CLI is now tried first for GitHub version checks since it uses authenticated requests with much higher rate limits
- All return statements in `notify_self_update()` now explicitly return 0 to prevent `set -e` termination

## 0.0.13 - 2026-03-24

### Features
- add parallel update support with configurable job count (default: 3)

### Performance
- add parallel update support with configurable job count (default: 3)
- add version caching with 1-hour TTL to reduce API calls
- add `--parallel N` option to control concurrency
- add `--no-parallel` option to disable parallel updates
- add `KITUP_PARALLEL_JOBS` environment variable
- add `KITUP_VERSION_CACHE_TTL_SECONDS` environment variable

### Configuration
- add persistent configuration file support (`~/.kitup/config.json`)
- add `kitup config` command to create/edit configuration
- add auto-backup and auto-install options in config
- add tool exclusion list support via `--exclude` option
- add `KITUP_EXCLUDE_TOOLS` environment variable

### Advanced Update Features
- add version pinning with `kitup pin <tool> <version>` command
- add `kitup unpin <tool>` command to remove version pins
- add `kitup list-pins` command to show all pinned versions
- add pinned version storage in `~/.kitup/pinned_versions`
- updates respect pinned versions and skip if already at pinned version

### Website Enhancements
- add tool comparison matrix table showing all supported install methods
- update supported tools count to 12
- add parallel updates and version pinning to feature list
- improve visual presentation of installation methods

### Features
- add Cursor CLI support (GitHub releases, Homebrew)
- add Windsurf CLI support (GitHub releases, Homebrew)
- add Tabby support (GitHub releases, Homebrew)
- add configuration backup paths for new tools
- add unit tests for core functions (parse_version, version_is_newer)
- add regression tests for new tools
- add CONTRIBUTING.md with development guidelines
- add architecture documentation (docs/ARCHITECTURE.md)
- add GitHub issue templates (bug report, feature request, tool request)
- add pull request template

### Improvements
- expand test coverage with dedicated unit test suite
- improve developer onboarding with comprehensive documentation
- standardize code formatting across shell and PowerShell scripts

### Documentation
- add contribution guidelines with coding standards
- add architecture documentation explaining core components
- add issue and PR templates for better collaboration
- add examples for parallel updates and version pinning
- add configuration file documentation
- update help text with new commands and options


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
