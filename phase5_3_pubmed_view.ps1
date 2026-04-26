# ==============================
# PHASE 5.3 PUBMED VIEW FIX
# ==============================

Write-Host "=== PHASE 5.3 PUBMED VIEW ==="

$BackupDir = "_phase5_3_backup"

if (Test-Path $BackupDir) {
    Remove-Item $BackupDir -Recurse -Force
}

New-Item -ItemType Directory -Path $BackupDir | Out-Null

$apiFile = "lib/services/api_service.dart"
$homeFile = "lib/screens/home_screen.dart"

Copy-Item $apiFile "$BackupDir/api_service.dart.bak"
Copy-Item $homeFile "$BackupDir/home_screen.dart.bak"

Write-Host "Backup created."

# ==============================
# PATCH 1 — FIX ABSTRACT PARSING
# ==============================

@'
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import 'package:xml/xml.dart';

class ApiService {

  Future<List<Article>> searchArticles(String query, String dateFilter) async {

    String filter = "";

    if (dateFilter == "1w") filter = " AND (\"last 7 days\"[dp])";
    if (dateFilter == "1m") filter = " AND (\"last 30 days\"[dp])";
    if (dateFilter == "3m") filter = " AND (\"last 90 days\"[dp])";
    if (dateFilter == "6m") filter = " AND (\"last 180 days\"[dp])";
    if (dateFilter == "1y") filter = " AND (\"last 365 days\"[dp])";

    final searchUrl = Uri.parse(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&retmode=json&retmax=20&term=" + query + filter
    );

    final searchRes = await http.get(searchUrl);
    final ids = json.decode(searchRes.body)['esearchresult']['idlist'];

    if (ids.isEmpty) return [];

    final fetchRes = await http.get(Uri.parse(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=" + ids.join(",") + "&retmode=xml"
    ));

    final xml = XmlDocument.parse(fetchRes.body);

    List<Article> articles = [];

    final nodes = xml.findAllElements("PubmedArticle");

    for (var node in nodes) {

      final title = node.findAllElements("ArticleTitle").isNotEmpty
          ? node.findAllElements("ArticleTitle").first.text
          : "";

      // 🔥 STRUCTURED ABSTRACT
      String abstractText = "";
      final sections = node.findAllElements("AbstractText");

      for (var s in sections) {
        final label = s.getAttribute("Label");
        if (label != null) {
          abstractText += label.toUpperCase() + ":\n";
        }
        abstractText += s.text + "\n\n";
      }

      final journal = node.findAllElements("Title").isNotEmpty
          ? node.findAllElements("Title").first.text
          : "";

      final date = node.findAllElements("PubDate").isNotEmpty
          ? node.findAllElements("PubDate").first.text
          : "";

      final authors = node.findAllElements("Author").map((a) {
        final last = a.findElements("LastName").isNotEmpty
            ? a.findElements("LastName").first.text
            : "";
        final first = a.findElements("ForeName").isNotEmpty
            ? a.findElements("ForeName").first.text
            : "";
        return first + " " + last;
      }).join(", ");

      final pmid = node.findAllElements("PMID").first.text;

      articles.add(Article(
        title: title,
        abstractText: abstractText,
        journal: journal,
        date: date,
        authors: authors,
        pmid: pmid,
        link: "https://pubmed.ncbi.nlm.nih.gov/" + pmid,
      ));
    }

    return articles;
  }
}
'@ | Set-Content $apiFile -Encoding UTF8

# ==============================
# PATCH 2 — IMPROVE LIST VIEW
# ==============================

$content = Get-Content $homeFile -Raw

$content = $content -replace "subtitle: Text\(a.authors\),",
"subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(a.authors),
    Text(a.journal + ' • ' + a.date),
    Text('PMID: ' + a.pmid),
    SizedBox(height: 5),
    Text(
      a.abstractText.split('\n').first,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  ],
),"

Set-Content $homeFile $content -Encoding UTF8

Write-Host ""
Write-Host "✅ PHASE 5.3 COMPLETE"
Write-Host "Run:"
Write-Host "flutter run -d windows"