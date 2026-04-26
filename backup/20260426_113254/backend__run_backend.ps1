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
$serveScript = Join-Path $backendRoot "serve_backend.ps1"
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

function Get-ListeningBackendPids {
  $processIds = New-Object System.Collections.Generic.HashSet[int]
  $pattern = "^\s*TCP\s+\S+:$Port\s+\S+\s+LISTENING\s+(\d+)\s*$"

  try {
    $netstatOutput = netstat -ano -p tcp 2>$null
    foreach ($line in $netstatOutput) {
      $match = [regex]::Match(
        [string]$line,
        $pattern,
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
      )
      if ($match.Success) {
        $null = $processIds.Add([int]$match.Groups[1].Value)
      }
    }
  } catch {
    # Ignore lookup failures and fall through.
  }

  return @([int[]]($processIds | ForEach-Object { $_ }))
}

function Stop-TrackedBackend {
  $processIds = New-Object System.Collections.Generic.HashSet[int]

  $tracked = Get-TrackedProcess
  if ($null -ne $tracked) {
    $null = $processIds.Add($tracked.Id)
  }

  foreach ($listeningPid in (Get-ListeningBackendPids)) {
    $null = $processIds.Add($listeningPid)
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
  $existingPids = Get-ListeningBackendPids
  if ($existingPids.Count -gt 0) {
    Set-Content -Path $pidFile -Value $existingPids[0] -Encoding UTF8
  }
  Write-Host "NeuroLit engineering backend is already running at $healthUrl"
  if ($existingPids.Count -gt 0) {
    Write-Host "PID: $($existingPids[0])"
  }
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
$launchCommand = 'start "" /min powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -BindHost {1} -Port {2}' -f $serveScript, $BindHost, $Port
Push-Location $projectRoot
try {
  & cmd.exe /c $launchCommand | Out-Null
} finally {
  Pop-Location
}

$started = $false
for ($attempt = 0; $attempt -lt 20; $attempt++) {
  Start-Sleep -Milliseconds 500

  if (Test-BackendHealthy) {
    $started = $true
    break
  }
}

if (!$started) {
  Stop-TrackedBackend
  throw "Engineering backend failed to start."
}

$listeningPids = Get-ListeningBackendPids
if ($listeningPids.Count -gt 0) {
  Set-Content -Path $pidFile -Value $listeningPids[0] -Encoding UTF8
}

Write-Host "NeuroLit engineering backend is running in the background."
if ($listeningPids.Count -gt 0) {
  Write-Host "PID: $($listeningPids[0])"
}
Write-Host "Stop it with: powershell -ExecutionPolicy Bypass -File .\backend\stop_backend.ps1"
