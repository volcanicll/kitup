#
# kitup
# A unified updater for AI coding assistants (Windows PowerShell version)
# Supports: Claude Code, OpenCode, Codex, Gemini CLI, Goose, Aider
#

$ErrorActionPreference = "Stop"

# Version
$script:VERSION = "0.0.1"

# Configuration
$script:DRY_RUN = $false
$script:FORCE = $false
$script:INSTALL_MISSING = $false
$script:BACKUP_CONFIG = $false
$script:VERBOSE = $false

# Tool definitions
# Format: Name, Command, NpmPackage, BrewFormula, PipxPackage, UvPackage, GitHubRepo, InstallUrl, ChocoPackage, ScoopPackage
$script:TOOLS = @(
    @("claude", "claude", "@anthropic-ai/claude-code", $null, $null, $null, "anthropics/claude-code", "https://claude.ai/install.sh", $null, $null),
    @("opencode", "opencode", "opencode-ai", $null, $null, $null, "opencode-ai/opencode", "https://opencode.ai/install", $null, $null),
    @("codex", "codex", "@openai/codex", $null, $null, $null, "openai/codex", "https://cli.openai.com/install.sh", $null, $null),
    @("gemini", "gemini", "@google/gemini-cli", $null, $null, $null, "google-gemini/gemini-cli", $null, $null, $null),
    @("goose", "goose", $null, "block-goose-cli", $null, $null, "block/goose", "https://github.com/block/goose/releases/download/stable/download_cli.sh", $null, $null),
    @("aider", "aider", $null, "aider", "aider-chat", "aider-chat", "Aider-AI/aider", "https://aider.chat/install.sh", $null, $null)
)

# Print functions
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Header { param($Message) Write-Host $Message -ForegroundColor Magenta -Bold }

# Check if command exists
function Test-CommandExists {
    param($Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

# Parse version string
function Get-ParsedVersion {
    param($VersionStr)
    if ($VersionStr -match '(\d+\.\d+\.\d+(?:[-\.]?[a-zA-Z0-9]+)?)') {
        return $Matches[1]
    }
    return $null
}

# Get local version of a tool
function Get-LocalVersion {
    param($Command)

    if (!(Test-CommandExists $Command)) {
        return $null
    }

    $versionStr = & $Command --version 2>$null
    if (!$versionStr) {
        $versionStr = & $Command -v 2>$null
    }
    return Get-ParsedVersion $versionStr
}

# Detect installation method
function Get-InstallMethod {
    param($Command, $NpmPkg, $BrewFormula, $PipxPkg, $UvPkg)

    $toolPath = (Get-Command $Command -ErrorAction SilentlyContinue).Source
    if (!$toolPath) {
        return $null
    }

    # Check npm
    if ($NpmPkg -and (Test-CommandExists npm)) {
        $npmList = npm list -g $NpmPkg 2>$null
        if ($npmList -match $NpmPkg) {
            return "npm"
        }
    }

    # Check pipx
    if ($PipxPkg -and (Test-CommandExists pipx)) {
        $pipxList = pipx list 2>$null
        if ($pipxList -match $PipxPkg) {
            return "pipx"
        }
    }

    # Check uv
    if ($UvPkg -and (Test-CommandExists uv)) {
        $uvList = uv tool list 2>$null
        if ($uvList -match $UvPkg) {
            return "uv"
        }
    }

    # Check if in Python Scripts directory (pip install)
    if ($toolPath -match "Python|Scripts|site-packages") {
        return "pip"
    }

    # Check standalone
    if ($toolPath -match "\.local|AppData|Program Files") {
        return "standalone"
    }

    return "unknown"
}

# Get latest version from npm
function Get-NpmLatestVersion {
    param($Package)
    if (!(Test-CommandExists npm)) { return $null }
    try {
        return npm view $Package version 2>$null
    } catch {
        return $null
    }
}

# Get latest version from GitHub releases
function Get-GitHubLatestVersion {
    param($Repo)
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -ErrorAction SilentlyContinue
        return $response.tag_name -replace '^v', ''
    } catch {
        return $null
    }
}

# Get latest version from PyPI
function Get-PyPiLatestVersion {
    param($Package)
    try {
        $response = Invoke-RestMethod -Uri "https://pypi.org/pypi/$Package/json" -ErrorAction SilentlyContinue
        return $response.info.version
    } catch {
        return $null
    }
}

# Get latest version for a tool
function Get-LatestVersion {
    param($Method, $NpmPkg, $BrewFormula, $PipxPkg, $UvPkg, $GitHubRepo)

    switch ($Method) {
        "npm" { return Get-NpmLatestVersion $NpmPkg }
        "pipx" { return Get-PyPiLatestVersion $PipxPkg }
        "uv" { return Get-PyPiLatestVersion $UvPkg }
        "pip" { return Get-PyPiLatestVersion ($PipxPkg -or $UvPkg) }
        default {
            if ($GitHubRepo) {
                return Get-GitHubLatestVersion $GitHubRepo
            }
            return $null
        }
    }
}

# Update a tool
function Update-Tool {
    param($Name, $Method, $NpmPkg, $BrewFormula, $PipxPkg, $UvPkg, $InstallUrl)

    if ($script:DRY_RUN) {
        Write-Info "[DRY RUN] Would update $Name using $Method"
        return $true
    }

    switch ($Method) {
        "npm" {
            if ($NpmPkg) {
                Write-Info "Updating $Name via npm..."
                npm update -g $NpmPkg
                return $?
            }
        }
        "pipx" {
            if ($PipxPkg) {
                Write-Info "Updating $Name via pipx..."
                pipx upgrade $PipxPkg
                return $?
            }
        }
        "uv" {
            if ($UvPkg) {
                Write-Info "Updating $Name via uv..."
                uv tool upgrade $UvPkg
                return $?
            }
        }
        "pip" {
            Write-Info "Updating $Name via pip..."
            pip install --upgrade ($PipxPkg -or $UvPkg -or $Name)
            return $?
        }
        default {
            if ($InstallUrl) {
                Write-Info "Updating $Name via official installer..."
                try {
                    if ($InstallUrl -match '\.ps1$') {
                        Invoke-Expression (Invoke-WebRequest -Uri $InstallUrl -UseBasicParsing).Content
                    } else {
                        # For bash scripts, use WSL or Git Bash
                        if (Test-CommandExists wsl) {
                            wsl bash -c "curl -fsSL '$InstallUrl' | bash"
                        } elseif (Test-CommandExists bash) {
                            bash -c "curl -fsSL '$InstallUrl' | bash"
                        } else {
                            Write-Error "Cannot run bash installer on Windows without WSL or Git Bash"
                            return $false
                        }
                    }
                    return $true
                } catch {
                    return $false
                }
            }
        }
    }
    return $false
}

# Install a tool
function Install-Tool {
    param($Name, $Command, $NpmPkg, $BrewFormula, $InstallUrl, $ChocoPkg, $ScoopPkg)

    if ($script:DRY_RUN) {
        Write-Info "[DRY RUN] Would install $Name"
        return $true
    }

    Write-Info "Installing $Name..."

    # Try npm first
    if ($NpmPkg -and (Test-CommandExists npm)) {
        Write-Info "Installing $Name via npm..."
        npm install -g $NpmPkg
        return $?
    }

    # Try pipx
    if (Test-CommandExists pipx) {
        Write-Info "Installing $Name via pipx..."
        pipx install ($NpmPkg -or $Name)
        return $?
    }

    # Try official installer
    if ($InstallUrl) {
        Write-Info "Installing $Name via official installer..."
        try {
            if (Test-CommandExists wsl) {
                wsl bash -c "curl -fsSL '$InstallUrl' | bash"
            } elseif (Test-CommandExists bash) {
                bash -c "curl -fsSL '$InstallUrl' | bash"
            } else {
                Write-Error "Cannot run bash installer. Please install WSL or Git Bash."
                return $false
            }
            return $true
        } catch {
            return $false
        }
    }

    Write-Error "No suitable installation method found for $Name"
    return $false
}

# Backup configurations
function Backup-Configs {
    if ($script:DRY_RUN) {
        Write-Info "[DRY RUN] Would backup configs"
        return
    }

    $backupDir = "$env:USERPROFILE\.config\kitup\backups\$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    $configs = @(
        "$env:USERPROFILE\.claude",
        "$env:USERPROFILE\.config\opencode",
        "$env:USERPROFILE\.config\codex",
        "$env:USERPROFILE\.config\gemini",
        "$env:USERPROFILE\.config\goose",
        "$env:USERPROFILE\.aider.conf.yml"
    )

    foreach ($config in $configs) {
        if (Test-Path $config) {
            Copy-Item -Path $config -Destination $backupDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Success "Configuration backed up to $backupDir"
    $backupDir | Out-File "$env:USERPROFILE\.config\kitup\last_backup"
}

# Show status
function Show-Status {
    Write-Header "AI Tools Status"
    Write-Host ""
    Write-Host "{0,-12} {1,-10} {2,-12} {3,-15} {4,-15}" -f "Tool", "Installed", "Method", "Local Version", "Latest Version"
    Write-Host "{0,-12} {1,-10} {2,-12} {3,-15} {4,-15}" -f "----", "---------", "------", "-------------", "--------------"

    foreach ($tool in $script:TOOLS) {
        $name = $tool[0]
        $cmd = $tool[1]
        $npmPkg = $tool[2]
        $brewFormula = $tool[3]
        $pipxPkg = $tool[4]
        $uvPkg = $tool[5]
        $githubRepo = $tool[6]

        $installed = "No"
        $method = "-"
        $localVer = "-"
        $latestVer = "-"

        if (Test-CommandExists $cmd) {
            $installed = "Yes"
            $method = Get-InstallMethod $cmd $npmPkg $brewFormula $pipxPkg $uvPkg
            $localVer = Get-LocalVersion $cmd
            $latestVer = Get-LatestVersion $method $npmPkg $brewFormula $pipxPkg $uvPkg $githubRepo
        }

        Write-Host "{0,-12} {1,-10} {2,-12} {3,-15} {4,-15}" -f $name, $installed, $method, $localVer, $latestVer
    }
    Write-Host ""
}

# List tools
function List-Tools {
    Write-Header "Supported AI Tools"
    Write-Host ""

    foreach ($tool in $script:TOOLS) {
        $name = $tool[0]
        $cmd = $tool[1]
        $npmPkg = $tool[2]
        $brewFormula = $tool[3]
        $pipxPkg = $tool[4]
        $uvPkg = $tool[5]
        $githubRepo = $tool[6]

        Write-Host $name -Bold
        Write-Host "  Command: $cmd"
        if ($npmPkg) { Write-Host "  npm: $npmPkg" }
        if ($brewFormula) { Write-Host "  Homebrew: $brewFormula" }
        if ($pipxPkg) { Write-Host "  pipx: $pipxPkg" }
        if ($uvPkg) { Write-Host "  uv: $uvPkg" }
        if ($githubRepo) { Write-Host "  GitHub: $githubRepo" }
        Write-Host ""
    }
}

# Update all tools
function Update-All {
    $updated = 0
    $failed = 0
    $skipped = 0

    Write-Header "Updating AI Tools"
    Write-Host ""

    if ($script:BACKUP_CONFIG) {
        Backup-Configs
    }

    foreach ($tool in $script:TOOLS) {
        $name = $tool[0]
        $cmd = $tool[1]
        $npmPkg = $tool[2]
        $brewFormula = $tool[3]
        $pipxPkg = $tool[4]
        $uvPkg = $tool[5]
        $githubRepo = $tool[6]
        $installUrl = $tool[7]

        if (!(Test-CommandExists $cmd)) {
            if ($script:INSTALL_MISSING) {
                if (Install-Tool $name $cmd $npmPkg $brewFormula $installUrl) {
                    $updated++
                } else {
                    $failed++
                }
            } else {
                Write-Info "Skipping $name (not installed)"
                $skipped++
            }
            continue
        }

        $method = Get-InstallMethod $cmd $npmPkg $brewFormula $pipxPkg $uvPkg
        $localVer = Get-LocalVersion $cmd
        $latestVer = Get-LatestVersion $method $npmPkg $brewFormula $pipxPkg $uvPkg $githubRepo

        if (!$latestVer) {
            Write-Warning "Cannot check latest version for $name"
            $skipped++
            continue
        }

        if ($localVer -eq $latestVer -and !$script:FORCE) {
            Write-Info "$name is already up to date ($localVer)"
            $skipped++
            continue
        }

        Write-Info "Updating $name from $localVer to $latestVer..."
        if (Update-Tool $name $method $npmPkg $brewFormula $pipxPkg $uvPkg $installUrl) {
            Write-Success "$name updated successfully"
            $updated++
        } else {
            Write-Error "Failed to update $name"
            $failed++
        }
    }

    Write-Host ""
    Write-Header "Update Summary"
    Write-Host "  Updated: $updated"
    Write-Host "  Failed: $failed"
    Write-Host "  Skipped: $skipped"
}

# Update specific tools
function Update-Specific {
    param($Targets)

    if ($script:BACKUP_CONFIG) {
        Backup-Configs
    }

    foreach ($target in $Targets) {
        $found = $false

        foreach ($tool in $script:TOOLS) {
            $name = $tool[0]

            if ($name -eq $target) {
                $found = $true
                $cmd = $tool[1]
                $npmPkg = $tool[2]
                $brewFormula = $tool[3]
                $pipxPkg = $tool[4]
                $uvPkg = $tool[5]
                $githubRepo = $tool[6]
                $installUrl = $tool[7]

                if (!(Test-CommandExists $cmd)) {
                    if ($script:INSTALL_MISSING) {
                        Install-Tool $name $cmd $npmPkg $brewFormula $installUrl
                    } else {
                        Write-Error "$name is not installed (use --install to install)"
                    }
                    continue
                }

                $method = Get-InstallMethod $cmd $npmPkg $brewFormula $pipxPkg $uvPkg
                $localVer = Get-LocalVersion $cmd
                $latestVer = Get-LatestVersion $method $npmPkg $brewFormula $pipxPkg $uvPkg $githubRepo

                if (!$latestVer) {
                    Write-Warning "Cannot check latest version for $name"
                    continue
                }

                if ($localVer -eq $latestVer -and !$script:FORCE) {
                    Write-Info "$name is already up to date ($localVer)"
                    continue
                }

                Write-Info "Updating $name from $localVer to $latestVer..."
                if (Update-Tool $name $method $npmPkg $brewFormula $pipxPkg $uvPkg $installUrl) {
                    Write-Success "$name updated successfully"
                } else {
                    Write-Error "Failed to update $name"
                }

                break
            }
        }

        if (!$found) {
            Write-Error "Unknown tool: $target (use --list to see supported tools)"
        }
    }
}

# Show help
function Show-Help {
    Write-Host @"
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
  update-ai-tools --status              Check status of all tools
  update-ai-tools --all                 Update all installed tools
  update-ai-tools --all --install       Update all and install missing tools
  update-ai-tools claude codex          Update specific tools
  update-ai-tools --all --dry-run       Preview what would be updated

Environment Variables:
  GITHUB_TOKEN        GitHub API token (for higher rate limits)
"@
}

# Main function
function Main {
    param($Arguments)

    $argsList = @($Arguments)
    $positionalArgs = @()

    for ($i = 0; $i -lt $argsList.Count; $i++) {
        $arg = $argsList[$i]
        switch ($arg) {
            { $_ -in "-h", "--help" } { Show-Help; exit 0 }
            { $_ -in "-v", "--version" } { Write-Host "kitup v$VERSION"; exit 0 }
            { $_ -in "-l", "--list" } { List-Tools; exit 0 }
            { $_ -in "-s", "--status" } { Show-Status; exit 0 }
            "-a" { $script:UPDATE_ALL = $true }
            "--all" { $script:UPDATE_ALL = $true }
            "-i" { $script:INSTALL_MISSING = $true }
            "--install" { $script:INSTALL_MISSING = $true }
            "-n" { $script:DRY_RUN = $true }
            "--dry-run" { $script:DRY_RUN = $true }
            "-f" { $script:FORCE = $true }
            "--force" { $script:FORCE = $true }
            "-b" { $script:BACKUP_CONFIG = $true }
            "--backup" { $script:BACKUP_CONFIG = $true }
            "--restore" {
                $lastBackupFile = "$env:USERPROFILE\.config\kitup\last_backup"
                if (Test-Path $lastBackupFile) {
                    $backupDir = Get-Content $lastBackupFile
                    if (Test-Path $backupDir) {
                        Write-Info "Restoring configuration from $backupDir..."
                        Copy-Item -Path "$backupDir\*" -Destination $env:USERPROFILE -Recurse -Force
                        Write-Success "Configuration restored"
                    } else {
                        Write-Error "Backup directory not found: $backupDir"
                        exit 1
                    }
                } else {
                    Write-Error "No backup found"
                    exit 1
                }
                exit 0
            }
            "--verbose" { $script:VERBOSE = $true }
            default {
                if ($arg -notlike "-*") {
                    $positionalArgs += $arg
                } else {
                    Write-Error "Unknown option: $arg"
                    Write-Host "Use --help for usage information"
                    exit 1
                }
            }
        }
    }

    # Show status if no arguments
    if ($positionalArgs.Count -eq 0 -and !$script:UPDATE_ALL) {
        Show-Status
        exit 0
    }

    # Update all or specific tools
    if ($script:UPDATE_ALL) {
        Update-All
    } else {
        Update-Specific $positionalArgs
    }
}

# Run main function
Main -Arguments $args
