$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backupRoot = Join-Path $projectRoot "backup\20260426_172836"

$restoreMap = @{
  "installer__NeuroLit_AI.iss" = "installer\NeuroLit_AI.iss"
  "lib__services__local_backend_launcher_service.dart" = "lib\services\local_backend_launcher_service.dart"
  "launch_neurolit_app.vbs" = "launch_neurolit_app.vbs"
  "backend__run_backend.ps1" = "backend\run_backend.ps1"
  "backend__serve_backend.ps1" = "backend\serve_backend.ps1"
}

foreach ($entry in $restoreMap.GetEnumerator()) {
  $source = Join-Path $backupRoot $entry.Key
  $destination = Join-Path $projectRoot $entry.Value
  if (Test-Path $source) {
    Copy-Item $source $destination -Force
  }
}

foreach ($path in @(
  "backend\server.py",
  "backend\build_backend.ps1",
  "backend\build_backend.cmd"
)) {
  $target = Join-Path $projectRoot $path
  if (Test-Path $target) {
    Remove-Item $target -Force
  }
}

Write-Host "Restored packaged-backend distribution files from $backupRoot"
