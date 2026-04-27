import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../models/ai_provider_profile.dart';
import '../storage/neuro_lit_path_service.dart';
import 'token_usage_models.dart';

class TokenService {
  static final TokenService _instance = TokenService._internal();
  static const _legacyProviderId = 'legacy_unknown';
  static const _legacyProviderLabel = 'Legacy/Unknown';
  static const _legacyProviderType = 'legacy';

  factory TokenService() => _instance;

  TokenService._internal();

  final NeuroLitPathService _pathService = NeuroLitPathService();

  int lastUsage = 0;
  final ValueNotifier<int> lastUsageNotifier = ValueNotifier<int>(0);

  Future<File> _getFile() async {
    return _pathService.getTokenUsageFile();
  }

  Future<void> logUsage(
    int tokens, {
    String providerId = _legacyProviderId,
    String providerLabel = _legacyProviderLabel,
    String providerType = _legacyProviderType,
    String modelUsed = '',
    String useCase = 'unknown',
  }) async {
    lastUsage = tokens;
    lastUsageNotifier.value = tokens;

    final entries = await _readEntries();
    entries.add(
      TokenUsageEntry(
        timestamp: DateTime.now(),
        tokens: tokens,
        providerId: providerId,
        providerLabel: providerLabel,
        providerType: providerType,
        modelUsed: modelUsed,
        useCase: useCase,
      ),
    );

    await _writeEntries(entries);
  }

  Future<Map<String, int>> getStats() async {
    final summary = await getUsageSummary();
    return {
      "today": summary.today,
      "week": summary.week,
      "month": summary.month,
    };
  }

  Future<TokenUsageSummary> getUsageSummary() async {
    final entries = await _readEntries();
    if (entries.isEmpty) {
      return TokenUsageSummary(
        allProviders: _buildEmptySummaryRow(),
        byProvider: [],
      );
    }

    final now = DateTime.now();
    final sortedEntries = List<TokenUsageEntry>.from(entries)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final latestOverall = sortedEntries.first;
    int today = 0;
    int week = 0;
    int month = 0;
    final grouped = <String, List<TokenUsageEntry>>{};

    for (final entry in sortedEntries) {
      final groupKey = _groupKey(entry.providerType);
      grouped.putIfAbsent(groupKey, () => []).add(entry);

      if (_isSameDay(entry.timestamp, now)) {
        today += entry.tokens;
      }

      if (_isSameWeek(entry.timestamp, now)) {
        week += entry.tokens;
      }

      if (entry.timestamp.year == now.year && entry.timestamp.month == now.month) {
        month += entry.tokens;
      }
    }

    final providerSummaries = grouped.entries.map((group) {
      final providerEntries = List<TokenUsageEntry>.from(group.value)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final latest = providerEntries.first;
      final providerType = _groupKey(latest.providerType);

      int providerToday = 0;
      int providerWeek = 0;
      int providerMonth = 0;

      for (final entry in providerEntries) {
        if (_isSameDay(entry.timestamp, now)) {
          providerToday += entry.tokens;
        }

        if (_isSameWeek(entry.timestamp, now)) {
          providerWeek += entry.tokens;
        }

        if (entry.timestamp.year == now.year &&
            entry.timestamp.month == now.month) {
          providerMonth += entry.tokens;
        }
      }

      return ProviderTokenSummary(
        providerId: providerType,
        providerLabel: _providerDisplayLabel(
          providerType,
          latest.providerLabel,
        ),
        providerType: providerType,
        lastModelUsed: latest.modelUsed,
        lastUseCase: latest.useCase,
        lastRun: latest.tokens,
        today: providerToday,
        week: providerWeek,
        month: providerMonth,
      );
    }).toList()
      ..sort((a, b) {
        final orderComparison = _providerSortOrder(
          a.providerType,
        ).compareTo(_providerSortOrder(b.providerType));
        if (orderComparison != 0) return orderComparison;
        return a.providerLabel.toLowerCase().compareTo(
          b.providerLabel.toLowerCase(),
        );
      });

    return TokenUsageSummary(
      allProviders: ProviderTokenSummary(
        providerId: 'all',
        providerLabel: 'All Providers',
        providerType: 'all',
        lastModelUsed: latestOverall.modelUsed,
        lastUseCase: latestOverall.useCase,
        lastRun: latestOverall.tokens,
        today: today,
        week: week,
        month: month,
      ),
      byProvider: providerSummaries,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  bool _isSameWeek(DateTime a, DateTime b) {
    final startOfWeek =
        b.subtract(Duration(days: b.weekday % 7));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return a.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
        a.isBefore(endOfWeek.add(const Duration(days: 1)));
  }

  Future<List<TokenUsageEntry>> _readEntries() async {
    final file = await _getFile();
    if (!await file.exists()) {
      return <TokenUsageEntry>[];
    }

    try {
      final decoded = jsonDecode(await file.readAsString());

      if (decoded is Map<String, dynamic>) {
        final rawEntries = decoded['entries'];
        if (rawEntries is List) {
          return rawEntries
              .whereType<Map>()
              .map(
                (entry) => TokenUsageEntry.fromJson(
                  entry.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                ),
              )
              .toList();
        }

        return _readLegacyMapEntries(decoded);
      }

      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (entry) => TokenUsageEntry.fromJson(
                entry.map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              ),
            )
            .toList();
      }
    } catch (_) {
      return <TokenUsageEntry>[];
    }

    return <TokenUsageEntry>[];
  }

  List<TokenUsageEntry> _readLegacyMapEntries(Map<String, dynamic> decoded) {
    final entries = <TokenUsageEntry>[];

    for (final entry in decoded.entries) {
      if (entry.value is! num) continue;

      final timestamp = DateTime.tryParse(entry.key);
      if (timestamp == null) continue;

      entries.add(
        TokenUsageEntry(
          timestamp: timestamp,
          tokens: (entry.value as num).toInt(),
          providerId: _legacyProviderId,
          providerLabel: _legacyProviderLabel,
          providerType: _legacyProviderType,
          modelUsed: '',
          useCase: 'unknown',
        ),
      );
    }

    return entries;
  }

  Future<void> _writeEntries(List<TokenUsageEntry> entries) async {
    final file = await _getFile();
    await file.writeAsString(
      jsonEncode({
        'entries': entries.map((entry) => entry.toJson()).toList(),
      }),
    );
  }

  ProviderTokenSummary _buildEmptySummaryRow() {
    return const ProviderTokenSummary(
      providerId: 'all',
      providerLabel: 'All Providers',
      providerType: 'all',
      lastModelUsed: '',
      lastUseCase: '',
      lastRun: 0,
      today: 0,
      week: 0,
      month: 0,
    );
  }

  String _groupKey(String providerType) {
    switch (providerType) {
      case 'openai':
      case 'gemini':
      case 'sarvam':
        return providerType;
      default:
        return _legacyProviderType;
    }
  }

  String _providerDisplayLabel(String providerType, String fallbackLabel) {
    switch (providerType) {
      case 'openai':
        return AiProviderType.openai.displayName;
      case 'gemini':
        return AiProviderType.gemini.displayName;
      case 'sarvam':
        return AiProviderType.sarvam.displayName;
      case 'all':
        return 'All Providers';
      default:
        final trimmedFallback = fallbackLabel.trim();
        return trimmedFallback.isEmpty ? 'Legacy / Unknown' : trimmedFallback;
    }
  }

  int _providerSortOrder(String providerType) {
    switch (providerType) {
      case 'openai':
        return 0;
      case 'gemini':
        return 1;
      case 'sarvam':
        return 2;
      default:
        return 99;
    }
  }
}
