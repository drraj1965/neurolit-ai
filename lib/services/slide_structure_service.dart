import '../models/slide_deck_model.dart';

class SlideStructureService {
  static const int maxPointsPerSlide = 6;
  static const int maxWordsPerPoint = 18;

  static final Map<String, List<String>> _sectionAliases = {
    'background': [
      'background',
      'introduction',
      'overview',
      'context',
      'rationale',
      'why this matters',
    ],
    'methods': [
      'methods',
      'methodology',
      'study methods',
      'search strategy',
      'materials and methods',
      'design',
    ],
    'key_findings': [
      'results',
      'findings',
      'key findings',
      'main findings',
      'outcomes',
      'evidence summary',
      'summary of evidence',
    ],
    'mechanism': [
      'mechanism',
      'mechanisms',
      'pathophysiology',
      'disease mechanism',
      'biological basis',
    ],
    'clinical_implications': [
      'clinical implications',
      'clinical relevance',
      'practical implications',
      'practice points',
      'treatment implications',
      'management implications',
    ],
    'limitations': [
      'limitations',
      'weaknesses',
      'caveats',
      'constraints',
      'gaps',
    ],
    'conclusion': [
      'conclusion',
      'conclusions',
      'take home',
      'take-home points',
      'summary',
      'final thoughts',
    ],
    'references': [
      'references',
      'bibliography',
      'citations',
    ],
  };

  static SlideDeckModel generateSlideDeck({
    required String topic,
    required String reviewText,
  }) {
    final cleanedTopic = _cleanText(topic).trim().isEmpty
        ? 'NeuroLit AI Review'
        : _cleanText(topic).trim();

    final cleanedReview = _normalizeReview(reviewText);
    final sectionMap = _extractSections(cleanedReview);

    final slides = <SlideItem>[];

    // 1. Title slide
    slides.add(
      SlideItem(
        title: cleanedTopic,
        points: const [
          'AI-generated literature synthesis',
          'Prepared using NeuroLit AI',
        ],
        section: 'title',
      ),
    );

    // 2. Background / Introduction
    slides.addAll(_buildSlidesForCanonicalSection(
      canonicalSection: 'background',
      displayTitle: 'Background / Introduction',
      rawText: sectionMap['background'] ?? '',
      fallbackText: cleanedReview,
      maxSlides: 2,
    ));

    // 3. Methods
    slides.addAll(_buildSlidesForCanonicalSection(
      canonicalSection: 'methods',
      displayTitle: 'Methods',
      rawText: sectionMap['methods'] ?? '',
      fallbackText: '',
      maxSlides: 1,
    ));

    // 4. Key Findings
    slides.addAll(_buildSlidesForCanonicalSection(
      canonicalSection: 'key_findings',
      displayTitle: 'Key Findings',
      rawText: sectionMap['key_findings'] ?? '',
      fallbackText: cleanedReview,
      maxSlides: 4,
    ));

    // 5. Mechanism / Pathophysiology
    slides.addAll(_buildSlidesForCanonicalSection(
      canonicalSection: 'mechanism',
      displayTitle: 'Mechanism / Pathophysiology',
      rawText: sectionMap['mechanism'] ?? '',
      fallbackText: '',
      maxSlides: 2,
    ));

    // 6. Clinical implications
    slides.addAll(_buildSlidesForCanonicalSection(
      canonicalSection: 'clinical_implications',
      displayTitle: 'Clinical Implications',
      rawText: sectionMap['clinical_implications'] ?? '',
      fallbackText: '',
      maxSlides: 2,
    ));

    // 7. Limitations
    slides.addAll(_buildSlidesForCanonicalSection(
      canonicalSection: 'limitations',
      displayTitle: 'Limitations',
      rawText: sectionMap['limitations'] ?? '',
      fallbackText: '',
      maxSlides: 1,
    ));

    // 8. Conclusion
    slides.addAll(_buildSlidesForCanonicalSection(
      canonicalSection: 'conclusion',
      displayTitle: 'Conclusion',
      rawText: sectionMap['conclusion'] ?? '',
      fallbackText: cleanedReview,
      maxSlides: 1,
    ));

    // 9. References
    final referenceSlide = _buildReferencesSlide(sectionMap['references'] ?? '');
    if (referenceSlide != null) {
      slides.add(referenceSlide);
    }

    // Final cleanup
    final finalSlides = slides
        .where((s) => s.points.isNotEmpty && s.title.trim().isNotEmpty)
        .map(_dedupeSlidePoints)
        .toList();

    return SlideDeckModel(
      topic: cleanedTopic,
      slides: finalSlides,
    );
  }

  static String generateSlideDeckJson({
    required String topic,
    required String reviewText,
  }) {
    final deck = generateSlideDeck(topic: topic, reviewText: reviewText);
    return deck.toPrettyJson();
  }

  static Map<String, String> _extractSections(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final result = <String, String>{};
    String? currentCanonical;
    final buffer = <String>[];

    void flush() {
      if (currentCanonical != null && buffer.isNotEmpty) {
        final existing = result[currentCanonical!] ?? '';
        result[currentCanonical!] = [existing, buffer.join('\n')]
            .where((e) => e.trim().isNotEmpty)
            .join('\n')
            .trim();
      }
      buffer.clear();
    }

    for (final line in lines) {
      final matchedCanonical = _matchCanonicalSection(line);
      if (matchedCanonical != null && _looksLikeHeading(line)) {
        flush();
        currentCanonical = matchedCanonical;
      } else {
        buffer.add(line);
      }
    }
    flush();

    return result;
  }

  static String? _matchCanonicalSection(String line) {
    final normalized = _normalizeHeading(line);

    for (final entry in _sectionAliases.entries) {
      for (final alias in entry.value) {
        if (normalized == alias) return entry.key;
        if (normalized.startsWith(alias)) return entry.key;
      }
    }
    return null;
  }

  static bool _looksLikeHeading(String line) {
    final trimmed = line.trim();
    if (trimmed.length > 60) return false;
    if (trimmed.split(RegExp(r'\s+')).length > 8) return false;

    final normalized = _normalizeHeading(trimmed);
    if (normalized.isEmpty) return false;

    for (final aliases in _sectionAliases.values) {
      for (final alias in aliases) {
        if (normalized == alias || normalized.startsWith(alias)) {
          return true;
        }
      }
    }

    return false;
  }

  static String _normalizeHeading(String input) {
    var s = input.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'^[\-\•\*\d\.\)\(]+'), '');
    s = s.replaceAll(':', '');
    s = s.replaceAll('/', ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s.trim();
  }

  static List<SlideItem> _buildSlidesForCanonicalSection({
    required String canonicalSection,
    required String displayTitle,
    required String rawText,
    required String fallbackText,
    required int maxSlides,
  }) {
    String source = rawText.trim();

    if (source.isEmpty && fallbackText.trim().isNotEmpty) {
      source = _inferFallbackContent(canonicalSection, fallbackText);
    }

    if (source.trim().isEmpty) return [];

    final points = _extractBulletPoints(source);

    if (points.isEmpty) return [];

    final chunks = _chunkPoints(points, maxPointsPerSlide);
    final limitedChunks = chunks.take(maxSlides).toList();

    final slides = <SlideItem>[];

    for (int i = 0; i < limitedChunks.length; i++) {
      final suffix = limitedChunks.length > 1 ? ' (${i + 1})' : '';
      slides.add(
        SlideItem(
          title: '$displayTitle$suffix',
          points: limitedChunks[i],
          section: canonicalSection,
        ),
      );
    }

    return slides;
  }

  static String _inferFallbackContent(String section, String reviewText) {
    final sentences = _splitIntoSentences(reviewText);

    bool matches(String sentence) {
      final s = sentence.toLowerCase();

      switch (section) {
        case 'background':
          return s.contains('multiple sclerosis') ||
              s.contains('disease') ||
              s.contains('background') ||
              s.contains('important') ||
              s.contains('burden') ||
              s.contains('overview') ||
              s.contains('condition');
        case 'methods':
          return s.contains('search') ||
              s.contains('reviewed') ||
              s.contains('included') ||
              s.contains('study') ||
              s.contains('studies') ||
              s.contains('meta-analysis') ||
              s.contains('systematic review');
        case 'key_findings':
          return s.contains('found') ||
              s.contains('result') ||
              s.contains('evidence') ||
              s.contains('improved') ||
              s.contains('associated') ||
              s.contains('reduced') ||
              s.contains('increased');
        case 'mechanism':
          return s.contains('mechanism') ||
              s.contains('pathophysiology') ||
              s.contains('immune') ||
              s.contains('inflammatory') ||
              s.contains('neuronal') ||
              s.contains('axonal') ||
              s.contains('synaptic');
        case 'clinical_implications':
          return s.contains('clinical') ||
              s.contains('practice') ||
              s.contains('management') ||
              s.contains('treatment') ||
              s.contains('screening') ||
              s.contains('monitoring');
        case 'limitations':
          return s.contains('limitation') ||
              s.contains('heterogeneity') ||
              s.contains('small sample') ||
              s.contains('bias') ||
              s.contains('uncertain') ||
              s.contains('further study');
        case 'conclusion':
          return s.contains('conclude') ||
              s.contains('overall') ||
              s.contains('in summary') ||
              s.contains('taken together') ||
              s.contains('future') ||
              s.contains('promise');
      }

      return false;
    }

    final selected = sentences.where(matches).take(12).toList();
    return selected.join('\n');
  }

  static List<String> _extractBulletPoints(String text) {
    final lines = text
        .split('\n')
        .map((e) => _cleanText(e))
        .where((e) => e.isNotEmpty)
        .toList();

    final points = <String>[];

    for (final line in lines) {
      final stripped = line.replaceFirst(RegExp(r'^[\-\•\*\d\.\)\(]+\s*'), '');

      if (_looksLikeMultiSentenceParagraph(stripped)) {
        final sentences = _splitIntoSentences(stripped);
        for (final sentence in sentences) {
          final point = _shortenPoint(sentence);
          if (point.isNotEmpty) points.add(point);
        }
      } else {
        final point = _shortenPoint(stripped);
        if (point.isNotEmpty) points.add(point);
      }
    }

    return _dedupeStrings(points);
  }

  static bool _looksLikeMultiSentenceParagraph(String text) {
    final sentenceCount =
        RegExp(r'[.!?]').allMatches(text).length;
    return text.length > 140 || sentenceCount >= 2;
  }

  static List<String> _splitIntoSentences(String text) {
    final normalized = text.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
    final raw = normalized.split(RegExp(r'(?<=[.!?])\s+'));
    return raw
        .map((e) => _cleanText(e))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static List<List<String>> _chunkPoints(List<String> items, int chunkSize) {
    final chunks = <List<String>>[];
    for (int i = 0; i < items.length; i += chunkSize) {
      final end = (i + chunkSize < items.length) ? i + chunkSize : items.length;
      chunks.add(items.sublist(i, end));
    }
    return chunks;
  }

  static String _shortenPoint(String input) {
    String text = _cleanText(input);

    text = text.replaceAll(RegExp(r'^[\-\•\*\d\.\)\(]+\s*'), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (text.isEmpty) return '';

    final words = text.split(' ');
    if (words.length > maxWordsPerPoint) {
      text = '${words.take(maxWordsPerPoint).join(' ')}...';
    }

    text = text.replaceAll(RegExp(r'^[,:;.\-]+'), '').trim();
    text = text.replaceAll(RegExp(r'[,:;]+$'), '').trim();

    if (text.isEmpty) return '';
    return _sentenceCase(text);
  }

  static SlideItem _dedupeSlidePoints(SlideItem slide) {
    final unique = _dedupeStrings(slide.points)
        .where((e) => e.trim().isNotEmpty)
        .toList();
    return SlideItem(
      title: slide.title,
      points: unique,
      section: slide.section,
    );
  }

  static List<String> _dedupeStrings(List<String> items) {
    final seen = <String>{};
    final output = <String>[];

    for (final item in items) {
      final key = item.toLowerCase().trim();
      if (key.isEmpty) continue;
      if (seen.contains(key)) continue;
      seen.add(key);
      output.add(item.trim());
    }

    return output;
  }

  static SlideItem? _buildReferencesSlide(String rawReferences) {
    final refs = <String>[];

    if (rawReferences.trim().isNotEmpty) {
      final lines = rawReferences
          .split('\n')
          .map((e) => _cleanText(e))
          .where((e) => e.isNotEmpty)
          .toList();

      for (final line in lines) {
        final cleaned = line.replaceFirst(RegExp(r'^[\-\•\*\d\.\)\(]+\s*'), '');
        if (cleaned.isNotEmpty) refs.add(cleaned);
        if (refs.length >= 6) break;
      }
    }

    if (refs.isEmpty) {
      return SlideItem(
        title: 'References',
        points: const [
          'References available in source review/session file',
          'PubMed-derived evidence base used for synthesis',
        ],
        section: 'references',
      );
    }

    return SlideItem(
      title: 'References',
      points: refs.take(6).toList(),
      section: 'references',
    );
  }

  static String _normalizeReview(String input) {
    var text = input.replaceAll('\r\n', '\n');
    text = text.replaceAll('\r', '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.replaceAll('\t', ' ');
    text = text.replaceAll(RegExp(r'[ ]{2,}'), ' ');
    return text.trim();
  }

  static String _cleanText(String input) {
    return input
        .replaceAll('\u2022', '•')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _sentenceCase(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }
}