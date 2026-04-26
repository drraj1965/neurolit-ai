Write-Host "=== PHASE 6.1 STEP 3 — SAVE AS NEW FILE ==="

$file = "lib/screens/home_screen.dart"
$backup = "_step3_backup"

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
# ADD METHOD
# -------------------------
if ($content -notmatch "saveAsNewFile") {

$method = @"

  Future<void> saveAsNewFile(String contentText, List<Article> selected) async {
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();

    final folder = Directory(dir.path + "/NeuroLit_Exports");
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final file = File(folder.path + "/NeuroLit_" + outputMode + "_" + now.millisecondsSinceEpoch.toString() + ".txt");

    String text = "";
    text += "============================================================\n";
    text += "NEUROLIT EXPORT FILE\n";
    text += "MODE: " + outputMode + "\n";
    text += "DATE: " + now.toString() + "\n";
    text += "============================================================\n\n";

    text += "SELECTED ARTICLES\n\n";

    for (var a in selected) {
      text += "TITLE: " + a.title + "\n";
      text += "AUTHORS: " + a.authors + "\n";
      text += "JOURNAL: " + a.journal + " • " + a.date + "\n";
      text += "PMID: " + a.pmid + "\n";
      text += "LINK: " + a.link + "\n\n";
    }

    text += "\n============================================================\n";
    text += "AI OUTPUT\n";
    text += "============================================================\n\n";

    text += contentText;

    await file.writeAsString(text);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Saved as new file")),
    );
  }

"@

    # Insert before build() method
    $content = $content -replace "Widget build\(BuildContext context\)", $method + "`r`nWidget build(BuildContext context)"

    Write-Host "Added saveAsNewFile method."
}

# -------------------------
# ADD BUTTON IN AI MODAL
# -------------------------

if ($content -notmatch "Save as New File") {

$content = $content -replace 'child: const Text\("Copy"\),', 'child: const Text("Copy"),' + "`r`n            TextButton(`r`n              onPressed: () => saveAsNewFile(result, selectedArticles),`r`n              child: const Text(""Save as New File""),`r`n            ),"

Write-Host "Added Save as New File button."
}

# -------------------------
# VALIDATION
# -------------------------

if ($content -notmatch "saveAsNewFile") {
    Write-Host "❌ Method missing — rollback"
    Copy-Item "$backup/home_screen.dart.bak" $file -Force
    exit
}

if ($content -notmatch "Save as New File") {
    Write-Host "❌ Button missing — rollback"
    Copy-Item "$backup/home_screen.dart.bak" $file -Force
    exit
}

# -------------------------
# SAVE FILE
# -------------------------

Set-Content $file $content -Encoding UTF8

Write-Host ""
Write-Host "✅ STEP 3 COMPLETE"
Write-Host "Run:"
Write-Host "flutter run -d windows"