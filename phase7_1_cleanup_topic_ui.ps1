Write-Host "=== PHASE 7.1 CLEANUP — REMOVE DUPLICATES ==="

$file = "lib/screens/home_screen.dart"
$backupDir = "_phase7_1_cleanup_backup"

if (!(Test-Path $file)) {
    Write-Host "ERROR: file not found"
    exit
}

# Backup
if (Test-Path $backupDir) {
    Remove-Item $backupDir -Recurse -Force
}
New-Item -ItemType Directory -Path $backupDir | Out-Null
Copy-Item $file "$backupDir/home_screen.dart.bak" -Force

Write-Host "Backup created."

$content = Get-Content $file -Raw

# ----------------------------------------
# STEP 1 — REMOVE ALL duplicate blocks
# ----------------------------------------

$pattern = "Row\(\s*children:\s*\[\s*Checkbox\([\s\S]*?currentTopic != null\)\s*Text\([\s\S]*?\),\s*\],\s*\),"

$content = [regex]::Replace($content, $pattern, "")

Write-Host "Removed duplicate Related-search blocks."

# ----------------------------------------
# STEP 2 — INSERT SINGLE CLEAN BLOCK
# ----------------------------------------

$insert = @"

const SizedBox(height: 8),

Row(
  children: [
    Checkbox(
      value: isRelatedMode,
      onChanged: (v) {
        setState(() {
          isRelatedMode = v ?? false;
          if (!isRelatedMode) currentTopic = null;
        });
      },
    ),
    const Text("Related searches"),
    const SizedBox(width: 12),
    if (currentTopic != null)
      Text(
        "Topic: $currentTopic",
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
  ],
),

"@

# Insert AFTER TextField
$content = $content -replace "TextField\([\s\S]*?onSubmitted: \(_\) => search\(\),\s*\),", "`$0$insert"

Write-Host "Inserted single clean UI block."

# ----------------------------------------
# VALIDATION
# ----------------------------------------

$count = ([regex]::Matches($content, "Related searches")).Count

if ($count -eq 1) {
    Set-Content -Path $file -Value $content -Encoding UTF8
    Write-Host "✅ Validation passed — only ONE checkbox present."
} else {
    Write-Host "❌ Validation failed — restoring backup"
    Copy-Item "$backupDir/home_screen.dart.bak" $file -Force
    exit
}

Write-Host ""
Write-Host "Rollback command:"
Write-Host "Copy-Item `"$backupDir/home_screen.dart.bak`" `"$file`" -Force"