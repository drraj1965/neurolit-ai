# ==============================
# PHASE 5.2C — OPEN FILE/FOLDER FIX
# ==============================

Write-Host "=== PHASE 5.2C OPEN FIX ==="

$BackupDir = "_phase5_2C_backup"

if (Test-Path $BackupDir) {
    Remove-Item $BackupDir -Recurse -Force
}

New-Item -ItemType Directory -Path $BackupDir | Out-Null

$homeFile = "lib/screens/home_screen.dart"

Copy-Item $homeFile "$BackupDir/home_screen.dart.bak"

Write-Host "Backup created."

$content = Get-Content $homeFile -Raw

# ==============================
# FIX OPEN FILE BUTTON
# ==============================

$content = $content -replace "Process.start\(currentSessionFile, \[\]\);",
"Process.start('notepad.exe', [currentSessionFile]);"

# ==============================
# FIX OPEN FOLDER BUTTON
# ==============================

$content = $content -replace "Process.start\(dir.path \+ ""/NeuroLit"", \[\]\);",
"Process.start('explorer.exe', [dir.path + '/NeuroLit']);"

# ==============================
# SAVE FILE
# ==============================

Set-Content $homeFile $content -Encoding UTF8

Write-Host ""
Write-Host "✅ OPEN FIX APPLIED"
Write-Host ""
Write-Host "Run:"
Write-Host "flutter run -d windows"