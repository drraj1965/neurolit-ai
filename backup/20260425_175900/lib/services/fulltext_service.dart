import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class FullTextService {

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

  Future<String> downloadFullText({
    required String pmid,
    required String title,
    required String pmcId,
    String? topic,
  }) async {

    final baseDir = await getApplicationDocumentsDirectory();

    final now = DateTime.now();
    final year = now.year.toString();
    final month = _monthName(now.month);
    final dayFolder = "${now.day} $month $year";

    final folder = Directory(
      "${baseDir.path}/NeuroLit/FullText/$year/$month/$dayFolder/${topic ?? "General"}",
    );

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    // 🔹 Structured folders
    final fullTextDir = Directory("${folder.path}/fulltext");
    final summariesDir = Directory("${folder.path}/summaries");
    final exportsDir = Directory("${folder.path}/exports");

    if (!await fullTextDir.exists()) await fullTextDir.create(recursive: true);
    if (!await summariesDir.exists()) await summariesDir.create(recursive: true);
    if (!await exportsDir.exists()) await exportsDir.create(recursive: true);

    final safeTitle = _safeFileName(title);
    final pdfUrl = "https://pmc.ncbi.nlm.nih.gov/articles/$pmcId/pdf/";

    await Clipboard.setData(ClipboardData(text: pdfUrl));

    await launchUrl(Uri.parse(pdfUrl), mode: LaunchMode.externalApplication);

    final file = File("${fullTextDir.path}/${safeTitle}.txt");

    await file.writeAsString(
      "PMID: $pmid\n"
      "TITLE: $title\n"
      "PMC: $pmcId\n"
      "PDF URL: $pdfUrl\n"
      "DOWNLOADED: ${DateTime.now()}\n"
    );

    return "Opened in browser. Save PDF to:\n${fullTextDir.path}";
  }

  String _monthName(int m) {
    const names = [
      "", "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    return names[m];
  }
}
