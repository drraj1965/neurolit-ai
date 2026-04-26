# ============================================
# PHASE 4 FIX PATCH
# - deletes previous backup
# - creates fresh backups
# - fixes empty-abstract AI prompt bug
# - adds API key save confirmation
# - loads saved key on startup
# - masks API key by default
# - improves error visibility
# ============================================

Write-Host "=== PHASE 4 FIX PATCH STARTING ==="

$BackupDir = "_phase4_fix_backup"

if (Test-Path $BackupDir) {
    Write-Host "Removing old backup..."
    Remove-Item $BackupDir -Recurse -Force
}

New-Item -ItemType Directory -Path $BackupDir | Out-Null

$summaryFile = "lib/services/summary_service.dart"
$homeFile    = "lib/screens/home_screen.dart"

if (-not (Test-Path $summaryFile)) {
    Write-Host "Missing file: $summaryFile"
    exit 1
}

if (-not (Test-Path $homeFile)) {
    Write-Host "Missing file: $homeFile"
    exit 1
}

Copy-Item $summaryFile "$BackupDir/summary_service.dart.bak"
Copy-Item $homeFile "$BackupDir/home_screen.dart.bak"

Write-Host "Fresh backups created."

# -----------------------------
# PATCH 1: summary_service.dart
# IMPORTANT: use SINGLE-QUOTED here-string
# so PowerShell does NOT expand $abstractText
# -----------------------------
@'
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SummaryService {
  Future<String> generateAISummary(String abstractText) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('openai_api_key') ?? '';

    if (apiKey.trim().isEmpty) {
      return '⚠️ Please save your OpenAI API key first.';
    }

    if (abstractText.trim().isEmpty) {
      return '⚠️ No abstract was available for this article.';
    }

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final prompt = '''
You are a senior consultant neurologist helping another neurologist review the literature.

Analyze the following medical abstract and produce a clinically useful structured summary with these exact headings:

BACKGROUND:
OBJECTIVE:
METHODS:
RESULTS:
LIMITATIONS:
CLINICAL TAKEAWAY:

Rules:
- Be faithful to the abstract only.
- Do not invent details not present.
- Be concise but meaningful.
- If some section is not clearly stated, say "Not clearly stated in abstract."

ABSTRACT:
$abstractText
''';

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.2
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final content = data['choices']?[0]?['message']?['content'];

      if (content is String && content.trim().isNotEmpty) {
        return content.trim();
      }

      return '⚠️ The AI response was empty.';
    } else {
      return 'OpenAI API error (' +
          response.statusCode.toString() +
          '): ' +
          response.body;
    }
  }
}
'@ | Set-Content $summaryFile -Encoding UTF8

# -----------------------------
# PATCH 2: home_screen.dart
# -----------------------------
@'
import 'package:flutter/material.dart';
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

  final TextEditingController controller = TextEditingController();
  final TextEditingController keyController = TextEditingController();

  bool obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('openai_api_key') ?? '';
    setState(() {
      keyController.text = saved;
    });
  }

  Future<void> saveApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('openai_api_key', keyController.text.trim());

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('API key saved successfully.')),
    );
  }

  Future<void> search() async {
    final q = controller.text.trim();
    if (q.isEmpty) return;

    final result = await api.searchArticles(q);
    setState(() {
      articles = result;
    });
  }

  Future<void> openAiSummary(Article a) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final aiSummary = await summary.generateAISummary(a.abstractText);

    if (!mounted) return;
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(a.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.authors),
              const SizedBox(height: 6),
              Text(a.journal + ' (' + a.date + ')'),
              const SizedBox(height: 14),
              const Text(
                'AI SUMMARY',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SelectableText(aiSummary),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NeuroLit AI - Phase 4'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: keyController,
              obscureText: obscureApiKey,
              decoration: InputDecoration(
                hintText: 'Enter OpenAI API key',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: obscureApiKey ? 'Show key' : 'Hide key',
                      icon: Icon(
                        obscureApiKey ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          obscureApiKey = !obscureApiKey;
                        });
                      },
                    ),
                    IconButton(
                      tooltip: 'Save API key',
                      icon: const Icon(Icons.save),
                      onPressed: saveApiKey,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Search topic',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: search,
                ),
              ),
              onSubmitted: (_) => search(),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: articles.length,
              itemBuilder: (context, index) {
                final a = articles[index];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: ListTile(
                    title: Text(a.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(a.authors),
                        Text(a.journal + ' (' + a.date + ')'),
                      ],
                    ),
                    onTap: () => openAiSummary(a),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
'@ | Set-Content $homeFile -Encoding UTF8

Write-Host ""
Write-Host "✅ PHASE 4 FIX PATCH APPLIED"
Write-Host "Backup folder: $BackupDir"
Write-Host ""
Write-Host "Now run:"
Write-Host "flutter clean"
Write-Host "flutter pub get"
Write-Host "flutter run -d windows"