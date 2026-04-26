Write-Host "=== FIXING TOGGLE BUTTON INSERTION ==="

$file = "lib/screens/home_screen.dart"
$backup = "_step2_button_fix_backup"

# -------------------------
# BACKUP
# -------------------------
if (Test-Path $backup) {
    Remove-Item $backup -Recurse -Force
}
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item $file "$backup/home_screen.dart.bak"

Write-Host "Backup created."

$content = Get-Content $file -Raw

# -------------------------
# SAFE INSERTION METHOD
# -------------------------

if ($content -match "Show Selected Only") {
    Write-Host "⚠️ Button already exists. Skipping."
} else {

    $lines = Get-Content $file

    $newLines = @()
    $inserted = $false

    foreach ($line in $lines) {

        $newLines += $line

        # Detect Generate AI Summary button line
        if ($line -match 'Generate AI Summary') {

            $newLines += ""
            $newLines += "        const SizedBox(height: 6),"
            $newLines += ""
            $newLines += "        ElevatedButton("
            $newLines += "          onPressed: () {"
            $newLines += "            setState(() {"
            $newLines += "              showSelectedOnly = !showSelectedOnly;"
            $newLines += "              currentPage = 0;"
            $newLines += "            });"
            $newLines += "          },"
            $newLines += "          child: Text("
            $newLines += "            showSelectedOnly ? 'Show All Articles' : 'Show Selected Only',"
            $newLines += "          ),"
            $newLines += "        ),"
            $newLines += ""

            $inserted = $true
        }
    }

    if (-not $inserted) {
        Write-Host "❌ Could not find insertion point. Restoring backup."
        Copy-Item "$backup/home_screen.dart.bak" $file -Force
        exit
    }

    $newLines | Set-Content $file -Encoding UTF8

    Write-Host "✅ Button inserted successfully."
}

# -------------------------
# VALIDATION
# -------------------------

$contentCheck = Get-Content $file -Raw

if ($contentCheck -notmatch "showSelectedOnly") {
    Write-Host "❌ Missing variable. Rolling back."
    Copy-Item "$backup/home_screen.dart.bak" $file -Force
    exit
}

if ($contentCheck -notmatch "Show Selected Only") {
    Write-Host "❌ Button not found after insert. Rolling back."
    Copy-Item "$backup/home_screen.dart.bak" $file -Force
    exit
}

Write-Host ""
Write-Host "✅ STEP 2 FULLY FIXED"
Write-Host "Run:"
Write-Host "flutter run -d windows"