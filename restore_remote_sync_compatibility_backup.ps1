$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backupRoot = Join-Path $projectRoot "backup\20260426_113254"

$restoreMap = @{
  "backend__run_backend.ps1" = "backend\run_backend.ps1"
  "backend__serve_backend.ps1" = "backend\serve_backend.ps1"
  "backend__stop_backend.ps1" = "backend\stop_backend.ps1"
  "lib__services__engineering_api_service.dart" = "lib\services\engineering_api_service.dart"
  "lib__services__ai__providers__openai_client.dart" = "lib\services\ai\providers\openai_client.dart"
  "lib__services__search_service.dart" = "lib\services\search_service.dart"
}

foreach ($entry in $restoreMap.GetEnumerator()) {
  $source = Join-Path $backupRoot $entry.Key
  $destination = Join-Path $projectRoot $entry.Value
  Copy-Item $source $destination -Force
}

$newFile = Join-Path $projectRoot "lib\services\local_backend_launcher_service.dart"
if (Test-Path $newFile) {
  Remove-Item $newFile -Force
}

Write-Host "Restored compatibility-pass files from $backupRoot"
