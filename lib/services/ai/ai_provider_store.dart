import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/ai_provider_profile.dart';
import '../../models/ai_provider_settings.dart';
import 'ai_secret_store.dart';

class AiProviderStore {
  static const _settingsKey = 'ai_provider_settings_v1';
  static const _secretPrefix = 'ai_provider_secret_';
  static const _legacyOpenAiKey = 'openai_api_key';

  final AiSecretStore secretStore;

  AiProviderStore({
    AiSecretStore? secretStore,
  }) : secretStore = secretStore ?? AiSecretStore();

  Future<AiProviderSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);

    if (raw == null || raw.trim().isEmpty) {
      return const AiProviderSettings(activeProviderId: null, profiles: []);
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return _normalizeSettings(AiProviderSettings.fromJson(decoded));
    } catch (_) {
      return const AiProviderSettings(activeProviderId: null, profiles: []);
    }
  }

  Future<List<AiProviderProfile>> getProfiles() async {
    final settings = await loadSettings();
    return settings.profiles;
  }

  Future<AiProviderProfile?> getProfile(String profileId) async {
    final settings = await loadSettings();
    for (final profile in settings.profiles) {
      if (profile.id == profileId) return profile;
    }
    return null;
  }

  Future<AiProviderProfile?> getActiveProfile() async {
    final settings = await loadSettings();
    if (settings.activeProviderId == null) return null;

    for (final profile in settings.profiles) {
      if (profile.id == settings.activeProviderId) return profile;
    }
    return null;
  }

  Future<bool> hasActiveProvider() async {
    final profile = await getActiveProfile();
    return profile != null;
  }

  Future<void> saveProfile(
    AiProviderProfile profile, {
    required String apiKey,
  }) async {
    final settings = await loadSettings();
    final profiles = settings.profiles.where((p) => p.id != profile.id).toList();

    var activeProviderId = settings.activeProviderId;
    if (activeProviderId == null || profile.isActive || profiles.isEmpty) {
      activeProviderId = profile.id;
    }

    profiles.add(
      profile.copyWith(
        isActive: activeProviderId == profile.id,
        updatedAt: DateTime.now(),
      ),
    );

    await secretStore.writeSecret(_secretKey(profile.id), apiKey.trim());

    await _persistSettings(
      AiProviderSettings(
        activeProviderId: activeProviderId,
        profiles: profiles,
      ),
    );
  }

  Future<void> updateProfile(
    AiProviderProfile profile, {
    String? apiKey,
  }) async {
    final settings = await loadSettings();
    final profiles = settings.profiles.where((p) => p.id != profile.id).toList();

    var activeProviderId = settings.activeProviderId;
    if (activeProviderId == null || profile.isActive) {
      activeProviderId = profile.id;
    }

    profiles.add(
      profile.copyWith(
        isActive: activeProviderId == profile.id,
        updatedAt: DateTime.now(),
      ),
    );

    if (apiKey != null && apiKey.trim().isNotEmpty) {
      await secretStore.writeSecret(_secretKey(profile.id), apiKey.trim());
    }

    await _persistSettings(
      AiProviderSettings(
        activeProviderId: activeProviderId,
        profiles: profiles,
      ),
    );
  }

  Future<void> deleteProfile(String profileId) async {
    final settings = await loadSettings();
    final profiles = settings.profiles.where((p) => p.id != profileId).toList();

    await secretStore.deleteSecret(_secretKey(profileId));

    var activeProviderId = settings.activeProviderId;
    if (activeProviderId == profileId) {
      activeProviderId = profiles.isEmpty ? null : profiles.first.id;
    }

    await _persistSettings(
      AiProviderSettings(
        activeProviderId: activeProviderId,
        profiles: profiles,
      ),
    );
  }

  Future<void> setActiveProfile(String profileId) async {
    final settings = await loadSettings();
    final exists = settings.profiles.any((profile) => profile.id == profileId);
    if (!exists) return;

    await _persistSettings(
      AiProviderSettings(
        activeProviderId: profileId,
        profiles: settings.profiles,
      ),
    );
  }

  Future<String?> readApiKey(String profileId) async {
    final secret = await secretStore.readSecret(_secretKey(profileId));
    if (secret == null || secret.trim().isEmpty) return null;
    return secret.trim();
  }

  Future<void> _persistSettings(AiProviderSettings settings) async {
    final normalized = _normalizeSettings(settings);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(normalized.toJson()));
    await _syncLegacyOpenAiKey(normalized, prefs);
  }

  AiProviderSettings _normalizeSettings(AiProviderSettings settings) {
    final activeProviderId = settings.activeProviderId;
    final profiles = settings.profiles
        .map(
          (profile) => profile.copyWith(
            isActive: profile.id == activeProviderId,
          ),
        )
        .toList()
      ..sort((a, b) {
        if (a.isActive && !b.isActive) return -1;
        if (!a.isActive && b.isActive) return 1;
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });

    var normalizedActiveId = activeProviderId;
    if (profiles.isNotEmpty &&
        !profiles.any((profile) => profile.id == normalizedActiveId)) {
      normalizedActiveId = profiles.first.id;
    }

    final normalizedProfiles = profiles
        .map(
          (profile) => profile.copyWith(
            isActive: profile.id == normalizedActiveId,
          ),
        )
        .toList();

    return AiProviderSettings(
      activeProviderId: normalizedActiveId,
      profiles: normalizedProfiles,
    );
  }

  Future<void> _syncLegacyOpenAiKey(
    AiProviderSettings settings,
    SharedPreferences prefs,
  ) async {
    AiProviderProfile? activeProfile;
    for (final profile in settings.profiles) {
      if (profile.id == settings.activeProviderId) {
        activeProfile = profile;
        break;
      }
    }

    if (activeProfile == null || activeProfile.type != AiProviderType.openai) {
      await prefs.remove(_legacyOpenAiKey);
      return;
    }

    final apiKey = await readApiKey(activeProfile.id);
    if (apiKey == null || apiKey.isEmpty) {
      await prefs.remove(_legacyOpenAiKey);
      return;
    }

    await prefs.setString(_legacyOpenAiKey, apiKey);
  }

  String _secretKey(String profileId) => '$_secretPrefix$profileId';
}
