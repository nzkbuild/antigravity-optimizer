param(
    [switch]$AddPath,
    [switch]$Force
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$workflowDir = Join-Path $env:USERPROFILE ".gemini\antigravity\global_workflows"
$workflowTarget = Join-Path $workflowDir "activate-skills.md"
$templatePath = Join-Path $repoRoot "workflows\activate-skills.md"

if (-not (Test-Path $templatePath)) {
    Write-Error "Template not found: $templatePath"
    exit 1
}

New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null

if ((Test-Path $workflowTarget) -and -not $Force) {
    Write-Error "Workflow already exists: $workflowTarget (use -Force to overwrite)"
    exit 1
}

$template = Get-Content -Path $templatePath -Raw
$template = $template -replace "\{\{REPO_ROOT\}\}", $repoRoot.Path
Set-Content -Path $workflowTarget -Value $template

Write-Host "Installed workflow: $workflowTarget"

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
