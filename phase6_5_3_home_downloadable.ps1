Write-Host "=== PHASE 6.5.3 STEP 3 — HOME SCREEN DOWNLOADABLE UI ==="

$file = "lib/screens/home_screen.dart"
$backup = "_phase6_5_3_home_backup"

if (Test-Path $backup) {
    Remove-Item $backup -Recurse -Force
}
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item $file "$backup/home_screen.dart.bak"

Write-Host "Backup created."

$content = Get-Content $file -Raw

# 1. Add Downloadable badge
if ($content -notmatch 'Text\("Downloadable"') {
    $content = $content -replace 'if \(a\.isPMC\) \{[\s\S]*?\n    \}', @"
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

  if (a.canDownloadFullText) {
    badges.add(Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.purple.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text("Downloadable", style: TextStyle(fontSize: 12)),
    ));
  }
"@
    Write-Host "Added Downloadable badge."
}

# 2. Add dropdown option
if ($content -notmatch 'value: "downloadable_full_text"') {
    $content = $content -replace 'DropdownMenuItem\(value: "free_full_text", child: Text\("Free Full Text"\)\),', 'DropdownMenuItem(value: "free_full_text", child: Text("Free Full Text")),`r`n    DropdownMenuItem(value: "downloadable_full_text", child: Text("Downloadable Full Text")),'
    Write-Host "Added Downloadable Full Text filter option."
}

# 3. Update pagedArticles filter logic
$content = $content -replace "else if \(postFilterTextAvailability == 'free_full_text'\) \{`r?`n      matchText = a\.isFree \|\| a\.isPMC;`r?`n    \}", @"
else if (postFilterTextAvailability == 'free_full_text') {
      matchText = a.isFree || a.isPMC;
    } else if (postFilterTextAvailability == 'downloadable_full_text') {
      matchText = a.canDownloadFullText;
    }
"@

# 4. Update totalPages filter logic
$content = $content -replace "else if \(postFilterTextAvailability == 'free_full_text'\) \{`r?`n      matchText = a\.isFree \|\| a\.isPMC;`r?`n    \}", @"
else if (postFilterTextAvailability == 'free_full_text') {
      matchText = a.isFree || a.isPMC;
    } else if (postFilterTextAvailability == 'downloadable_full_text') {
      matchText = a.canDownloadFullText;
    }
"@

if ($content -notmatch "downloadable_full_text" -or $content -notmatch "canDownloadFullText") {
    Write-Host "❌ Validation failed. Rolling back."
    Copy-Item "$backup/home_screen.dart.bak" $file -Force
    exit
}

Set-Content $file $content -Encoding UTF8

Write-Host "✅ home_screen.dart updated successfully"
Write-Host "Rollback if needed:"
Write-Host "Copy-Item $backup/home_screen.dart.bak lib/screens/home_screen.dart -Force"