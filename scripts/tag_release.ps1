param(
  [string]$Version = "v1.1.1",
  [string]$CommitMessage = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $scriptDir
Set-Location $root

if (-not $CommitMessage) {
  $CommitMessage = "Release $Version"
}

git status
git add -A

$staged = git diff --cached --name-only
if (-not $staged) {
  throw "No staged changes detected after git add -A. Nothing to commit."
}

git commit -m $CommitMessage
git tag $Version
git push origin main
git push origin $Version

Write-Host "Release commit and tag created: $Version" -ForegroundColor Green
