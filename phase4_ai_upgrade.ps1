# ==============================
# PHASE 4 AI UPGRADE
# ==============================

Write-Host "=== PHASE 4 AI UPGRADE ==="

$BackupDir = "_phase4_backup"

# CLEAN OLD BACKUP
if (Test-Path $BackupDir) {
    Remove-Item $BackupDir -Recurse -Force
}

New-Item -ItemType Directory -Path $BackupDir | Out-Null

# FILES
$summaryFile = "lib/services/summary_service.dart"
$homeFile = "lib/screens/home_screen.dart"

# BACKUP
Copy-Item $summaryFile "$BackupDir/summary_service.dart.bak"
Copy-Item $homeFile "$BackupDir/home_screen.dart.bak"

Write-Host "Backup created."

# ==============================
# PATCH 1: AI SUMMARY SERVICE
# ==============================

@"
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SummaryService {

  Future<String> generateAISummary(String abstractText) async {

    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('openai_api_key') ?? '';

    if (apiKey.isEmpty) {
      return "⚠️ Please set your OpenAI API key first.";
    }

    final url = Uri.parse("https://api.openai.com/v1/chat/completions");

    final prompt = """
You are a senior neurologist.

Analyze this medical abstract and provide:

BACKGROUND:
OBJECTIVE:
METHODS:
RESULTS:
LIMITATIONS:
CLINICAL TAKEAWAY:

Abstract:
$abstractText
""";

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer " + apiKey,
      },
      body: jsonEncode({
        "model": "gpt-4o-mini",
        "messages": [
          {"role": "user", "content": prompt}
        ],
        "temperature": 0.3
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      return "Error generating AI summary.";
    }
  }
}
"@ | Set-Content $summaryFile

# ==============================
# PATCH 2: UI WITH API KEY INPUT
# ==============================

@"
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/summary_service.dart';
import '../models/article.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  final ApiService api = ApiService();
  final SummaryService summary = SummaryService();

  List<Article> articles = [];

  final TextEditingController controller = TextEditingController();
  final TextEditingController keyController = TextEditingController();

  void saveApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('openai_api_key', keyController.text);
  }

  void search() async {
    final result = await api.searchArticles(controller.text);
    setState(() {
      articles = result;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: Text("NeuroLit AI - Phase 4")),
      body: Column(
        children: [

          TextField(
            controller: keyController,
            decoration: InputDecoration(
              hintText: "Enter OpenAI API Key",
              suffixIcon: IconButton(
                icon: Icon(Icons.save),
                onPressed: saveApiKey,
              ),
            ),
          ),

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
                  onTap: () async {

                    showDialog(
                      context: context,
                      builder: (_) => Center(child: CircularProgressIndicator()),
                    );

                    final aiSummary = await summary.generateAISummary(a.abstractText);

                    Navigator.pop(context);

                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text("AI Summary"),
                        content: SingleChildScrollView(
                          child: Text(aiSummary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("Close"),
                          ),
                        ],
                      ),
                    );
                  },
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
Write-Host "✅ PHASE 4 AI UPGRADE COMPLETE"
Write-Host ""
Write-Host "Run:"
Write-Host "flutter clean"
Write-Host "flutter run -d windows"