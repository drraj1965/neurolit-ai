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
    final model = _resolvedModel(profile, request.modelOverride);
    final response = await http.post(
      Uri.parse('${_baseUrlFor(profile)}/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(
        _buildChatCompletionPayload(
          model: model,
          prompt: request.prompt,
          temperature: request.temperature,
        ),
      ),
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
    final model = _resolvedModel(profile, null);
    final response = await http.post(
      Uri.parse('${_baseUrlFor(profile)}/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(
        _buildValidationPayload(model: model),
      ),
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

  Map<String, dynamic> _buildChatCompletionPayload({
    required String model,
    required String prompt,
    required double temperature,
  }) {
    final payload = <String, dynamic>{
      'model': model,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
    };

    if (_supportsCustomTemperature(model)) {
      payload['temperature'] = temperature;
    }

    return payload;
  }

  Map<String, dynamic> _buildValidationPayload({
    required String model,
  }) {
    final payload = <String, dynamic>{
      'model': model,
      'messages': const [
        {'role': 'user', 'content': 'Reply with OK.'},
      ],
      _maxOutputTokenParameter(model): 8,
    };

    if (_supportsCustomTemperature(model)) {
      payload['temperature'] = 0;
    }

    return payload;
  }

  String _resolvedModel(AiProviderProfile profile, String? overrideModel) {
    final candidate = (overrideModel ?? profile.model).trim();
    if (candidate.isNotEmpty) {
      return candidate;
    }

    return profile.type.defaultModel;
  }

  bool _supportsCustomTemperature(String model) {
    final normalized = model.trim().toLowerCase();
    if (normalized.startsWith('gpt-5')) {
      return false;
    }

    return true;
  }

  String _maxOutputTokenParameter(String model) {
    final normalized = model.trim().toLowerCase();
    if (normalized.startsWith('gpt-5')) {
      return 'max_completion_tokens';
    }

    return 'max_tokens';
  }
}
