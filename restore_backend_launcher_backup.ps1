$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backupTimestamp = "20260425_191500"
$backupRoot = Join-Path $projectRoot ("backup\" + $backupTimestamp)

$filesToRestore = @(
  "backend\run_backend.ps1",
  "backend\run_backend.cmd",
  "lib\services\engineering_api_service.dart"
)

$newFilesToRemove = @(
  "backend\stop_backend.ps1"
)

if (!(Test-Path $backupRoot)) {
  throw "Backup folder not found: $backupRoot"
}

foreach ($relativePath in $filesToRestore) {
  $backupFile = Join-Path $backupRoot $relativePath
  $targetFile = Join-Path $projectRoot $relativePath

  if (!(Test-Path $backupFile)) {
    throw "Missing backup file: $backupFile"
  }

  $targetDir = Split-Path -Parent $targetFile
  if (!(Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
  }

  Copy-Item $backupFile $targetFile -Force
}

foreach ($relativePath in $newFilesToRemove) {
  $targetFile = Join-Path $projectRoot $relativePath
  if (Test-Path $targetFile) {
    Remove-Item $targetFile -Force
  }
}

Write-Host "Backend launcher restore complete from backup $backupTimestamp"
