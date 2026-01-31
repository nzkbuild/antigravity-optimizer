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
    
    # Run the existing install script to handle git cloning/updates
    $installScript = Join-Path $PSScriptRoot "scripts\install.ps1"
    if (Test-Path $installScript) {
        # Pass appropriate flags. We always want to install global rules and skills.
        # We use -InstallGlobalRules to make sure the router is active.
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
    
    $keepList = @(".agent", "scripts", "tools", "workflows", "activate-skills.cmd", "activate-skills.ps1", "setup.ps1", "LICENSE", ".gitignore", ".git")
    $currentLocation = Get-Location

    $items = Get-ChildItem -Path $currentLocation
    
    foreach ($item in $items) {
        if ($keepList -notcontains $item.Name) {
            Write-Host "    Removing: $($item.Name)" -ForegroundColor $Gray
            Remove-Item -Recurse -Force $item.FullName -ErrorAction SilentlyContinue
        }
    }

    # Create a simplified README for Essentials
    $essentialsReadme = @"
# Antigravity Optimizer (Essentials)

Your optimizer is ready.
Skills have been installed to `.agent/skills`.

## Quick Start

1. **Activate Skills**:
   ```powershell
   .\activate-skills.ps1 "Your Task Here"
   ```

2. **In Antigravity**:
   ```
   /activate-skills Your Task Here
   ```

## Updates
Run `.\scripts\install.ps1` to update skills or global rules.
"@
    Set-Content -Path (Join-Path $currentLocation "README.md") -Value $essentialsReadme
    Write-Color "[+] Cleanup complete. You have a clean slate." $Green
}

# Main Menu
Show-Banner

Write-Color "Welcome to the Antigravity Optimizer." $White
Write-Color "This script will set up your environment and install the necessary skills." $White
Write-Host ""
Write-Color "Select Installation Mode:" $Cyan
Write-Color "  [1] Essentials Only (Recommended)" $Green
Write-Color "      - Installs skills & tools" $White
Write-Color "      - Removes docs, assets, and extra files for a clean project root" $White
Write-Host ""
Write-Color "  [2] Full Repository" $Yellow
Write-Color "      - Installs skills & tools" $White
Write-Color "      - Keeps all documentation, assets, and contributing guides" $White
Write-Color "      - Best for contributors or checking out the source" $White
Write-Host ""

$selection = Read-Host "Enter selection [1/2]"

switch ($selection) {
    "1" {
        Write-Host ""
        Write-Color ">> Selected: Essentials Only" $Green
        $confirm = Read-Host "This will DELETE non-essential files from this folder. Continue? [y/N]"
        if ($confirm -match "^[yY]$") {
            Install-Skills
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
    }
    Default {
        Write-Host ""
        Write-Color ">> Selected: Essentials Only (Default)" $Green
        $confirm = Read-Host "This will DELETE non-essential files from this folder. Continue? [y/N]"
        if ($confirm -match "^[yY]$") {
            Install-Skills
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
Write-Color "This optimizer relies on the 'Antigravity Awesome Skills' library." $White
Write-Color "Huge thanks to @sickn33 for creating the skills that power this tool." $White
Write-Color "Please verify the skills at: https://github.com/sickn33/antigravity-awesome-skills" $Cyan
Write-Host ""
Write-Color "Try running: .\activate-skills.ps1 `"Build a web app`"" $Green
Write-Host ""
Pause
