Write-Host "=== PHASE 6.5.1 — FULL TEXT SERVICE ==="

$path = "lib/services/fulltext_service.dart"
$backup = "_phase6_5_1_fulltext_backup"

New-Item -ItemType Directory -Force -Path $backup | Out-Null

if (Test-Path $path) {
    Copy-Item $path "$backup/fulltext_service.dart.bak"
    Write-Host "Backup created."
}

@'
import 'dart:io';
import 'package:intl/intl.dart';

class FullTextService {

  Future<String> downloadFullText({
    required String pmid,
    required String title,
    required String pmcId,
  }) async {

    try {
      final now = DateTime.now();

      final year = DateFormat('yyyy').format(now);
      final monthName = DateFormat('MMMM').format(now);
      final dayFolder = DateFormat('d MMMM yyyy').format(now);

      final baseDir = Directory(
        'C:/Users/${Platform.environment['USERNAME']}/Documents/NeuroLit/FullText/$year/$monthName/$dayFolder'
      );

      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      // Monthly index file
      final monthFile = File(
        'C:/Users/${Platform.environment['USERNAME']}/Documents/NeuroLit/FullText/$year/$monthName/downloads_${monthName}_$year.txt'
      );

      if (!await monthFile.exists()) {
        await monthFile.create(recursive: true);
      }

      final existing = await monthFile.readAsString();

      // 🔴 DUPLICATE CHECK
      if (existing.contains("PMID: $pmid")) {
        final lines = existing.split('\n');
        String foundPath = '';

        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains("PMID: $pmid")) {
            for (int j = i; j < i + 5 && j < lines.length; j++) {
              if (lines[j].startsWith("PATH:")) {
                foundPath = lines[j].replaceFirst("PATH: ", "");
              }
            }
          }
        }

        return "ALREADY_EXISTS::$foundPath";
      }

      // 🔽 Build PMC download URL
      final url = "https://www.ncbi.nlm.nih.gov/pmc/articles/$pmcId/pdf/";

      final filePath = "${baseDir.path}/$pmid.pdf";

      // NOTE: For now, we are saving URL reference (actual PDF download comes next step)
      final file = File(filePath);
      await file.writeAsString("PDF SOURCE:\n$url");

      // 📝 Append to monthly index
      final entry = """
============================================================
PMID: $pmid
TITLE: $title
PATH: $filePath
DATE: ${now.toString()}
============================================================

""";

      await monthFile.writeAsString(entry, mode: FileMode.append);

      return "DOWNLOADED::$filePath";

    } catch (e) {
      return "ERROR::$e";
    }
  }
}
'@ | Set-Content $path -Encoding UTF8

Write-Host ""
Write-Host "✅ FullTextService created successfully"
Write-Host ""
Write-Host "Next: integrate button in UI"