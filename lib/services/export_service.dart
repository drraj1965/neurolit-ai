import 'dart:io';

import '../models/article.dart';
import '../models/literature_mode.dart';
import 'mode_workspace_service.dart';

class ExportService {
  final ModeWorkspaceService workspaceService;

  ExportService({
    ModeWorkspaceService? workspaceService,
  }) : workspaceService = workspaceService ?? ModeWorkspaceService();

  Future<File> exportAsText(
    List<Article> articles,
    String content, {
    required String outputMode,
    required LiteratureMode literatureMode,
  }) async {
    final dir = await workspaceService.getExportsDirectory(literatureMode);

    final file = File(
      '${dir.path}/NeuroLit_${literatureMode.storageValue}_${outputMode}_${DateTime.now().millisecondsSinceEpoch}.txt',
    );

    String text = '';

    text += '============================================================\n';
    text += 'NEUROLIT EXPORT\n';
    text += 'MODE: ${literatureMode.displayName}\n';
    text += 'OUTPUT MODE: $outputMode\n';
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
