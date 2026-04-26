import '../models/article.dart';
import '../models/literature_mode.dart';
import 'api_service.dart';
import 'engineering_api_service.dart';

class SearchResponse {
  final List<Article> articles;
  final String emptyMessage;

  const SearchResponse({
    required this.articles,
    required this.emptyMessage,
  });
}

class SearchService {
  final ApiService medicalApi;
  final EngineeringApiService engineeringApi;

  SearchService({
    ApiService? medicalApi,
    EngineeringApiService? engineeringApi,
  })  : medicalApi = medicalApi ?? ApiService(),
        engineeringApi = engineeringApi ?? EngineeringApiService();

  Future<SearchResponse> search({
    required LiteratureMode mode,
    required String query,
    required String dateFilter,
    required bool fallback,
    DateTime? customFrom,
    DateTime? customTo,
    String textAvailability = 'any',
    String articleType = 'any',
  }) async {
    if (mode == LiteratureMode.medical) {
      final articles = await medicalApi.searchArticles(
        query,
        dateFilter,
        fallback: fallback,
        customFrom: customFrom,
        customTo: customTo,
        textAvailability: textAvailability,
        articleType: articleType,
      );

      if (articles.isNotEmpty) {
        return SearchResponse(
          articles: articles,
          emptyMessage: '',
        );
      }

      final hint = await medicalApi.getLatestArticleHint(query);
      return SearchResponse(
        articles: const [],
        emptyMessage: hint,
      );
    }

    try {
      final articles = await engineeringApi.searchArticles(query);
      if (articles.isNotEmpty) {
        return SearchResponse(
          articles: articles,
          emptyMessage: '',
        );
      }

      return const SearchResponse(
        articles: [],
        emptyMessage:
            'No engineering literature was found in CORE, DOAJ, or arXiv for this query.',
      );
    } catch (e) {
      return SearchResponse(
        articles: const [],
        emptyMessage:
            'Engineering sources are unavailable right now.\n\n$e\n\nCheck that the FastAPI backend is running and try again.',
      );
    }
  }
}
