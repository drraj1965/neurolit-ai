import 'dart:io';

import '../models/article.dart';

class ExportService {
  Future<File> exportAsText(
    List<Article> articles,
    String content,
    String mode,
  ) async {
    final username = Platform.environment['USERNAME'] ?? 'User';

    final dir = Directory(
      'C:/Users/$username/Documents/NeuroLit/Exports',
    );

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = File(
      '${dir.path}/NeuroLit_${mode}_${DateTime.now().millisecondsSinceEpoch}.txt',
    );

    String text = '';

    text += '============================================================\n';
    text += 'NEUROLIT EXPORT\n';
    text += 'MODE: $mode\n';
    text += 'DATE: ${DateTime.now()}\n';
    text += '============================================================\n\n';

    text += 'SELECTED ARTICLES\n\n';

    for (final a in articles) {
      text += 'TITLE: ${a.title}\n';
      text += 'AUTHORS: ${a.authors}\n';
      text += 'JOURNAL: ${a.journal} • ${a.date}\n';
      text += 'SOURCE: ${a.displaySource}\n';
      text += '${a.displayIdentifierLabel}: ${a.displayIdentifierValue}\n';
      if (a.link.trim().isNotEmpty) {
        text += 'LINK: ${a.link}\n';
      }
      if (a.pdfUrl.trim().isNotEmpty) {
        text += 'PDF_URL: ${a.pdfUrl}\n';
      }
      text += '\n';
    }

    text += '\n============================================================\n';
    text += 'CONTENT\n';
    text += '============================================================\n\n';

    text += content;

    await file.writeAsString(text);

    return file;
  }
}
