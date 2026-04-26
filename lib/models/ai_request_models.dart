import 'ai_provider_profile.dart';

enum AiUseCase {
  review,
  teaching,
  laymanQuick,
  laymanDetailed,
  laymanPpt,
  custom,
}

class AiTextRequest {
  final AiUseCase useCase;
  final String prompt;
  final double temperature;
  final String? modelOverride;
  final String? providerOverrideId;

  const AiTextRequest({
    required this.useCase,
    required this.prompt,
    this.temperature = 0.2,
    this.modelOverride,
    this.providerOverrideId,
  });
}

class AiTextResponse {
  final String text;
  final int? totalTokens;
  final String providerId;
  final AiProviderType providerType;

  const AiTextResponse({
    required this.text,
    required this.totalTokens,
    required this.providerId,
    required this.providerType,
  });
}
