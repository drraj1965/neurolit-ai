# ==============================
# PHASE 2 UPGRADE SCRIPT
# ==============================

Write-Host "=== PHASE 2 UPGRADE STARTING ==="

$BackupDir = "_phase2_backup"

# ------------------------------
# CLEAN OLD BACKUP
# ------------------------------
if (Test-Path $BackupDir) {
    Write-Host "Removing old Phase 2 backup..."
    Remove-Item $BackupDir -Recurse -Force
}

New-Item -ItemType Directory -Path $BackupDir | Out-Null

# ------------------------------
# FILE PATHS
# ------------------------------
$apiFile = "lib/services/api_service.dart"
$homeFile = "lib/screens/home_screen.dart"

# ------------------------------
# BACKUP FILES
# ------------------------------
Copy-Item $apiFile "$BackupDir/api_service.dart.bak"
Copy-Item $homeFile "$BackupDir/home_screen.dart.bak"

Write-Host "Backup created."

# ==============================
# PATCH 1: ADVANCED PUBMED API
# ==============================

@"
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article.dart';

class ApiService {

  Future<List<Article>> searchArticles(String query, String years) async {

    String dateFilter = "";
    if (years == "1") dateFilter = " AND 2025:2026[pdat]";
    if (years == "5") dateFilter = " AND 2020:2026[pdat]";
    if (years == "10") dateFilter = " AND 2015:2026[pdat]";

    final searchUrl = Uri.parse(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&retmode=json&retmax=20&term=" + query + dateFilter
    );

    final searchRes = await http.get(searchUrl);
    final searchData = json.decode(searchRes.body);

    List ids = searchData['esearchresult']['idlist'];

    if (ids.isEmpty) return [];

    final summaryUrl = Uri.parse(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&retmode=json&id=" + ids.join(",")
    );

    final summaryRes = await http.get(summaryUrl);
    final summaryData = json.decode(summaryRes.body);

    List<Article> articles = [];

    for (var id in ids) {
      var item = summaryData['result'][id];

      articles.add(Article(
        title: item['title'] ?? '',
        abstractText: "Abstract loading in Phase 3",
        journal: item['fulljournalname'] ?? '',
        date: item['pubdate'] ?? '',
        authors: (item['authors'] as List).map((a) => a['name']).join(", "),
        pmid: id,
        link: "https://pubmed.ncbi.nlm.nih.gov/" + id,
      ));
    }

    return articles;
  }
}
"@ | Set-Content $apiFile

# ==============================
# PATCH 2: UI UPGRADE
# ==============================

@"
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/article.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  final ApiService api = ApiService();

  List<Article> articles = [];

  String query = "";
  String selectedYears = "5";

  final TextEditingController controller = TextEditingController();

  void search() async {
    final result = await api.searchArticles(controller.text, selectedYears);
    setState(() {
      articles = result;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: Text("NeuroLit Review - Phase 2")),
      body: Column(
        children: [

          Padding(
            padding: EdgeInsets.all(10),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: "Enter topic (e.g. stroke AND thrombectomy)",
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: search,
                ),
              ),
            ),
          ),

          DropdownButton<String>(
            value: selectedYears,
            items: [
              DropdownMenuItem(value: "1", child: Text("Last 1 year")),
              DropdownMenuItem(value: "5", child: Text("Last 5 years")),
              DropdownMenuItem(value: "10", child: Text("Last 10 years")),
            ],
            onChanged: (value) {
              setState(() {
                selectedYears = value!;
              });
            },
          ),

          Expanded(
            child: ListView.builder(
              itemCount: articles.length,
              itemBuilder: (context, index) {

                final a = articles[index];

                return Card(
                  child: ListTile(
                    title: Text(a.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.authors),
                        Text(a.journal + " (" + a.date + ")"),
                      ],
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(a.title),
                          content: SingleChildScrollView(
                            child: Column(
                              children: [
                                Text(a.authors),
                                Text(a.journal + " (" + a.date + ")"),
                                SizedBox(height: 10),
                                Text(a.link),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {},
                              child: Text("Open in PubMed"),
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
# DONE
# ==============================

Write-Host ""
Write-Host "✅ PHASE 2 UPGRADE COMPLETE"
Write-Host ""
Write-Host "Run:"
Write-Host "flutter clean"
Write-Host "flutter run -d windows"