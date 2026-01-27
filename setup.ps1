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
        $customRoot = Read-Host "Custom Codex skills path? (Press Enter for auto-detect)"
        if ($customRoot) {
            [Environment]::SetEnvironmentVariable("ANTIGRAVITY_SKILLS_ROOT", $customRoot, "User")
            & $installScript -InstallGlobalRules -SkillsRoot $customRoot
        } else {
            & $installScript -InstallGlobalRules
        }
        if ($LASTEXITCODE -eq 0) {
            Write-Color "[+] Skills installed successfully." $Green
        } else {
            Write-Color "[!] Warning: Skills installation finished with exit code $LASTEXITCODE." $Red
        }
    } else {
        Write-Color "[!] Error: scripts\install.ps1 not found." $Red
    }
}

function Cleanup-Essentials {
    Write-Host ""
    Write-Color "[*] Cleaning up for Essentials Mode..." $Yellow
    
    $keepList = @("assets", "scripts", "skills", "tools", "workflows", "activate-skills.cmd", "activate-skills.ps1", "setup.ps1", "LICENSE", ".gitignore", ".git")
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
Skills have been installed to your Codex skills folder.
Restart Codex to pick up the new activate-skills skill.

## Quick Start

1. **Activate Skills**:
   ```powershell
   .\activate-skills.ps1 "Your Task Here"
   ```

2. **In Antigravity**:
   ```
   /activate-skills Your Task Here
   ```

3. **In Codex**:
   Use the `activate-skills` skill and provide your task.

## Updates
Run `.\scripts\install.ps1` to update skills or global rules.
"@
    Set-Content -Path (Join-Path $currentLocation "README.md") -Value $essentialsReadme
    Write-Color "[+] Cleanup complete. You have a clean slate." $Green
}

function Prompt-SetGlobalOptimizerRoot {
    Write-Host ""
    Write-Color "Make skills available everywhere?" $Cyan
    Write-Color "This stores the repo path once so `$activate-skills works from any folder." $White
    Write-Color "Recommended for non-technical users." $Green
    $setGlobal = Read-Host "Set ANTIGRAVITY_OPTIMIZER_ROOT permanently? [y/N]"
    if ($setGlobal -match "^[yY]$") {
        [Environment]::SetEnvironmentVariable("ANTIGRAVITY_OPTIMIZER_ROOT", $PSScriptRoot, "User")
        [Environment]::SetEnvironmentVariable("ANTIGRAVITY_OPTIMIZER_ROOT", $PSScriptRoot, "Process")
        Write-Color "[+] Saved ANTIGRAVITY_OPTIMIZER_ROOT for this user." $Green
        $savedValue = [Environment]::GetEnvironmentVariable("ANTIGRAVITY_OPTIMIZER_ROOT", "User")
        if ($savedValue) {
            Write-Color "[+] Verified: ANTIGRAVITY_OPTIMIZER_ROOT = $savedValue" $Green
        } else {
            Write-Color "[!] Could not verify ANTIGRAVITY_OPTIMIZER_ROOT after setting it." $Red
        }
        Write-Color "    Restart Codex/terminal to apply it everywhere." $Yellow
    } else {
        Write-Color "[i] Skipped. You can run setup again later to enable it." $Gray
    }
}

# Main Menu
Show-Banner

Write-Color "Welcome to the Antigravity Optimizer." $White
Write-Color "This script installs skills for Codex and sets up Antigravity workflows." $White
Write-Host ""
Write-Color "Select Installation Mode:" $Cyan
Write-Color "  [1] Essentials Only (Recommended)" $Green
Write-Color "      - Installs skills & tools" $White
Write-Color "      - Removes docs and extra files (keeps assets) for a clean project root" $White
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
        $confirm = Read-Host "This will DELETE non-essential files from this folder. Continue? [y/N]"
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
Write-Color "This optimizer relies on the 'Antigravity Awesome Skills' library." $White
Write-Color "Huge thanks to @sickn33 for creating the skills that power this tool." $White
Write-Color "Please verify the skills at: https://github.com/sickn33/antigravity-awesome-skills" $Cyan
Write-Host ""
Write-Color "Try running: .\activate-skills.ps1 `"Build a web app`"" $Green
Write-Host ""
Pause
