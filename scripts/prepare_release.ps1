param(
  [string]$Version = "1.1.1"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $scriptDir
Set-Location $root

if (-not (Test-Path ".git")) {
  throw "This script must be run from inside the NeuroLit AI repository."
}

$dirty = git status --porcelain
if ($dirty) {
  throw "Working tree is not clean. Commit or stash changes before preparing a release."
}

Write-Host "Preparing NeuroLit AI release v$Version..." -ForegroundColor Cyan

flutter clean
flutter pub get

try {
  flutter analyze
} catch {
  Write-Warning "flutter analyze reported issues. Review them before publishing."
}

if (Test-Path ".\backend\build_backend.ps1") {
  powershell -ExecutionPolicy Bypass -File .\backend\build_backend.ps1 -Clean
}

flutter build windows --release

$iscc = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (Test-Path $iscc) {
  & $iscc ".\installer\NeuroLit_AI.iss"
} else {
  Write-Warning "Inno Setup compiler not found at: $iscc"
  Write-Warning "Compile installer manually before publishing the release."
}

$artifactDir = Join-Path $root "release_artifacts\v$Version"
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

$installer = ".\installer\output\NeuroLit_Setup.exe"
if (Test-Path $installer) {
  Copy-Item $installer (Join-Path $artifactDir "NeuroLit_Setup.exe") -Force
}

if (Test-Path ".\update.json") {
  Copy-Item ".\update.json" (Join-Path $artifactDir "update.json") -Force
}

if (Test-Path ".\README.md") {
  Copy-Item ".\README.md" (Join-Path $artifactDir "README.md") -Force
}

Write-Host ""
Write-Host "Release artifacts prepared in:" -ForegroundColor Green
Write-Host $artifactDir
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review git status"
Write-Host "2. Commit the version/release changes"
Write-Host "3. Create tag v$Version"
Write-Host "4. Push branch and tag"
Write-Host "5. Create the GitHub Release and upload $artifactDir\\NeuroLit_Setup.exe"
