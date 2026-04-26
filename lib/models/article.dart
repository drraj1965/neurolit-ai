import 'literature_mode.dart';

class Article {
  final String title;
  final String abstractText;
  final String journal;
  final String date;
  final String authors;
  final String pmid;
  final String link;

  final String publicationType;
  final bool isFree;
  final bool isPMC;
  final String pmcId;
  final bool canDownloadFullText;
  final String source;
  final String pdfUrl;
  final bool hasFullText;
  final LiteratureMode literatureMode;
  final String identifierLabel;
  final String identifierValue;

  Article({
    required this.title,
    required this.abstractText,
    required this.journal,
    required this.date,
    required this.authors,
    required this.pmid,
    required this.link,
    this.publicationType = '',
    this.isFree = false,
    this.isPMC = false,
    this.pmcId = '',
    this.canDownloadFullText = false,
    this.source = '',
    this.pdfUrl = '',
    this.hasFullText = false,
    this.literatureMode = LiteratureMode.medical,
    this.identifierLabel = 'PMID',
    this.identifierValue = '',
  });

  String get selectionKey => pmid;

  String get displayIdentifierLabel {
    final trimmed = identifierLabel.trim();
    return trimmed.isEmpty ? 'PMID' : trimmed;
  }

  String get displayIdentifierValue {
    final trimmed = identifierValue.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }

    return pmid;
  }

  String get displaySource {
    final trimmed = source.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }

    return literatureMode == LiteratureMode.medical ? 'PubMed' : 'Engineering';
  }

  String get openLinkLabel {
    return literatureMode == LiteratureMode.medical
        ? 'Open in PubMed'
        : 'Open Source Record';
  }

  String get fullTextActionLabel {
    return literatureMode == LiteratureMode.medical
        ? 'Download Full Text'
        : 'Download PDF';
  }

  factory Article.fromEngineeringJson(Map<String, dynamic> json) {
    final identifierValue = _asString(
      json['identifier_value'] ?? json['identifier'],
    );
    final id = _asString(json['id']);
    final stableId = id.isNotEmpty
        ? id
        : _buildFallbackEngineeringId(
            _asString(json['source']),
            identifierValue,
            _asString(json['title']),
          );

    final pdfUrl = _asString(json['pdf_url']);
    final link = _asString(json['link']);

    return Article(
      title: _asString(json['title']),
      abstractText: _asString(json['abstract']).isEmpty
          ? 'No abstract available.'
          : _asString(json['abstract']),
      journal: _asString(json['journal']),
      date: _asString(json['date']),
      authors: _asString(json['authors']),
      pmid: stableId,
      link: link,
      source: _asString(json['source']),
      pdfUrl: pdfUrl,
      hasFullText: _asBool(json['has_full_text']) || pdfUrl.isNotEmpty,
      canDownloadFullText:
          _asBool(json['has_full_text']) || pdfUrl.isNotEmpty,
      literatureMode: LiteratureMode.engineering,
      identifierLabel: _asString(json['identifier_label']).isEmpty
          ? 'Identifier'
          : _asString(json['identifier_label']),
      identifierValue: identifierValue.isNotEmpty ? identifierValue : stableId,
    );
  }

  static String _asString(dynamic value) {
    return (value ?? '').toString().trim();
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;

    final lowered = _asString(value).toLowerCase();
    return lowered == 'true' || lowered == '1' || lowered == 'yes';
  }

  static String _buildFallbackEngineeringId(
    String source,
    String identifierValue,
    String title,
  ) {
    final seed = [
      source.trim().toLowerCase(),
      identifierValue.trim().toLowerCase(),
      title.trim().toLowerCase(),
    ].where((part) => part.isNotEmpty).join('-');

    final normalized = seed.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final cleaned = normalized.replaceAll(RegExp(r'-+'), '-').replaceAll(
      RegExp(r'^-|-$'),
      '',
    );

    return cleaned.isEmpty ? 'engineering-result' : cleaned;
  }
}
