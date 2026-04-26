Write-Host "=== PHASE 6.2 — EXPORT SERVICE CREATION ==="

$path = "lib/services/export_service.dart"

if (Test-Path $path) {
    Write-Host "⚠️ File already exists. Skipping to avoid overwrite."
    exit
}

$content = @'
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../models/article.dart';

class ExportService {

  Future<File> exportAsText(
      List<Article> articles,
      String content,
      String mode) async {

    final dir = Directory('C:/Users/${Platform.environment['USERNAME']}/Documents/NeuroLit/Exports');

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = File(
        '${dir.path}/NeuroLit_${mode}_${DateTime.now().millisecondsSinceEpoch}.txt');

    String text = '';

    text += '============================================================\n';
    text += 'NEUROLIT EXPORT\n';
    text += 'MODE: $mode\n';
    text += 'DATE: ${DateTime.now()}\n';
    text += '============================================================\n\n';

    text += 'SELECTED ARTICLES\n\n';

    for (var a in articles) {
      text += '${a.title}\n';
      text += '${a.authors}\n';
      text += '${a.journal} • ${a.date}\n';
      text += 'PMID: ${a.pmid}\n';
      text += '${a.link}\n\n';
    }

    text += '\n============================================================\n';
    text += 'CONTENT\n';
    text += '============================================================\n\n';

    text += content;

    await file.writeAsString(text);

    return file;
  }

}
'@

New-Item -ItemType Directory -Force -Path "lib/services" | Out-Null
Set-Content $path $content -Encoding UTF8

Write-Host "✅ Export service created successfully" ".