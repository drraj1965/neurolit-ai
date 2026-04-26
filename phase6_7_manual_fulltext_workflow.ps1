Write-Host "=== PHASE 6.7 MANUAL FULLTEXT WORKFLOW ==="

$file = "lib/services/fulltext_service.dart"
$backupDir = "_phase6_7_backup"

if (!(Test-Path $file)) {
    Write-Host "ERROR: $file not found"
    exit 1
}

if (Test-Path $backupDir) {
    Remove-Item $backupDir -Recurse -Force
}
New-Item -ItemType Directory -Path $backupDir | Out-Null
Copy-Item $file "$backupDir/fulltext_service.dart.bak" -Force

Write-Host "Backup created: $backupDir/fulltext_service.dart.bak"

$newContent = @'
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class FullTextService {
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

    final existingMarker = await _findExistingMarker(baseDir, pmid);
    if (existingMarker != null) {
      final previousFolder = existingMarker.parent.path;
      return "Already prepared before.\nFolder:\n$previousFolder";
    }

    final articleUrl = pmcId.isNotEmpty
        ? "https://www.ncbi.nlm.nih.gov/pmc/articles/$pmcId/"
        : "";

    String? pdfUrl;
    if (articleUrl.isNotEmpty) {
      final html = await _fetchText(articleUrl);
      if (html != null && html.isNotEmpty) {
        pdfUrl = _extractPdfUrlFromHtml(html, pmcId);
      }
    }

    pdfUrl ??= pmcId.isNotEmpty
        ? "https://pmc.ncbi.nlm.nih.gov/articles/$pmcId/pdf/main.pdf"
        : articleUrl;

    await Clipboard.setData(ClipboardData(text: pdfUrl));

    final uri = Uri.parse(pdfUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    final marker = File("${folder.path}/${pmid}_manual_download.txt");

    final content = StringBuffer()
      ..writeln("PMID: $pmid")
      ..writeln("TITLE: $title")
      ..writeln("PMC: $pmcId")
      ..writeln("ARTICLE URL: $articleUrl")
      ..writeln("PDF URL: $pdfUrl")
      ..writeln("TARGET FOLDER: ${folder.path}")
      ..writeln("BROWSER OPENED: $opened")
      ..writeln("DOWNLOADED: ${DateTime.now()}")
      ..writeln()
      ..writeln("INSTRUCTION:")
      ..writeln("PDF opened in browser.")
      ..writeln("Please download or print the file into this folder:")
      ..writeln(folder.path);

    await marker.writeAsString(content.toString());

    if (!opened) {
      return "PDF URL copied to clipboard.\nCould not open browser automatically.\nSave file into:\n${folder.path}";
    }

    return "PDF opened in browser.\nURL copied to clipboard.\nPlease save into:\n${folder.path}";
  }

  Future<File?> _findExistingMarker(Directory baseDir, String pmid) async {
    final root = Directory("${baseDir.path}/NeuroLit/FullText");

    if (!await root.exists()) return null;

    final files = root.listSync(recursive: true);
    for (final f in files) {
      if (f is File &&
          f.path.contains(pmid) &&
          f.path.endsWith("_manual_download.txt")) {
        return f;
      }
    }
    return null;
  }

  Future<String?> _fetchText(String url) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, "Mozilla/5.0");
      final response = await request.close();

      if (response.statusCode != 200) {
        client.close(force: true);
        return null;
      }

      final bytes = await consolidateBytes(response);
      client.close(force: true);
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  String? _extractPdfUrlFromHtml(String html, String pmcId) {
    final patterns = <RegExp>[
      RegExp(r'href="([^"]*/pdf/[^"]+\.pdf)"', caseSensitive: false),
      RegExp(r"href='([^']*/pdf/[^']+\.pdf)'", caseSensitive: false),
      RegExp(r'data-pdf-url="([^"]+\.pdf)"', caseSensitive: false),
      RegExp(r"data-pdf-url='([^']+\.pdf)'", caseSensitive: false),
      RegExp(r'https://pmc\.ncbi\.nlm\.nih\.gov/articles/' +
          RegExp.escape(pmcId) +
          r'/pdf/[A-Za-z0-9._-]+\.pdf', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        final raw = match.groupCount >= 1 ? match.group(1) ?? match.group(0) : match.group(0);
        if (raw != null && raw.isNotEmpty) {
          return _normalizePdfUrl(raw, pmcId);
        }
      }
    }

    return null;
  }

  String _normalizePdfUrl(String raw, String pmcId) {
    if (raw.startsWith("http://") || raw.startsWith("https://")) {
      return raw;
    }

    if (raw.startsWith("//")) {
      return "https:$raw";
    }

    if (raw.startsWith("/")) {
      return "https://pmc.ncbi.nlm.nih.gov$raw";
    }

    return "https://pmc.ncbi.nlm.nih.gov/articles/$pmcId/$raw";
  }

  Future<List<int>> consolidateBytes(HttpClientResponse response) async {
    final chunks = <int>[];
    await for (final chunk in response) {
      chunks.addAll(chunk);
    }
    return chunks;
  }

  String _monthName(int m) {
    const names = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];
    return names[m - 1];
  }
}
'@

Set-Content -Path $file -Value $newContent -Encoding UTF8
Write-Host "New file written."

$written = Get-Content $file -Raw

$requiredMarkers = @(
    "Future<String> downloadFullText(",
    "_findExistingMarker(",
    "_extractPdfUrlFromHtml(",
    "Clipboard.setData(",
    "launchUrl(",
    "_manual_download.txt"
)

$missing = @()
foreach ($marker in $requiredMarkers) {
    if ($written -notmatch [regex]::Escape($marker)) {
        $missing += $marker
    }
}

if ($missing.Count -gt 0) {
    Write-Host "VALIDATION FAILED. Missing markers:"
    $missing | ForEach-Object { Write-Host " - $_" }
    Write-Host "Restoring backup..."
    Copy-Item "$backupDir/fulltext_service.dart.bak" $file -Force
    exit 1
}

Write-Host "Validation passed."

$openCurlies = ([regex]::Matches($written, '\{')).Count
$closeCurlies = ([regex]::Matches($written, '\}')).Count
$openParens = ([regex]::Matches($written, '\(')).Count
$closeParens = ([regex]::Matches($written, '\)')).Count

Write-Host ""
Write-Host "Brace check:"
Write-Host "Curly braces: $openCurlies open / $closeCurlies close"
Write-Host "Parentheses : $openParens open / $closeParens close"

if ($openCurlies -ne $closeCurlies -or $openParens -ne $closeParens) {
    Write-Host "WARNING: delimiter counts do not match."
} else {
    Write-Host "Delimiter counts look balanced."
}

Write-Host ""
Write-Host "Rollback command:"
Write-Host "Copy-Item `"$backupDir/fulltext_service.dart.bak`" `"$file`" -Force"
Write-Host ""
Write-Host "Next:"
Write-Host "flutter clean"
Write-Host "flutter run -d windows"