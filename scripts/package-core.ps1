param(
    [string]$OutputDir = "dist",
    [string]$ArchiveName = "antigravity-optimizer-core.zip"
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$outDir = Join-Path $repoRoot $OutputDir
$archivePath = Join-Path $outDir $ArchiveName

$coreItems = @(
    "scripts/install.ps1",
    "tools",
    "workflows",
    "activate-skills.ps1",
    "activate-skills.cmd",
    "README.md",
    "LICENSE"
)

if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$tempDir = Join-Path $outDir "_core_staging"
if (Test-Path $tempDir) {
    Remove-Item -Recurse -Force $tempDir
}
New-Item -ItemType Directory -Path $tempDir | Out-Null

foreach ($item in $coreItems) {
    $source = Join-Path $repoRoot $item
    if (-not (Test-Path $source)) {
        Write-Error "Missing core item: $source"
        exit 1
    }
    Copy-Item -Path $source -Destination $tempDir -Recurse
}

if (Test-Path $archivePath) {
    Remove-Item -Force $archivePath
}

Compress-Archive -Path (Join-Path $tempDir "*") -DestinationPath $archivePath
Remove-Item -Recurse -Force $tempDir

Write-Host "Core release created: $archivePath"
