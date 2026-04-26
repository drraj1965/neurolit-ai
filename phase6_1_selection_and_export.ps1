# ==============================
# PHASE 6.1 — SELECTION + EXPORT IMPROVEMENTS
# ==============================

Write-Host "=== PHASE 6.1 SELECTION + EXPORT ==="

$BackupDir = "_phase6_1_backup"

if (Test-Path $BackupDir) {
    Remove-Item $BackupDir -Recurse -Force
}

New-Item -ItemType Directory -Path $BackupDir | Out-Null

$homeFile = "lib/screens/home_screen.dart"

Copy-Item $homeFile "$BackupDir/home_screen.dart.bak"

Write-Host "Backup created."

$content = Get-Content $homeFile -Raw

# ==============================
# 1. Replace selection system (index → PMID)
# ==============================

$content = $content -replace 'Set<int> selected = {};', 'Set<String> selectedPmids = {};'

# ==============================
# 2. Update checkbox logic
# ==============================

$content = $content -replace 'selected.contains\(originalIndex\)', 'selectedPmids.contains(a.pmid)'

$content = $content -replace 'selected.add\(originalIndex\);', 'selectedPmids.add(a.pmid);'

$content = $content -replace 'selected.remove\(originalIndex\);', 'selectedPmids.remove(a.pmid);'

# ==============================
# 3. Add toggle for selected-only view
# ==============================

if ($content -notmatch 'bool showSelectedOnly') {
    $content = $content -replace 'final int pageSize = 10;', "final int pageSize = 10;`r`n  bool showSelectedOnly = false;"
}

# ==============================
# 4. Modify pagedArticles getter
# ==============================

$content = $content -replace 'List<Article> get pagedArticles \{[^}]+\}', @'
List<Article> get pagedArticles {
  List<Article> source = showSelectedOnly
      ? articles.where((a) => selectedPmids.contains(a.pmid)).toList()
      : articles;

  final start = currentPage * pageSize;
  if (start >= source.length) return [];
  final end = (start + pageSize) > source.length
      ? source.length
      : (start + pageSize);
  return source.sublist(start, end);
}
'@

# ==============================
# 5. Add toggle button in UI
# ==============================

$content = $content -replace 'Generate AI Summary"\),', 'Generate AI Summary"),`r`n        const SizedBox(height: 6),`r`n        ElevatedButton(`r`n          onPressed: () {`r`n            setState(() {`r`n              showSelectedOnly = !showSelectedOnly;`r`n            });`r`n          },`r`n          child: Text(showSelectedOnly ? "Show All Articles" : "Show Selected Only"),`r`n        ),'

# ==============================
# 6. Fix selectedArticles creation
# ==============================

$content = $content -replace 'final selectedArticles = selected.map\(\(i\) => articles\[i\]\).toList\(\);', @'
final selectedArticles = articles
    .where((a) => selectedPmids.contains(a.pmid))
    .toList();
'@

# ==============================
# 7. Add Save-as-new-file function
# ==============================

if ($content -notmatch 'saveAsNewFile') {
    $content = $content -replace 'Future<void> generateSummary\(\) async \{', @'

Future<void> saveAsNewFile(String contentText, List<Article> selectedArticles) async {
  final dir = await getApplicationDocumentsDirectory();
  final now = DateTime.now();

  final folder = Directory(dir.path + "/NeuroLit");
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }

  final fileName = "NeuroLit_" +
      (outputMode == "teaching" ? "Teaching" : "Review") +
      "_" +
      now.millisecondsSinceEpoch.toString() +
      ".txt";

  final file = File(folder.path + "/" + fileName);

  String text = "SELECTED ARTICLES\n\n";

  for (var a in selectedArticles) {
    text += a.title + "\n";
    text += a.authors + "\n";
    text += a.journal + " • " + a.date + "\n";
    text += a.link + "\n\n";
  }

  text += "========================================\n";
  text += (outputMode == "teaching" ? "TEACHING SYNOPSIS\n\n" : "REVIEW\n\n");
  text += contentText;

  await file.writeAsString(text);

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("Saved as new file")),
  );
}

Future<void> generateSummary() async {
'@
}

# ==============================
# 8. Add button in dialog
# ==============================

$content = $content -replace 'child: const Text\("Close"\),', @'
child: const Text("Close"),
          ),
          TextButton(
            onPressed: () => saveAsNewFile(result, selectedArticles),
            child: const Text("Save as New File"),
          ),
'@

Set-Content $homeFile $content -Encoding UTF8

Write-Host ""
Write-Host "✅ PHASE 6.1 APPLIED"
Write-Host ""
Write-Host "Rollback:"
Write-Host "Copy-Item $BackupDir\home_screen.dart.bak lib\screens\home_screen.dart -Force"