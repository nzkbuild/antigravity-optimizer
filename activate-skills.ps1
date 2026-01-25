param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Task
)

if (-not $Task -or $Task.Count -eq 0) {
    Write-Error "Usage: activate-skills <task text> | activate-skills --verify"
    exit 1
}

$scriptPath = Join-Path $PSScriptRoot "tools\skill_router.py"
if (-not (Test-Path $scriptPath)) {
    Write-Error "Router not found at $scriptPath"
    exit 1
}

python $scriptPath @Task
