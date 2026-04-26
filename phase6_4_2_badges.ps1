Write-Host "=== PHASE 6.4.2 — RESULT BADGES ==="

$file = "lib/screens/home_screen.dart"
$backup = "_phase6_4_2_backup"

# Backup
if (Test-Path $backup) {
    Remove-Item $backup -Recurse -Force
}
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item $file "$backup/home_screen.dart.bak"

Write-Host "Backup created."

$content = Get-Content $file -Raw

# -------------------------
# STEP 1 — Add helper widget
# -------------------------
if ($content -notmatch "Widget buildArticleBadges") {

$helper = @"

  Widget buildArticleBadges(Article a) {
    final badges = <Widget>[];

    if (a.isFree) {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text("Free article", style: TextStyle(fontSize: 12)),
      ));
    }

    if (a.isPMC) {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text("PMC", style: TextStyle(fontSize: 12)),
      ));
    }

    if (a.publicationType.toLowerCase().contains('review')) {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text("Review", style: TextStyle(fontSize: 12)),
      ));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: badges,
      ),
    );
  }

"@

$content = $content -replace "Widget buildFilterPanel\(\)", $helper + "`r`n  Widget buildFilterPanel()"
Write-Host "Added badge helper."
}

# -------------------------
# STEP 2 — Render badges in result tiles
# -------------------------
if ($content -notmatch "buildArticleBadges\(a\)") {

$content = $content -replace "Text\(""PMID: "" \+ a\.pmid\),", "Text(""PMID: "" + a.pmid),`r`n                buildArticleBadges(a),"
Write-Host "Inserted badges into result list."
}

# -------------------------
# VALIDATION
# -------------------------
if ($content -notmatch "buildArticleBadges") {
    Write-Host "❌ Helper missing — rolling back"
    Copy-Item "$backup/home_screen.dart.bak" $file -Force
    exit
}

if ($content -notmatch "buildArticleBadges\(a\)") {
    Write-Host "❌ Badge render missing — rolling back"
    Copy-Item "$backup/home_screen.dart.bak" $file -Force
    exit
}

# Save
Set-Content $file $content -Encoding UTF8

Write-Host ""
Write-Host "✅ PHASE 6.4.2 APPLIED"
Write-Host "Rollback if needed:"
Write-Host "Copy-Item $backup/home_screen.dart.bak lib/screens/home_screen.dart -Force"
Write-Host ""
Write-Host "Now run:"
Write-Host "flutter run -d windows"