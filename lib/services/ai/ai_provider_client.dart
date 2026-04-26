import '../../models/ai_provider_profile.dart';
import '../../models/ai_request_models.dart';

abstract class AiProviderClient {
  Future<AiTextResponse> generateText({
    required AiProviderProfile profile,
    required String apiKey,
    required AiTextRequest request,
  });

  Future<void> validate({
    required AiProviderProfile profile,
    required String apiKey,
  });
}
