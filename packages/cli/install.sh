#!/bin/bash
#
# kitup - Installation Script
# One-click installer for the AI coding tools updater
# Usage: curl -fsSL https://raw.githubusercontent.com/volcanicll/kitup/main/packages/cli/install.sh | bash
#

set -e

# Version - should match kitup.sh
INSTALLER_VERSION="0.0.13"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_OWNER="${REPO_OWNER:-volcanicll}"
REPO_NAME="${REPO_NAME:-kitup}"
VERSION="${VERSION:-main}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
ENTRY_NAME="kitup"
SHELL_SCRIPT_NAME="kitup.sh"

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

# Detect platform
detect_platform() {
    local os
    local arch

    case "$(uname -s)" in
        Linux*)     os="linux";;
        Darwin*)    os="macos";;
        CYGWIN*|MINGW*|MSYS*) os="windows";;
        *)          os="unknown";;
    esac

    case "$(uname -m)" in
        x86_64|amd64)  arch="x64";;
        arm64|aarch64) arch="arm64";;
        i386|i686)     arch="x86";;
        *)             arch="unknown";;
    esac

    echo "${os}-${arch}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect shell profile file
detect_shell_profile() {
    local shell_name="${SHELL##*/}"
    case "$shell_name" in
        bash)
            if [ -f "$HOME/.bashrc" ]; then
                echo "$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                echo "$HOME/.bash_profile"
            fi
            ;;
        zsh)
            echo "$HOME/.zshrc"
            ;;
        fish)
            echo "$HOME/.config/fish/config.fish"
            ;;
        *)
            if [ -f "$HOME/.profile" ]; then
                echo "$HOME/.profile"
            fi
            ;;
    esac
}

# Add directory to PATH
add_to_path() {
    local dir="$1"
    local profile_file

    # Check if already in PATH
    if [[ ":$PATH:" == *":$dir:"* ]]; then
        return 0
    fi

    profile_file=$(detect_shell_profile)

    if [ -n "$profile_file" ]; then
        echo "" >> "$profile_file"
        echo "# Added by kitup installer" >> "$profile_file"
        echo "export PATH=\"$dir:\$PATH\"" >> "$profile_file"
        print_info "Added $dir to PATH in $profile_file"
        print_info "Please run 'source $profile_file' or restart your terminal to apply changes"
    else
        print_warning "Could not detect shell profile file"
        print_info "Please manually add $dir to your PATH"
    fi
}

# Download file with curl or wget
download_file() {
    local url="$1"
    local output="$2"

    if command_exists curl; then
        curl -fsSL "$url" -o "$output"
    elif command_exists wget; then
        wget -q "$url" -O "$output"
    else
        print_error "Neither curl nor wget is installed"
        exit 1
    fi
}

# Main installation function
install() {
    print_info "AI Tools Updater Installer"
    print_info "=========================="
    echo ""

    # Detect platform
    PLATFORM=$(detect_platform)
    print_info "Detected platform: $PLATFORM"

    # Check for Windows
    if [[ "$PLATFORM" == *"windows"* ]]; then
        print_error "Windows detected. Please use PowerShell installer instead:"
        print_info "irm https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$VERSION/install.ps1 | iex"
        exit 1
    fi

    # Create install directory
    if [ ! -d "$INSTALL_DIR" ]; then
        print_info "Creating directory: $INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
    fi

    # Check if directory is writable
    if [ ! -w "$INSTALL_DIR" ]; then
        print_error "Cannot write to $INSTALL_DIR"
        print_info "Try running with sudo or set INSTALL_DIR to a writable directory"
        exit 1
    fi

    # Download the entrypoint, shell script, and library files
    local base_url="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$VERSION/packages/cli"
    local entry_path="$INSTALL_DIR/$ENTRY_NAME"
    local script_path="$INSTALL_DIR/$SHELL_SCRIPT_NAME"
    local lib_config_path="$INSTALL_DIR/lib-config.sh"
    local lib_pin_path="$INSTALL_DIR/lib-pin.sh"

    print_info "Downloading kitup..."
    print_info "Base URL: $base_url"

    # Download main files
    if ! download_file "$base_url/$ENTRY_NAME" "$entry_path" || \
       ! download_file "$base_url/$SHELL_SCRIPT_NAME" "$script_path" || \
       ! download_file "$base_url/lib-config.sh" "$lib_config_path" || \
       ! download_file "$base_url/lib-pin.sh" "$lib_pin_path"; then
        print_error "Failed to download kitup files"
        print_info "Please check your internet connection and try again"
        exit 1
    fi

    chmod +x "$entry_path"
    chmod +x "$script_path"
    chmod +x "$lib_config_path"
    chmod +x "$lib_pin_path"
    print_success "Downloaded $ENTRY_NAME to $entry_path"
    print_success "Downloaded $SHELL_SCRIPT_NAME to $script_path"
    print_success "Downloaded lib-config.sh to $lib_config_path"
    print_success "Downloaded lib-pin.sh to $lib_pin_path"

    # Add to PATH if needed
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        print_info "Adding $INSTALL_DIR to PATH..."
        add_to_path "$INSTALL_DIR"
    fi

    echo ""
    print_success "Installation complete!"
    echo ""
    print_info "Usage:"
    echo "  kitup --help       Show help information"
    echo "  kitup --status     Check installed AI tools status"
    echo "  kitup --all        Update all installed AI tools"
    echo ""
    print_info "To get started, run: kitup --status"
}

# Uninstall function
uninstall() {
    print_info "Uninstalling kitup..."

    local entry_path="$INSTALL_DIR/$ENTRY_NAME"
    local script_path="$INSTALL_DIR/$SHELL_SCRIPT_NAME"
    local lib_config_path="$INSTALL_DIR/lib-config.sh"
    local lib_pin_path="$INSTALL_DIR/lib-pin.sh"

    if [ -f "$entry_path" ]; then
        rm -f "$entry_path"
        print_success "Removed $entry_path"
    fi

    if [ -f "$script_path" ]; then
        rm -f "$script_path"
        print_success "Removed $script_path"
    fi

    if [ -f "$lib_config_path" ]; then
        rm -f "$lib_config_path"
        print_success "Removed $lib_config_path"
    fi

    if [ -f "$lib_pin_path" ]; then
        rm -f "$lib_pin_path"
        print_success "Removed $lib_pin_path"
    fi

    print_success "Uninstallation complete!"
}

# Show help
show_help() {
    echo "kitup - Installer"
    echo ""
    echo "Usage:"
    echo "  curl -fsSL https://.../install.sh | bash                   # Install"
    echo "  curl -fsSL https://.../install.sh | bash -s -- --uninstall  # Uninstall"
    echo ""
    echo "Environment variables:"
    echo "  REPO_OWNER    GitHub repository owner (default: yourusername)"
    echo "  REPO_NAME     GitHub repository name (default: kitup)"
    echo "  VERSION       Version to install (default: main)"
    echo "  INSTALL_DIR   Installation directory (default: \$HOME/.local/bin)"
    echo ""
    echo "Options:"
    echo "  --help        Show this help message"
    echo "  --uninstall   Uninstall kitup"
    echo "  --version     Show installer version"
}

# Parse arguments
for arg in "$@"; do
    case $arg in
        --help|-h)
            show_help
            exit 0
            ;;
        --uninstall)
            uninstall
            exit 0
            ;;
        --version|-v)
            echo "kitup Installer v$INSTALLER_VERSION"
            exit 0
            ;;
    esac
done

# Run installation
install
