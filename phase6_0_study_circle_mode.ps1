# ==============================
# PHASE 6.0 — STUDY CIRCLE MODE
# Adds second AI mode: Review vs Teaching Synopsis
# ==============================

Write-Host "=== PHASE 6.0 STUDY CIRCLE MODE ==="

$BackupDir = "_phase6_0_backup"

if (Test-Path $BackupDir) {
    Remove-Item $BackupDir -Recurse -Force
}

New-Item -ItemType Directory -Path $BackupDir | Out-Null

$homeFile = "lib/screens/home_screen.dart"
$summaryFile = "lib/services/summary_service.dart"

if (Test-Path $homeFile) {
    Copy-Item $homeFile "$BackupDir/home_screen.dart.bak"
}
if (Test-Path $summaryFile) {
    Copy-Item $summaryFile "$BackupDir/summary_service.dart.bak"
}

Write-Host "Backup created."

# ==============================
# WRITE summary_service.dart
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
      compiled += "TITLE: " + (a["title"] ?? "") + "\n";
      compiled += "AUTHORS: " + (a["authors"] ?? "") + "\n";
      compiled += "ABSTRACT: " + (a["abstract"] ?? "") + "\n\n---\n\n";
    }

    final prompt = """
You are a senior neurologist.

Perform a multi-paper synthesis.

STRICT RULES:
- Every statement MUST reference the source paper by title or authors.
- Do NOT invent findings.
- Use only the provided abstracts.
- Distinguish between evidence, interpretation, and uncertainty.

OUTPUT FORMAT:

OVERVIEW OF EVIDENCE

CONSISTENT FINDINGS (with source references)

CONFLICTING RESULTS (with source references)

STRENGTH OF EVIDENCE

CLINICAL RECOMMENDATION (with source references)

DATA:
$compiled
""";

    return await _callOpenAI(apiKey, prompt);
  }

  Future<String> generateTeachingSynopsis(List<Map<String, String>> articles) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('openai_api_key') ?? '';

    if (apiKey.isEmpty) {
      return "⚠️ API key not set.";
    }

    String compiled = "";

    for (var a in articles) {
      compiled += "TITLE: " + (a["title"] ?? "") + "\n";
      compiled += "AUTHORS: " + (a["authors"] ?? "") + "\n";
      compiled += "ABSTRACT: " + (a["abstract"] ?? "") + "\n\n---\n\n";
    }

    final prompt = """
You are an expert neurologist and medical educator preparing content for a study circle.

Use these working principles:
1. Analyze papers like a medical reference analyst.
2. Summarize for healthcare professionals using evidence-based language.
3. Prioritize study design, evidence quality, clinical relevance, strengths, and limitations.
4. Do not invent facts beyond the provided abstracts.
5. Explicitly reference the source article when making a point.

Create a TEACHING SYNOPSIS with this exact structure:

TOPIC OVERVIEW
WHY THIS MATTERS CLINICALLY
KEY PAPERS SELECTED
CORE FINDINGS (with source references)
STRENGTHS AND LIMITATIONS OF THE EVIDENCE
AREAS OF AGREEMENT
AREAS OF DISAGREEMENT OR UNCERTAINTY
PRACTICAL TAKE-HOME POINTS
DISCUSSION QUESTIONS FOR A STUDY CIRCLE
SUGGESTED MEDICAL ILLUSTRATION PROMPTS

For "SUGGESTED MEDICAL ILLUSTRATION PROMPTS", produce short, medically accurate educational image prompts suitable for diagram generation.

DATA:
$compiled
""";

    return await _callOpenAI(apiKey, prompt);
  }

  Future<String> _callOpenAI(String apiKey, String prompt) async {
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
      return data['choices'][0]['message']['content'] ?? "Empty response.";
    } else {
      return "Error generating AI output: " + response.statusCode.toString();
    }
  }
}
'@ | Set-Content $summaryFile -Encoding UTF8

# ==============================
# PATCH home_screen.dart
# ==============================

$content = Get-Content $homeFile -Raw

# Add outputMode variable if missing
if ($content -notmatch 'String outputMode = "review";') {
    $content = $content -replace 'bool autoExpand = false;', "bool autoExpand = false;`r`n  String outputMode = ""review"";"
}

# Insert mode selector above Generate AI Summary button if missing
if ($content -notmatch 'Output mode') {
    $content = $content -replace 'ElevatedButton\(\s*onPressed: generateSummary,\s*child: const Text\("Generate AI Summary"\),\s*\)', @'
DropdownButtonFormField<String>(
            value: outputMode,
            decoration: const InputDecoration(
              labelText: "Output mode",
            ),
            items: const [
              DropdownMenuItem(value: "review", child: Text("Review")),
              DropdownMenuItem(value: "teaching", child: Text("Teaching Synopsis")),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                outputMode = v;
              });
            },
          ),

          const SizedBox(height: 8),

          ElevatedButton(
            onPressed: generateSummary,
            child: const Text("Generate AI Summary"),
          )
'@
}

# Replace generateSummary method
$pattern = [regex]'Future<void> generateSummary\(\) async \{.*?\n  \}'
$replacement = @'
Future<void> generateSummary() async {
    final selectedArticles = selected.map((i) => articles[i]).toList();
    if (selectedArticles.isEmpty) return;

    final payload = selectedArticles
        .map(
          (a) => {
            "title": a.title,
            "authors": a.authors,
            "abstract": a.abstractText,
          },
        )
        .toList();

    String result;
    if (outputMode == "teaching") {
      result = await summary.generateTeachingSynopsis(payload);
    } else {
      result = await summary.generateMultiArticleSummary(payload);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(outputMode == "teaching" ? "TEACHING SYNOPSIS" : "AI SUMMARY"),
        content: SingleChildScrollView(
          child: SelectableText(result),
        ),
        actions: [
          TextButton(
            onPressed: () => appendToSession(
              (outputMode == "teaching" ? "TEACHING SYNOPSIS" : "AI SUMMARY") + "\n\n" + result,
            ),
            child: const Text("Save"),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: result));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Output copied")),
              );
            },
            child: const Text("Copy"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }'@

$content = $pattern.Replace($content, $replacement)

Set-Content $homeFile $content -Encoding UTF8

Write-Host ""
Write-Host "✅ PHASE 6.0 PATCH APPLIED"
Write-Host ""
Write-Host "Rollback if needed:"
Write-Host "Copy-Item $BackupDir\home_screen.dart.bak lib\screens\home_screen.dart -Force"
Write-Host "Copy-Item $BackupDir\summary_service.dart.bak lib\services\summary_service.dart -Force"
Write-Host ""
Write-Host "Now run:"
Write-Host "flutter clean"
Write-Host "flutter run -d windows"