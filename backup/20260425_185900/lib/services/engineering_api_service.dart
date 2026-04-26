import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/article.dart';

class EngineeringApiService {
  static const String _defaultBaseUrl = String.fromEnvironment(
    'NEUROLIT_ENGINEERING_BACKEND_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final String baseUrl;
  final http.Client _client;

  EngineeringApiService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = (baseUrl ?? _defaultBaseUrl).replaceAll(RegExp(r'/$'), ''),
        _client = client ?? http.Client();

  Future<List<Article>> searchArticles(String query) async {
    final uri = Uri.parse(
      '$baseUrl/engineering/combined-search',
    ).replace(queryParameters: {'query': query});

    final response = await _client.get(uri);
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
      throw Exception('Source unavailable');
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
