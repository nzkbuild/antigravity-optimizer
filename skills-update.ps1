# Skills Update Checker for Antigravity Optimizer
param(
    [switch]$Yes
)

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

function Run-Git {
    param(
        [string[]]$Args,
        [string]$WorkingDir
    )
    $output = & git -C $WorkingDir @Args 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Args -join ' ') failed: $output"
    }
    return $output
}

$repoRoot = $PSScriptRoot
$skillsRepo = Join-Path $repoRoot "skills\antigravity-awesome-skills"
$stateFile = Join-Path $repoRoot ".skills-update.json"
$remoteUrl = "https://github.com/sickn33/antigravity-awesome-skills"
$branch = "main"

Write-Color "Antigravity Skills Update Checker" $Cyan

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Color "[!] Git not found. Please install Git and try again." $Red
    exit 1
}

if (-not (Test-Path $skillsRepo)) {
    Write-Color "[*] Skills repo not found. Cloning..." $Yellow
    & git clone $remoteUrl $skillsRepo
    if ($LASTEXITCODE -ne 0) {
        Write-Color "[!] Clone failed. Please check your network and try again." $Red
        exit 1
    }
}

if (-not (Test-Path (Join-Path $skillsRepo ".git"))) {
    Write-Color "[!] Skills directory exists but is not a git repo." $Red
    Write-Color "    Expected: $skillsRepo" $Gray
    exit 1
}

Write-Color "[*] Fetching updates..." $Yellow
try {
    Run-Git -Args @("fetch", "origin", $branch, "--quiet") -WorkingDir $skillsRepo | Out-Null
} catch {
    Write-Color "[!] Fetch failed: $($_.Exception.Message)" $Red
    exit 1
}

$localHead = (Run-Git -Args @("rev-parse", "HEAD") -WorkingDir $skillsRepo).Trim()
$remoteHead = (Run-Git -Args @("rev-parse", "origin/$branch") -WorkingDir $skillsRepo).Trim()

if ($localHead -eq $remoteHead) {
    Write-Color "[+] Skills are up to date." $Green
} else {
    Write-Color "[!] Updates available:" $Yellow
    $logLines = Run-Git -Args @("log", "--oneline", "$localHead..origin/$branch") -WorkingDir $skillsRepo
    $fileLines = Run-Git -Args @("diff", "--name-only", "$localHead..origin/$branch") -WorkingDir $skillsRepo

    if ($logLines) {
        Write-Color "Commits:" $White
        $logLines | Select-Object -First 20 | ForEach-Object { Write-Color "  $_" $Gray }
    }

    if ($fileLines) {
        Write-Color "Changed files:" $White
        $fileLines | Select-Object -First 30 | ForEach-Object { Write-Color "  $_" $Gray }
        if (($fileLines | Measure-Object).Count -gt 30) {
            Write-Color "  ...and more" $Gray
        }
    }

    if (-not $Yes) {
        $apply = Read-Host "Apply updates now? [y/N]"
    } else {
        $apply = "y"
    }

    if ($apply -match "^[yY]$") {
        Write-Color "[*] Applying updates..." $Yellow
        try {
            Run-Git -Args @("pull", "--ff-only", "origin", $branch) -WorkingDir $skillsRepo | Out-Null
            $localHead = (Run-Git -Args @("rev-parse", "HEAD") -WorkingDir $skillsRepo).Trim()
            Write-Color "[+] Skills updated." $Green
        } catch {
            Write-Color "[!] Update failed: $($_.Exception.Message)" $Red
            exit 1
        }
    } else {
        Write-Color "[i] Skipped update." $Gray
    }
}

$state = @{
    lastAppliedCommit = $localHead
    lastAppliedAt     = (Get-Date).ToString("s")
    repoPath          = $skillsRepo
    branch            = $branch
}
$state | ConvertTo-Json | Set-Content -Path $stateFile
Write-Color "[i] State saved to $stateFile" $Gray
