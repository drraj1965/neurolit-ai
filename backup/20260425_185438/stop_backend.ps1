param(
  [int]$Port = 8000
)

$ErrorActionPreference = "Stop"

$backendRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$runtimeRoot = Join-Path $backendRoot ".runtime"
$pidFile = Join-Path $runtimeRoot "backend.pid"

function Stop-ProcessById {
  param([int]$ProcessId)

  try {
    Stop-Process -Id $ProcessId -Force -ErrorAction Stop
    return $true
  } catch {
    return $false
  }
}

$stoppedIds = @()

if (Test-Path $pidFile) {
  $rawPid = (Get-Content $pidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
  $parsedPid = 0
  if ([int]::TryParse(([string]$rawPid).Trim(), [ref]$parsedPid)) {
    if (Stop-ProcessById -ProcessId $parsedPid) {
      $stoppedIds += $parsedPid
      Write-Host "Stopped tracked NeuroLit engineering backend (PID $parsedPid)."
    }
  }

  Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
}

if ($stoppedIds.Count -eq 0) {
  try {
    $listeners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop
    foreach ($listener in $listeners) {
      if ($stoppedIds -contains $listener.OwningProcess) {
        continue
      }

      if (Stop-ProcessById -ProcessId $listener.OwningProcess) {
        $stoppedIds += $listener.OwningProcess
        Write-Host "Stopped backend process listening on port $Port (PID $($listener.OwningProcess))."
      }
    }
  } catch {
    # Ignore lookup failures and fall through to the final message.
  }
}

if ($stoppedIds.Count -eq 0) {
  Write-Host "No NeuroLit backend process was found on port $Port."
}
