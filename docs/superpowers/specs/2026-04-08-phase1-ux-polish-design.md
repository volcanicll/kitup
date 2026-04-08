# Phase 1: UX Polish Design Spec

Date: 2026-04-08
Status: Approved

## Overview

Five UX improvements for kitup CLI to enhance discoverability, clarity, and interactivity. All implemented in pure Bash with ANSI escape codes — no external dependencies.

## Architecture

Add `lib-tui.sh` as a new library file sourced by `kitup.sh`. All TUI, progress, and summary rendering logic lives here. Changelog and auto-detect logic are added directly to `kitup.sh` as new functions and commands.

### Files changed

- `packages/cli/kitup.sh` — new commands (changelog, auto-detect), updated `update_all` / `update_all_parallel` / `update_specific` to collect results and render summary table, updated `show_status` to include detected tools
- `packages/cli/lib-tui.sh` — new file: TUI rendering, keyboard input, progress indicator, summary table
- `packages/cli/lib-config.sh` — new config keys: `changelog_count` (default 3), `detect_new_tools` (default true)

## Feature 1: Interactive TUI

### Trigger

`kitup` with no arguments in an interactive terminal (`[ -t 0 ]`). Non-interactive contexts (piped, CI) fall back to current text-based `show_status`.

### Layout

```
┌─ kitup v0.0.14 ──────────────────────────────────────────┐
│  AI Tools Status          [j/k] navigate  [Space] select │
│                                        [Enter] update     │
│                                                          │
│  ◉ claude    0.2.48 → 0.2.50    npm       ● needs update │
│  ○ opencode  0.8.2              brew      ✓ up to date   │
│  ◉ codex     0.1.0  → 0.1.2    npm       ● needs update │
│  ○ gemini    0.1.0              npm       ✓ up to date   │
│  ◉ kimi      1.0.0  → 1.0.3    pipx      ● needs update │
│  ─ not installed ─────────────────────────────────────── │
│  ○ cline     -                  npm                      │
│  ○ qwen      -                  npm                      │
│  ─ new tools detected ────────────────────────────────── │
│  ⚑ augment  (detected)        consider adding support    │
│                                                          │
│  [3 selected]                          [Enter] Update    │
└──────────────────────────────────────────────────────────┘
```

### Behavior

- `j`/`k` or arrow keys: move cursor up/down
- `Space`: toggle selection (only tools that need update are pre-selected)
- `Enter`: update all selected tools, then show summary
- `q`: quit without updating
- `a`: select/deselect all
- Tools needing update are pre-selected (`◉`); up-to-date tools start unselected (`○`)
- Not-installed tools shown in a collapsed section, non-selectable unless `--install` mode
- New detected tools shown at bottom with flag icon, non-selectable

### Rendering

- Pure ANSI: `\033[?25l` hide cursor, `\033[?25h` restore, `\033[A` cursor up for in-place refresh
- Terminal size detection via `tput cols` / `tput lines`; fallback to 80x24
- Restore terminal state on exit (trap SIGINT)

### Key reading

```bash
read -rsn1 key
case "$key" in
    j|$'\x1b[B')  # down
    k|$'\x1b[A')  # up
    ' ')          # space (toggle)
    q)            # quit
    a)            # select all
    '')           # enter
esac
```

Arrow keys send ESC prefix: read `-rsn1` twice to distinguish.

## Feature 2: Update Summary Report

### When shown

After any update operation: `--all`, specific tools, or TUI-triggered update.

### Layout

```
┌─ Update Results ─────────────────────────────────────────┐
│                                                          │
│  ✓ claude    0.2.48 → 0.2.50    npm        3s           │
│  ✓ codex     0.1.0  → 0.1.2    npm        2s           │
│  ✓ kimi      1.0.0  → 1.0.3    pipx       5s           │
│                                                          │
│  - opencode  0.8.2              brew       skipped       │
│  - gemini    0.1.0              npm        skipped       │
│                                                          │
│  ✗ tabby     failed             brew       timeout       │
│                                                          │
│──────────────────────────────────────────────────────────│
│  Updated: 3  │  Skipped: 2  │  Failed: 1  │  Time: 10s  │
└──────────────────────────────────────────────────────────┘
```

### Data collection

- Each update job writes result to temp file: `status|local_ver|latest_ver|method|elapsed_seconds|error_message`
- Status values: `success`, `skip`, `fail`
- After all jobs complete, `render_summary()` reads all temp files and renders the table

### Changes to existing functions

- `update_all`, `update_all_parallel`, `update_specific`: collect results into `$tmp_dir/results_*.txt` instead of printing inline
- After loop, call `render_summary "$tmp_dir"`
- `--verbose` flag: show error details for failed items below the summary table

## Feature 3: Progress Indicator

### When shown

During parallel update execution (`update_all_parallel`).

### Layout (per-tool three-state)

```
Updating AI Tools... (2/4 complete)

  ✓ claude    done                npm     3s
  ⟳ codex     updating via npm...         2s
  ⟳ kimi      downloading...     pipx    1s
  ○ gemini    queued
```

### Implementation

- Background jobs write state to `$tmp_dir/job_N_status` (already exists in current code)
- Main loop polls every 0.5s, re-renders the block using ANSI cursor-up to overwrite previous output
- Three states:
  1. `queued` — job not started yet
  2. `running` — job in progress, show tool name + method
  3. `done` / `fail` — completed
- Total elapsed time tracked from start of update batch
- On completion, clear the progress block and render the summary table

### Non-interactive fallback

When `[ -t 0 ]` is false, fall back to current line-by-line output (no progress animation).

## Feature 4: Changelog Viewer

### Command

```bash
kitup changelog <tool>           # Show last 3 releases
kitup changelog <tool> --count 5 # Show last 5 releases
kitup changelog <tool> --since   # Only show releases after current version
kitup changelog --all            # Show latest release for all installed tools
```

### Data source

- GitHub Releases API: `https://api.github.com/repos/$repo/releases?per_page=$count`
- Uses existing `get_github_latest_version` auth pattern (gh CLI → curl + GITHUB_TOKEN)
- Response parsed for: `tag_name`, `published_at`, `body` (markdown)

### Layout

```
┌─ claude changelog ───────────────────────────────────────┐
│  v0.2.50 (2025-01-15)                                    │
│  ─────────────────────                                    │
│  • Fix: Handle edge case in token counting               │
│  • Feat: Add streaming support for long responses        │
│  • Fix: Resolve timeout on slow connections              │
│                                                          │
│  v0.2.49 (2025-01-12)                                    │
│  ─────────────────────                                    │
│  • Fix: Memory leak in session management                │
│  • Feat: New /compact command                            │
│                                                          │
│  (current: 0.2.48 → latest: 0.2.50)                     │
└──────────────────────────────────────────────────────────┘
```

### Markdown-to-text rendering

- Strip markdown formatting: `**bold**` → bold text, `- item` → `• item`, headings → underlined
- Truncate body to 10 lines per release
- If no GitHub repo available for tool, show "Changelog not available for $tool"

### Caching

- Cache location: `~/.config/kitup/changelog_cache/$tool`
- TTL: 1 hour (reuse `VERSION_CACHE_TTL_SECONDS` env var)
- Cache format: `timestamp\n` + raw JSON body

### Integration into main()

New arg handling in `main()`:

```bash
if [ "${args[0]}" = "changelog" ]; then
    # parse tool name, --count, --since, --all
    show_changelog ...
    exit 0
fi
```

## Feature 5: Auto-detect New Tools

### Candidate list

A hardcoded array of ~20 known AI coding tool command names not already in `TOOLS`:

```bash
declare -a DETECT_CANDIDATES=(
    "augment|augment"
    "copilot|github-copilot-cli"
    "continue|continue"
    "fabric|fabric"
    "devika|devika"
    "swe-agent|sweagent"
    "openhands|openhands"
    "aider-chat|aider"
    ".cursor|cursor-agent"
    "warp|warp"
    "pearai|pearai"
    "void|void"
    "zed|zed"
    "trae|trae"
    "marscode|marscode"
    "lingma|lingma"
    "tongyi|tongyi lingma"
    "bitsail|bitsail"
    "cody|cody"
    "sourcegraph|src"
)
```

Note: some of these overlap with existing TOOLS entries. The detection function filters out any command already present in TOOLS.

### Detection logic

```bash
detect_new_tools() {
    local results=()
    for candidate in "${DETECT_CANDIDATES[@]}"; do
        IFS='|' read -r name cmd <<< "$candidate"
        # Skip if already in TOOLS
        is_known_tool "$cmd" && continue
        # Check if command exists
        if command_exists "$cmd"; then
            local ver
            ver=$(get_local_version "$cmd")
            results+=("$name|$cmd|$ver|$(get_command_path "$cmd")")
        fi
    done
    echo "${results[@]}"
}
```

### Display

- In TUI: shown in a section at the bottom with `⚑` icon, non-selectable
- In `--status`: shown after the main table
- In both cases: tip line pointing to GitHub issues

### Output

```
─ new tools detected ──────────────────────────────────────
  ⚑ augment   v0.3.0    /usr/local/bin/augment
  ⚑ copilot   v1.0.2    ~/.local/bin/copilot

  Tip: Request support at github.com/volcanicll/kitup/issues
```

### Caching

- Cache: `~/.config/kitup/detected_tools`
- TTL: 24 hours
- Format: `timestamp\ntool|cmd|version|path\n...`
- Cleared on `kitup --status` if stale

### Config

New config key `detect_new_tools` (default: `true`). Set to `false` to disable detection.

## Error Handling

- TUI: SIGINT trap restores terminal state (cursor, echo)
- Progress: if terminal too small (< 20 lines), fall back to line-by-line output
- Changelog: network errors show "Unable to fetch changelog" with retry suggestion
- Auto-detect: detection failure is non-fatal, silently skipped

## Testing

- Unit tests for: version comparison, markdown stripping, candidate filtering
- Regression tests for: TUI key handling (via stdin mock), progress state transitions, summary rendering
- New test file: `test-tui.sh` with mocked terminal (force tty detection)

## Non-goals

- No real download progress percentage (package managers don't expose this)
- No mouse support in TUI (keyboard only)
- No Windows TUI support in this phase (PowerShell `kitup.ps1` gets text-only improvements)
