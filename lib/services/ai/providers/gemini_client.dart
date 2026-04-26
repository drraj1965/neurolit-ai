import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../models/ai_provider_profile.dart';
import '../../../models/ai_request_models.dart';
import '../ai_exceptions.dart';
import '../ai_provider_client.dart';

class GeminiClient implements AiProviderClient {
  static const _defaultBaseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  @override
  Future<AiTextResponse> generateText({
    required AiProviderProfile profile,
    required String apiKey,
    required AiTextRequest request,
  }) async {
    final model = _resolvedModel(profile, request);
    final response = await http.post(
      Uri.parse('${_baseUrlFor(profile)}/${_modelPath(model)}:generateContent'),
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': request.prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': request.temperature,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw AiProviderValidationException(
        'Gemini request failed (${response.statusCode}). ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractText(data);
    if (text.isEmpty) {
      final promptFeedback = data['promptFeedback'] as Map<String, dynamic>?;
      final blockReason = (promptFeedback?['blockReason'] ?? '').toString();
      if (blockReason.isNotEmpty) {
        throw AiProviderValidationException(
          'Gemini blocked the prompt: $blockReason',
        );
      }
      throw AiProviderValidationException('Gemini returned an empty response.');
    }

    final usage = data['usageMetadata'] as Map<String, dynamic>?;
    final totalTokens = (usage?['totalTokenCount'] as num?)?.toInt();

    return AiTextResponse(
      text: text,
      totalTokens: totalTokens,
      providerId: profile.id,
      providerType: profile.type,
    );
  }

  @override
  Future<void> validate({
    required AiProviderProfile profile,
    required String apiKey,
  }) async {
    final model = _resolvedModel(
      profile,
      const AiTextRequest(
        useCase: AiUseCase.custom,
        prompt: 'Reply with OK.',
        temperature: 0,
      ),
    );

    final response = await http.post(
      Uri.parse('${_baseUrlFor(profile)}/${_modelPath(model)}:generateContent'),
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': const [
              {'text': 'Reply with OK.'},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0,
          'maxOutputTokens': 8,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw AiProviderValidationException(
        'Gemini validation failed (${response.statusCode}). ${response.body}',
      );
    }
  }

  String _extractText(Map<String, dynamic> data) {
    final candidates = data['candidates'] as List<dynamic>? ?? const [];
    if (candidates.isEmpty) return '';

    final firstCandidate = candidates.first as Map<String, dynamic>;
    final content = firstCandidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? const [];

    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map<String, dynamic>) {
        final text = (part['text'] ?? '').toString();
        if (text.isNotEmpty) {
          buffer.write(text);
        }
      }
    }

    return buffer.toString().trim();
  }

  String _resolvedModel(AiProviderProfile profile, AiTextRequest request) {
    final candidate = (request.modelOverride ?? profile.model).trim();
    return candidate.isEmpty ? 'gemini-2.5-flash' : candidate;
  }

  String _modelPath(String model) {
    return model.startsWith('models/') ? model : 'models/$model';
  }

  String _baseUrlFor(AiProviderProfile profile) {
    final custom = profile.baseUrl?.trim() ?? '';
    if (custom.isEmpty) return _defaultBaseUrl;
    return custom.endsWith('/') ? custom.substring(0, custom.length - 1) : custom;
  }
}
