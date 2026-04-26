import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/article.dart';
import 'local_backend_launcher_service.dart';

class EngineeringApiService {
  static const String _defaultBaseUrl = String.fromEnvironment(
    'NEUROLIT_ENGINEERING_BACKEND_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final String baseUrl;
  final http.Client _client;
  final LocalBackendLauncherService _backendLauncher;

  EngineeringApiService({
    String? baseUrl,
    http.Client? client,
    LocalBackendLauncherService? backendLauncher,
  })  : baseUrl = (baseUrl ?? _defaultBaseUrl).replaceAll(RegExp(r'/$'), ''),
        _client = client ?? http.Client(),
        _backendLauncher = backendLauncher ?? LocalBackendLauncherService();

  Future<List<Article>> searchArticles(String query) async {
    try {
      await _backendLauncher.ensureEngineeringBackendRunning(baseUrl: baseUrl);
    } catch (e) {
      throw Exception(
        'Engineering backend could not be started automatically.\n\n$e',
      );
    }

    final uri = Uri.parse(
      '$baseUrl/engineering/combined-search',
    ).replace(queryParameters: {'query': query});

    http.Response response;
    try {
      response = await _client.get(uri);
    } on SocketException {
      throw Exception(
        'Engineering backend is not running.\n\n'
        'The app tried to start it automatically, but the local service still did not respond.\n\n'
        'Start it manually with:\n'
        'powershell -ExecutionPolicy Bypass -File backend\\run_backend.ps1\n\n'
        'Then try the search again.',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Engineering backend connection failed.\n\n'
        '${e.message}\n\n'
        'Start the local backend manually with:\n'
        'powershell -ExecutionPolicy Bypass -File backend\\run_backend.ps1',
      );
    }

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final rawResults = _extractResultList(decoded);
      return rawResults
          .whereType<Map>()
          .map(
            (item) => Article.fromEngineeringJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    }

    if (response.statusCode == 503) {
      throw Exception(
        'Engineering backend is running, but one or more sources are unavailable right now.',
      );
    }

    throw Exception(
      'Engineering search failed (${response.statusCode}).',
    );
  }

  List<dynamic> _extractResultList(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map<String, dynamic> && decoded['results'] is List) {
      return decoded['results'] as List;
    }

    return const [];
  }
}
