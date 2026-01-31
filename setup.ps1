# Antigravity Setup Script
# Interactive onboarding for the Antigravity Optimizer
param(
    [switch]$Force
)

# Colors and Formatting
$Host.UI.RawUI.WindowTitle = "Antigravity Optimizer Setup"
$Cyan = "Cyan"
$Green = "Green"
$Yellow = "Yellow"
$Red = "Red"
$White = "White"
$Gray = "Gray"

function Write-Color {
    param($Text, $Color = $White)
    Write-Host $Text -ForegroundColor $Color
}

function Show-Banner {
    Clear-Host
    Write-Color "    _    _   _ _____ ___ ____ ____      ___ __     __ ___ _____ __ __" $Cyan
    Write-Color "   / \  | \ | |_   _|_ _/ ___|  _ \    /   |\ \   / /|_ _|_   _|\ \ / /" $Cyan
    Write-Color "  / _ \ |  \| | | |  | | |  _| |_) |  / /| | \ \ / /  | |  | |   \ V / " $Cyan
    Write-Color " / ___ \| |\  | | |  | | |_| |  _ <  / ___ |  \ V /   | |  | |    | |  " $Cyan
    Write-Color "/_/   \_\_| \_| |_| |___\____|_| \_\/_/  |_|   \_/   |___| |_|    |_|  " $Cyan
    Write-Color "                                                   " $Cyan
    Write-Color "      >> ANTIGRAVITY OPTIMIZER SETUP <<            " $Green
    Write-Color "---------------------------------------------------" $White
    Write-Host ""
}

function Install-Skills {
    Write-Host ""
    Write-Color "[*] Installing Skills..." $Yellow
    
    $installScript = Join-Path $PSScriptRoot "scripts\install.ps1"
    if (Test-Path $installScript) {
        & $installScript -InstallGlobalRules
        if ($LASTEXITCODE -ne 0) {
            Write-Color "[!] Error: Skills installation failed with exit code $LASTEXITCODE." $Red
            Write-Host ""
            Pause
            exit 1
        }
        Write-Color "[+] Skills installed successfully." $Green
    } else {
        Write-Color "[!] Error: scripts\install.ps1 not found." $Red
        Pause
        exit 1
    }
}

function Cleanup-Essentials {
    Write-Host ""
    Write-Color "[*] Cleaning up for Essentials Mode..." $Yellow
    
    $keepList = @("assets", "scripts", "skills", "tools", "workflows", "activate-skills.ps1", "activate-skills.sh", "setup.ps1", "LICENSE", ".gitignore", ".gitattributes", ".git", "bundles.json")
    $currentLocation = Get-Location

    $items = Get-ChildItem -Path $currentLocation
    
    foreach ($item in $items) {
        if ($keepList -notcontains $item.Name) {
            Write-Host "    Removing: $($item.Name)" -ForegroundColor $Gray
            Remove-Item -Recurse -Force $item.FullName -ErrorAction SilentlyContinue
        }
    }

    $essentialsReadme = @"
# Antigravity Optimizer (Essentials)

Your optimizer is ready. Skills have been installed.

## Quick Start

**Windows PowerShell:**
``powershell
.\activate-skills.ps1 "Your Task Here"
``

**Linux/macOS:**
``bash
./activate-skills.sh "Your Task Here"
``

**In Antigravity IDE:**
``
/activate-skills Your Task Here
``

## Updates
Run ``.\setup.ps1`` again to update skills.
"@
    $essentialsReadme = $essentialsReadme -replace "``", '`'
    Set-Content -Path (Join-Path $currentLocation "README.md") -Value $essentialsReadme
    Write-Color "[+] Cleanup complete." $Green
}

function Prompt-SetGlobalOptimizerRoot {
    Write-Host ""
    Write-Color "Make skills available everywhere?" $Cyan
    Write-Color "This stores the repo path so activate-skills works from any folder." $White
    $setGlobal = Read-Host "Set ANTIGRAVITY_OPTIMIZER_ROOT permanently? [y/N]"
    if ($setGlobal -match "^[yY]$") {
        [Environment]::SetEnvironmentVariable("ANTIGRAVITY_OPTIMIZER_ROOT", $PSScriptRoot, "User")
        [Environment]::SetEnvironmentVariable("ANTIGRAVITY_OPTIMIZER_ROOT", $PSScriptRoot, "Process")
        Write-Color "[+] Saved ANTIGRAVITY_OPTIMIZER_ROOT for this user." $Green
        Write-Color "    Restart terminal to apply it everywhere." $Yellow
    } else {
        Write-Color "[i] Skipped. Run setup again later to enable it." $Gray
    }
}

# Main Menu
Show-Banner

Write-Color "Welcome to the Antigravity Optimizer." $White
Write-Color "This script installs skills and sets up Antigravity workflows." $White
Write-Host ""
Write-Color "Select Installation Mode:" $Cyan
Write-Color "  [1] Essentials Only (Recommended)" $Green
Write-Color "      - Installs skills & tools, removes extra files" $White
Write-Host ""
Write-Color "  [2] Full Repository" $Yellow
Write-Color "      - Keeps all documentation and assets" $White
Write-Host ""

$selection = Read-Host "Enter selection [1/2]"

switch ($selection) {
    "1" {
        Write-Host ""
        Write-Color ">> Selected: Essentials Only" $Green
        $confirm = Read-Host "This will DELETE non-essential files. Continue? [y/N]"
        if ($confirm -match "^[yY]$") {
            Install-Skills
            Prompt-SetGlobalOptimizerRoot
            Cleanup-Essentials
        } else {
            Write-Color "Aborted." $Red
            exit
        }
    }
    "2" {
        Write-Host ""
        Write-Color ">> Selected: Full Repository" $Yellow
        Install-Skills
        Prompt-SetGlobalOptimizerRoot
    }
    Default {
        Write-Host ""
        Write-Color ">> Selected: Essentials Only (Default)" $Green
        $confirm = Read-Host "This will DELETE non-essential files. Continue? [y/N]"
        if ($confirm -match "^[yY]$") {
            Install-Skills
            Prompt-SetGlobalOptimizerRoot
            Cleanup-Essentials
        } else {
            Write-Color "Aborted." $Red
            exit
        }
    }
}

Write-Host ""
Write-Color "---------------------------------------------------" $White
Write-Color "[+] Setup Complete!" $Green
Write-Host ""
Write-Color "CREDITS:" $Yellow
Write-Color "Skills powered by @sickn33's Antigravity Awesome Skills." $White
Write-Color "https://github.com/sickn33/antigravity-awesome-skills" $Cyan
Write-Host ""
Write-Color "Try: .\activate-skills.ps1 `"Build a web app`"" $Green
Write-Host ""
Pause
