param(
  [string]$Version = "v1.1.1",
  [string]$InstallerPath = ".\release_artifacts\v1.1.1\NeuroLit_Setup.exe"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $scriptDir
Set-Location $root

$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
  Write-Warning "GitHub CLI (gh) is not installed or not in PATH."
  Write-Host "Manual release steps:"
  Write-Host "1. Open your GitHub repository in the browser."
  Write-Host "2. Open Releases."
  Write-Host "3. Draft a new release with tag $Version."
  Write-Host "4. Upload $InstallerPath."
  exit 0
}

if (-not (Test-Path $InstallerPath)) {
  throw "Installer not found: $InstallerPath"
}

$notes = @"
NeuroLit AI $Version

- safer Windows installer upgrades
- configurable NeuroLit data folder
- updated release automation
- refreshed user documentation
"@

gh release create $Version $InstallerPath --title "NeuroLit AI $Version" --notes $notes

Write-Host "GitHub Release created for $Version" -ForegroundColor Green
