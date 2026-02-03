param(
    [string]$SkillsRepo = "https://github.com/sickn33/antigravity-awesome-skills.git",
    [string]$SkillsRoot,
    [string]$SkillsCache,
    [switch]$SkipSkills,
    [switch]$SkipWorkflow,
    [switch]$InstallGlobalRules,
    [switch]$AddPath,
    [switch]$Force
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }
$skillsRoot = if ($SkillsRoot) { $SkillsRoot } elseif ($env:ANTIGRAVITY_SKILLS_ROOT) { $env:ANTIGRAVITY_SKILLS_ROOT } else { Join-Path $codexHome "skills" }
$skillsCache = if ($SkillsCache) { $SkillsCache } else { Join-Path $repoRoot ".cache\antigravity-awesome-skills" }
$skillsIndex = Join-Path $skillsCache "skills_index.json"
$routerSkillSource = Join-Path $repoRoot "skills\activate-skills"
$routerSkillDest = Join-Path $skillsRoot "activate-skills"
$workflowDir = Join-Path $env:USERPROFILE ".gemini\antigravity\global_workflows"
$workflowTarget = Join-Path $workflowDir "activate-skills.md"
$templatePath = Join-Path $repoRoot "workflows\activate-skills.md"
$globalRulesPath = Join-Path $env:USERPROFILE ".gemini\GEMINI.md"

function Ensure-SkillsRepo {
    if ($SkipSkills) {
        return
    }

    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        Write-Error "git is required to clone/update skills. Install git or clone manually."
        exit 1
    }

    # Check if cache exists and is git repo - update it
    if (Test-Path $skillsCache) {
        if (Test-Path (Join-Path $skillsCache ".git")) {
            Write-Host "Updating skills cache..."
            Push-Location $skillsCache
            try {
                $pullResult = git pull --ff-only 2>&1
                if ($LASTEXITCODE -eq 0) {
                    if ($pullResult -match "Already up to date") {
                        Write-Host "Skills cache is up to date."
                    } else {
                        Write-Host "Skills cache updated!"
                    }
                } else {
                    Write-Warning "Could not update cache. Using existing version."
                }
            } finally {
                Pop-Location
            }
        } elseif ($Force) {
            Write-Host "Removing existing skills cache..."
            Remove-Item -Recurse -Force $skillsCache
            git clone $SkillsRepo $skillsCache
        } else {
            Write-Error "Skills cache exists but is not a git repo: $skillsCache (use -Force to replace)"
            exit 1
        }
    } else {
        Write-Host "Cloning skills repo..."
        git clone $SkillsRepo $skillsCache
    }

    if (-not (Test-Path $skillsIndex)) {
        Write-Error "skills_index.json not found after clone. Check the repo at $skillsCache."
        exit 1
    }

    # Count skills
    $skillsSourceDir = Join-Path $skillsCache "skills"
    if (-not (Test-Path $skillsSourceDir)) {
        Write-Error "Skills folder not found in repo: $skillsSourceDir"
        exit 1
    }
    $skillCount = (Get-Content $skillsIndex | ConvertFrom-Json).Count

    # Copy skills to Codex folder (only skills/ and skills_index.json - skip docs, assets, etc.)
    if (-not (Test-Path $skillsRoot)) {
        New-Item -ItemType Directory -Path $skillsRoot | Out-Null
    }

    $skillDirs = Get-ChildItem -Path $skillsSourceDir -Directory
    foreach ($skillDir in $skillDirs) {
        $targetDir = Join-Path $skillsRoot $skillDir.Name
        if (Test-Path $targetDir) {
            Remove-Item -Recurse -Force $targetDir
        }
        Copy-Item -Path $skillDir.FullName -Destination $targetDir -Recurse
    }

    Copy-Item -Path $skillsIndex -Destination (Join-Path $skillsRoot "skills_index.json") -Force
    Write-Host "Skills installed to: $skillsRoot ($skillCount skills)"

    # Also copy to .agent/skills in this repo (for Antigravity IDE)
    $agentSkillsDir = Join-Path $repoRoot ".agent\skills"
    if (-not (Test-Path $agentSkillsDir)) {
        New-Item -ItemType Directory -Path $agentSkillsDir -Force | Out-Null
    }
    
    # Copy skills folder (only skills/ and index - no docs, assets, bin, etc.)
    $agentSkillsSubDir = Join-Path $agentSkillsDir "skills"
    if (Test-Path $agentSkillsSubDir) {
        Remove-Item -Recurse -Force $agentSkillsSubDir
    }
    Copy-Item -Path $skillsSourceDir -Destination $agentSkillsSubDir -Recurse
    Copy-Item -Path $skillsIndex -Destination (Join-Path $agentSkillsDir "skills_index.json") -Force
    Write-Host "Skills also installed to: $agentSkillsDir"

    # Auto-add .agent/skills/ to .gitignore (prevent 2000+ file tracking)
    $gitignorePath = Join-Path $repoRoot ".gitignore"
    if (Test-Path $gitignorePath) {
        $gitignoreContent = Get-Content $gitignorePath -Raw
        if ($gitignoreContent -notmatch "\.agent/skills/") {
            Add-Content -Path $gitignorePath -Value "`n# Skills (installed separately)`n.agent/skills/"
            Write-Host "Added .agent/skills/ to .gitignore (prevents tracking $skillCount skill files)"
        }
    }

    Write-Host ""
    Write-Host "Total skills installed: $skillCount" -ForegroundColor Green
}

function Install-Workflow {
    if ($SkipWorkflow) {
        return
    }

    if (-not (Test-Path $templatePath)) {
        Write-Error "Template not found: $templatePath"
        exit 1
    }

    New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null

    # Copy template as-is (no path replacement needed - template is now dynamic)
    Copy-Item -Path $templatePath -Destination $workflowTarget -Force

    Write-Host "Installed workflow: $workflowTarget"
}

function Install-GlobalRules {
    if (-not $InstallGlobalRules) {
        return
    }

    $rulesBlock = @"
## Activate Skills Router (Preferred)

For non-trivial tasks, prefer routing with the optimizer instead of manual skill loading.

- IDE: /activate-skills <task>
- CLI: @activate-skills "<task>" or activate-skills "<task>"

The router outputs the /skill line + task line. Use that output as-is.
If the router is unavailable, fall back to manual skill loading below.

"@

    # Check if already installed
    if (Test-Path $globalRulesPath) {
        $content = Get-Content -Path $globalRulesPath -Raw
        if ($content -match "## Activate Skills Router \(Preferred\)") {
            Write-Host "Global rules already contain Activate Skills Router section." -ForegroundColor Gray
            return
        }
    }

    # Show user what we want to add
    Write-Host ""
    Write-Host "-----------------------------------------------------------" -ForegroundColor White
    Write-Host "GLOBAL RULES UPDATE" -ForegroundColor Cyan
    Write-Host "-----------------------------------------------------------" -ForegroundColor White
    Write-Host ""
    Write-Host "We'd like to add this to your global AI rules:" -ForegroundColor Yellow
    Write-Host "Location: $globalRulesPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "--- What will be added ---" -ForegroundColor Cyan
    Write-Host $rulesBlock -ForegroundColor White
    Write-Host "--------------------------" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This teaches AI to use /activate-skills automatically." -ForegroundColor White
    Write-Host ""

    $response = Read-Host "Add to global rules? [Y/n/skip]"
    
    if ($response -match "^[sS]") {
        Write-Host "Skipped global rules. You can add them manually later." -ForegroundColor Gray
        return
    }
    
    if ($response -match "^[nN]") {
        Write-Host "Skipped global rules." -ForegroundColor Gray
        return
    }

    # User approved (Y or Enter)
    try {
        if (Test-Path $globalRulesPath) {
            Add-Content -Path $globalRulesPath -Value ("`r`n" + $rulesBlock)
            Write-Host "[+] Updated global rules: $globalRulesPath" -ForegroundColor Green
        } else {
            New-Item -ItemType Directory -Path (Split-Path $globalRulesPath) -Force | Out-Null
            Set-Content -Path $globalRulesPath -Value $rulesBlock
            Write-Host "[+] Created global rules: $globalRulesPath" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[!] Failed to update global rules: $_" -ForegroundColor Red
    }
}

function Install-RouterSkill {
    if (-not (Test-Path $routerSkillSource)) {
        return
    }

    if (-not (Test-Path $skillsRoot)) {
        New-Item -ItemType Directory -Path $skillsRoot | Out-Null
    }

    if (Test-Path $routerSkillDest) {
        Remove-Item -Recurse -Force $routerSkillDest
    }

    Copy-Item -Path $routerSkillSource -Destination $routerSkillDest -Recurse
    Write-Host "Installed Codex skill: activate-skills"

    [Environment]::SetEnvironmentVariable("ANTIGRAVITY_OPTIMIZER_ROOT", $repoRoot.Path, "User")
}

Ensure-SkillsRepo
Install-Workflow
Install-GlobalRules
Install-RouterSkill

if ($AddPath) {
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $currentPath) { $currentPath = "" }
    $pathParts = $currentPath.Split(";") | Where-Object { $_ -ne "" }
    if ($pathParts -notcontains $repoRoot.Path) {
        $newPath = ($pathParts + $repoRoot.Path) -join ";"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Host "Added to user PATH: $repoRoot"
        Write-Host "Restart your terminal for PATH changes to apply."
    } else {
        Write-Host "PATH already contains: $repoRoot"
    }
}
