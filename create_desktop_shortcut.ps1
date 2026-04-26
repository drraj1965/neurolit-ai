$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcherPath = Join-Path $projectRoot "launch_neurolit_app.vbs"
$appExe = Join-Path $projectRoot "build\windows\x64\runner\Release\neurolit_review_app.exe"
$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktopPath "NeuroLit App.lnk"

if (!(Test-Path $launcherPath)) {
  throw "Launcher script not found: $launcherPath"
}

if (!(Test-Path $appExe)) {
  throw "Windows app executable not found: $appExe"
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $launcherPath
$shortcut.WorkingDirectory = $projectRoot
$shortcut.IconLocation = "$appExe,0"
$shortcut.Description = "Launch NeuroLit App and start the local engineering backend automatically."
$shortcut.Save()

Write-Host "Desktop shortcut created at $shortcutPath"
