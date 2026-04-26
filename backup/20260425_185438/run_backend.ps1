param(
  [switch]$Foreground,
  [switch]$ForceRestart,
  [string]$BindHost = "127.0.0.1",
  [int]$Port = 8000
)

$ErrorActionPreference = "Stop"

$backendRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $backendRoot
$venvRoot = Join-Path $backendRoot ".venv"
$pythonExe = Join-Path $venvRoot "Scripts\\python.exe"
$requirements = Join-Path $backendRoot "requirements.txt"
$runtimeRoot = Join-Path $backendRoot ".runtime"
$pidFile = Join-Path $runtimeRoot "backend.pid"
$stdoutLog = Join-Path $runtimeRoot "backend.stdout.log"
$stderrLog = Join-Path $runtimeRoot "backend.stderr.log"
$stampFile = Join-Path $runtimeRoot "requirements.installed.stamp"
$healthUrl = "http://$BindHost`:$Port/"

function Ensure-RuntimeDirectory {
  if (!(Test-Path $runtimeRoot)) {
    New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
  }
}

function Test-BackendHealthy {
  try {
    $response = Invoke-WebRequest -UseBasicParsing $healthUrl -TimeoutSec 2
    return $response.StatusCode -eq 200
  } catch {
    return $false
  }
}

function Get-TrackedProcess {
  if (!(Test-Path $pidFile)) {
    return $null
  }

  $rawPid = (Get-Content $pidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
  $parsedPid = 0
  if (![int]::TryParse(([string]$rawPid).Trim(), [ref]$parsedPid)) {
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    return $null
  }

  try {
    return Get-Process -Id $parsedPid -ErrorAction Stop
  } catch {
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    return $null
  }
}

function Stop-TrackedBackend {
  $processIds = New-Object System.Collections.Generic.HashSet[int]

  $tracked = Get-TrackedProcess
  if ($null -ne $tracked) {
    $null = $processIds.Add($tracked.Id)
  }

  try {
    $listeners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop
    foreach ($listener in $listeners) {
      $null = $processIds.Add($listener.OwningProcess)
    }
  } catch {
    # Ignore lookup failures and fall through to command-line matching.
  }

  try {
    $backendProcesses = Get-CimInstance Win32_Process -Filter "Name = 'python.exe' OR Name = 'pythonw.exe'"
    foreach ($process in $backendProcesses) {
      $commandLine = [string]$process.CommandLine
      if ($commandLine -like "*uvicorn*" -and $commandLine -like "*backend.main:app*") {
        $null = $processIds.Add([int]$process.ProcessId)
      }
    }
  } catch {
    # Ignore process-inspection failures.
  }

  foreach ($processId in $processIds) {
    try {
      Stop-Process -Id $processId -Force -ErrorAction Stop
    } catch {
      # Ignore already-exited processes.
    }
  }

  if ($processIds.Count -gt 0) {
    Start-Sleep -Seconds 1
  }

  if (Test-Path $pidFile) {
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
  }
}

function Ensure-BackendEnvironment {
  if (!(Test-Path $venvRoot)) {
    Write-Host "Creating backend virtual environment..."
    python -m venv $venvRoot
  }

  if (!(Test-Path $pythonExe)) {
    throw "Python executable not found in virtual environment: $pythonExe"
  }

  $installRequired = !(Test-Path $stampFile)
  if (!$installRequired) {
    $requirementsTime = (Get-Item $requirements).LastWriteTimeUtc
    $stampTime = (Get-Item $stampFile).LastWriteTimeUtc
    if ($requirementsTime -gt $stampTime) {
      $installRequired = $true
    }
  }

  if ($installRequired) {
    Write-Host "Installing backend dependencies..."
    & $pythonExe -m pip install --upgrade pip
    & $pythonExe -m pip install -r $requirements
    Set-Content -Path $stampFile -Value (Get-Date).ToString("o") -Encoding UTF8
  }
}

Ensure-RuntimeDirectory

if ($ForceRestart) {
  Stop-TrackedBackend
}

if (!$Foreground -and (Test-BackendHealthy)) {
  Write-Host "NeuroLit engineering backend is already running at $healthUrl"
  exit 0
}

Ensure-BackendEnvironment

if ($Foreground) {
  Write-Host "Starting NeuroLit engineering backend in foreground at $healthUrl"
  Push-Location $projectRoot
  try {
    & $pythonExe -m uvicorn backend.main:app --host $BindHost --port $Port --reload
  } finally {
    Pop-Location
  }
  exit 0
}

$tracked = Get-TrackedProcess
if ($null -ne $tracked -and !(Test-BackendHealthy)) {
  Stop-TrackedBackend
}

if (Test-Path $stdoutLog) {
  Remove-Item $stdoutLog -Force -ErrorAction SilentlyContinue
}
if (Test-Path $stderrLog) {
  Remove-Item $stderrLog -Force -ErrorAction SilentlyContinue
}

Write-Host "Starting NeuroLit engineering backend in background at $healthUrl"
$process = Start-Process `
  -FilePath $pythonExe `
  -ArgumentList "-m", "uvicorn", "backend.main:app", "--host", $BindHost, "--port", $Port `
  -WorkingDirectory $projectRoot `
  -WindowStyle Hidden `
  -RedirectStandardOutput $stdoutLog `
  -RedirectStandardError $stderrLog `
  -PassThru

Set-Content -Path $pidFile -Value $process.Id -Encoding UTF8

$started = $false
for ($attempt = 0; $attempt -lt 20; $attempt++) {
  Start-Sleep -Milliseconds 500

  if (Test-BackendHealthy) {
    $started = $true
    break
  }

  try {
    $null = Get-Process -Id $process.Id -ErrorAction Stop
  } catch {
    break
  }
}

if (!$started) {
  Stop-TrackedBackend
  $stderrPreview = ""
  if (Test-Path $stderrLog) {
    $stderrPreview = (Get-Content $stderrLog -ErrorAction SilentlyContinue | Select-Object -First 20) -join [Environment]::NewLine
  }

  throw "Engineering backend failed to start.`n`n$stderrPreview"
}

Write-Host "NeuroLit engineering backend is running in the background."
Write-Host "PID: $($process.Id)"
Write-Host "Stop it with: powershell -ExecutionPolicy Bypass -File .\backend\stop_backend.ps1"
