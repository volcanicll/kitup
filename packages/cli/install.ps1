#
# kitup - Windows Installation Script
# One-click installer for the AI coding tools updater
# Usage: irm https://raw.githubusercontent.com/volcanicll/kitup/main/install.ps1 | iex
#

$ErrorActionPreference = "Stop"

# Version - should match kitup.ps1
$script:INSTALLER_VERSION = "0.0.1"

# Configuration
$RepoOwner = $env:REPO_OWNER -or "volcanicll"
$RepoName = $env:REPO_NAME -or "kitup"
$Version = $env:VERSION -or "main"
$InstallDir = $env:INSTALL_DIR -or "$env:LOCALAPPDATA\kitup"

# Colors for output (if supported)
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

# Detect platform
function Get-Platform {
    $os = "windows"
    $arch = switch ([System.Environment]::Is64BitOperatingSystem) {
        $true { "x64" }
        $false { "x86" }
    }
    # Check for ARM64
    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
        $arch = "arm64"
    }
    return "$os-$arch"
}

# Download file
function Download-File {
    param($Url, $OutputPath)
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
        $ProgressPreference = 'Continue'
        return $true
    } catch {
        return $false
    }
}

# Add to PATH
function Add-ToPath {
    param($Directory)

    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

    if ($currentPath -notlike "*$Directory*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$Directory", "User")
        Write-Info "Added $Directory to PATH"
        Write-Info "Please restart your terminal or run 'refreshenv' to apply changes"
    }
}

# Create wrapper script
function Create-Wrapper {
    param($ScriptPath, $WrapperPath)

    $wrapperContent = @"
@echo off
powershell -ExecutionPolicy Bypass -File "$ScriptPath" %*
"@

    Set-Content -Path $WrapperPath -Value $wrapperContent -Encoding ASCII
}

# Main installation function
function Install-Updater {
    Write-Info "AI Tools Updater Installer"
    Write-Info "=========================="
    Write-Host ""

    # Detect platform
    $platform = Get-Platform
    Write-Info "Detected platform: $platform"

    # Create install directory
    if (!(Test-Path $InstallDir)) {
        Write-Info "Creating directory: $InstallDir"
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }

    # Download the main script
    $scriptUrl = "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Version/kitup.ps1"
    $scriptPath = Join-Path $InstallDir "kitup.ps1"
    $wrapperPath = Join-Path $InstallDir "kitup.bat"

    Write-Info "Downloading kitup..."
    Write-Info "URL: $scriptUrl"

    if (!(Download-File -Url $scriptUrl -OutputPath $scriptPath)) {
        Write-Error "Failed to download script"
        Write-Info "Please check your internet connection and try again"
        exit 1
    }

    Write-Success "Downloaded kitup.ps1 to $scriptPath"

    # Create wrapper script
    Create-Wrapper -ScriptPath $scriptPath -WrapperPath $wrapperPath
    Write-Success "Created wrapper script: $wrapperPath"

    # Add to PATH
    Add-ToPath -Directory $InstallDir

    Write-Host ""
    Write-Success "Installation complete!"
    Write-Host ""
    Write-Info "Usage:"
    Write-Host "  kitup --help       Show help information"
    Write-Host "  kitup --status     Check installed AI tools status"
    Write-Host "  kitup --all        Update all installed AI tools"
    Write-Host ""
    Write-Info "To get started, run: kitup --status"
}

# Uninstall function
function Uninstall-Updater {
    Write-Info "Uninstalling kitup..."

    $scriptPath = Join-Path $InstallDir "kitup.ps1"
    $wrapperPath = Join-Path $InstallDir "kitup.bat"

    if (Test-Path $wrapperPath) {
        Remove-Item $wrapperPath -Force
        Write-Success "Removed $wrapperPath"
    }

    if (Test-Path $scriptPath) {
        Remove-Item $scriptPath -Force
        Write-Success "Removed $scriptPath"
    }

    # Remove from PATH
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -like "*$InstallDir*") {
        $newPath = ($currentPath -split ';' | Where-Object { $_ -ne $InstallDir }) -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Success "Removed $InstallDir from PATH"
    }

    Write-Success "Uninstallation complete!"
}

# Show help
function Show-Help {
    Write-Host "kitup - Installer"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  irm https://.../install.ps1 | iex              # Install"
    Write-Host "  irm https://.../install.ps1 | iex -Args @('--uninstall')  # Uninstall"
    Write-Host ""
    Write-Host "Environment variables:"
    Write-Host "  REPO_OWNER    GitHub repository owner (default: yourusername)"
    Write-Host "  REPO_NAME     GitHub repository name (default: kitup)"
    Write-Host "  VERSION       Version to install (default: main)"
    Write-Host "  INSTALL_DIR   Installation directory (default: %LOCALAPPDATA%\kitup)"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  --help        Show this help message"
    Write-Host "  --uninstall   Uninstall kitup"
    Write-Host "  --version     Show installer version"
}

# Parse arguments
if ($args -contains "--help" -or $args -contains "-h") {
    Show-Help
    exit 0
}

if ($args -contains "--uninstall") {
    Uninstall-Updater
    exit 0
}

if ($args -contains "--version" -or $args -contains "-v") {
    Write-Host "kitup Installer v$INSTALLER_VERSION"
    exit 0
}

# Run installation
Install-Updater
