Write-Host "=== FIX home_screen.dart recentSearch block ==="

$file = "lib/screens/home_screen.dart"
$backup = "_fix_recent_search_backup"

if (Test-Path $backup) {
    Remove-Item $backup -Recurse -Force
}
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item $file "$backup/home_screen.dart.bak"

Write-Host "Backup created."

$content = Get-Content $file -Raw

$pattern = [regex]::Escape(@"
    recentSearches.insert(0, entry);

// Limit to last 5 searches
if (recentSearches.length > 5) {
  recentSearches = recentSearches.sublist(0, 5);
}

// Save to preferences
await prefs.setStringList(
  'recent_searches_v1',
  recentSearches.map((e) => jsonEncode(e)).toList(),
);

if (!mounted) return;
setState(() {});

  Future<void> applyRecentSearch(Map<String, dynamic> entry) async {
"@)

$replacement = @"
    recentSearches.insert(0, entry);

    // Limit to last 5 searches
    if (recentSearches.length > 5) {
      recentSearches = recentSearches.sublist(0, 5);
    }

    // Save to preferences
    await prefs.setStringList(
      'recent_searches_v1',
      recentSearches.map((e) => jsonEncode(e)).toList(),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> applyRecentSearch(Map<String, dynamic> entry) async {
"@

$newContent = [regex]::Replace($content, $pattern, $replacement)

if ($newContent -eq $content) {
    Write-Host "❌ Target block not found. Restoring backup."
    Copy-Item "$backup/home_screen.dart.bak" $file -Force
    exit
}

Set-Content $file $newContent -Encoding UTF8

Write-Host "✅ Block fixed successfully"
Write-Host "Rollback if needed:"
Write-Host "Copy-Item $backup/home_screen.dart.bak lib/screens/home_screen.dart -Force"