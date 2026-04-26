# ==============================
# PHASE 5.2B SAFE PATCH (FIXED)
# ==============================

Write-Host "=== PHASE 5.2B FIXED PATCH ==="

$BackupDir = "_phase5_2B_fix_backup"

if (Test-Path $BackupDir) {
    Remove-Item $BackupDir -Recurse -Force
}

New-Item -ItemType Directory -Path $BackupDir | Out-Null

$homeFile = "lib/screens/home_screen.dart"

Copy-Item $homeFile "$BackupDir/home_screen.dart.bak"

Write-Host "Backup created."

$content = Get-Content $homeFile -Raw

# ==============================
# PATCH 1 — SEARCH HOOK
# ==============================

if ($content -notmatch "createSessionFile\(controller.text\)") {

    $content = $content -replace "void search\(\) async {", "void search() async {

    await createSessionFile(controller.text);"
}

# ==============================
# PATCH 2 — ABSTRACT SAVE HOOK (SAFE INSERT)
# ==============================

if ($content -notmatch "appendToSession\(a.abstractText\)") {

    $content = $content -replace "void openAbstract\(Article a\) {", "void openAbstract(Article a) {

    appendToSession(a.abstractText);"
}

# ==============================
# PATCH 3 — AI SUMMARY SAVE HOOK
# ==============================

if ($content -notmatch "appendToSession\(result\)") {

    $content = $content -replace "final review =", "await appendToSession(result);

    final review ="
}

# ==============================
# SAVE FILE
# ==============================

Set-Content $homeFile $content -Encoding UTF8

Write-Host ""
Write-Host "✅ PHASE 5.2B FIX APPLIED"
Write-Host ""
Write-Host "Run:"
Write-Host "flutter run -d windows"