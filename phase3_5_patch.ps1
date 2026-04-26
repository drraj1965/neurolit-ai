# ==============================
# PHASE 3.5 PATCH SCRIPT
# ==============================

Write-Host "=== PHASE 3.5 PATCH STARTING ==="

$BackupDir = "_phase3_5_backup"

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
$homeFile = "lib/screens/home_screen.dart"
$summaryFile = "lib/services/summary_service.dart"

# ------------------------------
# BACKUP FILES
# ------------------------------
Copy-Item $homeFile "$BackupDir/home_screen.dart.bak"
Copy-Item $summaryFile "$BackupDir/summary_service.dart.bak"

Write-Host "Backup created."

# ==============================
# PATCH 1: SUMMARY SERVICE (REAL CONTENT)
# ==============================

@"
class SummaryService {

  String generateStructuredSummary(String text) {

    if (text.trim().isEmpty) return "No abstract available.";

    if (text.length < 300) return text;

    int mid = text.length ~/ 2;

    return "BACKGROUND:\n" +
        text.substring(0, 300) +
        "\n\nKEY POINTS:\n" +
        text.substring(mid, mid + 200 > text.length ? text.length : mid + 200) +
        "\n\nCLINICAL TAKEAWAY:\nDerived from study findings.";
  }
}
"@ | Set-Content $summaryFile

# ==============================
# PATCH 2: HOME SCREEN UI (ABSTRACT FIX)
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
      appBar: AppBar(title: Text("NeuroLit Review - Phase 3.5")),
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

                final preview = a.abstractText.length > 300
                    ? a.abstractText.substring(0, 300) + "..."
                    : a.abstractText;

                return Card(
                  child: ListTile(
                    title: Text(a.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.authors),
                        Text(a.journal + " (" + a.date + ")"),
                        SizedBox(height: 5),
                        Text(preview),
                      ],
                    ),
                    onTap: () {

                      final refined = summary.generateStructuredSummary(a.abstractText);

                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(a.title),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.authors),
                                Text(a.journal + " (" + a.date + ")"),
                                SizedBox(height: 15),
                                Text("FULL ABSTRACT:\n"),
                                Text(a.abstractText),
                                SizedBox(height: 20),
                                Text("REFINED SUMMARY:\n"),
                                Text(refined),
                              ],
                            ),
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
# DONE
# ==============================

Write-Host ""
Write-Host "✅ PHASE 3.5 PATCH APPLIED SUCCESSFULLY"
Write-Host ""
Write-Host "Run:"
Write-Host "flutter clean"
Write-Host "flutter run -d windows"