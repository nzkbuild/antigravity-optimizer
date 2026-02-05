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

# Check for Python availability (prefer Windows launcher, then python3, then python)
$pythonExe = $null
$pythonArgs = @()

$pyLauncher = Get-Command py -ErrorAction SilentlyContinue
if ($pyLauncher) {
    $pythonExe = "py"
    $pythonArgs = @("-3")
} else {
    $python3 = Get-Command python3 -ErrorAction SilentlyContinue
    if ($python3) {
        $pythonExe = "python3"
    } else {
        $python = Get-Command python -ErrorAction SilentlyContinue
        if ($python) {
            $pythonExe = "python"
        }
    }
}

if (-not $pythonExe) {
    Write-Error "Python is required but not found in PATH. Please install Python 3.6+ from https://python.org"
    exit 1
}

& $pythonExe @pythonArgs "$scriptPath" @Task
