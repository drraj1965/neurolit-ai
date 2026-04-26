$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backupRoot = Join-Path $projectRoot "backup\20260425_185438"

Copy-Item (Join-Path $backupRoot "run_backend.ps1") (Join-Path $projectRoot "backend\run_backend.ps1") -Force
Copy-Item (Join-Path $backupRoot "stop_backend.ps1") (Join-Path $projectRoot "backend\stop_backend.ps1") -Force

$serveScript = Join-Path $projectRoot "backend\serve_backend.ps1"
if (Test-Path $serveScript) {
  Remove-Item $serveScript -Force
}

Write-Host "Restored backend launcher scripts from $backupRoot"
