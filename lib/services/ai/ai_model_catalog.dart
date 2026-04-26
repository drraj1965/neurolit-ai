import '../../models/ai_model_option.dart';
import '../../models/ai_provider_profile.dart';

class AiModelCatalog {
  static const String customModelValue = '__custom_model__';

  static List<AiModelOption> optionsFor(AiProviderType type) {
    switch (type) {
      case AiProviderType.openai:
        return const [
          AiModelOption(
            id: 'gpt-5.5',
            label: 'GPT-5.5',
            description: 'Newest flagship for complex research and writing.',
          ),
          AiModelOption(
            id: 'gpt-5.4',
            label: 'GPT-5.4',
            description: 'Balanced GPT-5 option for strong professional work.',
          ),
          AiModelOption(
            id: 'gpt-5.4-mini',
            label: 'GPT-5.4 Mini',
            description: 'Faster and lower-cost GPT-5 family model.',
          ),
          AiModelOption(
            id: 'gpt-5.2',
            label: 'GPT-5.2',
            description: 'Earlier GPT-5 model for deep reasoning workflows.',
          ),
        ];
      case AiProviderType.gemini:
        return const [
          AiModelOption(
            id: 'gemini-2.5-pro',
            label: 'Gemini 2.5 Pro',
            description: 'Highest-quality Gemini option for complex synthesis.',
          ),
          AiModelOption(
            id: 'gemini-2.5-flash',
            label: 'Gemini 2.5 Flash',
            description: 'Balanced Gemini option for fast literature workflows.',
          ),
          AiModelOption(
            id: 'gemini-2.5-flash-lite',
            label: 'Gemini 2.5 Flash-Lite',
            description: 'Fastest and most budget-friendly Gemini text option.',
          ),
        ];
      case AiProviderType.sarvam:
        return const [
          AiModelOption(
            id: 'sarvam-105b',
            label: 'Sarvam 105B',
            description: 'Higher-quality Sarvam model for harder reasoning.',
          ),
          AiModelOption(
            id: 'sarvam-30b',
            label: 'Sarvam 30B',
            description: 'Balanced Sarvam model for general review generation.',
          ),
        ];
    }
  }

  static bool contains(AiProviderType type, String modelId) {
    final normalized = modelId.trim();
    if (normalized.isEmpty) return false;
    return optionsFor(type).any((option) => option.id == normalized);
  }

  static AiModelOption? find(AiProviderType type, String modelId) {
    final normalized = modelId.trim();
    if (normalized.isEmpty) return null;

    for (final option in optionsFor(type)) {
      if (option.id == normalized) {
        return option;
      }
    }

    return null;
  }

  static String displayLabelFor(AiProviderType type, String modelId) {
    final option = find(type, modelId);
    if (option != null) {
      return option.label;
    }

    final trimmed = modelId.trim();
    return trimmed.isEmpty ? '(not set)' : trimmed;
  }
}
