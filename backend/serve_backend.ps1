param(
  [string]$BindHost = "127.0.0.1",
  [int]$Port = 8000
)

$ErrorActionPreference = "Stop"

$backendRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $backendRoot
$pythonExe = Join-Path $backendRoot ".venv\Scripts\python.exe"
$runtimeRoot = Join-Path $backendRoot ".runtime"
$stdoutLog = Join-Path $runtimeRoot "backend.stdout.log"
$stderrLog = Join-Path $runtimeRoot "backend.stderr.log"

if (!(Test-Path $pythonExe)) {
  throw "Python executable not found in backend virtual environment: $pythonExe"
}

if (!(Test-Path $runtimeRoot)) {
  New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
}

Push-Location $projectRoot
try {
  & $pythonExe -m uvicorn backend.main:app --host $BindHost --port $Port 1>> $stdoutLog 2>> $stderrLog
} finally {
  Pop-Location
}
