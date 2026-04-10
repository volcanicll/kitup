#
# kitup
# A unified updater for AI coding assistants (Windows PowerShell version)
# Supports: Claude Code, OpenCode, Codex, Gemini CLI, Kimi CLI, Cline CLI, Qwen Code, Goose, Aider, Cursor CLI, Windsurf CLI, Tabby
#

$ErrorActionPreference = "Stop"

# Version
$script:VERSION = if ($env:VERSION) { $env:VERSION } else { "0.1.0" }

# Configuration
$script:DRY_RUN = $false
$script:FORCE = $false
$script:INSTALL_MISSING = $false
$script:BACKUP_CONFIG = $false
$script:VERBOSE = $false
$script:SELF_UPDATE_TTL_SECONDS = if ($env:KITUP_SELF_UPDATE_TTL_SECONDS) { [int]$env:KITUP_SELF_UPDATE_TTL_SECONDS } else { 86400 }
$script:SELF_UPDATE_CACHE_FILE = Join-Path $HOME ".config/kitup/self_update_check"

# Tool definitions
# Format: Name, Command, NpmPackage, BrewFormula, PipxPackage, UvPackage, GitHubRepo, InstallUrl, ChocoPackage, ScoopPackage
$script:TOOLS = @(
    @("claude", "claude", "@anthropic-ai/claude-code", $null, $null, $null, "anthropics/claude-code", "https://claude.ai/install.sh", $null, $null),
    @("opencode", "opencode", "opencode-ai", $null, $null, $null, "opencode-ai/opencode", "https://opencode.ai/install", "opencode", "opencode"),
    @("codex", "codex", "@openai/codex", $null, $null, $null, "openai/codex", "https://cli.openai.com/install.sh", "codex", $null),
    @("gemini", "gemini", "@google/gemini-cli", $null, $null, $null, "google-gemini/gemini-cli", $null, "gemini-cli", $null),
    @("kimi", "kimi", $null, $null, "kimi-cli", "kimi-cli", "MoonshotAI/kimi-cli", $null, $null, $null),
    @("cline", "cline", "cline", $null, $null, $null, "cline/cline", $null, $null, $null),
    @("qwen", "qwen", "@qwen-code/qwen-code", $null, $null, $null, "QwenLM/qwen-code", "https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen.sh", $null, $null),
    @("goose", "goose", $null, "block-goose-cli", $null, $null, "block/goose", "https://github.com/block/goose/releases/download/stable/download_cli.sh", $null, $null),
    @("aider", "aider", $null, "aider", "aider-chat", "aider-chat", "Aider-AI/aider", "https://aider.chat/install.sh", $null, $null),
    @("cursor", "cursor", $null, "cursor", $null, $null, "cursor-sh/cursor", $null, $null, $null),
    @("windsurf", "windsurf", $null, "windsurf", $null, $null, "codeium/windsurf", $null, $null, $null),
    @("tabby", "tabby", $null, "tabby", $null, $null, "TabbyML/tabby", $null, $null, $null)
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

function Get-CommandSource {
    param($Command)
    $resolved = Get-Command $Command -ErrorAction SilentlyContinue
    if ($resolved) { return $resolved.Source }
    return $null
}

function Get-NpmGlobalPrefix {
    if (!(Test-CommandExists npm)) { return $null }
    try {
        return (npm prefix -g 2>$null | Select-Object -First 1)
    } catch {
        return $null
    }
}

function Get-ChocoBinPath {
    if ($env:ChocolateyInstall) {
        return (Join-Path $env:ChocolateyInstall "bin")
    }
    return $null
}

function Get-ScoopShimsPath {
    $userProfile = if ($env:USERPROFILE) { $env:USERPROFILE } else { [Environment]::GetFolderPath("UserProfile") }
    $scoopPath = Join-Path $userProfile "scoop\shims"
    if (Test-Path $scoopPath) { return $scoopPath }
    return $null
}

function Test-StandalonePath {
    param($ToolPath)
    if (!$ToolPath) { return $false }
    return $ToolPath -match '\\\.local\\bin\\' -or $ToolPath -match '\\AppData\\Local\\bin\\' -or $ToolPath -match '\\Program Files\\'
}

function Invoke-ToolCapture {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )
    try {
        $output = & $FilePath @Arguments 2>$null
        return @($output)
    } catch {
        return @()
    }
}

function Get-PreferredPackageName {
    param([string[]]$Candidates)
    foreach ($candidate in $Candidates) {
        if ($candidate) { return $candidate }
    }
    return $null
}

function Test-ChocoPackageInstalled {
    param($Package)
    if (!$Package -or !(Test-CommandExists choco)) { return $false }
    $output = Invoke-ToolCapture -FilePath "choco" -Arguments @("list", "--local-only", "--exact", $Package, "--limit-output")
    return ($output | Select-String -Pattern "^$([regex]::Escape($Package))\|" -Quiet)
}

function Test-ScoopPackageInstalled {
    param($Package)
    if (!$Package -or !(Test-CommandExists scoop)) { return $false }
    $output = Invoke-ToolCapture -FilePath "scoop" -Arguments @("list", $Package)
    return ($output | Select-String -Pattern "^\s*$([regex]::Escape($Package))\s" -Quiet)
}

function Get-ChocoInstalledVersion {
    param($Package)
    if (!(Test-ChocoPackageInstalled $Package)) { return $null }
    $output = Invoke-ToolCapture -FilePath "choco" -Arguments @("list", "--local-only", "--exact", $Package, "--limit-output")
    $line = $output | Select-Object -First 1
    if ($line -match '^[^|]+\|(.+)$') { return Get-ParsedVersion $Matches[1] }
    return $null
}

function Get-ChocoLatestVersion {
    param($Package)
    if (!$Package -or !(Test-CommandExists choco)) { return $null }
    try {
        $output = Invoke-ToolCapture -FilePath "choco" -Arguments @("search", $Package, "--exact", "--limit-output")
        $line = $output | Select-Object -First 1
        if ($line -match '^[^|]+\|(.+)$') { return Get-ParsedVersion $Matches[1] }
    } catch {}
    return $null
}

function Get-ScoopInstalledVersion {
    param($Package)
    if (!(Test-ScoopPackageInstalled $Package)) { return $null }
    $output = Invoke-ToolCapture -FilePath "scoop" -Arguments @("list", $Package)
    foreach ($line in $output) {
        if ($line -match "^\s*$([regex]::Escape($Package))\s+([^\s]+)") {
            return Get-ParsedVersion $Matches[1]
        }
    }
    return $null
}

function Get-ScoopLatestVersion {
    param($Package)
    if (!$Package -or !(Test-CommandExists scoop)) { return $null }
    try {
        $output = Invoke-ToolCapture -FilePath "scoop" -Arguments @("info", $Package)
        foreach ($line in $output) {
            if ($line -match 'Updated by manifest:\s*([^\s]+)') { return Get-ParsedVersion $Matches[1] }
            if ($line -match 'Version:\s*([^\s]+)') { return Get-ParsedVersion $Matches[1] }
        }
    } catch {}
    return $null
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
    param($Command, $NpmPkg, $BrewFormula, $PipxPkg, $UvPkg, $ChocoPkg, $ScoopPkg)

    $toolPath = Get-CommandSource $Command
    if (!$toolPath) {
        return $null
    }

    $npmPrefix = Get-NpmGlobalPrefix
    $chocoBin = Get-ChocoBinPath
    $scoopShims = Get-ScoopShimsPath

    if ($NpmPkg -and $npmPrefix -and $toolPath.StartsWith((Join-Path $npmPrefix "bin"), [System.StringComparison]::OrdinalIgnoreCase)) {
        if ((Invoke-ToolCapture -FilePath "npm" -Arguments @("list", "-g", $NpmPkg, "--depth", "0")) -match [regex]::Escape($NpmPkg)) {
            return "npm"
        }
    }

    if ($ChocoPkg -and $chocoBin -and $toolPath.StartsWith($chocoBin, [System.StringComparison]::OrdinalIgnoreCase)) {
        if (Test-ChocoPackageInstalled $ChocoPkg) {
            return "choco"
        }
    }

    if ($ScoopPkg -and $scoopShims -and $toolPath.StartsWith($scoopShims, [System.StringComparison]::OrdinalIgnoreCase)) {
        if (Test-ScoopPackageInstalled $ScoopPkg) {
            return "scoop"
        }
    }

    # Check npm
    if ($NpmPkg -and (Test-CommandExists npm)) {
        $npmList = Invoke-ToolCapture -FilePath "npm" -Arguments @("list", "-g", $NpmPkg, "--depth", "0")
        if ($npmList -match $NpmPkg) {
            return "npm"
        }
    }

    if ($ChocoPkg -and (Test-ChocoPackageInstalled $ChocoPkg)) {
        return "choco"
    }

    if ($ScoopPkg -and (Test-ScoopPackageInstalled $ScoopPkg)) {
        return "scoop"
    }

    # Check pipx
    if ($PipxPkg -and (Test-CommandExists pipx)) {
        $pipxList = Invoke-ToolCapture -FilePath "pipx" -Arguments @("list")
        if ($pipxList -match $PipxPkg) {
            return "pipx"
        }
    }

    # Check uv
    if ($UvPkg -and (Test-CommandExists uv)) {
        $uvList = Invoke-ToolCapture -FilePath "uv" -Arguments @("tool", "list")
        if ($uvList -match $UvPkg) {
            return "uv"
        }
    }

    # Check if in Python Scripts directory (pip install)
    if ($toolPath -match "Python|Scripts|site-packages") {
        return "pip"
    }

    # Check standalone
    if (Test-StandalonePath $toolPath) {
        return "standalone"
    }

    return "unknown"
}

# Get latest version from npm
function Get-NpmLatestVersion {
    param($Package)
    if (!(Test-CommandExists npm)) { return $null }
    try {
        return Get-ParsedVersion (npm view $Package version 2>$null)
    } catch {
        return $null
    }
}

# Get latest version from GitHub releases
function Get-GitHubLatestVersion {
    param($Repo)
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -ErrorAction SilentlyContinue
        return Get-ParsedVersion $response.tag_name
    } catch {
        return $null
    }
}

# Get latest version from PyPI
function Get-PyPiLatestVersion {
    param($Package)
    try {
        $response = Invoke-RestMethod -Uri "https://pypi.org/pypi/$Package/json" -ErrorAction SilentlyContinue
        return Get-ParsedVersion $response.info.version
    } catch {
        return $null
    }
}

# Get latest version for a tool
function Get-LatestVersion {
    param($Method, $NpmPkg, $BrewFormula, $PipxPkg, $UvPkg, $GitHubRepo, $ChocoPkg, $ScoopPkg)

    switch ($Method) {
        "npm" { return Get-NpmLatestVersion $NpmPkg }
        "choco" { return Get-ChocoLatestVersion $ChocoPkg }
        "scoop" { return Get-ScoopLatestVersion $ScoopPkg }
        "pipx" { return Get-PyPiLatestVersion $PipxPkg }
        "uv" { return Get-PyPiLatestVersion $UvPkg }
        "pip" {
            $packageName = Get-PreferredPackageName @($PipxPkg, $UvPkg)
            if ($packageName) { return Get-PyPiLatestVersion $packageName }
            return $null
        }
        "standalone" {
            if ($GitHubRepo) { return Get-GitHubLatestVersion $GitHubRepo }
            return $null
        }
        default {
            if ($NpmPkg) {
                $npmLatest = Get-NpmLatestVersion $NpmPkg
                if ($npmLatest) { return $npmLatest }
            }
            if ($ChocoPkg) {
                $chocoLatest = Get-ChocoLatestVersion $ChocoPkg
                if ($chocoLatest) { return $chocoLatest }
            }
            if ($ScoopPkg) {
                $scoopLatest = Get-ScoopLatestVersion $ScoopPkg
                if ($scoopLatest) { return $scoopLatest }
            }
            if ($PipxPkg) {
                $pipxLatest = Get-PyPiLatestVersion $PipxPkg
                if ($pipxLatest) { return $pipxLatest }
            }
            if ($UvPkg) {
                $uvLatest = Get-PyPiLatestVersion $UvPkg
                if ($uvLatest) { return $uvLatest }
            }
            if ($GitHubRepo) {
                return Get-GitHubLatestVersion $GitHubRepo
            }
            return $null
        }
    }
}

function Test-VersionNewer {
    param($Candidate, $Current)

    $candidateBase = Get-ParsedVersion $Candidate
    $currentBase = Get-ParsedVersion $Current
    if (!$candidateBase -or !$currentBase) { return $false }

    try {
        return ([version]$candidateBase) -gt ([version]$currentBase)
    } catch {
        return $false
    }
}

function Get-CachedSelfUpdateVersion {
    if (!(Test-Path $script:SELF_UPDATE_CACHE_FILE)) { return $null }

    try {
        $lines = Get-Content $script:SELF_UPDATE_CACHE_FILE -ErrorAction Stop
        if ($lines.Count -lt 2) { return $null }

        $checkedAt = 0L
        if (!([long]::TryParse($lines[0], [ref]$checkedAt))) { return $null }

        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        if (($now - $checkedAt) -le $script:SELF_UPDATE_TTL_SECONDS) {
            return $lines[1]
        }
    } catch {}

    return $null
}

function Set-SelfUpdateCache {
    param($LatestVersion)

    $cacheDir = Split-Path -Parent $script:SELF_UPDATE_CACHE_FILE
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null

    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    @("$now", "$LatestVersion") | Set-Content $script:SELF_UPDATE_CACHE_FILE
}

function Get-KitupLatestVersion {
    $cachedVersion = Get-CachedSelfUpdateVersion
    if ($cachedVersion) { return $cachedVersion }

    $latestVersion = Get-GitHubLatestVersion "volcanicll/kitup"
    if ($latestVersion) {
        Set-SelfUpdateCache $latestVersion
    }
    return $latestVersion
}

function Show-SelfUpdateNotice {
    if ($env:KITUP_SKIP_SELF_UPDATE_CHECK -eq "1") { return }

    $latestVersion = Get-KitupLatestVersion
    if (!$latestVersion) { return }

    if (Test-VersionNewer $latestVersion $script:VERSION) {
        Write-Host ""
        Write-Warning "A newer kitup version is available: $latestVersion (current: $script:VERSION)"
        Write-Info "Upgrade with: irm https://raw.githubusercontent.com/volcanicll/kitup/main/packages/cli/install.ps1 | iex"
        Write-Host ""
    }
}

# Update a tool
function Update-Tool {
    param($Name, $Method, $NpmPkg, $BrewFormula, $PipxPkg, $UvPkg, $InstallUrl, $ChocoPkg, $ScoopPkg)

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
        "choco" {
            if ($ChocoPkg) {
                Write-Info "Updating $Name via Chocolatey..."
                choco upgrade $ChocoPkg -y
                return $?
            }
        }
        "scoop" {
            if ($ScoopPkg) {
                Write-Info "Updating $Name via Scoop..."
                scoop update $ScoopPkg
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
            $packageName = Get-PreferredPackageName @($PipxPkg, $UvPkg, $Name)
            if (!$packageName) { return $false }
            pip install --upgrade $packageName
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
            Write-Warning "No update method available for $Name"
            return $false
        }
    }
    return $false
}

# Install a tool
function Install-Tool {
    param($Name, $Command, $NpmPkg, $BrewFormula, $InstallUrl, $ChocoPkg, $ScoopPkg, $PipxPkg, $UvPkg)

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

    if ($ChocoPkg -and (Test-CommandExists choco)) {
        Write-Info "Installing $Name via Chocolatey..."
        choco install $ChocoPkg -y
        return $?
    }

    if ($ScoopPkg -and (Test-CommandExists scoop)) {
        Write-Info "Installing $Name via Scoop..."
        scoop install $ScoopPkg
        return $?
    }

    # Try pipx
    if ($PipxPkg -and (Test-CommandExists pipx)) {
        Write-Info "Installing $Name via pipx..."
        pipx install $PipxPkg
        return $?
    }

    if ($UvPkg -and (Test-CommandExists uv)) {
        Write-Info "Installing $Name via uv..."
        uv tool install $UvPkg
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
        "$env:USERPROFILE\.aider.conf.yml",
        "$env:USERPROFILE\.config\cursor",
        "$env:USERPROFILE\.config\windsurf",
        "$env:USERPROFILE\.config\tabby"
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
        $chocoPkg = $tool[8]
        $scoopPkg = $tool[9]

        $installed = "No"
        $method = "-"
        $localVer = "-"
        $latestVer = "-"

        if (Test-CommandExists $cmd) {
            $installed = "Yes"
            $method = Get-InstallMethod $cmd $npmPkg $brewFormula $pipxPkg $uvPkg $chocoPkg $scoopPkg
            $localVer = Get-LocalVersion $cmd
            if ($method -eq "choco" -and $chocoPkg) {
                $localVer = Get-ChocoInstalledVersion $chocoPkg
            } elseif ($method -eq "scoop" -and $scoopPkg) {
                $localVer = Get-ScoopInstalledVersion $scoopPkg
            }
            $latestVer = Get-LatestVersion $method $npmPkg $brewFormula $pipxPkg $uvPkg $githubRepo $chocoPkg $scoopPkg
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
        $chocoPkg = $tool[8]
        $scoopPkg = $tool[9]
        $installUrl = $tool[7]

        if (!(Test-CommandExists $cmd)) {
            if ($script:INSTALL_MISSING) {
                if (Install-Tool $name $cmd $npmPkg $brewFormula $installUrl $chocoPkg $scoopPkg $pipxPkg $uvPkg) {
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

        $method = Get-InstallMethod $cmd $npmPkg $brewFormula $pipxPkg $uvPkg $chocoPkg $scoopPkg
        $localVer = Get-LocalVersion $cmd
        if ($method -eq "choco" -and $chocoPkg) {
            $localVer = Get-ChocoInstalledVersion $chocoPkg
        } elseif ($method -eq "scoop" -and $scoopPkg) {
            $localVer = Get-ScoopInstalledVersion $scoopPkg
        }
        $latestVer = Get-LatestVersion $method $npmPkg $brewFormula $pipxPkg $uvPkg $githubRepo $chocoPkg $scoopPkg

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
        if (Update-Tool $name $method $npmPkg $brewFormula $pipxPkg $uvPkg $installUrl $chocoPkg $scoopPkg) {
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
                $chocoPkg = $tool[8]
                $scoopPkg = $tool[9]

                if (!(Test-CommandExists $cmd)) {
                    if ($script:INSTALL_MISSING) {
                        Install-Tool $name $cmd $npmPkg $brewFormula $installUrl $chocoPkg $scoopPkg $pipxPkg $uvPkg
                    } else {
                        Write-Error "$name is not installed (use --install to install)"
                    }
                    continue
                }

                $method = Get-InstallMethod $cmd $npmPkg $brewFormula $pipxPkg $uvPkg $chocoPkg $scoopPkg
                $localVer = Get-LocalVersion $cmd
                if ($method -eq "choco" -and $chocoPkg) {
                    $localVer = Get-ChocoInstalledVersion $chocoPkg
                } elseif ($method -eq "scoop" -and $scoopPkg) {
                    $localVer = Get-ScoopInstalledVersion $scoopPkg
                }
                $latestVer = Get-LatestVersion $method $npmPkg $brewFormula $pipxPkg $uvPkg $githubRepo $chocoPkg $scoopPkg

                if (!$latestVer) {
                    Write-Warning "Cannot check latest version for $name"
                    continue
                }

                if ($localVer -eq $latestVer -and !$script:FORCE) {
                    Write-Info "$name is already up to date ($localVer)"
                    continue
                }

                Write-Info "Updating $name from $localVer to $latestVer..."
                if (Update-Tool $name $method $npmPkg $brewFormula $pipxPkg $uvPkg $installUrl $chocoPkg $scoopPkg) {
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
Supports: Claude Code, OpenCode, Codex, Gemini CLI, Kimi CLI, Cline CLI, Qwen Code, Goose, Aider, Cursor CLI, Windsurf CLI, Tabby

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
  kitup --status                        Check status of all tools
  kitup --all                           Update all installed tools
  kitup --all --install                 Update all and install missing tools
  kitup claude codex                    Update specific tools
  kitup --all --dry-run                 Preview what would be updated

Environment Variables:
  GITHUB_TOKEN        GitHub API token (for higher rate limits)
  KITUP_SKIP_SELF_UPDATE_CHECK=1
                      Disable the once-per-use kitup version check
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

    Show-SelfUpdateNotice

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
