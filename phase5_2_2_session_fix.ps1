# ==============================
# PHASE 5.2.2 SESSION FIX (STABLE)
# ==============================

Write-Host "=== FIXING SESSION STORAGE SYSTEM ==="

$BackupDir = "_phase5_2_2_backup"

if (Test-Path $BackupDir) {
    Remove-Item $BackupDir -Recurse -Force
}

New-Item -ItemType Directory -Path $BackupDir | Out-Null

$homeFile = "lib/screens/home_screen.dart"

Copy-Item $homeFile "$BackupDir/home_screen.dart.bak"

Write-Host "Backup created."

# ==============================
# PATCH: RELIABLE SESSION SYSTEM
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

  Future<String> createSessionFile(String query) async {

    try {
      final baseDir = await getApplicationDocumentsDirectory();

      final now = DateTime.now();

      String year = now.year.toString();
      String month = "${now.month.toString().padLeft(2,'0')}-${_monthName(now.month)}";
      String day = "${now.day.toString().padLeft(2,'0')}-${_monthName(now.month)}";

      final dirPath = baseDir.path + "/NeuroLit/" + year + "/" + month + "/" + day;

      final dir = Directory(dirPath);

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final safeQuery = query.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(" ", "_");

      final fileName = "NeuroLit_" +
          safeQuery +
          "_" +
          now.hour.toString() +
          "-" +
          now.minute.toString() +
          ".txt";

      final filePath = dirPath + "/" + fileName;

      final file = File(filePath);

      await file.writeAsString("SESSION: " + query + "\n\n");

      currentFilePath = filePath;

      return filePath;

    } catch (e) {
      return "";
    }
  }

  String _monthName(int m) {
    const names = [
      "", "Jan","Feb","Mar","Apr","May","Jun",
      "Jul","Aug","Sep","Oct","Nov","Dec"
    ];
    return names[m];
  }

  Future<void> appendToFile(String text) async {

    if (currentFilePath.isEmpty) return;

    try {
      final file = File(currentFilePath);

      if (!await file.exists()) return;

      await file.writeAsString("\n\n" + text, mode: FileMode.append);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Saved to session file")),
      );

    } catch (e) {}
  }

  void search() async {

    final query = controller.text;

    final path = await createSessionFile(query);

    if (path.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Session created")),
      );
    }

    final result = await api.searchArticles(query, "1y");

    setState(() {
      articles = result;
    });

    String listText = "RESULTS:\n\n";

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
            onPressed: () => appendToFile(a.abstractText),
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

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: Text("NeuroLit AI - Session Fixed")),
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

          Expanded(
            child: ListView.builder(
              itemCount: articles.length,
              itemBuilder: (context, index) {

                final a = articles[index];

                return ListTile(
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
Write-Host "✅ SESSION SYSTEM FIXED"
Write-Host "Run:"
Write-Host "flutter run -d windows"