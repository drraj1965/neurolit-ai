# ==============================
# PHASE 4.6 UX + CLINICAL SAFETY
# ==============================

Write-Host "=== PHASE 4.6 PATCH ==="

$BackupDir = "_phase4_6_backup"

if (Test-Path $BackupDir) {
    Remove-Item $BackupDir -Recurse -Force
}

New-Item -ItemType Directory -Path $BackupDir | Out-Null

$homeFile = "lib/screens/home_screen.dart"
$summaryFile = "lib/services/summary_service.dart"

Copy-Item $homeFile "$BackupDir/home_screen.dart.bak"
Copy-Item $summaryFile "$BackupDir/summary_service.dart.bak"

Write-Host "Backup created."

# ==============================
# PATCH 1: AI WITH CITATIONS
# ==============================

@'
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SummaryService {

  Future<String> generateMultiArticleSummary(List<Map<String, String>> articles) async {

    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('openai_api_key') ?? '';

    if (apiKey.isEmpty) {
      return "⚠️ API key not set.";
    }

    String compiled = "";

    for (var a in articles) {
      compiled += "TITLE: " + a["title"]! + "\n";
      compiled += "AUTHORS: " + a["authors"]! + "\n";
      compiled += "ABSTRACT: " + a["abstract"]! + "\n\n---\n\n";
    }

    final prompt = """
You are a senior neurologist.

Perform a multi-paper synthesis.

STRICT RULES:
- Every statement MUST reference the source paper (Author, Year)
- DO NOT generalize without citation
- DO NOT invent findings
- Use only provided abstracts

OUTPUT FORMAT:

OVERVIEW OF EVIDENCE

CONSISTENT FINDINGS (with citations)

CONFLICTING RESULTS (with citations)

STRENGTH OF EVIDENCE

CLINICAL RECOMMENDATION (with cited support)

DATA:
$compiled
""";

    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $apiKey",
      },
      body: jsonEncode({
        "model": "gpt-4o-mini",
        "messages": [
          {"role": "user", "content": prompt}
        ],
        "temperature": 0.2
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      return "Error generating synthesis.";
    }
  }
}
'@ | Set-Content $summaryFile -Encoding UTF8

# ==============================
# PATCH 2: FULL UI RESTORE + SETTINGS + COPY
# ==============================

@'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  final TextEditingController controller = TextEditingController();

  void openSettings() async {
    final TextEditingController keyController = TextEditingController();

    final prefs = await SharedPreferences.getInstance();
    keyController.text = prefs.getString('openai_api_key') ?? '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Settings"),
        content: TextField(
          controller: keyController,
          decoration: InputDecoration(labelText: "OpenAI API Key"),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await prefs.setString('openai_api_key', keyController.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("API key saved")),
              );
            },
            child: Text("Save"),
          )
        ],
      ),
    );
  }

  void search() async {
    final result = await api.searchArticles(controller.text);
    setState(() {
      articles = result;
      selected.clear();
    });
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

    if (selectedArticles.isEmpty) return;

    final data = selectedArticles.map((a) => {
      "title": a.title,
      "authors": a.authors,
      "abstract": a.abstractText
    }).toList();

    showDialog(
      context: context,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );

    final result = await summary.generateMultiArticleSummary(data);

    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("AI SYNTHESIS"),
        content: SingleChildScrollView(
          child: SelectableText(result),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: result));
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
      appBar: AppBar(
        title: Text("NeuroLit AI - Phase 4.6"),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: openSettings,
          )
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

          ElevatedButton(
            onPressed: generateSummary,
            child: Text("Generate AI Summary (Selected)"),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: articles.length,
              itemBuilder: (context, index) {

                final a = articles[index];

                return Card(
                  child: ListTile(
                    leading: Checkbox(
                      value: selected.contains(index),
                      onChanged: (val) {
                        setState(() {
                          if (val!) {
                            selected.add(index);
                          } else {
                            selected.remove(index);
                          }
                        });
                      },
                    ),
                    title: Text(a.title),
                    subtitle: Text(a.authors),
                    onTap: () => openAbstract(a),
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
'@ | Set-Content $homeFile -Encoding UTF8

Write-Host ""
Write-Host "✅ PHASE 4.6 PATCH COMPLETE"
Write-Host "Run:"
Write-Host "flutter run -d windows"