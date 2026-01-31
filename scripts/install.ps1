param(
    [string]$SkillsRepo = "https://github.com/sickn33/antigravity-awesome-skills.git",
    [switch]$SkipSkills,
    [switch]$SkipWorkflow,
    [switch]$InstallGlobalRules,
    [switch]$AddPath,
    [switch]$Force
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$skillsRoot = Join-Path $repoRoot ".agent\skills"
$skillsIndex = Join-Path $skillsRoot "skills_index.json"
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
        Write-Error "git is required to clone/update skills. Install git or clone manually to $skillsRoot."
        exit 1
    }

    # Check if skills repo already exists and is a git repo
    $gitDir = Join-Path $skillsRoot ".git"
    if ((Test-Path $skillsRoot) -and (Test-Path $gitDir)) {
        # Skills exist - update them
        Write-Host "Updating skills from upstream..."
        Push-Location $skillsRoot
        try {
            $pullResult = git pull --ff-only 2>&1
            if ($LASTEXITCODE -eq 0) {
                if ($pullResult -match "Already up to date") {
                    Write-Host "Skills are already up to date."
                } else {
                    Write-Host "Skills updated successfully!"
                    Write-Host $pullResult
                }
            } else {
                Write-Warning "Could not update skills (git pull failed). Using existing version."
                Write-Host $pullResult
            }
        } finally {
            Pop-Location
        }
        return
    }

    # Skills don't exist or not a git repo - clone fresh
    if (Test-Path $skillsRoot) {
        if ($Force) {
            Write-Host "Removing existing skills directory: $skillsRoot"
            Remove-Item -Recurse -Force $skillsRoot
        } else {
            Write-Error "Skills directory exists but is not a git repo: $skillsRoot (use -Force to replace)"
            exit 1
        }
    }

    Write-Host "Cloning skills repo to $skillsRoot..."
    git clone $SkillsRepo $skillsRoot
    if (-not (Test-Path $skillsIndex)) {
        Write-Error "skills_index.json not found after clone. Check the repo at $skillsRoot."
        exit 1
    }
    Write-Host "Skills installed successfully!"
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

Ensure-SkillsRepo
Install-Workflow
Install-GlobalRules

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
