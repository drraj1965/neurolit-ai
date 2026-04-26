$ErrorActionPreference = "Stop"

$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktopPath "NeuroLit App.lnk"

if (Test-Path $shortcutPath) {
  Remove-Item $shortcutPath -Force
  Write-Host "Removed desktop shortcut: $shortcutPath"
} else {
  Write-Host "Desktop shortcut not found: $shortcutPath"
}
