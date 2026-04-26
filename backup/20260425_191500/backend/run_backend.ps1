$ErrorActionPreference = "Stop"

$backendRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$venvRoot = Join-Path $backendRoot ".venv"
$pythonExe = Join-Path $venvRoot "Scripts\\python.exe"
$uvicornExe = Join-Path $venvRoot "Scripts\\uvicorn.exe"
$requirements = Join-Path $backendRoot "requirements.txt"

if (!(Test-Path $venvRoot)) {
  Write-Host "Creating backend virtual environment..."
  python -m venv $venvRoot
}

if (!(Test-Path $pythonExe)) {
  throw "Python executable not found in virtual environment: $pythonExe"
}

Write-Host "Installing backend dependencies..."
& $pythonExe -m pip install --upgrade pip
& $pythonExe -m pip install -r $requirements

Write-Host "Starting NeuroLit engineering backend on http://127.0.0.1:8000"
Push-Location (Split-Path -Parent $backendRoot)
try {
  & $pythonExe -m uvicorn backend.main:app --host 127.0.0.1 --port 8000 --reload
} finally {
  Pop-Location
}
