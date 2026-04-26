# ==============================
# NeuroLit Patch Script (Phase 1 Upgrade)
# ==============================

Write-Host "=== Applying Patch: Article + API + UI Upgrade ==="

$BackupDir = "_patch_backup"

# ------------------------------
# CLEAN OLD BACKUP
# ------------------------------
if (Test-Path $BackupDir) {
    Write-Host "Removing old backup..."
    Remove-Item $BackupDir -Recurse -Force
}

New-Item -ItemType Directory -Path $BackupDir | Out-Null

# ------------------------------
# FILE PATHS
# ------------------------------
$articleFile = "lib/models/article.dart"
$apiFile = "lib/services/api_service.dart"
$homeFile = "lib/screens/home_screen.dart"

# ------------------------------
# BACKUP FILES
# ------------------------------
Copy-Item $articleFile "$BackupDir/article.dart.bak"
Copy-Item $apiFile "$BackupDir/api_service.dart.bak"
Copy-Item $homeFile "$BackupDir/home_screen.dart.bak"

Write-Host "Backup created."

# ==============================
# PATCH 1: ARTICLE MODEL
# ==============================

@"
class Article {
  final String title;
  final String abstractText;
  final String journal;
  final String date;
  final String authors;
  final String pmid;
  final String link;

  Article({
    required this.title,
    required this.abstractText,
    required this.journal,
    required this.date,
    required this.authors,
    required this.pmid,
    required this.link,
  });
}
"@ | Set-Content $articleFile

# ==============================
# PATCH 2: API SERVICE
# ==============================

@"
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article.dart';

class ApiService {

  Future<List<Article>> searchArticles(String query) async {

    final url = Uri.parse(
      "https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=" + query + "&format=json&pageSize=20"
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      List<Article> articles = [];

      for (var item in data['resultList']['result']) {
        articles.add(Article(
          title: item['title'] ?? '',
          abstractText: item['abstractText'] ?? 'No abstract available',
          journal: item['journalTitle'] ?? '',
          date: item['firstPublicationDate'] ?? '',
          authors: item['authorString'] ?? '',
          pmid: item['pmid'] ?? '',
          link: item['pmid'] != null
              ? "https://pubmed.ncbi.nlm.nih.gov/" + item['pmid']
              : "",
        ));
      }

      return articles;
    } else {
      throw Exception("Failed to fetch articles");
    }
  }
}
"@ | Set-Content $apiFile

# ==============================
# PATCH 3: HOME SCREEN UI
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

  final topics = [
    "stroke",
    "epilepsy",
    "migraine",
    "parkinson disease",
    "alzheimer disease"
  ];

  void search(String topic) async {
    final result = await api.searchArticles(topic);
    setState(() {
      articles = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("NeuroLit Review")),
      body: Column(
        children: [

          Wrap(
            children: topics.map((t) =>
              ElevatedButton(
                onPressed: () => search(t),
                child: Text(t),
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.authors),
                        Text(a.journal + " (" + a.date + ")"),
                        SizedBox(height: 5),
                        Text(a.abstractText),
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
                                Text(a.abstractText),
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
Write-Host "✅ PATCH APPLIED SUCCESSFULLY"
Write-Host "Backup stored in: $BackupDir"
Write-Host ""
Write-Host "Now run:"
Write-Host "flutter clean"
Write-Host "flutter run -d windows"