Write-Host "=== PHASE 6.6 FIX — PMC PDF EXTRACTION ==="

$file = "lib/services/fulltext_service.dart"
$backup = "_phase6_6_fix_backup"

# Backup
if (!(Test-Path $backup)) {
    New-Item -ItemType Directory -Path $backup | Out-Null
}
Copy-Item $file "$backup/fulltext_service.dart.bak" -Force
Write-Host "Backup created."

$content = Get-Content $file -Raw

# Replace ONLY the downloadFullText method
$pattern = "Future<String> downloadFullText\([\s\S]*?return ""Saved \(PDF not directly accessible\):\\n\$\{file\.path\}"";\s*\}"

$replacement = @'
Future<String> downloadFullText({
  required String pmid,
  required String title,
  required String pmcId,
}) async {
  final baseDir = await getApplicationDocumentsDirectory();

  final now = DateTime.now();
  final year = now.year.toString();
  final month = _monthName(now.month);
  final dayFolder = "${now.day} $month $year";

  final folder = Directory(
    "${baseDir.path}/NeuroLit/FullText/$year/$month/$dayFolder",
  );

  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }

  final existing = await _findExistingFile(baseDir, pmid);
  if (existing != null) {
    return "Already downloaded:\n${existing.path}";
  }

  if (pmcId.isNotEmpty) {

    // 🔹 Attempt 1: direct endpoint
    final directUrl =
        "https://www.ncbi.nlm.nih.gov/pmc/articles/$pmcId/pdf/";

    final direct = await _tryDownloadPdf(
      directUrl,
      "${folder.path}/${pmid}_$pmcId.pdf",
    );

    if (direct != null) {
      return "PDF downloaded:\n$direct";
    }

    // 🔹 Attempt 2: fetch HTML and extract ANY PDF
    final htmlUrl =
        "https://www.ncbi.nlm.nih.gov/pmc/articles/$pmcId/";

    final html = await _fetchText(htmlUrl);

    if (html != null && html.isNotEmpty) {

      final regex = RegExp(
        r'href=["\']([^"\']+\.pdf)["\']',
        caseSensitive: false,
      );

      final matches = regex.allMatches(html);

      for (final m in matches) {
        final raw = m.group(1);
        if (raw == null) continue;

        String url;

        if (raw.startsWith('http')) {
          url = raw;
        } else if (raw.startsWith('/')) {
          url = "https://pmc.ncbi.nlm.nih.gov$raw";
        } else {
          url = "https://pmc.ncbi.nlm.nih.gov/articles/$pmcId/$raw";
        }

        final extracted = await _tryDownloadPdf(
          url,
          "${folder.path}/${pmid}_$pmcId.pdf",
        );

        if (extracted != null) {
          return "PDF downloaded:\n$extracted";
        }
      }
    }
  }

  // 🔹 Fallback
  final file = File("${folder.path}/$pmid.txt");

  var content = "";
  content += "PMID: $pmid\n";
  content += "TITLE: $title\n";
  content += "PMC: $pmcId\n";
  content += "PDF LINK:\nhttps://www.ncbi.nlm.nih.gov/pmc/articles/$pmcId/\n";
  content += "DOWNLOADED: ${DateTime.now()}\n";

  await file.writeAsString(content);

  return "Saved (PDF not directly accessible):\n${file.path}";
}
'@

$newContent = [regex]::Replace($content, $pattern, $replacement)

Set-Content -Path $file -Value $newContent -Encoding UTF8

Write-Host "Method replaced."

# Validation
$check = Get-Content $file -Raw

if ($check -match "_tryDownloadPdf" -and $check -match "\.pdf") {
    Write-Host "✅ Validation passed."
} else {
    Write-Host "❌ Validation failed — restoring backup"
    Copy-Item "$backup/fulltext_service.dart.bak" $file -Force
}

Write-Host ""
Write-Host "Rollback command:"
Write-Host "Copy-Item `"$backup/fulltext_service.dart.bak`" `"$file`" -Force"