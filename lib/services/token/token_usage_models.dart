class TokenUsageEntry {
  final DateTime timestamp;
  final int tokens;
  final String providerId;
  final String providerLabel;
  final String providerType;
  final String modelUsed;
  final String useCase;

  const TokenUsageEntry({
    required this.timestamp,
    required this.tokens,
    required this.providerId,
    required this.providerLabel,
    required this.providerType,
    required this.modelUsed,
    required this.useCase,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'tokens': tokens,
      'providerId': providerId,
      'providerLabel': providerLabel,
      'providerType': providerType,
      'modelUsed': modelUsed,
      'useCase': useCase,
    };
  }

  factory TokenUsageEntry.fromJson(Map<String, dynamic> json) {
    return TokenUsageEntry(
      timestamp: DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.now(),
      tokens: (json['tokens'] as num?)?.toInt() ?? 0,
      providerId: (json['providerId'] ?? 'legacy_unknown').toString(),
      providerLabel: (json['providerLabel'] ?? 'Legacy/Unknown').toString(),
      providerType: (json['providerType'] ?? 'legacy').toString(),
      modelUsed: (json['modelUsed'] ?? '').toString(),
      useCase: (json['useCase'] ?? 'unknown').toString(),
    );
  }
}

class ProviderTokenSummary {
  final String providerId;
  final String providerLabel;
  final String providerType;
  final String lastModelUsed;
  final String lastUseCase;
  final int lastRun;
  final int today;
  final int week;
  final int month;

  const ProviderTokenSummary({
    required this.providerId,
    required this.providerLabel,
    required this.providerType,
    required this.lastModelUsed,
    required this.lastUseCase,
    required this.lastRun,
    required this.today,
    required this.week,
    required this.month,
  });
}

class TokenUsageSummary {
  final ProviderTokenSummary allProviders;
  final List<ProviderTokenSummary> byProvider;

  const TokenUsageSummary({
    required this.allProviders,
    required this.byProvider,
  });

  int get lastRun => allProviders.lastRun;
  int get today => allProviders.today;
  int get week => allProviders.week;
  int get month => allProviders.month;
}
