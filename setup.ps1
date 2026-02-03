<#
.SYNOPSIS
    Antigravity Optimizer Setup Script

.DESCRIPTION
    Interactive onboarding for the Antigravity Optimizer.
    Installs 600+ AI skills for use with Codex CLI and Antigravity IDE.
    
    Modes:
    - Essentials: Installs skills, removes docs (recommended)
    - Full: Keeps all files
    - Update: Quick skill update only

.PARAMETER Mode
    Installation mode: 'essentials', 'full', or 'update'
    Skip the interactive menu by specifying this.

.PARAMETER Silent
    Run without prompts (for automation/CI).
    Defaults to 'essentials' mode if -Mode not specified.

.PARAMETER SkipGlobalRoot
    Skip the prompt to set ANTIGRAVITY_OPTIMIZER_ROOT environment variable.

.PARAMETER Force
    Force overwrite of existing installations.

.EXAMPLE
    .\setup.ps1
    Interactive setup with menu.

.EXAMPLE
    .\setup.ps1 -Mode essentials -Silent
    Automated essentials install (for CI/CD).

.EXAMPLE
    .\setup.ps1 -Mode update
    Quick skill update only.

.NOTES
    Version:        1.1.0
    Author:         nzkbuild
    Repository:     https://github.com/nzkbuild/antigravity-optimizer
    Credits:        Skills from @sickn33's Antigravity Awesome Skills
    License:        MIT

.LINK
    https://github.com/nzkbuild/antigravity-optimizer
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('essentials', 'full', 'update')]
    [string]$Mode,
    
    [Parameter()]
    [switch]$Silent,
    
    [Parameter()]
    [switch]$SkipGlobalRoot,
    
    [Parameter()]
    [switch]$Force
)

# ============================================================================
# CONFIGURATION
# ============================================================================

$script:Version = "1.1.0"
$script:StartTime = Get-Date
$script:ExitCode = 0

# Colors
$script:Colors = @{
    Cyan   = "Cyan"
    Green  = "Green"
    Yellow = "Yellow"
    Red    = "Red"
    White  = "White"
    Gray   = "Gray"
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-Color {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text,
        
        [Parameter()]
        [string]$Color = "White"
    )
    Write-Host $Text -ForegroundColor $Color
}

function Write-Step {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Progress')]
        [string]$Type = 'Info'
    )
    
    $prefix = switch ($Type) {
        'Info'     { "[i]"; $script:Colors.Gray }
        'Success'  { "[+]"; $script:Colors.Green }
        'Warning'  { "[!]"; $script:Colors.Yellow }
        'Error'    { "[X]"; $script:Colors.Red }
        'Progress' { "[*]"; $script:Colors.Yellow }
        default    { "[>]"; $script:Colors.White }
    }
    
    Write-Host "$($prefix[0]) " -ForegroundColor $prefix[1] -NoNewline
    Write-Host $Message
}

function Show-Banner {
    [CmdletBinding()]
    param()
    
    if (-not $Silent) {
        Clear-Host
    }
    
    $Host.UI.RawUI.WindowTitle = "Antigravity Optimizer Setup v$script:Version"
    
    Write-Color "    _    _   _ _____ ___ ____ ____      ___ __     __ ___ _____ __ __" $script:Colors.Cyan
    Write-Color "   / \  | \ | |_   _|_ _/ ___|  _ \    /   |\ \   / /|_ _|_   _|\ \ / /" $script:Colors.Cyan
    Write-Color "  / _ \ |  \| | | |  | | |  _| |_) |  / /| | \ \ / /  | |  | |   \ V / " $script:Colors.Cyan
    Write-Color " / ___ \| |\  | | |  | | |_| |  _ <  / ___ |  \ V /   | |  | |    | |  " $script:Colors.Cyan
    Write-Color "/_/   \_\_| \_| |_| |___\____|_| \_\/_/  |_|   \_/   |___| |_|    |_|  " $script:Colors.Cyan
    Write-Host ""
    Write-Color "         >> ANTIGRAVITY OPTIMIZER SETUP v$script:Version <<" $script:Colors.Green
    Write-Color "-----------------------------------------------------------" $script:Colors.White
    Write-Host ""
}

function Test-Prerequisites {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Checking prerequisites..."
    $allPassed = $true
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Step "PowerShell 5.1+ required (found: $($PSVersionTable.PSVersion))" -Type Error
        $allPassed = $false
    } else {
        Write-Verbose "PowerShell version OK: $($PSVersionTable.PSVersion)"
    }
    
    # Check if Git is available (optional but recommended)
    $gitAvailable = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitAvailable) {
        Write-Step "Git not found - some features may not work" -Type Warning
    } else {
        Write-Verbose "Git found: $(git --version)"
    }
    
    # Check if install script exists
    $installScript = Join-Path $PSScriptRoot "scripts\install.ps1"
    if (-not (Test-Path $installScript)) {
        Write-Step "Required file missing: scripts\install.ps1" -Type Error
        $allPassed = $false
    }
    
    return $allPassed
}

# ============================================================================
# CORE FUNCTIONS
# ============================================================================

function Install-Skills {
    [CmdletBinding()]
    param()
    
    Write-Host ""
    Write-Step "Installing Skills..." -Type Progress
    
    $installScript = Join-Path $PSScriptRoot "scripts\install.ps1"
    
    try {
        & $installScript -InstallGlobalRules
        
        if ($LASTEXITCODE -ne 0) {
            throw "Skills installation failed with exit code $LASTEXITCODE"
        }
        
        Write-Step "Skills installed successfully" -Type Success
        return $true
    }
    catch {
        Write-Step "Skills installation failed: $_" -Type Error
        return $false
    }
}

function Remove-OptimizerGit {
    [CmdletBinding()]
    param()
    
    # This prevents your project from accidentally pointing to the optimizer's repo!
    # (The "address sticker" problem for vibe coders)
    
    Write-Host ""
    Write-Step "Removing optimizer's .git folder..." -Type Progress
    Write-Color "    (So your project stays pointed to YOUR repo, not ours!)" $script:Colors.Gray
    
    $gitFolder = Join-Path $PSScriptRoot ".git"
    
    try {
        if (Test-Path $gitFolder) {
            Remove-Item -Recurse -Force $gitFolder -ErrorAction Stop
            Write-Step ".git removed - your project's Git is safe!" -Type Success
        } else {
            Write-Step ".git already removed" -Type Info
        }
        return $true
    }
    catch {
        Write-Step "Failed to remove .git: $_" -Type Warning
        return $false
    }
}

function Set-GlobalOptimizerRoot {
    [CmdletBinding()]
    param(
        [switch]$SkipPrompt
    )
    
    Write-Host ""
    
    if ($SkipPrompt -or $Silent) {
        Write-Step "Skipping global root setup (use -SkipGlobalRoot:$false to enable)" -Type Info
        return
    }
    
    Write-Color "Make skills available everywhere?" $script:Colors.Cyan
    Write-Color "This stores the repo path so activate-skills works from any folder." $script:Colors.White
    
    $response = Read-Host "Set ANTIGRAVITY_OPTIMIZER_ROOT permanently? [y/N]"
    
    if ($response -match "^[yY]$") {
        try {
            [Environment]::SetEnvironmentVariable("ANTIGRAVITY_OPTIMIZER_ROOT", $PSScriptRoot, "User")
            [Environment]::SetEnvironmentVariable("ANTIGRAVITY_OPTIMIZER_ROOT", $PSScriptRoot, "Process")
            Write-Step "Saved ANTIGRAVITY_OPTIMIZER_ROOT for this user" -Type Success
            Write-Color "    Restart terminal to apply it everywhere." $script:Colors.Yellow
        }
        catch {
            Write-Step "Failed to set environment variable: $_" -Type Warning
        }
    } else {
        Write-Step "Skipped. Run setup again later to enable." -Type Info
    }
}

function Invoke-EssentialsCleanup {
    [CmdletBinding()]
    param()
    
    Write-Host ""
    Write-Step "Cleaning up for Essentials Mode..." -Type Progress
    
    $keepList = @(
        ".agent", ".cache", ".gitignore", ".gitattributes",
        "assets", "scripts", "tools", "workflows",
        "activate-skills.cmd", "activate-skills.ps1", "activate-skills.sh", "setup.ps1",
        "bundles.json", "LICENSE"
    )
    
    $removed = 0
    
    try {
        Get-ChildItem -Path $PSScriptRoot | ForEach-Object {
            if ($keepList -notcontains $_.Name) {
                Write-Verbose "Removing: $($_.Name)"
                Remove-Item -Recurse -Force $_.FullName -ErrorAction SilentlyContinue
                $removed++
            }
        }
        
        # Create simplified README
        $essentialsReadme = @"
# Antigravity Optimizer (Essentials)

Your optimizer is ready. Skills have been installed.

## Quick Start

**Windows PowerShell:**
```powershell
.\activate-skills.ps1 "Your Task Here"
```

**Linux/macOS:**
```bash
./activate-skills.sh "Your Task Here"
```

**In Antigravity IDE:**
```
/activate-skills Your Task Here
```

## Updates
Run ``.\setup.ps1`` again to update skills.

---
*Setup completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm')*
"@
        Set-Content -Path (Join-Path $PSScriptRoot "README.md") -Value $essentialsReadme
        
        Write-Step "Cleanup complete ($removed items removed)" -Type Success
        return $true
    }
    catch {
        Write-Step "Cleanup failed: $_" -Type Error
        return $false
    }
}

function Show-Completion {
    [CmdletBinding()]
    param()
    
    $elapsed = (Get-Date) - $script:StartTime
    
    Write-Host ""
    Write-Color "-----------------------------------------------------------" $script:Colors.White
    Write-Step "Setup Complete! ($('{0:N1}' -f $elapsed.TotalSeconds)s)" -Type Success
    Write-Host ""
    Write-Color "CREDITS:" $script:Colors.Yellow
    Write-Color "Skills powered by @sickn33's Antigravity Awesome Skills." $script:Colors.White
    Write-Color "https://github.com/sickn33/antigravity-awesome-skills" $script:Colors.Cyan
    Write-Host ""
    Write-Color "Try: .\activate-skills.ps1 `"Build a web app`"" $script:Colors.Green
    Write-Host ""
}

function Show-Menu {
    [CmdletBinding()]
    param()
    
    Write-Color "Welcome to the Antigravity Optimizer." $script:Colors.White
    Write-Color "This script installs skills and sets up Antigravity workflows." $script:Colors.White
    Write-Host ""
    Write-Color "Select Mode:" $script:Colors.Cyan
    Write-Color "  [1] Essentials Only (Recommended)" $script:Colors.Green
    Write-Color "      - Installs skills & tools, removes extra files" $script:Colors.White
    Write-Host ""
    Write-Color "  [2] Full Repository" $script:Colors.Yellow
    Write-Color "      - Keeps all documentation and assets" $script:Colors.White
    Write-Host ""
    Write-Color "  [3] Update Skills Only" $script:Colors.Cyan
    Write-Color "      - Just check for and install skill updates (quick)" $script:Colors.White
    Write-Host ""
    
    return Read-Host "Enter selection [1/2/3]"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    Show-Banner
    
    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        Write-Step "Prerequisites check failed. Please fix the issues above." -Type Error
        exit 1
    }
    
    # Determine mode
    $selectedMode = $Mode
    
    if (-not $selectedMode) {
        if ($Silent) {
            $selectedMode = 'essentials'
            Write-Step "Silent mode: defaulting to 'essentials'" -Type Info
        } else {
            $selection = Show-Menu
            $selectedMode = switch ($selection) {
                "1" { 'essentials' }
                "2" { 'full' }
                "3" { 'update' }
                default { 'essentials' }
            }
        }
    }
    
    Write-Host ""
    Write-Color ">> Selected: $($selectedMode.ToUpper())" $script:Colors.Green
    
    # Execute based on mode
    switch ($selectedMode) {
        'essentials' {
            if (-not $Silent) {
                $confirm = Read-Host "This will DELETE non-essential files. Continue? [y/N]"
                if ($confirm -notmatch "^[yY]$") {
                    Write-Color "Aborted." $script:Colors.Red
                    exit 0
                }
            }
            
            if (-not (Install-Skills)) { exit 1 }
            Remove-OptimizerGit
            Set-GlobalOptimizerRoot -SkipPrompt:$SkipGlobalRoot
            if (-not (Invoke-EssentialsCleanup)) { exit 1 }
        }
        
        'full' {
            if (-not (Install-Skills)) { exit 1 }
            Remove-OptimizerGit
            Set-GlobalOptimizerRoot -SkipPrompt:$SkipGlobalRoot
        }
        
        'update' {
            if (-not (Install-Skills)) { exit 1 }
            Show-Completion
            if (-not $Silent) { Pause }
            exit 0
        }
    }
    
    Show-Completion
    
    if (-not $Silent) {
        Pause
    }
}
catch {
    Write-Step "Unexpected error: $_" -Type Error
    Write-Verbose $_.ScriptStackTrace
    $script:ExitCode = 1
}
finally {
    exit $script:ExitCode
}
