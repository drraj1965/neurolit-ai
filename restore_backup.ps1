$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backupTimestamp = "20260425_183900"
$backupRoot = Join-Path $projectRoot ("backup\" + $backupTimestamp)

$filesToRestore = @(
  "lib\models\literature_mode.dart",
  "lib\screens\home_screen.dart",
  "lib\screens\home\actions\home_search_actions.dart",
  "lib\screens\home\actions\home_review_actions.dart",
  "lib\screens\home\actions\home_collection_actions.dart",
  "lib\screens\home\actions\home_file_actions.dart",
  "lib\screens\home\widgets\sidebar_panel.dart",
  "lib\services\fulltext_service.dart",
  "lib\services\collection_service.dart",
  "lib\services\export_service.dart",
  "lib\services\layman\layman_service.dart"
)

$newFilesToRemove = @(
  "lib\services\mode_workspace_service.dart"
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

Write-Host "Restore complete from backup $backupTimestamp"
