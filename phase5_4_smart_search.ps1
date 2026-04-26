# ==============================
# PHASE 5.4 SMART SEARCH FALLBACK
# ==============================

Write-Host "=== PHASE 5.4 SMART SEARCH ==="

$BackupDir = "_phase5_4_backup"

if (Test-Path $BackupDir) {
    Remove-Item $BackupDir -Recurse -Force
}

New-Item -ItemType Directory -Path $BackupDir | Out-Null

$apiFile = "lib/services/api_service.dart"
$homeFile = "lib/screens/home_screen.dart"

Copy-Item $apiFile "$BackupDir/api_service.dart.bak"
Copy-Item $homeFile "$BackupDir/home_screen.dart.bak"

Write-Host "Backup created."

# ==============================
# PATCH API SERVICE (ADD FALLBACK)
# ==============================

$content = Get-Content $apiFile -Raw

$content = $content -replace "Future<List<Article>> searchArticles\(String query, String dateFilter\) async {",
"Future<List<Article>> searchArticles(String query, String dateFilter, {bool fallback = false}) async {"

$content = $content -replace "if \(ids.isEmpty\) return \[\];",
"
if (ids.isEmpty && fallback) {
  // Retry with 1 year
  return await searchArticles(query, '1y');
}

if (ids.isEmpty) return [];
"

Set-Content $apiFile $content -Encoding UTF8

# ==============================
# PATCH UI (ADD CHECKBOX + MESSAGE)
# ==============================

$content = Get-Content $homeFile -Raw

# Add variable
$content = $content -replace "String dateFilter = ""1y"";",
"String dateFilter = ""1y"";
bool autoExpand = false;"

# Add checkbox UI
$content = $content -replace "DropdownButton<String>\(",
"Column(children: [
DropdownButton<String>("

$content = $content -replace "\),\s*ElevatedButton",
"),
CheckboxListTile(
  title: Text('Auto-expand search (1 year fallback)'),
  value: autoExpand,
  onChanged: (v) {
    setState(() {
      autoExpand = v!;
    });
  },
),
ElevatedButton"

# Modify search call
$content = $content -replace "final result = await api.searchArticles\(query, dateFilter\);",
"
final result = await api.searchArticles(query, dateFilter, fallback: autoExpand);

if (result.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('No results found. Try expanding date range.'),
    ),
  );
}
"

Set-Content $homeFile $content -Encoding UTF8

Write-Host ""
Write-Host "✅ PHASE 5.4 COMPLETE"
Write-Host "Run:"
Write-Host "flutter run -d windows"