#!/bin/bash
#
# kitup
# A unified updater for AI coding assistants
# Supports: Claude Code, OpenCode, Codex, Gemini CLI, Goose, Aider
#

set -e

# Version
VERSION="0.0.1"

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

# Tool definitions
# Format: name|command|npm_package|brew_formula|pipx_package|uv_package|github_repo|install_url
declare -a TOOLS=(
    "claude|claude|@anthropic-ai/claude-code|anthropic-ai/tap/claude-code|||anthropics/claude-code|https://claude.ai/install.sh"
    "opencode|opencode|opencode-ai|opencode|||opencode-ai/opencode|https://opencode.ai/install"
    "codex|codex|@openai/codex|codex|||openai/codex|https://cli.openai.com/install.sh"
    "gemini|gemini|@google/gemini-cli|gemini-cli|||google-gemini/gemini-cli|"
    "goose|goose||block-goose-cli|||block/goose|https://github.com/block/goose/releases/download/stable/download_cli.sh"
    "aider|aider||aider|aider-chat|aider-chat|Aider-AI/aider|https://aider.chat/install.sh"
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

# Detect installation method for a tool
detect_install_method() {
    local cmd="$1"
    local npm_pkg="$2"
    local brew_formula="$3"
    local pipx_pkg="$4"
    local uv_pkg="$5"

    local tool_path
    tool_path=$(which "$cmd" 2>/dev/null || echo "")

    if [ -z "$tool_path" ]; then
        echo ""
        return
    fi

    # Check if it's a symlink
    if [ -L "$tool_path" ]; then
        local link_target
        link_target=$(readlink "$tool_path" 2>/dev/null || echo "")

        # Check for Homebrew
        if [[ "$link_target" == *"/homebrew/"* ]] || [[ "$link_target" == *"/Cellar/"* ]] || [[ "$tool_path" == *"/homebrew/"* ]]; then
            if [ -n "$brew_formula" ]; then
                echo "brew"
                return
            fi
        fi

        # Check for npm
        if [[ "$link_target" == *"/npm/"* ]] || [[ "$link_target" == *"/.npm/"* ]] || [[ "$link_target" == *"/node_modules/"* ]]; then
            if [ -n "$npm_pkg" ]; then
                echo "npm"
                return
            fi
        fi
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
        if brew list "$brew_formula" > /dev/null 2>&1; then
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
    if [[ "$tool_path" == *".local/bin"* ]] || [[ "$tool_path" == *"/usr/local/bin"* ]]; then
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
        npm view "$pkg" version 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Get latest version from Homebrew
get_brew_latest_version() {
    local formula="$1"
    if command_exists brew && command_exists jq; then
        brew info "$formula" --json 2>/dev/null | jq -r '.[0].versions.stable' 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Get latest version from GitHub releases
get_github_latest_version() {
    local repo="$1"
    if command_exists curl && command_exists jq; then
        curl -s "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null | jq -r '.tag_name' 2>/dev/null | sed 's/^v//' || echo ""
    else
        echo ""
    fi
}

# Get latest version from PyPI
get_pypi_latest_version() {
    local pkg="$1"
    if command_exists curl && command_exists jq; then
        curl -s "https://pypi.org/pypi/$pkg/json" 2>/dev/null | jq -r '.info.version' 2>/dev/null || echo ""
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
    local latest_ver=""

    # Try npm first (usually most up-to-date for npm packages)
    if [ -n "$npm_pkg" ]; then
        latest_ver=$(get_npm_latest_version "$npm_pkg")
        [ -n "$latest_ver" ] && { echo "$latest_ver"; return; }
    fi

    # Try PyPI for pipx/uv packages
    if [ -n "$pipx_pkg" ]; then
        latest_ver=$(get_pypi_latest_version "$pipx_pkg")
        [ -n "$latest_ver" ] && { echo "$latest_ver"; return; }
    fi
    if [ -n "$uv_pkg" ]; then
        latest_ver=$(get_pypi_latest_version "$uv_pkg")
        [ -n "$latest_ver" ] && { echo "$latest_ver"; return; }
    fi

    # Try Homebrew
    if [ -n "$brew_formula" ]; then
        latest_ver=$(get_brew_latest_version "$brew_formula")
        [ -n "$latest_ver" ] && { echo "$latest_ver"; return; }
    fi

    # Try GitHub releases as fallback
    if [ -n "$github_repo" ]; then
        latest_ver=$(get_github_latest_version "$github_repo")
        [ -n "$latest_ver" ] && { echo "$latest_ver"; return; }
    fi

    echo ""
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
                brew upgrade "$brew_formula"
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
    local install_url="$5"

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would install $name"
        return 0
    fi

    print_info "Installing $name..."

    # Try different installation methods in order of preference
    if [ -n "$brew_formula" ] && command_exists brew; then
        print_info "Installing $name via Homebrew..."
        brew install "$brew_formula"
    elif [ -n "$npm_pkg" ] && command_exists npm; then
        print_info "Installing $name via npm..."
        npm install -g "$npm_pkg"
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
        fi

        printf "%-12s %-10s %-12s %-15s %-15s\n" "$name" "$installed" "$method" "$local_ver" "$latest_ver"
    done

    printf "\n"
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

    for tool_def in "${TOOLS[@]}"; do
        IFS='|' read -r name cmd npm_pkg brew_formula pipx_pkg uv_pkg github_repo install_url <<< "$tool_def"

        if ! command_exists "$cmd"; then
            if [ "$INSTALL_MISSING" = true ]; then
                if install_tool "$name" "$cmd" "$npm_pkg" "$brew_formula" "$install_url"; then
                    ((updated++))
                else
                    ((failed++))
                fi
            else
                print_info "Skipping $name (not installed)"
                ((skipped++))
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
            ((skipped++))
            continue
        fi

        if [ "$local_ver" = "$latest_ver" ] && [ "$FORCE" = false ]; then
            print_info "$name is already up to date ($local_ver)"
            ((skipped++))
            continue
        fi

        print_info "Updating $name from $local_ver to $latest_ver..."
        if update_tool "$name" "$method" "$npm_pkg" "$brew_formula" "$pipx_pkg" "$uv_pkg" "$install_url"; then
            print_success "$name updated successfully"
            ((updated++))
        else
            print_error "Failed to update $name"
            ((failed++))
        fi
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
                        install_tool "$name" "$cmd" "$npm_pkg" "$brew_formula" "$install_url"
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
Supports: Claude Code, OpenCode, Codex, Gemini CLI, Goose, Aider

Usage:
  kitup [options] [tool1] [tool2] ...

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
  --verbose           Enable verbose output

Examples:
  kitup --status              Check status of all tools
  kitup --all                 Update all installed tools
  kitup --all --install       Update all and install missing tools
  kitup claude codex          Update specific tools
  kitup --all --dry-run       Preview what would be updated

Environment Variables:
  GITHUB_TOKEN        GitHub API token (for higher rate limits)
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

    # Handle restore
    if [ "$RESTORE_CONFIG" = true ]; then
        if [ -f "$HOME/.config/kitup/last_backup" ]; then
            local backup_dir
            backup_dir=$(cat "$HOME/.config/update-ai-tools/last_backup")
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
