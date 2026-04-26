import 'ai_provider_profile.dart';

class AiProviderSettings {
  final String? activeProviderId;
  final List<AiProviderProfile> profiles;

  const AiProviderSettings({
    required this.activeProviderId,
    required this.profiles,
  });

  Map<String, dynamic> toJson() {
    return {
      'activeProviderId': activeProviderId,
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
    };
  }

  factory AiProviderSettings.fromJson(Map<String, dynamic> json) {
    final rawProfiles = json['profiles'] as List<dynamic>? ?? const [];
    return AiProviderSettings(
      activeProviderId: json['activeProviderId']?.toString(),
      profiles: rawProfiles
          .whereType<Map>()
          .map(
            (profile) => AiProviderProfile.fromJson(
              Map<String, dynamic>.from(profile),
            ),
          )
          .toList(),
    );
  }

  AiProviderSettings copyWith({
    String? activeProviderId,
    List<AiProviderProfile>? profiles,
  }) {
    return AiProviderSettings(
      activeProviderId: activeProviderId ?? this.activeProviderId,
      profiles: profiles ?? this.profiles,
    );
  }
}
