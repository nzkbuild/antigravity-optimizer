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
        Write-Error "git is required to clone skills. Install git or clone manually."
        exit 1
    }

    if (Test-Path $skillsCache) {
        if (Test-Path (Join-Path $skillsCache ".git")) {
            Write-Host "Updating skills cache: $skillsCache"
            git -C $skillsCache pull
        } elseif ($Force) {
            Write-Host "Removing existing skills cache: $skillsCache"
            Remove-Item -Recurse -Force $skillsCache
            git clone $SkillsRepo $skillsCache
        } else {
            Write-Error "Skills cache exists but is not a git repo: $skillsCache (use -Force to replace)"
            exit 1
        }
    } else {
        Write-Host "Cloning skills repo to $skillsCache"
        git clone $SkillsRepo $skillsCache
    }

    if (-not (Test-Path $skillsIndex)) {
        Write-Error "skills_index.json not found after clone. Check the repo at $skillsCache."
        exit 1
    }

    if (-not (Test-Path $skillsRoot)) {
        New-Item -ItemType Directory -Path $skillsRoot | Out-Null
    }

    $skillsSourceDir = Join-Path $skillsCache "skills"
    if (-not (Test-Path $skillsSourceDir)) {
        Write-Error "Skills folder not found in repo: $skillsSourceDir"
        exit 1
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
    Write-Host "Installed skills to: $skillsRoot"
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

    if ((Test-Path $workflowTarget) -and -not $Force) {
        Write-Host "Workflow already exists: $workflowTarget (use -Force to overwrite)"
        return
    }

    $template = Get-Content -Path $templatePath -Raw
    $template = $template -replace "\{\{REPO_ROOT\}\}", $repoRoot.Path
    try {
        Set-Content -Path $workflowTarget -Value $template
    } catch {
        Write-Error "Failed to write workflow. Check permissions for $workflowDir or run PowerShell as admin."
        exit 1
    }

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

    if (Test-Path $globalRulesPath) {
        $content = Get-Content -Path $globalRulesPath -Raw
        if ($content -match "## Activate Skills Router \(Preferred\)") {
            Write-Host "Global rules already contain Activate Skills Router section."
            return
        }
        Add-Content -Path $globalRulesPath -Value ("`r`n" + $rulesBlock)
        Write-Host "Updated global rules: $globalRulesPath"
        return
    }

    New-Item -ItemType Directory -Path (Split-Path $globalRulesPath) -Force | Out-Null
    Set-Content -Path $globalRulesPath -Value $rulesBlock
    Write-Host "Created global rules: $globalRulesPath"
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
