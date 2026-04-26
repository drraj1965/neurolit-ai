import '../../models/ai_provider_profile.dart';
import '../../models/ai_request_models.dart';
import '../token/token_service.dart';
import 'ai_exceptions.dart';
import 'ai_provider_client.dart';
import 'ai_provider_store.dart';
import 'providers/gemini_client.dart';
import 'providers/openai_client.dart';
import 'providers/sarvam_client.dart';

class AiProviderRouter {
  final AiProviderStore store;
  final TokenService tokenService;

  AiProviderRouter({
    required this.store,
    required this.tokenService,
  });

  Future<bool> hasActiveProvider() {
    return store.hasActiveProvider();
  }

  Future<AiProviderProfile?> getActiveProfile() {
    return store.getActiveProfile();
  }

  Future<AiTextResponse> generateText(AiTextRequest request) async {
    final profile = request.providerOverrideId == null ||
            request.providerOverrideId!.trim().isEmpty
        ? await store.getActiveProfile()
        : await store.getProfile(request.providerOverrideId!.trim());
    if (profile == null) {
      throw AiConfigurationRequiredException();
    }

    final apiKey = await store.readApiKey(profile.id);
    if (apiKey == null || apiKey.isEmpty) {
      throw AiConfigurationRequiredException(
        'The active provider is missing an API key.',
      );
    }

    final client = _clientFor(profile.type);
    final response = await client.generateText(
      profile: profile,
      apiKey: apiKey,
      request: request,
    );

    if (response.totalTokens != null) {
      await tokenService.logUsage(
        response.totalTokens!,
        providerId: profile.id,
        providerLabel: profile.label,
        providerType: profile.type.storageValue,
        modelUsed: _resolvedModel(profile, request),
        useCase: request.useCase.name,
      );
    }

    return response;
  }

  Future<void> validateProfile({
    required AiProviderProfile profile,
    required String apiKey,
  }) async {
    final client = _clientFor(profile.type);
    await client.validate(profile: profile, apiKey: apiKey);
  }

  AiProviderClient _clientFor(AiProviderType type) {
    switch (type) {
      case AiProviderType.openai:
        return OpenAiClient();
      case AiProviderType.gemini:
        return GeminiClient();
      case AiProviderType.sarvam:
        return SarvamClient();
    }
  }

  String _resolvedModel(AiProviderProfile profile, AiTextRequest request) {
    final candidate = (request.modelOverride ?? profile.model).trim();
    if (candidate.isNotEmpty) {
      return candidate;
    }

    return profile.type.defaultModel;
  }
}
