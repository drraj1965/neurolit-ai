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

$processIds = New-Object System.Collections.Generic.HashSet[int]
$stoppedIds = New-Object System.Collections.Generic.List[int]

if (Test-Path $pidFile) {
  $rawPid = (Get-Content $pidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
  $parsedPid = 0
  if ([int]::TryParse(([string]$rawPid).Trim(), [ref]$parsedPid)) {
    $null = $processIds.Add($parsedPid)
  }
}

foreach ($listeningPid in (Get-ListeningBackendPids)) {
  $null = $processIds.Add($listeningPid)
}

foreach ($processId in $processIds) {
  if (Stop-ProcessById -ProcessId $processId) {
    $stoppedIds.Add($processId) | Out-Null
  }
}

if (Test-Path $pidFile) {
  Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
}

foreach ($stoppedId in $stoppedIds) {
  Write-Host "Stopped NeuroLit engineering backend process (PID $stoppedId)."
}

if ($stoppedIds.Count -eq 0) {
  if ($processIds.Count -gt 0) {
    Write-Host "Found backend listener(s) on port $Port, but they could not be stopped from this shell."
    exit 1
  }

  Write-Host "No NeuroLit backend process was found on port $Port."
}
