import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../models/ai_provider_profile.dart';
import '../../../models/ai_request_models.dart';
import '../ai_exceptions.dart';
import '../ai_provider_client.dart';

class OpenAiClient implements AiProviderClient {
  static const _defaultBaseUrl = 'https://api.openai.com/v1';

  @override
  Future<AiTextResponse> generateText({
    required AiProviderProfile profile,
    required String apiKey,
    required AiTextRequest request,
  }) async {
    final response = await http.post(
      Uri.parse('${_baseUrlFor(profile)}/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': request.modelOverride ?? profile.model,
        'messages': [
          {'role': 'user', 'content': request.prompt},
        ],
        'temperature': request.temperature,
      }),
    );

    if (response.statusCode != 200) {
      throw AiProviderValidationException(
        'OpenAI request failed (${response.statusCode}). ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>? ?? const [];
    final firstChoice = choices.isEmpty
        ? null
        : choices.first as Map<String, dynamic>;
    final message = firstChoice?['message'] as Map<String, dynamic>?;
    final text = (message?['content'] ?? '').toString().trim();

    if (text.isEmpty) {
      throw AiProviderValidationException('OpenAI returned an empty response.');
    }

    final usage = data['usage'] as Map<String, dynamic>?;
    final totalTokens = usage?['total_tokens'] as int?;

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
    final response = await http.post(
      Uri.parse('${_baseUrlFor(profile)}/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': profile.model,
        'messages': const [
          {'role': 'user', 'content': 'Reply with OK.'},
        ],
        'temperature': 0,
        'max_tokens': 8,
      }),
    );

    if (response.statusCode != 200) {
      throw AiProviderValidationException(
        'OpenAI validation failed (${response.statusCode}). ${response.body}',
      );
    }
  }

  String _baseUrlFor(AiProviderProfile profile) {
    final custom = profile.baseUrl?.trim() ?? '';
    if (custom.isEmpty) return _defaultBaseUrl;
    return custom.endsWith('/') ? custom.substring(0, custom.length - 1) : custom;
  }
}
