#!/bin/bash
#
# kitup
# A unified updater for AI coding assistants
# Supports: Claude Code, OpenCode, Codex, Gemini CLI, Kimi CLI, Cline CLI, Qwen Code, Goose, Aider, Cursor CLI, Windsurf CLI, Tabby
#

set -e

# Source library files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib-config.sh" ]; then
    source "$SCRIPT_DIR/lib-config.sh"
fi
if [ -f "$SCRIPT_DIR/lib-pin.sh" ]; then
    source "$SCRIPT_DIR/lib-pin.sh"
fi

# Version
VERSION="0.0.12"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
DRY_RUN=false
FORCE=false
INSTALL_MISSING=false
BACKUP_CONFIG=false
VERBOSE=false
RESTORE_CONFIG=false
UPDATE_ALL=false
PARALLEL_JOBS="${KITUP_PARALLEL_JOBS:-3}"  # Number of parallel update jobs
SELF_UPDATE_TTL_SECONDS="${KITUP_SELF_UPDATE_TTL_SECONDS:-86400}"
SELF_UPDATE_CACHE_FILE="${HOME}/.config/kitup/self_update_check"
VERSION_CACHE_FILE="${HOME}/.config/kitup/version_cache"
VERSION_CACHE_TTL_SECONDS="${KITUP_VERSION_CACHE_TTL_SECONDS:-3600}"  # 1 hour TTL

# Tool definitions
# Format: name|command|npm_package|brew_formula|pipx_package|uv_package|github_repo|install_url
declare -a TOOLS=(
    "claude|claude|@anthropic-ai/claude-code|anthropic-ai/tap/claude-code|||anthropics/claude-code|https://claude.ai/install.sh"
    "opencode|opencode|opencode-ai|opencode|||opencode-ai/opencode|https://opencode.ai/install"
    "codex|codex|@openai/codex|codex|||openai/codex|https://cli.openai.com/install.sh"
    "gemini|gemini|@google/gemini-cli|gemini-cli|||google-gemini/gemini-cli|"
    "kimi|kimi|||kimi-cli|kimi-cli|MoonshotAI/kimi-cli|"
    "cline|cline|cline||||cline/cline|"
    "qwen|qwen|@qwen-code/qwen-code|qwen-code|||QwenLM/qwen-code|https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen.sh"
    "goose|goose||block-goose-cli|||block/goose|https://github.com/block/goose/releases/download/stable/download_cli.sh"
    "aider|aider||aider|aider-chat|aider-chat|Aider-AI/aider|https://aider.chat/install.sh"
    "cursor|cursor||cursor|||cursor-sh/cursor|https://downloader.cursor.sh/linux"
    "windsurf|windsurf||windsurf|||codeium/windsurf|https://windsurf.sh/install"
    "tabby|tabby||tabby|||TabbyML/tabby|"
)

# Print functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BOLD}${CYAN}$1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" > /dev/null 2>&1
}

get_command_path() {
    command -v "$1" 2>/dev/null || echo ""
}

get_npm_global_prefix() {
    if command_exists npm; then
        npm prefix -g 2>/dev/null || echo ""
    else
        echo ""
    fi
}

get_brew_prefix() {
    if command_exists brew; then
        brew --prefix 2>/dev/null || echo ""
    else
        echo ""
    fi
}

is_standalone_path() {
    local tool_path="$1"
    local brew_prefix
    brew_prefix=$(get_brew_prefix)

    [[ "$tool_path" == "$HOME/.local/bin/"* ]] || [[ "$tool_path" == "$HOME/bin/"* ]] || {
        [[ "$tool_path" == /usr/local/bin/* ]] && [ "$brew_prefix" != "/usr/local" ]
    }
}

# Check whether a Homebrew package is installed as a cask
is_brew_cask() {
    local package="$1"
    command_exists brew && brew list --cask "$package" > /dev/null 2>&1
}

# Parse version string (extract x.y.z)
parse_version() {
    local version_str="$1"
    # Extract version number like x.y.z or x.y.z-alpha
    echo "$version_str" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+([-\.]?[a-zA-Z0-9]+)?' | head -1
}

# Get local version of a tool
get_local_version() {
    local cmd="$1"
    local version_str

    if ! command_exists "$cmd"; then
        echo ""
        return
    fi

    version_str=$($cmd --version 2>/dev/null || $cmd -v 2>/dev/null || echo "")
    parse_version "$version_str"
}

# Detect all installation methods for a tool (returns comma-separated list)
detect_all_install_methods() {
    local cmd="$1"
    local npm_pkg="$2"
    local brew_formula="$3"
    local pipx_pkg="$4"
    local uv_pkg="$5"

    local methods=""
    local tool_path
    tool_path=$(get_command_path "$cmd")

    # Check npm global list
    if [ -n "$npm_pkg" ] && command_exists npm; then
        if npm list -g "$npm_pkg" > /dev/null 2>&1; then
            methods="npm"
        fi
    fi

    # Check Homebrew list
    if [ -n "$brew_formula" ] && command_exists brew; then
        if brew list "$brew_formula" > /dev/null 2>&1 || brew list --cask "$brew_formula" > /dev/null 2>&1; then
            if [ -n "$methods" ]; then
                methods="$methods,brew"
            else
                methods="brew"
            fi
        fi
    fi

    # Check pipx
    if [ -n "$pipx_pkg" ] && command_exists pipx; then
        if pipx list | grep -q "$pipx_pkg"; then
            if [ -n "$methods" ]; then
                methods="$methods,pipx"
            else
                methods="pipx"
            fi
        fi
    fi

    # Check uv
    if [ -n "$uv_pkg" ] && command_exists uv; then
        if uv tool list | grep -q "$uv_pkg"; then
            if [ -n "$methods" ]; then
                methods="$methods,uv"
            else
                methods="uv"
            fi
        fi
    fi

    # Check current tool path for standalone
    if [ -n "$tool_path" ]; then
        if is_standalone_path "$tool_path"; then
            if [ -n "$methods" ]; then
                methods="$methods,standalone"
            else
                methods="standalone"
            fi
        fi
    fi

    echo "$methods"
}

# Detect installation method for a tool
detect_install_method() {
    local cmd="$1"
    local npm_pkg="$2"
    local brew_formula="$3"
    local pipx_pkg="$4"
    local uv_pkg="$5"

    local tool_path
    tool_path=$(get_command_path "$cmd")
    local npm_prefix
    npm_prefix=$(get_npm_global_prefix)
    local brew_prefix
    brew_prefix=$(get_brew_prefix)

    if [ -z "$tool_path" ]; then
        echo ""
        return
    fi

    # Respect the command currently selected by PATH first.
    if [ -n "$brew_formula" ] && [ -n "$brew_prefix" ] && [[ "$tool_path" == "$brew_prefix/bin/"* ]]; then
        if brew list "$brew_formula" > /dev/null 2>&1 || brew list --cask "$brew_formula" > /dev/null 2>&1; then
            echo "brew"
            return
        fi
    fi

    if [ -n "$npm_pkg" ] && [ -n "$npm_prefix" ] && [[ "$tool_path" == "$npm_prefix/bin/"* ]]; then
        if npm list -g "$npm_pkg" > /dev/null 2>&1; then
            echo "npm"
            return
        fi
    fi

    if is_standalone_path "$tool_path"; then
        echo "standalone"
        return
    fi

    # Check npm global list
    if [ -n "$npm_pkg" ] && command_exists npm; then
        if npm list -g "$npm_pkg" > /dev/null 2>&1; then
            echo "npm"
            return
        fi
    fi

    # Check Homebrew list
    if [ -n "$brew_formula" ] && command_exists brew; then
        if brew list "$brew_formula" > /dev/null 2>&1 || brew list --cask "$brew_formula" > /dev/null 2>&1; then
            echo "brew"
            return
        fi
    fi

    # Check pipx
    if [ -n "$pipx_pkg" ] && command_exists pipx; then
        if pipx list | grep -q "$pipx_pkg"; then
            echo "pipx"
            return
        fi
    fi

    # Check uv
    if [ -n "$uv_pkg" ] && command_exists uv; then
        if uv tool list | grep -q "$uv_pkg"; then
            echo "uv"
            return
        fi
    fi

    # Check if it's in common standalone locations
    if is_standalone_path "$tool_path"; then
        echo "standalone"
        return
    fi

    # Default to unknown
    echo "unknown"
}

# Get latest version from npm
get_npm_latest_version() {
    local pkg="$1"
    if command_exists npm; then
        parse_version "$(npm view "$pkg" version 2>/dev/null || echo "")"
    else
        echo ""
    fi
}

# Get latest version from Homebrew
get_brew_latest_version() {
    local formula="$1"
    if command_exists brew; then
        local version
        if command_exists jq; then
            version=$(brew info "$formula" --json 2>/dev/null | jq -r '.[0].versions.stable // empty' 2>/dev/null || true)
        else
            version=$(brew info "$formula" --json 2>/dev/null | tr -d '\n' | sed -n 's/.*"stable":"\([^"]*\)".*/\1/p' | head -1)
        fi
        if [ -n "$version" ]; then
            parse_version "$version"
            return
        fi

        if command_exists jq; then
            parse_version "$(brew info --cask "$formula" --json=v2 2>/dev/null | jq -r '.casks[0].version // empty' 2>/dev/null || echo "")"
        else
            parse_version "$(brew info --cask "$formula" --json=v2 2>/dev/null | tr -d '\n' | sed -n 's/.*"version":"\([^"]*\)".*/\1/p' | head -1)"
        fi
    else
        echo ""
    fi
}

# Get latest version from GitHub releases
get_github_latest_version() {
    local repo="$1"
    if command_exists curl && command_exists jq; then
        parse_version "$(curl -s "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null | jq -r '.tag_name' 2>/dev/null || echo "")"
    elif command_exists curl; then
        parse_version "$(curl -s "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null | tr -d '\n' | sed -n 's/.*"tag_name":"\([^"]*\)".*/\1/p' | head -1)"
    else
        echo ""
    fi
}

# Version cache functions
get_cached_version() {
    local cache_key="$1"
    [ -f "$VERSION_CACHE_FILE" ] || return 1

    local now cached_at cached_version
    now=$(date +%s 2>/dev/null || echo "0")

    while IFS='|' read -r key timestamp version; do
        if [ "$key" = "$cache_key" ]; then
            cached_at="$timestamp"
            cached_version="$version"
            [[ "$cached_at" =~ ^[0-9]+$ ]] || return 1

            if (( now - cached_at <= VERSION_CACHE_TTL_SECONDS )); then
                echo "$cached_version"
                return 0
            fi
            return 1
        fi
    done < "$VERSION_CACHE_FILE"

    return 1
}

set_cached_version() {
    local cache_key="$1"
    local version="$2"
    local config_dir now

    config_dir=$(dirname "$VERSION_CACHE_FILE")
    mkdir -p "$config_dir"

    now=$(date +%s 2>/dev/null || echo "0")

    # Remove old entry for this key if exists
    if [ -f "$VERSION_CACHE_FILE" ]; then
        local temp_file="${VERSION_CACHE_FILE}.tmp"
        grep -v "^${cache_key}|" "$VERSION_CACHE_FILE" > "$temp_file" 2>/dev/null || true
        mv "$temp_file" "$VERSION_CACHE_FILE" 2>/dev/null || true
    fi

    # Add new entry
    printf '%s|%s|%s\n' "$cache_key" "$now" "$version" >> "$VERSION_CACHE_FILE"
}

# Get latest version from PyPI
get_pypi_latest_version() {
    local pkg="$1"
    if command_exists curl && command_exists jq; then
        parse_version "$(curl -s "https://pypi.org/pypi/$pkg/json" 2>/dev/null | jq -r '.info.version' 2>/dev/null || echo "")"
    else
        echo ""
    fi
}

# Get latest version for a tool - tries all available sources
get_latest_version() {
    local method="$1"
    local npm_pkg="$2"
    local brew_formula="$3"
    local pipx_pkg="$4"
    local uv_pkg="$5"
    local github_repo="$6"
    local use_cache="${7:-true}"
    local latest_ver=""

    # Create cache key
    local cache_key="${method}:${npm_pkg}:${brew_formula}:${pipx_pkg}:${uv_pkg}:${github_repo}"

    # Try cache first
    if [ "$use_cache" = "true" ]; then
        local cached_version
        cached_version=$(get_cached_version "$cache_key") || true
        if [ -n "$cached_version" ]; then
            echo "$cached_version"
            return
        fi
    fi

    case "$method" in
        npm)
            [ -n "$npm_pkg" ] && latest_ver=$(get_npm_latest_version "$npm_pkg")
            ;;
        pipx)
            [ -n "$pipx_pkg" ] && latest_ver=$(get_pypi_latest_version "$pipx_pkg")
            ;;
        uv)
            [ -n "$uv_pkg" ] && latest_ver=$(get_pypi_latest_version "$uv_pkg")
            ;;
        brew)
            [ -n "$brew_formula" ] && latest_ver=$(get_brew_latest_version "$brew_formula")
            ;;
        standalone|unknown)
            [ -n "$github_repo" ] && latest_ver=$(get_github_latest_version "$github_repo")
            ;;
    esac

    # Fallbacks when detection is incomplete
    if [ -z "$latest_ver" ] && [ -n "$npm_pkg" ]; then
        latest_ver=$(get_npm_latest_version "$npm_pkg")
    fi
    if [ -z "$latest_ver" ] && [ -n "$pipx_pkg" ]; then
        latest_ver=$(get_pypi_latest_version "$pipx_pkg")
    fi
    if [ -z "$latest_ver" ] && [ -n "$uv_pkg" ]; then
        latest_ver=$(get_pypi_latest_version "$uv_pkg")
    fi
    if [ -z "$latest_ver" ] && [ -n "$brew_formula" ]; then
        latest_ver=$(get_brew_latest_version "$brew_formula")
    fi
    if [ -z "$latest_ver" ] && [ -n "$github_repo" ]; then
        latest_ver=$(get_github_latest_version "$github_repo")
    fi

    # Cache the result
    if [ -n "$latest_ver" ] && [ "$use_cache" = "true" ]; then
        set_cached_version "$cache_key" "$latest_ver"
    fi

    echo "$latest_ver"
}

version_is_newer() {
    local candidate="$1"
    local current="$2"
    local candidate_base current_base
    local IFS=.
    local -a candidate_parts current_parts

    candidate_base=$(echo "$candidate" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+')
    current_base=$(echo "$current" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+')

    [ -z "$candidate_base" ] || [ -z "$current_base" ] && return 1

    read -r -a candidate_parts <<< "$candidate_base"
    read -r -a current_parts <<< "$current_base"

    for idx in 0 1 2; do
        local candidate_num="${candidate_parts[$idx]:-0}"
        local current_num="${current_parts[$idx]:-0}"
        if (( candidate_num > current_num )); then
            return 0
        fi
        if (( candidate_num < current_num )); then
            return 1
        fi
    done

    return 1
}

get_cached_self_update_version() {
    [ -f "$SELF_UPDATE_CACHE_FILE" ] || return 1

    local checked_at cached_version now
    checked_at=$(sed -n '1p' "$SELF_UPDATE_CACHE_FILE" 2>/dev/null)
    cached_version=$(sed -n '2p' "$SELF_UPDATE_CACHE_FILE" 2>/dev/null)
    now=$(date +%s 2>/dev/null || echo "")

    [ -n "$checked_at" ] || return 1
    [ -n "$cached_version" ] || return 1
    [ -n "$now" ] || return 1
    [[ "$checked_at" =~ ^[0-9]+$ ]] || return 1

    if (( now - checked_at <= SELF_UPDATE_TTL_SECONDS )); then
        echo "$cached_version"
        return 0
    fi

    return 1
}

write_self_update_cache() {
    local latest_version="$1"
    local config_dir checked_at

    config_dir=$(dirname "$SELF_UPDATE_CACHE_FILE")
    mkdir -p "$config_dir"
    checked_at=$(date +%s 2>/dev/null || echo "0")
    printf '%s\n%s\n' "$checked_at" "$latest_version" > "$SELF_UPDATE_CACHE_FILE"
}

get_kitup_latest_version() {
    local cached_version
    cached_version=$(get_cached_self_update_version) || true
    if [ -n "$cached_version" ]; then
        echo "$cached_version"
        return
    fi

    local latest_version
    latest_version=$(get_github_latest_version "volcanicll/kitup")
    if [ -n "$latest_version" ]; then
        write_self_update_cache "$latest_version"
    fi
    echo "$latest_version"
}

notify_self_update() {
    [ "${KITUP_SKIP_SELF_UPDATE_CHECK:-0}" = "1" ] && return

    local latest_version
    latest_version=$(get_kitup_latest_version)
    [ -n "$latest_version" ] || return

    if version_is_newer "$latest_version" "$VERSION"; then
        printf "\n"
        print_warning "A newer kitup version is available: $latest_version (current: $VERSION)"
        print_info "Upgrade with: curl -fsSL https://raw.githubusercontent.com/volcanicll/kitup/main/packages/cli/install.sh | bash"
        printf "\n"
    fi
}

# Update a tool using specific method
update_tool() {
    local name="$1"
    local method="$2"
    local npm_pkg="$3"
    local brew_formula="$4"
    local pipx_pkg="$5"
    local uv_pkg="$6"
    local install_url="$7"

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would update $name using $method"
        return 0
    fi

    case "$method" in
        npm)
            if [ -n "$npm_pkg" ]; then
                print_info "Updating $name via npm..."
                npm update -g "$npm_pkg"
            fi
            ;;
        brew)
            if [ -n "$brew_formula" ]; then
                print_info "Updating $name via Homebrew..."
                if is_brew_cask "$brew_formula"; then
                    brew upgrade --cask "$brew_formula"
                else
                    brew upgrade "$brew_formula"
                fi
            fi
            ;;
        pipx)
            if [ -n "$pipx_pkg" ]; then
                print_info "Updating $name via pipx..."
                pipx upgrade "$pipx_pkg"
            fi
            ;;
        uv)
            if [ -n "$uv_pkg" ]; then
                print_info "Updating $name via uv..."
                uv tool upgrade "$uv_pkg"
            fi
            ;;
        standalone|unknown)
            if [ -n "$install_url" ]; then
                print_info "Updating $name via official installer..."
                if [[ "$install_url" == *.sh ]]; then
                    curl -fsSL "$install_url" | bash
                else
                    curl -fsSL "$install_url" | bash
                fi
            else
                print_warning "No update URL available for $name"
                return 1
            fi
            ;;
    esac
}

# Install a tool
install_tool() {
    local name="$1"
    local cmd="$2"
    local npm_pkg="$3"
    local brew_formula="$4"
    local pipx_pkg="$5"
    local uv_pkg="$6"
    local install_url="$7"

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would install $name"
        return 0
    fi

    print_info "Installing $name..."

    # Try different installation methods in order of preference
    if [ -n "$brew_formula" ] && command_exists brew; then
        print_info "Installing $name via Homebrew..."
        if brew info --cask "$brew_formula" > /dev/null 2>&1; then
            brew install --cask "$brew_formula"
        else
            brew install "$brew_formula"
        fi
    elif [ -n "$npm_pkg" ] && command_exists npm; then
        print_info "Installing $name via npm..."
        npm install -g "$npm_pkg"
    elif [ -n "$pipx_pkg" ] && command_exists pipx; then
        print_info "Installing $name via pipx..."
        pipx install "$pipx_pkg"
    elif [ -n "$uv_pkg" ] && command_exists uv; then
        print_info "Installing $name via uv..."
        uv tool install "$uv_pkg"
    elif [ -n "$install_url" ]; then
        print_info "Installing $name via official installer..."
        curl -fsSL "$install_url" | bash
    else
        print_error "Cannot install $name: no suitable installation method found"
        return 1
    fi
}

# Backup configuration
backup_configs() {
    local backup_dir="$HOME/.config/kitup/backups/$(date +%Y%m%d_%H%M%S)"

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would backup configs to $backup_dir"
        return 0
    fi

    mkdir -p "$backup_dir"

    # Backup common config files
    local configs=(
        "$HOME/.claude"
        "$HOME/.config/opencode"
        "$HOME/.config/codex"
        "$HOME/.config/gemini"
        "$HOME/.config/goose"
        "$HOME/.aider.conf.yml"
        "$HOME/.aider.model.settings.yml"
        "$HOME/.config/cursor"
        "$HOME/.config/windsurf"
        "$HOME/.config/tabby"
    )

    for config in "${configs[@]}"; do
        if [ -e "$config" ]; then
            cp -r "$config" "$backup_dir/" 2>/dev/null || true
        fi
    done

    print_success "Configuration backed up to $backup_dir"
    echo "$backup_dir" > "$HOME/.config/kitup/last_backup"
}

# Show status of all tools
show_status() {
    print_header "AI Tools Status"
    printf "\n"
    printf "%-12s %-10s %-12s %-15s %-15s\n" "Tool" "Installed" "Method" "Local Version" "Latest Version"
    printf "%-12s %-10s %-12s %-15s %-15s\n" "----" "---------" "------" "-------------" "--------------"

    local multi_install_tools=""

    for tool_def in "${TOOLS[@]}"; do
        IFS='|' read -r name cmd npm_pkg brew_formula pipx_pkg uv_pkg github_repo install_url <<< "$tool_def"

        local installed="No"
        local method="-"
        local local_ver="-"
        local latest_ver="-"

        if command_exists "$cmd"; then
            installed="Yes"
            method=$(detect_install_method "$cmd" "$npm_pkg" "$brew_formula" "$pipx_pkg" "$uv_pkg")
            local_ver=$(get_local_version "$cmd")
            latest_ver=$(get_latest_version "$method" "$npm_pkg" "$brew_formula" "$pipx_pkg" "$uv_pkg" "$github_repo")

            # Check for multiple installations
            local all_methods
            all_methods=$(detect_all_install_methods "$cmd" "$npm_pkg" "$brew_formula" "$pipx_pkg" "$uv_pkg")
            local method_count
            if [ -n "$all_methods" ]; then
                method_count=$(echo "$all_methods" | tr ',' '\n' | sed '/^$/d' | wc -l | tr -d ' ')
            else
                method_count=0
            fi

            if [ "$method_count" -gt 1 ]; then
                method="${method}*"
                multi_install_tools="$multi_install_tools\n  $name: $all_methods"
            fi
        fi

        printf "%-12s %-10s %-12s %-15s %-15s\n" "$name" "$installed" "$method" "$local_ver" "$latest_ver"
    done

    printf "\n"

    # Show warning for multiple installations
    if [ -n "$multi_install_tools" ]; then
        print_warning "Multiple installations detected (*):"
        echo -e "$multi_install_tools"
        echo ""
        print_info "Options:"
        echo "  1. Update current (PATH priority): kitup <tool>"
        echo "  2. Update all installations: kitup <tool> --force"
        echo "  3. Remove duplicates manually, then reinstall with preferred method"
        echo ""
    fi
}

# List all supported tools
list_tools() {
    print_header "Supported AI Tools"
    printf "\n"

    for tool_def in "${TOOLS[@]}"; do
        IFS='|' read -r name cmd npm_pkg brew_formula pipx_pkg uv_pkg github_repo install_url <<< "$tool_def"

        echo -e "${BOLD}$name${NC}"
        echo "  Command: $cmd"
        [ -n "$npm_pkg" ] && echo "  npm: $npm_pkg"
        [ -n "$brew_formula" ] && echo "  Homebrew: $brew_formula"
        [ -n "$pipx_pkg" ] && echo "  pipx: $pipx_pkg"
        [ -n "$uv_pkg" ] && echo "  uv: $uv_pkg"
        [ -n "$github_repo" ] && echo "  GitHub: $github_repo"
        echo ""
    done
}

# Update all installed tools
update_all() {
    local updated=0
    local failed=0
    local skipped=0

    print_header "Updating AI Tools"
    printf "\n"

    if [ "$BACKUP_CONFIG" = true ]; then
        backup_configs
    fi

    # Check if we should use parallel updates
    if [ "$PARALLEL_JOBS" -gt 1 ] && [ "${KITUP_ENABLE_PARALLEL:-true}" = "true" ]; then
        update_all_parallel
        return $?
    fi

    for tool_def in "${TOOLS[@]}"; do
        IFS='|' read -r name cmd npm_pkg brew_formula pipx_pkg uv_pkg github_repo install_url <<< "$tool_def"

        # Check if tool is excluded
        if is_tool_excluded "$name"; then
            print_info "Skipping $name (excluded)"
            skipped=$((skipped + 1))
            continue
        fi

        if ! command_exists "$cmd"; then
            if [ "$INSTALL_MISSING" = true ]; then
                if install_tool "$name" "$cmd" "$npm_pkg" "$brew_formula" "$pipx_pkg" "$uv_pkg" "$install_url"; then
                    updated=$((updated + 1))
                else
                    failed=$((failed + 1))
                fi
            else
                print_info "Skipping $name (not installed)"
                skipped=$((skipped + 1))
            fi
            continue
        fi

        local method
        method=$(detect_install_method "$cmd" "$npm_pkg" "$brew_formula" "$pipx_pkg" "$uv_pkg")

        local local_ver latest_ver target_ver
        local_ver=$(get_local_version "$cmd")

        # Check if version is pinned
        if has_pinned_version "$name"; then
            local pinned_ver
            pinned_ver=$(get_pinned_version "$name")
            target_ver="$pinned_ver"

            if [ "$local_ver" = "$pinned_ver" ] && [ "$FORCE" = false ]; then
                print_info "$name is at pinned version ($local_ver)"
                skipped=$((skipped + 1))
                continue
            fi
        else
            latest_ver=$(get_latest_version "$method" "$npm_pkg" "$brew_formula" "$pipx_pkg" "$uv_pkg" "$github_repo")
            target_ver="$latest_ver"

            if [ -z "$latest_ver" ]; then
                print_warning "Cannot check latest version for $name"
                skipped=$((skipped + 1))
                continue
            fi

            if [ "$local_ver" = "$latest_ver" ] && [ "$FORCE" = false ]; then
                print_info "$name is already up to date ($local_ver)"
                skipped=$((skipped + 1))
                continue
            fi
        fi

        print_info "Updating $name from $local_ver to $target_ver..."
        if update_tool "$name" "$method" "$npm_pkg" "$brew_formula" "$pipx_pkg" "$uv_pkg" "$install_url"; then
            print_success "$name updated successfully"
            updated=$((updated + 1))
        else
            print_error "Failed to update $name"
            failed=$((failed + 1))
        fi
    done

    printf "\n"
    print_header "Update Summary"
    echo "  Updated: $updated"
    echo "  Failed: $failed"
    echo "  Skipped: $skipped"
}

# Update all tools in parallel
update_all_parallel() {
    local updated=0
    local failed=0
    local skipped=0
    local pids=()
    local tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    # Create status files for each job
    local job_count=0

    for tool_def in "${TOOLS[@]}"; do
        IFS='|' read -r name cmd npm_pkg brew_formula pipx_pkg uv_pkg github_repo install_url <<< "$tool_def"

        # Check if tool is installed
        if ! command_exists "$cmd"; then
            if [ "$INSTALL_MISSING" = true ]; then
                # Install sequentially (not parallelized for safety)
                if install_tool "$name" "$cmd" "$npm_pkg" "$brew_formula" "$pipx_pkg" "$uv_pkg" "$install_url"; then
                    updated=$((updated + 1))
                else
                    failed=$((failed + 1))
                fi
            else
                print_info "Skipping $name (not installed)"
                skipped=$((skipped + 1))
            fi
            continue
        fi

        # Wait if we've reached max parallel jobs
        while [ ${#pids[@]} -ge "$PARALLEL_JOBS" ]; do
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                    wait "${pids[$i]}"
                    unset "pids[$i]"
                fi
            done
            pids=("${pids[@]}")
            sleep 0.1
        done

        # Run update in background
        (
            local status_file="$tmp_dir/job_$job_count"
            local method
            method=$(detect_install_method "$cmd" "$npm_pkg" "$brew_formula" "$pipx_pkg" "$uv_pkg")

            local local_ver latest_ver
            local_ver=$(get_local_version "$cmd")
            latest_ver=$(get_latest_version "$method" "$npm_pkg" "$brew_formula" "$pipx_pkg" "$uv_pkg" "$github_repo" "true")

            if [ -z "$latest_ver" ]; then
                echo "skip|Cannot check latest version" > "$status_file"
                exit 0
            fi

            if [ "$local_ver" = "$latest_ver" ] && [ "$FORCE" = false ]; then
                echo "skip|$local_ver" > "$status_file"
                exit 0
            fi

            if update_tool "$name" "$method" "$npm_pkg" "$brew_formula" "$pipx_pkg" "$uv_pkg" "$install_url"; then
                echo "success|$latest_ver" > "$status_file"
            else
                echo "fail|update failed" > "$status_file"
            fi
        ) &

        pids+=($!)
        job_count=$((job_count + 1))
    done

    # Wait for all remaining jobs
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    # Process results
    job_count=0
    for tool_def in "${TOOLS[@]}"; do
        IFS='|' read -r name cmd npm_pkg brew_formula pipx_pkg uv_pkg github_repo install_url <<< "$tool_def"

        # Check if tool is excluded
        if is_tool_excluded "$name"; then
            print_info "Skipping $name (excluded)"
            skipped=$((skipped + 1))
            continue
        fi

        if ! command_exists "$cmd"; then
            continue
        fi

        local status_file="$tmp_dir/job_$job_count"
        if [ ! -f "$status_file" ]; then
            continue
        fi

        local result status message
        IFS='|' read -r result message < "$status_file"

        case "$result" in
            skip)
                print_info "$name is already up to date ($message)"
                skipped=$((skipped + 1))
                ;;
            success)
                print_success "$name updated successfully ($message)"
                updated=$((updated + 1))
                ;;
            fail)
                print_error "Failed to update $name: $message"
                failed=$((failed + 1))
                ;;
        esac

        job_count=$((job_count + 1))
    done

    printf "\n"
    print_header "Update Summary"
    echo "  Updated: $updated"
    echo "  Failed: $failed"
    echo "  Skipped: $skipped"
}

# Update specific tools
update_specific() {
    local targets=("$@")

    if [ "$BACKUP_CONFIG" = true ]; then
        backup_configs
    fi

    for target in "${targets[@]}"; do
        local found=false

        for tool_def in "${TOOLS[@]}"; do
            IFS='|' read -r name cmd npm_pkg brew_formula pipx_pkg uv_pkg github_repo install_url <<< "$tool_def"

            if [ "$name" = "$target" ]; then
                found=true

                if ! command_exists "$cmd"; then
                    if [ "$INSTALL_MISSING" = true ]; then
                        install_tool "$name" "$cmd" "$npm_pkg" "$brew_formula" "$pipx_pkg" "$uv_pkg" "$install_url"
                    else
                        print_error "$name is not installed (use --install to install)"
                    fi
                    continue
                fi

                local method
                method=$(detect_install_method "$cmd" "$npm_pkg" "$brew_formula" "$pipx_pkg" "$uv_pkg")

                local local_ver latest_ver
                local_ver=$(get_local_version "$cmd")
                latest_ver=$(get_latest_version "$method" "$npm_pkg" "$brew_formula" "$pipx_pkg" "$uv_pkg" "$github_repo")

                if [ -z "$latest_ver" ]; then
                    print_warning "Cannot check latest version for $name"
                    continue
                fi

                if [ "$local_ver" = "$latest_ver" ] && [ "$FORCE" = false ]; then
                    print_info "$name is already up to date ($local_ver)"
                    continue
                fi

                print_info "Updating $name from $local_ver to $latest_ver..."
                if update_tool "$name" "$method" "$npm_pkg" "$brew_formula" "$pipx_pkg" "$uv_pkg" "$install_url"; then
                    print_success "$name updated successfully"
                else
                    print_error "Failed to update $name"
                fi

                break
            fi
        done

        if [ "$found" = false ]; then
            print_error "Unknown tool: $target (use --list to see supported tools)"
        fi
    done
}

# Show help
show_help() {
    cat << EOF
kitup v$VERSION

A unified updater for AI coding assistants
Supports: Claude Code, OpenCode, Codex, Gemini CLI, Kimi CLI, Cline CLI, Qwen Code, Goose, Aider, Cursor CLI, Windsurf CLI, Tabby

Usage:
  kitup [options] [tool1] [tool2] ...
  kitup pin <tool> <version>        Pin a tool to specific version
  kitup unpin <tool>                 Remove version pin for a tool
  kitup list-pins                   List all pinned versions
  kitup config                      Create/edit configuration file

Options:
  -h, --help          Show this help message
  -v, --version       Show version information
  -l, --list          List all supported AI tools
  -s, --status        Show status of all tools
  -a, --all           Update all installed tools
  -i, --install       Install missing tools (use with --all or specific tools)
  -n, --dry-run       Show what would be done without making changes
  -f, --force         Force update even if already at latest version
  -b, --backup        Backup configuration before updating
      --restore       Restore configuration from last backup
      --exclude TOOLS  Comma-separated list of tools to exclude from updates
      --parallel N    Set number of parallel update jobs (default: 3)
      --no-parallel   Disable parallel updates
  --verbose           Enable verbose output

Examples:
  kitup --status              Check status of all tools
  kitup --all                 Update all installed tools
  kitup --all --install       Update all and install missing tools
  kitup claude codex          Update specific tools
  kitup --all --dry-run       Preview what would be updated
  kitup --all --parallel 5    Update with 5 parallel jobs
  kitup pin claude 0.2.45     Pin claude to version 0.2.45
  kitup unpin claude          Remove version pin for claude
  kitup list-pins             List all pinned versions
  kitup --exclude kimi,gemini --all  Update all except kimi and gemini

Environment Variables:
  GITHUB_TOKEN        GitHub API token (for higher rate limits)
  KITUP_SKIP_SELF_UPDATE_CHECK=1
                      Disable the once-per-use kitup version check
  KITUP_PARALLEL_JOBS=N
                      Number of parallel update jobs (default: 3)
  KITUP_ENABLE_PARALLEL=0
                      Disable parallel updates
  KITUP_VERSION_CACHE_TTL_SECONDS=N
                      Version cache TTL in seconds (default: 3600)
EOF
}

# Main function
main() {
    local args=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "kitup v$VERSION"
                exit 0
                ;;
            -l|--list)
                list_tools
                exit 0
                ;;
            -s|--status)
                show_status
                exit 0
                ;;
            -a|--all)
                UPDATE_ALL=true
                shift
                ;;
            -i|--install)
                INSTALL_MISSING=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -b|--backup)
                BACKUP_CONFIG=true
                shift
                ;;
            --restore)
                RESTORE_CONFIG=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --parallel)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            --no-parallel)
                PARALLEL_JOBS=1
                shift
                ;;
            --exclude)
                KITUP_EXCLUDE_TOOLS="$2"
                shift 2
                ;;
            -*)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    # Load user configuration
    load_config

    # Handle pin command
    if [ ${#args[@]} -gt 0 ] && [ "${args[0]}" = "pin" ]; then
        if [ ${#args[@]} -lt 3 ]; then
            print_error "Usage: kitup pin <tool> <version>"
            echo "Example: kitup pin claude 0.2.45"
            exit 1
        fi
        set_pinned_version "${args[1]}" "${args[2]}"
        exit 0
    fi

    # Handle unpin command
    if [ ${#args[@]} -gt 0 ] && [ "${args[0]}" = "unpin" ]; then
        if [ ${#args[@]} -lt 2 ]; then
            print_error "Usage: kitup unpin <tool>"
            echo "Example: kitup unpin claude"
            exit 1
        fi
        remove_pinned_version "${args[1]}"
        exit 0
    fi

    # Handle list-pins command
    if [ ${#args[@]} -gt 0 ] && [ "${args[0]}" = "list-pins" ]; then
        list_pinned_versions
        exit 0
    fi

    # Handle config command
    if [ ${#args[@]} -gt 0 ] && [ "${args[0]}" = "config" ]; then
        init_config
        print_info "Configuration file: $CONFIG_FILE_JSON"
        exit 0
    fi

    # Handle restore
    if [ "$RESTORE_CONFIG" = true ]; then
        if [ -f "$HOME/.config/kitup/last_backup" ]; then
            local backup_dir
            backup_dir=$(cat "$HOME/.config/kitup/last_backup")
            if [ -d "$backup_dir" ]; then
                print_info "Restoring configuration from $backup_dir..."
                cp -r "$backup_dir"/* "$HOME/" 2>/dev/null || true
                print_success "Configuration restored"
            else
                print_error "Backup directory not found: $backup_dir"
                exit 1
            fi
        else
            print_error "No backup found"
            exit 1
        fi
        exit 0
    fi

    notify_self_update

    # Show status if no arguments
    if [ ${#args[@]} -eq 0 ] && [ "$UPDATE_ALL" != true ]; then
        show_status
        exit 0
    fi

    # Update all or specific tools
    if [ "$UPDATE_ALL" = true ]; then
        update_all
    else
        update_specific "${args[@]}"
    fi
}

# Run main function
main "$@"
