import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../models/ai_request_models.dart';
import '../../models/article.dart';
import '../summary_service.dart';

class LaymanService {
  final SummaryService summary;

  LaymanService(this.summary);

  String computeHash(List<Article> articles, String mode) {
    final pmids = articles.map((a) => a.pmid).toList()..sort();
    final base = pmids.join("|") + "|mode:$mode";
    return base.hashCode.toString();
  }

  Future<File?> findExisting(
    String folderPath,
    String hash,
    String mode,
  ) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return null;

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) =>
            f.path.contains("${mode}_$hash") &&
            f.path.endsWith(".txt"))
        .toList();

    if (files.isEmpty) return null;

    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files.first;
  }

  String _compiledArticles(List<Map<String, dynamic>> payload) {
    final buffer = StringBuffer();

    for (int i = 0; i < payload.length; i++) {
      final item = payload[i];
      buffer.writeln("ARTICLE ${i + 1}");
      buffer.writeln("TITLE: ${item["title"] ?? ""}");
      buffer.writeln("AUTHORS: ${item["authors"] ?? ""}");
      buffer.writeln("ABSTRACT: ${item["abstract"] ?? ""}");
      buffer.writeln("");
      buffer.writeln("---");
      buffer.writeln("");
    }

    return buffer.toString();
  }

  String buildPrompt(String mode, List<Map<String, dynamic>> payload) {
    final compiled = _compiledArticles(payload);

    if (mode == "quick") {
      return """
You are preparing a patient-friendly explanation based on MULTIPLE medical research articles.

IMPORTANT RULES:
- Use ALL the articles provided below.
- Do NOT focus on only the first article.
- Do NOT summarize articles one by one.
- Instead, combine the key messages across all the articles into one simple explanation.
- If several articles make the same point, treat that as stronger support.
- If the articles differ, mention that experts are still learning.

TASK:
Write a QUICK PATIENT SUMMARY in very simple language.

FORMAT:
- 6 to 10 bullet points
- short, clear lines
- suitable for WhatsApp or outpatient counselling
- avoid jargon as much as possible
- if a medical term is necessary, explain it simply

TOPIC:
Use the combined findings from all selected articles.

ARTICLES:
$compiled
""";
    }

    if (mode == "detailed") {
      return """
You are preparing a DETAILED LAYMAN EXPLANATION based on MULTIPLE medical research articles.

CRITICAL INSTRUCTIONS:
- Use ALL the articles provided below.
- Do NOT use only the first article.
- Do NOT write a single-paper summary.
- Do NOT summarize each article separately.
- Instead, SYNTHESIZE the findings across all selected articles into one coherent patient-friendly explanation.
- Where multiple articles support a point, present it as a stronger conclusion.
- Where the evidence is mixed or uncertain, say so clearly in simple language.

AUDIENCE:
- educated layperson / patient / family member
- not a doctor

STYLE:
- simple, clear, non-technical English
- warm, explanatory tone
- no academic jargon unless briefly explained
- no citation numbering
- no paper-by-paper breakdown

OUTPUT STRUCTURE:
1. What this treatment / topic is
2. Why doctors are interested in it
3. What the combined research suggests so far
4. Possible benefits
5. Possible risks or limitations
6. What remains uncertain
7. Practical take-home message for patients

VERY IMPORTANT:
Your explanation must reflect the OVERALL MESSAGE from ALL selected articles, not just one article.

ARTICLES:
$compiled
""";
    }

    return """
You are generating a patient-friendly slide deck from MULTIPLE research articles.

STRICT RULES:
- Use ALL articles
- Do NOT focus on one article
- Combine findings into a single explanation

OUTPUT RULES:
- Return ONLY valid JSON
- No text before or after
- No markdown
- No explanation

FORMAT:
{
  "topic": "short title",
  "slides": [
    {
      "title": "Slide title",
      "points": ["point 1", "point 2", "point 3"]
    }
  ]
}

SLIDES:
- 8 to 12 slides
- 3–5 bullet points per slide
- simple patient-friendly language

ARTICLES:
$compiled
""";
  }

  Future<Map<String, dynamic>> generate({
    required List<Article> articles,
    required String mode,
    required String topic,
    required String providerCacheKey,
    String? providerOverrideId,
  }) async {
    final payload = articles.map((a) => {
          "title": a.title,
          "authors": a.authors,
          "abstract": a.abstractText.trim().isNotEmpty
              ? a.abstractText
              : "No abstract available. Use the title and the overall context carefully.",
        }).toList();

    final hash = computeHash(
      articles,
      "layman_${mode}_provider_$providerCacheKey",
    );

    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final monthNames = const [
      "",
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    final monthName = monthNames[now.month];
    final dayFolder = "${now.day} $monthName ${now.year}";

    final path =
        "${dir.path}/NeuroLit/FullText/${now.year}/$monthName/$dayFolder/$topic/summaries";

    final existing = await findExisting(path, hash, "layman_$mode");

    if (existing != null) {
      return {
        "reused": true,
        "content": await existing.readAsString(),
        "file": existing,
      };
    }

    final prompt = buildPrompt(mode, payload);
    final result = await summary.generateCustomPrompt(
      prompt,
      useCase: _useCaseForMode(mode),
      providerOverrideId: providerOverrideId,
    );

    final folder = Directory(path);
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final file = File("$path/layman_${mode}_$hash.txt");
    await file.writeAsString(result);

    return {
      "reused": false,
      "content": result,
      "file": file,
    };
  }

  AiUseCase _useCaseForMode(String mode) {
    switch (mode) {
      case "quick":
        return AiUseCase.laymanQuick;
      case "detailed":
        return AiUseCase.laymanDetailed;
      case "ppt":
        return AiUseCase.laymanPpt;
      default:
        return AiUseCase.custom;
    }
  }
}
