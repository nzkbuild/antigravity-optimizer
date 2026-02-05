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
function Test-PythonCmd {
    param(
        [Parameter(Mandatory)] [string]$Exe,
        [string[]]$Args = @()
    )
    try {
        $p = Start-Process -FilePath $Exe -ArgumentList ($Args + @("-V")) -NoNewWindow -PassThru -Wait -ErrorAction Stop
        return ($p.ExitCode -eq 0)
    } catch {
        return $false
    }
}

$pythonExe = $null
$pythonArgs = @()

if (Get-Command py -ErrorAction SilentlyContinue) {
    if (Test-PythonCmd -Exe "py" -Args @("-3")) {
        $pythonExe = "py"
        $pythonArgs = @("-3")
    }
}

if (-not $pythonExe -and (Get-Command python3 -ErrorAction SilentlyContinue)) {
    if (Test-PythonCmd -Exe "python3") {
        $pythonExe = "python3"
    }
}

if (-not $pythonExe -and (Get-Command python -ErrorAction SilentlyContinue)) {
    if (Test-PythonCmd -Exe "python") {
        $pythonExe = "python"
    }
}

if (-not $pythonExe) {
    Write-Error "Python is required but not found in PATH. Please install Python 3.6+ from https://python.org"
    exit 1
}

& $pythonExe @pythonArgs "$scriptPath" @Task
