param(
  [string]$BindHost = "127.0.0.1",
  [int]$Port = 8000
)

$ErrorActionPreference = "Stop"

$backendRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $backendRoot
$pythonExe = Join-Path $backendRoot ".venv\Scripts\python.exe"

if (!(Test-Path $pythonExe)) {
  throw "Python executable not found in backend virtual environment: $pythonExe"
}

Push-Location $projectRoot
try {
  & $pythonExe -m uvicorn backend.main:app --host $BindHost --port $Port
} finally {
  Pop-Location
}
