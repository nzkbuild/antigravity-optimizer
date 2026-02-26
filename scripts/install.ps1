param(
    [string]$SkillsRepo = "https://github.com/sickn33/antigravity-awesome-skills.git",
    [string]$SkillsRoot,
    [string]$SkillsCache,
    [switch]$SkipSkills,
    [switch]$SkipWorkflow,
    [ValidateSet('global', 'workspace')]
    [string]$WorkflowScope = "global",
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
$templatePath = Join-Path $repoRoot "workflows\activate-skills.md"
$globalRulesPath = Join-Path $env:USERPROFILE ".gemini\GEMINI.md"

function Get-SkillCountFromIndex {
    param(
        [Parameter(Mandatory)]
        [string]$IndexPath
    )

    if (-not (Test-Path $IndexPath)) {
        return 0
    }

    try {
        $data = Get-Content $IndexPath -Raw | ConvertFrom-Json
        if ($data -is [System.Collections.IEnumerable] -and -not ($data.PSObject.Properties.Name -contains "skills")) {
            return $data.Count
        }
        if ($data.PSObject.Properties.Name -contains "skills" -and $data.skills) {
            return $data.skills.Count
        }
    }
    catch {
        return 0
    }

    return 0
}

function Install-SkillsToTarget {
    param(
        [Parameter(Mandatory)]
        [string]$SourceSkillsDir,
        [Parameter(Mandatory)]
        [string]$SourceIndexPath,
        [Parameter(Mandatory)]
        [string]$TargetRoot,
        [Parameter(Mandatory)]
        [string]$TargetLabel,
        [string]$IndexDestinationPath
    )

    $result = [ordered]@{
        Label         = $TargetLabel
        Target        = $TargetRoot
        Attempted     = 0
        Installed     = 0
        Failed        = 0
        ErrorMessages = New-Object System.Collections.Generic.List[string]
    }

    try {
        New-Item -ItemType Directory -Path $TargetRoot -Force -ErrorAction Stop | Out-Null
    }
    catch {
        $result.ErrorMessages.Add("Cannot create target directory '$TargetRoot': $_")
        return [pscustomobject]$result
    }

    $skillDirs = Get-ChildItem -Path $SourceSkillsDir -Directory -ErrorAction SilentlyContinue
    foreach ($skillDir in $skillDirs) {
        $result.Attempted++
        $targetDir = Join-Path $TargetRoot $skillDir.Name

        try {
            if (Test-Path $targetDir) {
                # Best effort: clear read-only attributes before replacing directories.
                Get-ChildItem -Path $targetDir -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    $_.Attributes = 'Normal'
                }
                Remove-Item -Recurse -Force -Path $targetDir -ErrorAction Stop
            }

            Copy-Item -Path $skillDir.FullName -Destination $targetDir -Recurse -ErrorAction Stop
            $result.Installed++
        }
        catch {
            $result.Failed++
            if ($result.ErrorMessages.Count -lt 10) {
                $result.ErrorMessages.Add("[$($skillDir.Name)] $($_.Exception.Message)")
            }
        }
    }

    try {
        $indexPath = if ($IndexDestinationPath) { $IndexDestinationPath } else { Join-Path $TargetRoot "skills_index.json" }
        Copy-Item -Path $SourceIndexPath -Destination $indexPath -Force -ErrorAction Stop
    }
    catch {
        if ($result.ErrorMessages.Count -lt 10) {
            $result.ErrorMessages.Add("[skills_index.json] $($_.Exception.Message)")
        }
    }

    return [pscustomobject]$result
}

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
                $pullResult = git -c "safe.directory=$skillsCache" pull --ff-only 2>&1
                if ($LASTEXITCODE -eq 0) {
                    if ($pullResult -match "Already up to date") {
                        Write-Host "Skills cache is up to date."
                    } else {
                        Write-Host "Skills cache updated!"
                    }
                } else {
                    Write-Warning "Could not update cache. Using existing version. Details: $pullResult"
                    $global:LASTEXITCODE = 0
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
    $skillCount = Get-SkillCountFromIndex -IndexPath $skillsIndex

    # Install to Codex folder (only skills/ and skills_index.json)
    $codexInstall = Install-SkillsToTarget `
        -SourceSkillsDir $skillsSourceDir `
        -SourceIndexPath $skillsIndex `
        -TargetRoot $skillsRoot `
        -TargetLabel "Codex" `
        -IndexDestinationPath (Join-Path $skillsRoot "skills_index.json")

    if ($codexInstall.Installed -gt 0 -and $codexInstall.Failed -eq 0) {
        Write-Host "Skills installed to: $skillsRoot ($($codexInstall.Installed) skills)"
    } elseif ($codexInstall.Installed -gt 0) {
        Write-Warning "Partial install to $skillsRoot ($($codexInstall.Installed) installed, $($codexInstall.Failed) failed)."
    } else {
        Write-Warning "Could not install skills to $skillsRoot."
    }

    # Also install to .agent/skills in this repo (for Antigravity IDE)
    $agentSkillsDir = Join-Path $repoRoot ".agent\skills"
    $agentSkillsSubDir = Join-Path $agentSkillsDir "skills"
    $agentInstall = Install-SkillsToTarget `
        -SourceSkillsDir $skillsSourceDir `
        -SourceIndexPath $skillsIndex `
        -TargetRoot $agentSkillsSubDir `
        -TargetLabel "Antigravity IDE" `
        -IndexDestinationPath (Join-Path $agentSkillsDir "skills_index.json")

    if ($agentInstall.Installed -gt 0 -and $agentInstall.Failed -eq 0) {
        Write-Host "Skills also installed to: $agentSkillsDir"
    } elseif ($agentInstall.Installed -gt 0) {
        Write-Warning "Partial install to $agentSkillsDir ($($agentInstall.Installed) installed, $($agentInstall.Failed) failed)."
    } else {
        Write-Warning "Could not install skills to $agentSkillsDir."
    }

    foreach ($message in $codexInstall.ErrorMessages) {
        Write-Verbose "[Codex] $message"
    }
    foreach ($message in $agentInstall.ErrorMessages) {
        Write-Verbose "[Agent] $message"
    }

    if ($codexInstall.Installed -eq 0 -and $agentInstall.Installed -eq 0) {
        Write-Error "Skills installation failed for all targets. Check filesystem permissions."
        exit 1
    }

    # Auto-add .agent/skills/ to .gitignore (prevent 2000+ file tracking)
    $gitignorePath = Join-Path $repoRoot ".gitignore"
    if ((Test-Path $gitignorePath) -and $agentInstall.Installed -gt 0) {
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

    if ($WorkflowScope -eq "workspace") {
        $workflowDir = Join-Path $repoRoot ".gemini\workflows"
    } else {
        $workflowDir = Join-Path $env:USERPROFILE ".gemini\antigravity\global_workflows"
    }
    $workflowTarget = Join-Path $workflowDir "activate-skills.md"
    
    try {
        New-Item -ItemType Directory -Path $workflowDir -Force -ErrorAction Stop | Out-Null
        # Copy template as-is (no path replacement needed - template is now dynamic)
        Copy-Item -Path $templatePath -Destination $workflowTarget -Force -ErrorAction Stop
        Write-Host "Installed workflow: $workflowTarget"
        return
    }
    catch {
        if ($WorkflowScope -eq "global") {
            Write-Warning "Global workflow install failed: $($_.Exception.Message)"
            $fallbackDir = Join-Path $repoRoot ".gemini\workflows"
            $fallbackTarget = Join-Path $fallbackDir "activate-skills.md"
            try {
                New-Item -ItemType Directory -Path $fallbackDir -Force -ErrorAction Stop | Out-Null
                Copy-Item -Path $templatePath -Destination $fallbackTarget -Force -ErrorAction Stop
                Write-Host "Installed workflow (workspace fallback): $fallbackTarget"
                return
            }
            catch {
                Write-Warning "Workflow install skipped: $($_.Exception.Message)"
                return
            }
        }

        Write-Warning "Workflow install skipped: $($_.Exception.Message)"
        return
    }
}

function Install-GlobalRules {
    if (-not $InstallGlobalRules) {
        return
    }

    $version = "1.3.2"
    $rulesBlock = @"
<!-- ANTIGRAVITY_OPTIMIZER_VERSION: $version -->
## Activate Skills Router (Preferred)

For non-trivial tasks, prefer routing with the optimizer instead of manual skill loading.

- IDE: /activate-skills <task>
- CLI: @activate-skills "<task>" or activate-skills "<task>"

The router should auto-load the suggested skills and execute the task end-to-end.
If the router is unavailable, fall back to manual skill loading below.

Guardrails:
- Cap skills to 3–5 (drop extras).
- Avoid heavy skills (e.g., loki-mode) unless explicitly requested.
- Prefer domain-matching skills over generic ones.

Feedback:
- Local memory: ~/.codex/.router_feedback.json

"@

    # Detect existing files
    $globalExists = Test-Path $globalRulesPath
    $workspacePath = Join-Path $repoRoot ".gemini\GEMINI.md"
    $workspaceExists = Test-Path $workspacePath
    
    $globalHasRules = $globalExists -and ((Get-Content -Path $globalRulesPath -Raw -ErrorAction SilentlyContinue) -match "Activate Skills Router")
    $workspaceHasRules = $workspaceExists -and ((Get-Content -Path $workspacePath -Raw -ErrorAction SilentlyContinue) -match "Activate Skills Router")

    # Scenario 1: Global rules already exist
    if ($globalHasRules) {
        Write-Host ""
        Write-Host "===========================================================" -ForegroundColor Cyan
        Write-Host "  AI INSTRUCTIONS ALREADY INSTALLED" -ForegroundColor White
        Write-Host "===========================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  $([char]0x2713) Global instructions found at:" -ForegroundColor Green
        Write-Host "    $globalRulesPath" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  All your projects already have /activate-skills enabled."
        Write-Host "  No additional setup needed!"
        Write-Host ""
        return
    }

    # Scenario 2: Both workspace and global exist (conflict)
    if ($globalExists -and $workspaceExists) {
        Write-Host ""
        Write-Host "===========================================================" -ForegroundColor Yellow
        Write-Host "  [!] CONFLICT DETECTED" -ForegroundColor Yellow
        Write-Host "===========================================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  You have configuration files in BOTH locations:" -ForegroundColor White
        Write-Host ""
        Write-Host "    Global:    $globalRulesPath" -ForegroundColor Cyan
        Write-Host "    Workspace: $workspacePath" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  How AI works:" -ForegroundColor Yellow
        Write-Host "    AI always checks GLOBAL first, then workspace."
        Write-Host "    Global instructions will take priority."
        Write-Host ""
        Write-Host "  Recommendation:" -ForegroundColor Yellow
        Write-Host "    - Keep global if you want consistency everywhere"
        Write-Host "    - Delete global if you want per-project control"
        Write-Host ""
        $response = Read-Host "  Continue anyway? [Y/N]"
        if ($response -notmatch "^[yY]$") {
            Write-Host "[i] Skipped rules installation." -ForegroundColor Gray
            return
        }
    }

    # Scenario 3: Show menu for fresh install
    Write-Host ""
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host "  AI INSTRUCTIONS SETUP" -ForegroundColor White
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  The optimizer needs to teach AI how to use /activate-skills."
    Write-Host "  This adds ~15 lines to a configuration file."
    Write-Host ""
    Write-Host "  Where should we add these instructions?" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "  [1] " -NoNewline -ForegroundColor Green
    Write-Host "Global - All Your Projects " -NoNewline
    Write-Host "[RECOMMENDED]" -ForegroundColor Yellow
    Write-Host "      AI File:  $globalRulesPath" -ForegroundColor Gray
    Write-Host "      Effect:   /activate-skills works in ALL projects"
    Write-Host "      Use when: Your personal computer"
    Write-Host ""
    Write-Host "      $([char]0x2713) Set once, works everywhere" -ForegroundColor Green
    Write-Host "      $([char]0x2713) Consistent across projects" -ForegroundColor Green
    Write-Host "      $([char]0x2717) Shared repos might conflict" -ForegroundColor Red
    Write-Host ""
    
    Write-Host "  [2] " -NoNewline -ForegroundColor Cyan
    Write-Host "Workspace - This Project Only"
    Write-Host "      AI File:  $workspacePath" -ForegroundColor Gray
    Write-Host "      Effect:   /activate-skills only works HERE"
    Write-Host "      Use when: Team projects, client work"
    Write-Host ""
    Write-Host "      $([char]0x2713) Won't affect other projects" -ForegroundColor Green
    Write-Host "      $([char]0x2713) Safe for shared repositories" -ForegroundColor Green
    Write-Host "      $([char]0x2717) Must setup per project" -ForegroundColor Red
    Write-Host ""
    
    Write-Host "  [3] " -NoNewline -ForegroundColor Gray
    Write-Host "Skip - I'll Configure This Later" -ForegroundColor Gray
    Write-Host "      Effect: Skills install, but /activate-skills won't work yet" -ForegroundColor Gray
    Write-Host ""
    Write-Host "      Run setup again anytime to add instructions." -ForegroundColor Gray
    Write-Host ""
    
    $choice = Read-Host "  Choose [1/2/3]"
    
    switch ($choice) {
        "1" {
            # Global install
            $targetPath = $globalRulesPath
        }
        "2" {
            # Workspace install
            $targetPath = $workspacePath
        }
        default {
            Write-Host "[i] Skipped rules installation." -ForegroundColor Gray
            return
        }
    }

    # Preview before modifying
    if (Test-Path $targetPath) {
        $currentSize = (Get-Item $targetPath).Length
        $newSize = $currentSize + $rulesBlock.Length
        
        Write-Host ""
        Write-Host "===========================================================" -ForegroundColor Cyan
        Write-Host "  PREVIEW: WHAT WILL BE MODIFIED" -ForegroundColor White
        Write-Host "===========================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  File: $targetPath" -ForegroundColor White
        Write-Host "  Current size: $([math]::Round($currentSize/1KB, 1)) KB" -ForegroundColor Gray
        Write-Host "  New size:     $([math]::Round($newSize/1KB, 1)) KB (added ~15 lines)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Your existing rules will NOT be overwritten." -ForegroundColor Yellow
        Write-Host "  We will APPEND this section at the end:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  ---" -ForegroundColor Gray
        Write-Host "  <!-- ANTIGRAVITY_OPTIMIZER_VERSION: $version -->" -ForegroundColor Gray
        Write-Host "  ## Activate Skills Router (Preferred)" -ForegroundColor Gray
        Write-Host "  " -ForegroundColor Gray
        Write-Host "  For non-trivial tasks, prefer routing..." -ForegroundColor Gray
        Write-Host "  [... 10 more lines ...]" -ForegroundColor Gray
        Write-Host "  ---" -ForegroundColor Gray
        Write-Host ""
        
        $confirm = Read-Host "  Continue? [Y/N]"
        if ($confirm -notmatch "^[yY]$") {
            Write-Host "[i] Cancelled rules installation." -ForegroundColor Gray
            return
        }
    }

    # Install to chosen location with error handling
    try {
        $targetDir = Split-Path $targetPath
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        
        if (Test-Path $targetPath) {
            Add-Content -Path $targetPath -Value ("`r`n" + $rulesBlock) -ErrorAction Stop
            Write-Host "[+] Updated: $targetPath" -ForegroundColor Green
        } else {
            Set-Content -Path $targetPath -Value $rulesBlock -ErrorAction Stop
            Write-Host "[+] Created: $targetPath" -ForegroundColor Green
        }
    }
    catch {
        Write-Host ""
        Write-Host "[X] ERROR: Cannot write to location" -ForegroundColor Red
        Write-Host "    Reason: $_" -ForegroundColor Gray
        Write-Host ""
        
        # Fallback to workspace if global failed
        if ($targetPath -eq $globalRulesPath) {
            Write-Host "[!] Fallback: Installing to workspace instead..." -ForegroundColor Yellow
            try {
                $fallbackPath = Join-Path $repoRoot ".gemini\GEMINI.md"
                $fallbackDir = Split-Path $fallbackPath
                if (-not (Test-Path $fallbackDir)) {
                    New-Item -ItemType Directory -Path $fallbackDir -Force | Out-Null
                }
                Set-Content -Path $fallbackPath -Value $rulesBlock -ErrorAction Stop
                Write-Host "[+] Installed to: $fallbackPath" -ForegroundColor Green
            }
            catch {
                Write-Host "[X] Fallback also failed: $_" -ForegroundColor Red
            }
        }
    }
}

function Install-RouterSkill {
    if (-not (Test-Path $routerSkillSource)) {
        return
    }

    try {
        if (-not (Test-Path $skillsRoot)) {
            New-Item -ItemType Directory -Path $skillsRoot -Force -ErrorAction Stop | Out-Null
        }

        if (Test-Path $routerSkillDest) {
            Remove-Item -Recurse -Force $routerSkillDest -ErrorAction Stop
        }

        Copy-Item -Path $routerSkillSource -Destination $routerSkillDest -Recurse -ErrorAction Stop
        Write-Host "Installed Codex skill: activate-skills"
        [Environment]::SetEnvironmentVariable("ANTIGRAVITY_OPTIMIZER_ROOT", $repoRoot.Path, "User")
    }
    catch {
        Write-Warning "Skipped Codex router skill install: $($_.Exception.Message)"
    }
}

function Repair-SkillYaml {
    <#
    .SYNOPSIS
        Repairs broken YAML frontmatter in SKILL.md files.
    .DESCRIPTION
        The upstream skills repo has files with invalid YAML that breaks Codex.
        This function auto-fixes these issues after skills are installed.
        
        Common issues fixed:
        - Empty multi-line descriptions: "description: |" with no content
        - Nested double quotes: description: "...says "hello"..."
        - Missing description field entirely
        
        This is designed to be future-proof and handle any number of nested quotes.
    #>
    
    Write-Host ""
    Write-Host "Validating skill files..." -ForegroundColor Gray
    
    $repaired = 0
    $failed = 0
    $verboseFailures = 0
    $skillDirs = @($skillsRoot, (Join-Path $repoRoot ".agent\skills"))
    
    foreach ($baseDir in $skillDirs) {
        if (-not (Test-Path $baseDir)) { continue }
        
        $skillFiles = Get-ChildItem -Path $baseDir -Filter "SKILL.md" -Recurse -ErrorAction SilentlyContinue
        
        foreach ($file in $skillFiles) {
            try {
                $content = Get-Content $file.FullName -Raw -ErrorAction Stop
                $originalContent = $content
                $needsRepair = $false
                
                # Issue 1: Empty multi-line description followed by another field
                # Pattern: "description: |\r\nsource:" or "description: |\nsource:"
                if ($content -match 'description:\s*\|\s*[\r\n]+\s*[a-z_]+:') {
                    # Extract the skill name for a generic description
                    $skillName = $file.Directory.Name
                    $content = $content -replace '(description:\s*)\|\s*([\r\n]+)', "`$1`"$skillName skill - no description provided.`"`$2"
                    $needsRepair = $true
                }
                
                # Issue 2: Nested double quotes in description (unlimited pairs)
                # Pattern: description: "...text "quoted text" more..."
                # Fix: Replace ALL inner quotes with single quotes using a loop
                # This handles any number of nested quote pairs, not just 4
                $maxIterations = 20  # Safety limit to prevent infinite loops
                $iteration = 0
                while ($content -match '(description:\s*"[^"]*)"([^"]*)"' -and $iteration -lt $maxIterations) {
                    # Replace the first pair of inner quotes with single quotes
                    $content = $content -replace '(description:\s*"[^"]*)"([^"]*)"', '$1''$2'''
                    $needsRepair = $true
                    $iteration++
                }
                
                # Issue 3: Description missing entirely (has name but no description)
                if ($content -match '^---\s*[\r\n]+name:\s*[^\r\n]+[\r\n]+(?!description:)' -and $content -notmatch 'description:') {
                    $skillName = $file.Directory.Name
                    $content = $content -replace '(^---\s*[\r\n]+name:\s*[^\r\n]+)([\r\n]+)', "`$1`r`ndescription: `"$skillName skill`"`$2"
                    $needsRepair = $true
                }

                # Issue 4: Risky/broken frontmatter quoting
                # - Converts double-quoted scalars to single-quoted to avoid invalid escapes (e.g. \')
                # - Repairs malformed single-quoted command hooks with inner single quotes
                $fmMatch = [regex]::Match($content, '(?s)^(---\s*\r?\n)(.*?)(\r?\n---\s*\r?\n)')
                if ($fmMatch.Success) {
                    $fm = $fmMatch.Groups[2].Value
                    $fmLines = $fm -split "`n"
                    $fmChanged = $false

                    for ($i = 0; $i -lt $fmLines.Count; $i++) {
                        $line = $fmLines[$i].TrimEnd("`r")

                        if ($line -match '^(\s*[A-Za-z0-9_-]+:\s*)"((?:[^"\\]|\\.)*)"\s*$') {
                            $prefix = $matches[1]
                            $value = $matches[2]
                            $value = $value -replace "\\'", "'"
                            $value = $value -replace '\\"', '"'
                            $value = $value -replace "'", "''"
                            $fmLines[$i] = "$prefix'$value'"
                            $fmChanged = $true
                            continue
                        }

                        if ($line -match '^(\s*[A-Za-z0-9_-]+:\s*)"(.+)$') {
                            $prefix = $matches[1]
                            $value = $matches[2].TrimEnd('"')
                            $value = $value -replace "\\'", "'"
                            $value = $value -replace '\\"', '"'
                            $value = $value -replace "'", "''"
                            $fmLines[$i] = "$prefix'$value'"
                            $fmChanged = $true
                            continue
                        }

                        if ($line -match "^(\s*command:\s*)'(.*)'\s*$") {
                            $prefix = $matches[1]
                            $value = $matches[2]
                            if ($value -match "(?<!')'(?!')") {
                                $value = $value -replace "''", "'"
                                $value = $value -replace '\\', '\\\\'
                                $value = $value -replace '"', '\"'
                                $fmLines[$i] = "$prefix`"$value`""
                                $fmChanged = $true
                            }
                        }
                    }

                    if ($fmChanged) {
                        $newFm = $fmLines -join "`n"
                        $restStart = $fmMatch.Index + $fmMatch.Length
                        $rest = if ($restStart -lt $content.Length) { $content.Substring($restStart) } else { "" }
                        $content = $fmMatch.Groups[1].Value + $newFm + $fmMatch.Groups[3].Value + $rest
                        $needsRepair = $true
                    }
                }
                
                if ($needsRepair -and $content -ne $originalContent) {
                    Set-Content -Path $file.FullName -Value $content -NoNewline
                    $repaired++
                }
            }
            catch {
                $failed++
                if ($verboseFailures -lt 10) {
                    Write-Verbose "Failed to process $($file.FullName): $_"
                }
                $verboseFailures++
            }
        }
    }
    
    if ($repaired -gt 0) {
        Write-Host "[+] Repaired $repaired skill files with YAML issues" -ForegroundColor Green
    } else {
        Write-Host "[+] All skill files validated OK" -ForegroundColor Green
    }
    
    if ($failed -gt 0) {
        Write-Host "[!] Failed to process $failed files" -ForegroundColor Yellow
        if ($verboseFailures -gt 10) {
            Write-Verbose "Suppressed $($verboseFailures - 10) additional verbose file errors."
        }
    }
}

function Show-VerificationReport {
    Write-Host ""
    Write-Host "-----------------------------------------------------------" -ForegroundColor White
    Write-Host "SKILLS VERIFICATION REPORT" -ForegroundColor Cyan
    Write-Host "-----------------------------------------------------------" -ForegroundColor White
    
    # Count installed skills in .agent/skills
    $agentSkillsIndex = Join-Path $repoRoot ".agent\skills\skills_index.json"
    $codexSkillsIndex = Join-Path $skillsRoot "skills_index.json"
    
    $installedCount = 0
    $sourceCount = 0
    
    # Get installed count
    if (Test-Path $agentSkillsIndex) {
        $installedCount = Get-SkillCountFromIndex -IndexPath $agentSkillsIndex
    }
    
    # Get source count from cache
    if (Test-Path $skillsIndex) {
        $sourceCount = Get-SkillCountFromIndex -IndexPath $skillsIndex
    }
    
    # Display results
    Write-Host ""
    Write-Host "  Source repo (sickn33):    $sourceCount skills" -ForegroundColor White
    Write-Host "  Installed locally:        $installedCount skills" -ForegroundColor White
    
    if ($installedCount -eq $sourceCount -and $installedCount -gt 0) {
        Write-Host ""
        Write-Host "  Status: " -NoNewline
        Write-Host "SYNCED" -ForegroundColor Green -NoNewline
        Write-Host " - You have all available skills!" -ForegroundColor White
    } elseif ($installedCount -lt $sourceCount) {
        $missing = $sourceCount - $installedCount
        Write-Host ""
        Write-Host "  Status: " -NoNewline
        Write-Host "PARTIAL" -ForegroundColor Yellow -NoNewline
        Write-Host " - Missing $missing skills. Run setup again." -ForegroundColor White
    } elseif ($installedCount -eq 0) {
        Write-Host ""
        Write-Host "  Status: " -NoNewline
        Write-Host "NOT INSTALLED" -ForegroundColor Red -NoNewline
        Write-Host " - Run .\setup.ps1 to install skills." -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "  Status: " -NoNewline
        Write-Host "OK" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "  Tip: Run '.\activate-skills.ps1 --verify' for detailed check" -ForegroundColor Gray
    Write-Host "-----------------------------------------------------------" -ForegroundColor White
}

Ensure-SkillsRepo
Install-Workflow
Install-GlobalRules
Install-RouterSkill
Repair-SkillYaml
Show-VerificationReport

# Ensure callers do not receive a stale non-zero code from handled external commands.
$global:LASTEXITCODE = 0

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
