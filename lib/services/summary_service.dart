import '../models/ai_request_models.dart';
import 'ai/ai_provider_router.dart';
import 'ai/ai_provider_store.dart';
import 'token/token_service.dart';

class SummaryService {
  final AiProviderRouter router;

  SummaryService({
    AiProviderRouter? router,
  }) : router = router ??
            AiProviderRouter(
              store: AiProviderStore(),
              tokenService: TokenService(),
            );

  Future<String> generateMultiArticleSummary(
    List<Map<String, String>> articles,
    {String? providerOverrideId}
  ) async {
    final compiled = _compileArticles(articles);

    final prompt = """
You are a senior neurologist preparing a journal review and teaching presentation.

Your task is to synthesize multiple research abstracts into a high-quality, consultant-level review.

DO NOT summarize each abstract individually.
INSTEAD:
- Integrate findings across studies
- Identify patterns, agreements, and conflicts
- Provide clinical interpretation

STRUCTURE your output EXACTLY as follows:

1. Background
- Brief overview of the topic

2. Pathophysiological Basis
- Mechanisms involved (if applicable)

3. Key Findings from Literature
- Synthesized findings across studies
- Highlight important trends

4. Clinical Implications
- How this affects real-world practice

5. Limitations of Current Evidence
- Study weaknesses, gaps, biases

6. Future Directions
- Where research is heading

7. Consultant Summary
- Bullet-point actionable insights for clinicians

Maintain clarity, depth, and academic tone.
Avoid repetition.
Avoid listing studies individually unless necessary.

Here are the extracted abstracts (structured):

$compiled
""";

    return _generateViaRouter(
      useCase: AiUseCase.review,
      prompt: prompt,
      providerOverrideId: providerOverrideId,
    );
  }

  Future<String> generateTeachingSynopsis(
    List<Map<String, String>> articles,
    {String? providerOverrideId}
  ) async {
    final compiled = _compileArticles(articles);

    final prompt = """
You are an expert neurologist and medical educator preparing content for a study circle.

Use these principles:
1. Analyze papers like a medical research analyst.
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

    return _generateViaRouter(
      useCase: AiUseCase.teaching,
      prompt: prompt,
      providerOverrideId: providerOverrideId,
    );
  }

  Future<String> generateCustomPrompt(
    String prompt, {
    AiUseCase useCase = AiUseCase.custom,
    String? modelOverride,
    String? providerOverrideId,
    double temperature = 0.2,
  }) async {
    return _generateViaRouter(
      useCase: useCase,
      prompt: prompt,
      modelOverride: modelOverride,
      providerOverrideId: providerOverrideId,
      temperature: temperature,
    );
  }

  String _compileArticles(List<Map<String, String>> articles) {
    final buffer = StringBuffer();

    for (final article in articles) {
      buffer.writeln("TITLE: ${article["title"] ?? ""}");
      buffer.writeln("AUTHORS: ${article["authors"] ?? ""}");
      buffer.writeln("ABSTRACT: ${article["abstract"] ?? ""}");
      buffer.writeln();
      buffer.writeln("---");
      buffer.writeln();
    }

    return buffer.toString();
  }

  Future<String> _generateViaRouter({
    required AiUseCase useCase,
    required String prompt,
    String? modelOverride,
    String? providerOverrideId,
    double temperature = 0.2,
  }) async {
    final response = await router.generateText(
      AiTextRequest(
        useCase: useCase,
        prompt: prompt,
        temperature: temperature,
        modelOverride: modelOverride,
        providerOverrideId: providerOverrideId,
      ),
    );

    return response.text;
  }
}
