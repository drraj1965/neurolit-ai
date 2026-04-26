Write-Host "=== PHASE 7.2 — TOPIC FOLDER (SAFE) ==="

$file = "lib/services/fulltext_service.dart"
$backupDir = "_phase7_2_backup"

if (!(Test-Path $file)) {
    Write-Host "ERROR: file not found"
    exit
}

# Backup
if (Test-Path $backupDir) {
    Remove-Item $backupDir -Recurse -Force
}
New-Item -ItemType Directory -Path $backupDir | Out-Null
Copy-Item $file "$backupDir/fulltext_service.dart.bak" -Force

Write-Host "Backup created."

$content = Get-Content $file -Raw

# ----------------------------------------
# STEP 1 — Add topic parameter (SAFE)
# ----------------------------------------

$content = $content -replace `
"required String pmcId,", `
"required String pmcId,
    required String? topic,"

Write-Host "Added topic parameter."

# ----------------------------------------
# STEP 2 — Update ONLY base folder path
# ----------------------------------------

$content = $content -replace `
'NeuroLit/FullText/\$year/\$month/\$dayFolder', `
'NeuroLit/FullText/$year/$month/$dayFolder/${topic ?? "General"}'

Write-Host "Updated folder path."

# ----------------------------------------
# STEP 3 — Add subfolders (SAFE INSERT)
# ----------------------------------------

$insert = @"

    // 🔹 Structured folders
    final fullTextDir = Directory("${folder.path}/fulltext");
    final summariesDir = Directory("${folder.path}/summaries");
    final exportsDir = Directory("${folder.path}/exports");

    if (!await fullTextDir.exists()) await fullTextDir.create(recursive: true);
    if (!await summariesDir.exists()) await summariesDir.create(recursive: true);
    if (!await exportsDir.exists()) await exportsDir.create(recursive: true);

"@

$content = $content -replace `
"await folder.create\(recursive: true\);", `
"await folder.create(recursive: true);$insert"

Write-Host "Inserted subfolders."

# ----------------------------------------
# VALIDATION
# ----------------------------------------

if ($content -match "topic" -and $content -match "fulltext") {
    Set-Content -Path $file -Value $content -Encoding UTF8
    Write-Host "✅ Validation passed."
} else {
    Write-Host "❌ Validation failed — restoring backup"
    Copy-Item "$backupDir/fulltext_service.dart.bak" $file -Force
    exit
}

Write-Host ""
Write-Host "Rollback:"
Write-Host "Copy-Item `"$backupDir/fulltext_service.dart.bak`" `"$file`" -Force"