Write-Host "=== STEP 3: FIX FILTER LOGIC ==="

$file = "lib/screens/home_screen.dart"
$backup = "_filter_fix_backup"

# Backup
if (Test-Path $backup) { Remove-Item $backup -Recurse -Force }
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item $file "$backup/home_screen.dart.bak"

Write-Host "Backup created."

$content = Get-Content $file -Raw

# Replace incorrect filter logic
$content = $content -replace "a\.link\.toLowerCase\(\)\.contains\('pmc'\)",
"a.isFree || a.isPMC"

Write-Host "Updated free full text logic."

# Ensure abstract logic is correct
$content = $content -replace "a\.abstractText\.isNotEmpty",
"a.abstractText.trim().isNotEmpty"

Write-Host "Updated abstract logic."

# Validate
if ($content -notmatch "a.isFree") {
    Write-Host "❌ Patch failed — rolling back"
    Copy-Item "$backup/home_screen.dart.bak" $file -Force
    exit
}

# Save
Set-Content $file $content -Encoding UTF8

Write-Host "✅ STEP 3 COMPLETE"