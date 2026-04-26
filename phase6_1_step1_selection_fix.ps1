Write-Host "=== SAFE PATCH: SELECTION FIX ==="

$backup = "_step1_backup"

if (Test-Path $backup) {
    Remove-Item $backup -Recurse -Force
}

New-Item -ItemType Directory -Path $backup | Out-Null

$file = "lib/screens/home_screen.dart"

Copy-Item $file "$backup/home_screen.dart.bak"

$content = Get-Content $file -Raw

# Replace selection variable
$content = $content -replace "Set<int> selected = \{\};", "Set<String> selectedPmids = {};"

# Replace checkbox usage
$content = $content -replace "selected.contains\(originalIndex\)", "selectedPmids.contains\(a.pmid\)"
$content = $content -replace "selected.add\(originalIndex\);", "selectedPmids.add\(a.pmid\);"
$content = $content -replace "selected.remove\(originalIndex\);", "selectedPmids.remove\(a.pmid\);"

# Replace AI selection mapping
$content = $content -replace "selected.map\(\(i\) => articles\[i\]\).toList\(\);", "articles.where((a) => selectedPmids.contains(a.pmid)).toList();"

Set-Content $file $content -Encoding UTF8

Write-Host "✅ STEP 1 COMPLETE"
Write-Host "Rollback:"
Write-Host "Copy-Item $backup\home_screen.dart.bak $file -Force"