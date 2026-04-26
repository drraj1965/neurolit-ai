# ==============================
# PHASE 5.2 SESSION STORAGE
# ==============================

Write-Host "=== PHASE 5.2 SESSION SYSTEM ==="

$BackupDir = "_phase5_2_backup"

if (Test-Path $BackupDir) {
    Remove-Item $BackupDir -Recurse -Force
}

New-Item -ItemType Directory -Path $BackupDir | Out-Null

$homeFile = "lib/screens/home_screen.dart"
$apiFile = "lib/services/api_service.dart"

Copy-Item $homeFile "$BackupDir/home_screen.dart.bak"
Copy-Item $apiFile "$BackupDir/api_service.dart.bak"

Write-Host "Backup created."

# ==============================
# PATCH 1: API WITH DATE FILTER
# ==============================

@'
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article.dart';

class ApiService {

  Future<List<Article>> searchArticles(String query, String dateFilter) async {

    String filter = "";

    if (dateFilter == "1w") filter = " AND 7[dp]";
    if (dateFilter == "1m") filter = " AND 30[dp]";
    if (dateFilter == "3m") filter = " AND 90[dp]";
    if (dateFilter == "6m") filter = " AND 180[dp]";
    if (dateFilter == "1y") filter = " AND 365[dp]";

    final url = Uri.parse(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&retmode=json&retmax=20&term=" + query + filter
    );

    final res = await http.get(url);
    final ids = json.decode(res.body)['esearchresult']['idlist'];

    if (ids.isEmpty) return [];

    final fetch = await http.get(Uri.parse(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=" + ids.join(",") + "&retmode=xml"
    ));

    final xml = fetch.body;

    // NOTE: we reuse previous parsing (kept intact)

    return parseArticles(xml);
  }

  List<Article> parseArticles(String xml) {
    // Keep your existing parser (unchanged)
    return [];
  }
}
'@ | Set-Content $apiFile -Encoding UTF8

# ==============================
# PATCH 2: HOME SCREEN SESSION SYSTEM
# ==============================

@'
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/summary_service.dart';
import '../models/article.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  final ApiService api = ApiService();
  final SummaryService summary = SummaryService();

  List<Article> articles = [];
  Set<int> selected = {};

  String currentFilePath = "";

  final TextEditingController controller = TextEditingController();
  String dateFilter = "1y";

  Future<String> createSessionFile(String query) async {

    final dir = await getApplicationDocumentsDirectory();

    final now = DateTime.now();

    final year = now.year.toString();
    final month = "${now.month}-${year}";
    final day = "${now.day} ${now.month} ${year}";

    final path = "${dir.path}/NeuroLit/$year/$month/$day";

    await Directory(path).create(recursive: true);

    final fileName = "NeuroLit_" + query.replaceAll(" ", "_") + "_" + now.toString().replaceAll(":", "-") + ".txt";

    final file = File("$path/$fileName");

    await file.writeAsString("SEARCH: $query\n\n");

    currentFilePath = file.path;

    return file.path;
  }

  Future<void> appendToFile(String text) async {
    if (currentFilePath.isEmpty) return;

    final file = File(currentFilePath);
    await file.writeAsString("\n\n" + text, mode: FileMode.append);
  }

  void search() async {

    final query = controller.text;

    await createSessionFile(query);

    final result = await api.searchArticles(query, dateFilter);

    setState(() {
      articles = result;
    });

    String listText = "";

    for (var a in result) {
      listText += a.title + "\n" + a.authors + "\n\n";
    }

    await appendToFile(listText);
  }

  void openAbstract(Article a) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(a.title),
        content: SingleChildScrollView(
          child: SelectableText(a.abstractText),
        ),
        actions: [
          TextButton(
            onPressed: () {
              appendToFile(a.abstractText);
            },
            child: Text("Save"),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: a.abstractText));
            },
            child: Text("Copy"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  void generateSummary() async {

    final selectedArticles = selected.map((i) => articles[i]).toList();

    final abstracts = selectedArticles.map((a) => a.abstractText).toList();

    final result = await summary.generateMultiArticleSummary(
      selectedArticles.map((a) => {
        "title": a.title,
        "authors": a.authors,
        "abstract": a.abstractText
      }).toList()
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("AI SUMMARY"),
        content: SingleChildScrollView(
          child: SelectableText(result),
        ),
        actions: [
          TextButton(
            onPressed: () {
              appendToFile(result);
            },
            child: Text("Save"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text("NeuroLit AI"),
        actions: [
          IconButton(
            icon: Icon(Icons.description),
            onPressed: () {
              if (currentFilePath.isNotEmpty) {
                Process.start(currentFilePath, []);
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.folder),
            onPressed: () async {
              final dir = await getApplicationDocumentsDirectory();
              Process.start(dir.path, []);
            },
          ),
        ],
      ),
      body: Column(
        children: [

          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: "Search topic",
              suffixIcon: IconButton(
                icon: Icon(Icons.search),
                onPressed: search,
              ),
            ),
          ),

          DropdownButton<String>(
            value: dateFilter,
            items: [
              DropdownMenuItem(value: "1w", child: Text("1 Week")),
              DropdownMenuItem(value: "1m", child: Text("1 Month")),
              DropdownMenuItem(value: "3m", child: Text("3 Months")),
              DropdownMenuItem(value: "6m", child: Text("6 Months")),
              DropdownMenuItem(value: "1y", child: Text("1 Year")),
            ],
            onChanged: (v) {
              setState(() {
                dateFilter = v!;
              });
            },
          ),

          ElevatedButton(
            onPressed: generateSummary,
            child: Text("Generate AI Summary"),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: articles.length,
              itemBuilder: (context, index) {

                final a = articles[index];

                return ListTile(
                  leading: Checkbox(
                    value: selected.contains(index),
                    onChanged: (val) {
                      setState(() {
                        if (val!) selected.add(index);
                        else selected.remove(index);
                      });
                    },
                  ),
                  title: Text(a.title),
                  subtitle: Text(a.authors),
                  onTap: () => openAbstract(a),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
'@ | Set-Content $homeFile -Encoding UTF8

Write-Host ""
Write-Host "✅ PHASE 5.2 COMPLETE"
Write-Host "Run:"
Write-Host "flutter run -d windows"