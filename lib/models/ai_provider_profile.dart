enum AiProviderType { openai, gemini, sarvam }

AiProviderType aiProviderTypeFromValue(String value) {
  switch (value) {
    case 'openai':
      return AiProviderType.openai;
    case 'gemini':
      return AiProviderType.gemini;
    case 'sarvam':
      return AiProviderType.sarvam;
    default:
      return AiProviderType.openai;
  }
}

extension AiProviderTypeX on AiProviderType {
  String get storageValue {
    switch (this) {
      case AiProviderType.openai:
        return 'openai';
      case AiProviderType.gemini:
        return 'gemini';
      case AiProviderType.sarvam:
        return 'sarvam';
    }
  }

  String get displayName {
    switch (this) {
      case AiProviderType.openai:
        return 'OpenAI';
      case AiProviderType.gemini:
        return 'Gemini';
      case AiProviderType.sarvam:
        return 'Sarvam AI';
    }
  }

  String get defaultModel {
    switch (this) {
      case AiProviderType.openai:
        return 'gpt-5.5';
      case AiProviderType.gemini:
        return 'gemini-2.5-flash';
      case AiProviderType.sarvam:
        return 'sarvam-30b';
    }
  }

  bool get supportsValidation {
    return true;
  }

  bool get supportsRuntimeToday {
    return true;
  }
}

class AiProviderProfile {
  final String id;
  final AiProviderType type;
  final String label;
  final String model;
  final String? baseUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiProviderProfile({
    required this.id,
    required this.type,
    required this.label,
    required this.model,
    this.baseUrl,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.storageValue,
      'label': label,
      'model': model,
      'baseUrl': baseUrl,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AiProviderProfile.fromJson(Map<String, dynamic> json) {
    return AiProviderProfile(
      id: (json['id'] ?? '').toString(),
      type: aiProviderTypeFromValue((json['type'] ?? 'openai').toString()),
      label: (json['label'] ?? '').toString(),
      model: (json['model'] ?? '').toString(),
      baseUrl: json['baseUrl']?.toString(),
      isActive: json['isActive'] == true,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  AiProviderProfile copyWith({
    String? id,
    AiProviderType? type,
    String? label,
    String? model,
    String? baseUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AiProviderProfile(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      model: model ?? this.model,
      baseUrl: baseUrl ?? this.baseUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
