import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/article.dart';
import '../models/literature_mode.dart';
import 'mode_workspace_service.dart';

class FullTextService {
  final ModeWorkspaceService workspaceService;

  FullTextService({
    ModeWorkspaceService? workspaceService,
  }) : workspaceService = workspaceService ?? ModeWorkspaceService();

  String _safeFileName(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.length > 120) {
      return cleaned.substring(0, 120);
    }
    return cleaned;
  }

  Future<String> downloadForArticle({
    required Article article,
    String? topic,
  }) async {
    if (article.literatureMode == LiteratureMode.engineering) {
      return _openEngineeringPdf(
        article: article,
        topic: topic,
      );
    }

    return downloadFullText(
      pmid: article.displayIdentifierValue,
      title: article.title,
      pmcId: article.pmcId,
      topic: topic,
    );
  }

  Future<String> downloadFullText({
    required String pmid,
    required String title,
    required String pmcId,
    String? topic,
  }) async {
    final now = DateTime.now();
    final topicDir = await workspaceService.getTopicDirectory(
      mode: LiteratureMode.medical,
      date: now,
      topic: topic ?? "General",
    );
    final fullTextDir = await workspaceService.getFullTextArtifactsDirectory(
      mode: LiteratureMode.medical,
      date: now,
      topic: topic ?? "General",
    );
    final summariesDir = Directory("${topicDir.path}/summaries");
    final exportsDir = Directory("${topicDir.path}/exports");

    if (!await summariesDir.exists()) await summariesDir.create(recursive: true);
    if (!await exportsDir.exists()) await exportsDir.create(recursive: true);

    final safeTitle = _safeFileName(title);
    final pdfUrl = "https://pmc.ncbi.nlm.nih.gov/articles/$pmcId/pdf/";

    await Clipboard.setData(ClipboardData(text: pdfUrl));

    await launchUrl(Uri.parse(pdfUrl), mode: LaunchMode.externalApplication);

    final file = File('${fullTextDir.path}/$safeTitle.txt');

    await file.writeAsString(
      "PMID: $pmid\n"
      "TITLE: $title\n"
      "PMC: $pmcId\n"
      "PDF URL: $pdfUrl\n"
      "DOWNLOADED: $now\n",
    );

    return "Opened in browser. Save PDF to:\n${fullTextDir.path}";
  }

  Future<String> _openEngineeringPdf({
    required Article article,
    String? topic,
  }) async {
    if (article.pdfUrl.trim().isEmpty) {
      return "No PDF is available for this engineering article.";
    }

    final now = DateTime.now();
    final fullTextDir = await workspaceService.getFullTextArtifactsDirectory(
      mode: LiteratureMode.engineering,
      date: now,
      topic: topic ?? "General",
    );

    await Clipboard.setData(ClipboardData(text: article.pdfUrl));
    await launchUrl(
      Uri.parse(article.pdfUrl),
      mode: LaunchMode.externalApplication,
    );

    final safeTitle = _safeFileName(article.title);
    final file = File('${fullTextDir.path}/$safeTitle.txt');

    await file.writeAsString(
      "MODE: Engineering\n"
      "SOURCE: ${article.displaySource}\n"
      "TITLE: ${article.title}\n"
      "${article.displayIdentifierLabel}: ${article.displayIdentifierValue}\n"
      "LINK: $article.link\n"
      "PDF URL: $article.pdfUrl\n"
      "OPENED: $now\n",
    );

    return "Opened PDF in browser. Save file to:\n${fullTextDir.path}";
  }
}
