# ==============================
# PHASE 4.5 ADVANCED SYNTHESIS
# ==============================

Write-Host "=== PHASE 4.5 ADVANCED SYNTHESIS ==="

$BackupDir = "_phase4_5_backup"

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
# PATCH 1: ADVANCED AI SERVICE
# ==============================

@'
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SummaryService {

  Future<String> generateMultiArticleSummary(List<String> abstracts) async {

    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('openai_api_key') ?? '';

    if (apiKey.isEmpty) {
      return "⚠️ API key not set.";
    }

    final combined = abstracts.join("\n\n---\n\n");

    final prompt = """
You are a senior neurologist conducting a literature synthesis.

Given multiple abstracts, produce:

1. OVERVIEW OF EVIDENCE
2. CONSISTENT FINDINGS
3. CONFLICTING RESULTS
4. STRENGTH OF EVIDENCE
5. CLINICAL RECOMMENDATION

Do NOT repeat abstracts.
Do NOT paraphrase individually.
Provide synthesis.

Abstracts:
$combined
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
# PATCH 2: HOME SCREEN WITH SELECTION + AMA
# ==============================

@'
import 'package:flutter/material.dart';
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

  void search() async {
    final result = await api.searchArticles(controller.text);
    setState(() {
      articles = result;
      selected.clear();
    });
  }

  String formatAMA(Article a) {
    String authors = a.authors.split(",").take(3).join(", ") +
        (a.authors.split(",").length > 3 ? ", et al" : "");

    return authors +
        ". " +
        a.title +
        ". " +
        a.journal +
        ". " +
        a.date +
        ". doi:" +
        (a.link.isNotEmpty ? a.link : "");
  }

  void generateSummary() async {

    final selectedArticles = selected.map((i) => articles[i]).toList();

    if (selectedArticles.isEmpty) return;

    final abstracts = selectedArticles.map((a) => a.abstractText).toList();

    showDialog(
      context: context,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );

    final result = await summary.generateMultiArticleSummary(abstracts);

    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("AI SYNTHESIS"),
        content: SingleChildScrollView(child: Text(result)),
        actions: [
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
      appBar: AppBar(title: Text("NeuroLit AI - Phase 4.5")),
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.authors),
                        Text(formatAMA(a)),
                        GestureDetector(
                          child: Text(
                            a.link,
                            style: TextStyle(color: Colors.blue),
                          ),
                          onTap: () {},
                        ),
                      ],
                    ),
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
Write-Host "✅ PHASE 4.5 COMPLETE"
Write-Host "Run:"
Write-Host "flutter clean"
Write-Host "flutter run -d windows"