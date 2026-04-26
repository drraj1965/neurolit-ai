Write-Host "=== PHASE 7.3 — FOLDER REVIEW BUTTON (FIXED) ==="

$file = "lib/screens/home_screen.dart"
$backupDir = "_phase7_3_fix_backup"

if (!(Test-Path $file)) {
    Write-Host "ERROR: file not found"
    exit 1
}

if (Test-Path $backupDir) {
    Remove-Item $backupDir -Recurse -Force
}
New-Item -ItemType Directory -Path $backupDir | Out-Null
Copy-Item $file "$backupDir/home_screen.dart.bak" -Force

Write-Host "Backup created."

$content = Get-Content $file -Raw

# 1) Insert generateFromFolder() before build()
$functionBlock = @'

Future<void> generateFromFolder() async {
  final dir = await getApplicationDocumentsDirectory();
  final base = Directory("${dir.path}/NeuroLit/FullText");

  if (!await base.exists()) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No data folder found")),
    );
    return;
  }

  final files = base.listSync(recursive: true);
  final abstracts = <Map<String, String>>[];

  for (final f in files) {
    if (f is File && f.path.endsWith(".txt")) {
      final content = await f.readAsString();
      if (content.contains("ABSTRACT ENTRY")) {
        abstracts.add({
          "title": "From file",
          "authors": "",
          "abstract": content,
        });
      }
    }
  }

  if (abstracts.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No abstracts found")),
    );
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      title: Text("Generating Review"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Analyzing folder..."),
        ],
      ),
    ),
  );

  try {
    final result = await summary.generateMultiArticleSummary(abstracts);

    if (!mounted) return;
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("FOLDER REVIEW"),
        content: SingleChildScrollView(
          child: SelectableText(result),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  } catch (e) {
    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Folder review failed: $e")),
    );
  }
}

'@

if ($content -notmatch "Future<void> generateFromFolder\(\) async") {
    $content = $content -replace [regex]::Escape("@override"), "$functionBlock@override"
    Write-Host "Inserted generateFromFolder()."
} else {
    Write-Host "generateFromFolder() already present."
}

# 2) Insert button next to Generate AI Summary
$oldBlock = @'
      ElevatedButton(
        onPressed: generateSummary,
        child: const Text("Generate AI Summary"),
      ),
'@

$newBlock = @'
      ElevatedButton(
        onPressed: generateSummary,
        child: const Text("Generate AI Summary"),
      ),

      const SizedBox(width: 8),

      ElevatedButton(
        onPressed: generateFromFolder,
        child: const Text("Review from Folder"),
      ),
'@

if ($content -notmatch 'Review from Folder') {
    $content = $content.Replace($oldBlock, $newBlock)
    Write-Host "Inserted Review from Folder button."
} else {
    Write-Host "Review from Folder button already present."
}

# 3) Validate
$ok = $true
if ($content -notmatch "Future<void> generateFromFolder\(\) async") { $ok = $false }
if ($content -notmatch 'Review from Folder') { $ok = $false }

if (-not $ok) {
    Write-Host "VALIDATION FAILED. Restoring backup."
    Copy-Item "$backupDir/home_screen.dart.bak" $file -Force
    exit 1
}

Set-Content -Path $file -Value $content -Encoding UTF8

Write-Host "✅ Patch applied successfully."
Write-Host ""
Write-Host "Rollback:"
Write-Host "Copy-Item `"$backupDir/home_screen.dart.bak`" `"$file`" -Force"