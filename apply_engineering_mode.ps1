$ErrorActionPreference = "Stop"

param(
  [string]$TargetRoot = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

$sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupRoot = Join-Path $TargetRoot ("backup\" + $timestamp)

$existingFiles = @(
  "lib\models\article.dart",
  "lib\screens\home_screen.dart",
  "lib\screens\home\actions\home_search_actions.dart",
  "lib\screens\home\actions\home_review_actions.dart",
  "lib\screens\home\actions\home_collection_actions.dart",
  "lib\screens\home\actions\home_file_actions.dart",
  "lib\screens\home\widgets\search_section.dart",
  "lib\screens\home\widgets\article_card.dart",
  "lib\screens\home\widgets\sidebar_panel.dart",
  "lib\services\fulltext_service.dart",
  "lib\services\collection_service.dart",
  "lib\services\export_service.dart",
  "lib\services\layman\layman_service.dart",
  "lib\services\ui\modal_service.dart"
)

$newFiles = @(
  "lib\models\literature_mode.dart",
  "lib\services\engineering_api_service.dart",
  "lib\services\mode_workspace_service.dart",
  "lib\services\search_service.dart",
  "backend\__init__.py",
  "backend\engineering_service.py",
  "backend\main.py",
  "backend\requirements.txt"
)

$filesToApply = $existingFiles + $newFiles

foreach ($relativePath in $filesToApply) {
  $targetFile = Join-Path $TargetRoot $relativePath
  if (Test-Path $targetFile) {
    $backupFile = Join-Path $backupRoot $relativePath
    $backupDir = Split-Path -Parent $backupFile
    if (!(Test-Path $backupDir)) {
      New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }
    Copy-Item $targetFile $backupFile -Force
  }
}

foreach ($relativePath in $filesToApply) {
  $sourceFile = Join-Path $sourceRoot $relativePath
  if (!(Test-Path $sourceFile)) {
    throw "Source file not found: $sourceFile"
  }

  $targetFile = Join-Path $TargetRoot $relativePath
  $targetDir = Split-Path -Parent $targetFile
  if (!(Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
  }

  Copy-Item $sourceFile $targetFile -Force
}

$restoreScriptPath = Join-Path $TargetRoot "restore_backup.ps1"
$restoreScript = @"
`$ErrorActionPreference = "Stop"

`$projectRoot = Split-Path -Parent `$MyInvocation.MyCommand.Path
`$backupTimestamp = "$timestamp"
`$backupRoot = Join-Path `$projectRoot ("backup\" + `$backupTimestamp)

`$filesToRestore = @(
$(($existingFiles | ForEach-Object { '  "' + $_ + '"' }) -join ",`r`n")
)

`$newFilesToRemove = @(
$(($newFiles | ForEach-Object { '  "' + $_ + '"' }) -join ",`r`n")
)

if (!(Test-Path `$backupRoot)) {
  throw "Backup folder not found: `$backupRoot"
}

foreach (`$relativePath in `$filesToRestore) {
  `$backupFile = Join-Path `$backupRoot `$relativePath
  `$targetFile = Join-Path `$projectRoot `$relativePath

  if (!(Test-Path `$backupFile)) {
    throw "Missing backup file: `$backupFile"
  }

  `$targetDir = Split-Path -Parent `$targetFile
  if (!(Test-Path `$targetDir)) {
    New-Item -ItemType Directory -Path `$targetDir -Force | Out-Null
  }

  Copy-Item `$backupFile `$targetFile -Force
}

foreach (`$relativePath in `$newFilesToRemove) {
  `$targetFile = Join-Path `$projectRoot `$relativePath
  if (Test-Path `$targetFile) {
    Remove-Item `$targetFile -Force
  }
}

Write-Host "Restore complete from backup `$backupTimestamp"
"@

Set-Content -Path $restoreScriptPath -Value $restoreScript -Encoding UTF8

Write-Host "Engineering mode applied."
Write-Host "Backup created at: $backupRoot"
Write-Host "Rollback script written to: $restoreScriptPath"
