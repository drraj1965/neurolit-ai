enum UpdateFrequency {
  daily,
  weekly,
  monthly,
  manual,
}

extension UpdateFrequencyX on UpdateFrequency {
  String get displayLabel {
    switch (this) {
      case UpdateFrequency.daily:
        return 'Daily';
      case UpdateFrequency.weekly:
        return 'Weekly';
      case UpdateFrequency.monthly:
        return 'Monthly';
      case UpdateFrequency.manual:
        return 'Manual';
    }
  }

  Duration? get interval {
    switch (this) {
      case UpdateFrequency.daily:
        return const Duration(days: 1);
      case UpdateFrequency.weekly:
        return const Duration(days: 7);
      case UpdateFrequency.monthly:
        return const Duration(days: 30);
      case UpdateFrequency.manual:
        return null;
    }
  }

  String get storageValue => name;

  static UpdateFrequency fromStorage(String? value) {
    for (final frequency in UpdateFrequency.values) {
      if (frequency.name == value) return frequency;
    }
    return UpdateFrequency.weekly;
  }
}

class UpdateInfo {
  const UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      latestVersion: (json['latest_version'] ?? '').toString().trim(),
      downloadUrl: (json['download_url'] ?? '').toString().trim(),
      releaseNotes: (json['release_notes'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latest_version': latestVersion,
      'download_url': downloadUrl,
      'release_notes': releaseNotes,
    };
  }
}

class UpdateSettings {
  const UpdateSettings({
    required this.frequency,
    this.lastCheckedAt,
  });

  final UpdateFrequency frequency;
  final DateTime? lastCheckedAt;

  UpdateSettings copyWith({
    UpdateFrequency? frequency,
    DateTime? lastCheckedAt,
    bool clearLastCheckedAt = false,
  }) {
    return UpdateSettings(
      frequency: frequency ?? this.frequency,
      lastCheckedAt: clearLastCheckedAt
          ? null
          : (lastCheckedAt ?? this.lastCheckedAt),
    );
  }
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    this.updateInfo,
    required this.isUpdateAvailable,
    this.wasSkippedBySchedule = false,
  });

  final String currentVersion;
  final UpdateInfo? updateInfo;
  final bool isUpdateAvailable;
  final bool wasSkippedBySchedule;
}
