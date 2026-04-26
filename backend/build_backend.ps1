param(
  [switch]$Clean
)

$ErrorActionPreference = "Stop"

$backendRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$venvRoot = Join-Path $backendRoot ".venv"
$pythonExe = Join-Path $venvRoot "Scripts\python.exe"
$requirements = Join-Path $backendRoot "requirements.txt"
$distRoot = Join-Path $backendRoot "dist"
$distAppRoot = Join-Path $distRoot "neurolit_backend"
$buildRoot = Join-Path $backendRoot "build_pyinstaller"
$specPath = Join-Path $backendRoot "neurolit_backend.spec"
$serverScript = Join-Path $backendRoot "server.py"

function Get-PythonBootstrapCommand {
  $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
  if ($null -ne $pythonCommand) {
    return @{
      FilePath = $pythonCommand.Source
      Arguments = @("-m", "venv", $venvRoot)
    }
  }

  $pyCommand = Get-Command py -ErrorAction SilentlyContinue
  if ($null -ne $pyCommand) {
    return @{
      FilePath = $pyCommand.Source
      Arguments = @("-3", "-m", "venv", $venvRoot)
    }
  }

  throw "Python 3 was not found. Install Python 3.11+ and ensure either 'python' or 'py' is available on PATH."
}

if (!(Test-Path $venvRoot)) {
  Write-Host "Creating backend virtual environment..."
  $bootstrap = Get-PythonBootstrapCommand
  & $bootstrap.FilePath @($bootstrap.Arguments)
}

if (!(Test-Path $pythonExe)) {
  throw "Python executable not found in backend virtual environment: $pythonExe"
}

Write-Host "Installing backend dependencies..."
& $pythonExe -m pip install --upgrade pip
& $pythonExe -m pip install -r $requirements
& $pythonExe -m pip install pyinstaller

if ($Clean) {
  foreach ($path in @($distRoot, $buildRoot, $specPath)) {
    if (Test-Path $path) {
      Remove-Item $path -Recurse -Force
    }
  }
}

Write-Host "Building packaged engineering backend..."
& $pythonExe -m PyInstaller `
  --noconfirm `
  --clean `
  --onedir `
  --noconsole `
  --name neurolit_backend `
  --distpath $distRoot `
  --workpath $buildRoot `
  --specpath $backendRoot `
  --paths $backendRoot `
  --hidden-import uvicorn.logging `
  --hidden-import uvicorn.loops.auto `
  --hidden-import uvicorn.protocols.http.auto `
  --hidden-import uvicorn.protocols.websockets.auto `
  --hidden-import uvicorn.lifespan.on `
  --collect-all fastapi `
  --collect-all starlette `
  --collect-all anyio `
  --collect-all pydantic `
  --collect-all pydantic_core `
  --collect-all uvicorn `
  --collect-all websockets `
  --collect-all httptools `
  --collect-all h11 `
  $serverScript

$backendExe = Join-Path $distAppRoot "neurolit_backend.exe"
if (!(Test-Path $backendExe)) {
  throw "Packaged backend executable was not created: $backendExe"
}

Write-Host "Packaged backend ready at:"
Write-Host $distAppRoot
