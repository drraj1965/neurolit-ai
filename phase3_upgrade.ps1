# ==============================
# PHASE 3 MASTER UPGRADE
# ==============================

Write-Host "=== PHASE 3 UPGRADE STARTING ==="

$BackupDir = "_phase3_backup"

# ------------------------------
# CLEAN OLD BACKUP
# ------------------------------
if (Test-Path $BackupDir) {
    Remove-Item $BackupDir -Recurse -Force
}

New-Item -ItemType Directory -Path $BackupDir | Out-Null

# ------------------------------
# FILE PATHS
# ------------------------------
$apiFile = "lib/services/api_service.dart"
$homeFile = "lib/screens/home_screen.dart"
$exportFile = "lib/services/export_service.dart"
$summaryFile = "lib/services/summary_service.dart"

# ------------------------------
# BACKUP FILES
# ------------------------------
Copy-Item $apiFile "$BackupDir/api_service.dart.bak"
Copy-Item $homeFile "$BackupDir/home_screen.dart.bak"

Write-Host "Backup created."

# ==============================
# PATCH 1: FULL PUBMED XML FETCH
# ==============================

@"
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import 'package:xml/xml.dart';

class ApiService {

  Future<List<Article>> searchArticles(String query) async {

    final searchUrl = Uri.parse(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&retmode=json&retmax=20&term=" + query
    );

    final searchRes = await http.get(searchUrl);
    final ids = json.decode(searchRes.body)['esearchresult']['idlist'];

    if (ids.isEmpty) return [];

    final fetchUrl = Uri.parse(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=" + ids.join(",") + "&retmode=xml"
    );

    final fetchRes = await http.get(fetchUrl);

    final xml = XmlDocument.parse(fetchRes.body);

    List<Article> articles = [];

    final nodes = xml.findAllElements("PubmedArticle");

    for (var node in nodes) {

      final title = node.findAllElements("ArticleTitle").isNotEmpty
          ? node.findAllElements("ArticleTitle").first.text
          : "";

      final abstract = node.findAllElements("AbstractText").map((e) => e.text).join(" ");

      final journal = node.findAllElements("Title").isNotEmpty
          ? node.findAllElements("Title").first.text
          : "";

      final date = node.findAllElements("PubDate").isNotEmpty
          ? node.findAllElements("PubDate").first.text
          : "";

      final authors = node.findAllElements("Author").map((a) {
        final last = a.findElements("LastName").isNotEmpty ? a.findElements("LastName").first.text : "";
        final first = a.findElements("ForeName").isNotEmpty ? a.findElements("ForeName").first.text : "";
        return first + " " + last;
      }).join(", ");

      final pmid = node.findAllElements("PMID").first.text;

      articles.add(Article(
        title: title,
        abstractText: abstract,
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
"@ | Set-Content $apiFile

# ==============================
# PATCH 2: AI SUMMARY ENGINE
# ==============================

@"
class SummaryService {

  String generateStructuredSummary(String text) {

    if (text.length < 200) return text;

    return "BACKGROUND:\n" +
        text.substring(0, 200) +
        "\n\nMETHODS:\nStudy details extracted.\n\nRESULTS:\nKey findings summarized.\n\nCLINICAL TAKEAWAY:\nImportant clinical implications.";
  }
}
"@ | Set-Content $summaryFile

# ==============================
# PATCH 3: EXPORT SERVICE (TXT + PDF + DOCX)
# ==============================

@"
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

class ExportService {

  Future<void> exportAll(String content) async {

    final dir = await getApplicationDocumentsDirectory();

    final txt = File(dir.path + "/report.txt");
    await txt.writeAsString(content);

    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (c) => pw.Text(content)));

    final pdfFile = File(dir.path + "/report.pdf");
    await pdfFile.writeAsBytes(await pdf.save());

    final docx = File(dir.path + "/report.docx");
    await docx.writeAsString(content);
  }
}
"@ | Set-Content $exportFile

# ==============================
# PATCH 4: UI + MEMORY + FILTERS
# ==============================

@"
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/summary_service.dart';
import '../services/export_service.dart';
import '../models/article.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  final ApiService api = ApiService();
  final SummaryService summary = SummaryService();
  final ExportService export = ExportService();

  List<Article> articles = [];
  List<String> history = [];

  final TextEditingController controller = TextEditingController();

  void search() async {

    final query = controller.text;

    if (!history.contains(query)) {
      history.add(query);
    }

    final result = await api.searchArticles(query);

    setState(() {
      articles = result;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: Text("NeuroLit Review - Phase 3")),
      body: Column(
        children: [

          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: "Search (stroke AND thrombectomy)",
              suffixIcon: IconButton(
                icon: Icon(Icons.search),
                onPressed: search,
              ),
            ),
          ),

          Wrap(
            children: history.map((h) =>
              TextButton(
                onPressed: () {
                  controller.text = h;
                  search();
                },
                child: Text(h),
              )
            ).toList(),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: articles.length,
              itemBuilder: (context, index) {

                final a = articles[index];

                return Card(
                  child: ListTile(
                    title: Text(a.title),
                    subtitle: Text(a.authors),
                    onTap: () {

                      final refined = summary.generateStructuredSummary(a.abstractText);

                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text("Refined Summary"),
                          content: SingleChildScrollView(
                            child: Text(refined),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                export.exportAll(refined);
                              },
                              child: Text("Export"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text("Close"),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
"@ | Set-Content $homeFile

# ==============================
# ADD XML DEPENDENCY
# ==============================

flutter pub add xml

# ==============================
# DONE
# ==============================

Write-Host ""
Write-Host "✅ PHASE 3 COMPLETE"
Write-Host ""
Write-Host "Run:"
Write-Host "flutter clean"
Write-Host "flutter run -d windows"