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

# Check for Python availability
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Error "Python is required but not found in PATH. Please install Python 3.6+ from https://python.org"
    exit 1
}

python $scriptPath @Task
