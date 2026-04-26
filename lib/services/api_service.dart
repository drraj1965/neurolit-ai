import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/article.dart';

class ApiService {
  Future<List<Article>> searchArticles(
  String query,
  String dateFilter, {
  bool fallback = false,
  DateTime? customFrom,
  DateTime? customTo,
  String textAvailability = 'any',
  String articleType = 'any',
}) async {
  final filter = _buildFilterClause(
    dateFilter,
    customFrom: customFrom,
    customTo: customTo,
    textAvailability: textAvailability,
    articleType: articleType,
  );

  final searchUrl = Uri.parse(
    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
    "?db=pubmed&retmode=json&retmax=50&sort=pub+date&term=" +
    Uri.encodeQueryComponent(query + filter),
  );

  final searchRes = await http.get(searchUrl);

  if (searchRes.statusCode != 200) {
    return [];
  }

  final searchJson = json.decode(searchRes.body);
  final ids = (searchJson['esearchresult']?['idlist'] as List?) ?? [];

  if (ids.isEmpty) {
    if (fallback && !_isBroadEnough(dateFilter)) {
      return await searchArticles(
        query,
        '1y',
        fallback: false,
        customFrom: null,
        customTo: null,
        textAvailability: textAvailability,
        articleType: articleType,
      );
    }
    return [];
  }

  final summaryUrl = Uri.parse(
    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi"
    "?db=pubmed&retmode=json&id=" + ids.join(","),
  );

  final summaryRes = await http.get(summaryUrl);
  final Map<String, dynamic> summaryResult =
      summaryRes.statusCode == 200
          ? (json.decode(summaryRes.body)['result'] as Map<String, dynamic>)
          : <String, dynamic>{};

  final fetchUrl = Uri.parse(
    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"
    "?db=pubmed&id=" + ids.join(",") + "&retmode=xml",
  );

  final fetchRes = await http.get(fetchUrl);

  if (fetchRes.statusCode != 200) {
    return [];
  }

  final xml = XmlDocument.parse(fetchRes.body);
  final nodes = xml.findAllElements("PubmedArticle");

  List<Article> articles = [];

  for (final node in nodes) {
    final title = _firstText(node, "ArticleTitle");
    final journal = _firstText(node, "Title");
    final date = _extractPubDate(node);
    final authors = _extractAuthors(node);
    final pmid = _firstText(node, "PMID");
    final abstractText = _extractStructuredAbstract(node);

    final summaryItem = _summaryItem(summaryResult, pmid);
    final publicationType = _extractPubTypesFromSummary(summaryItem);
    final pmcId = _extractPmcIdFromSummary(summaryItem);
    final isPMC = pmcId.isNotEmpty;
    final isFree = isPMC || _isFreeFromSummary(summaryItem);

    articles.add(
      Article(
        title: title,
        abstractText: abstractText,
        journal: journal,
        date: date,
        authors: authors,
        pmid: pmid,
        link: pmid.isNotEmpty
            ? "https://pubmed.ncbi.nlm.nih.gov/" + pmid + "/"
            : "",
        publicationType: publicationType,
        isFree: isFree,
        isPMC: isPMC,
        pmcId: pmcId,
        canDownloadFullText: pmcId.isNotEmpty,
      ),
    );
  }

  return articles;
}

  Future<String> getLatestArticleHint(String query) async {
    final searchUrl = Uri.parse(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
      "?db=pubmed&retmode=json&retmax=1&sort=pub+date&term=" +
      Uri.encodeQueryComponent(query),
    );

    final searchRes = await http.get(searchUrl);
    if (searchRes.statusCode != 200) {
      return "No results found, and latest-publication hint could not be retrieved.";
    }

    final searchJson = json.decode(searchRes.body);
    final ids = (searchJson['esearchresult']?['idlist'] as List?) ?? [];
    if (ids.isEmpty) {
      return "No articles were found for this search term in PubMed.";
    }

    final summaryUrl = Uri.parse(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi"
      "?db=pubmed&retmode=json&id=" + ids.first.toString(),
    );

    final summaryRes = await http.get(summaryUrl);
    if (summaryRes.statusCode != 200) {
      return "No results in this date range. Try widening the time filter.";
    }

    final summaryJson = json.decode(summaryRes.body);
    final item = summaryJson['result']?[ids.first.toString()];
    if (item == null) {
      return "No results in this date range. Try widening the time filter.";
    }

    final title = (item['title'] ?? '').toString();
    final pubdate = (item['pubdate'] ?? '').toString();

    return "No results in the selected date range.\n\nLatest available article:\n$title\n$pubdate\n\nSuggestion: widen the date range or clear one or more filters.";
  }

  String _buildFilterClause(
    String dateFilter, {
    DateTime? customFrom,
    DateTime? customTo,
    String textAvailability = 'any',
    String articleType = 'any',
  }) {
    String clause = '';

    clause += _buildDateClause(
      dateFilter,
      customFrom: customFrom,
      customTo: customTo,
    );

    clause += _buildTextAvailabilityClause(textAvailability);
    clause += _buildArticleTypeClause(articleType);

    return clause;
  }

  String _buildDateClause(
    String dateFilter, {
    DateTime? customFrom,
    DateTime? customTo,
  }) {
    switch (dateFilter) {
      case "1w":
        return ' AND ("last 7 days"[dp])';
      case "1m":
        return ' AND ("last 30 days"[dp])';
      case "3m":
        return ' AND ("last 90 days"[dp])';
      case "6m":
        return ' AND ("last 180 days"[dp])';
      case "1y":
        return ' AND ("last 365 days"[dp])';
      case "5y":
        return ' AND ("last 1825 days"[dp])';
      case "10y":
        return ' AND ("last 3650 days"[dp])';
      case "custom":
        if (customFrom != null && customTo != null) {
          final from = _fmt(customFrom);
          final to = _fmt(customTo);
          return ' AND ("' + from + '"[Date - Publication] : "' + to + '"[Date - Publication])';
        }
        return '';
      case "all":
      default:
        return '';
    }
  }

  String _buildTextAvailabilityClause(String textAvailability) {
    switch (textAvailability) {
      case 'abstract':
        return ' AND hasabstract';
      case 'free_full_text':
        return ' AND free full text[sb]';
      case 'full_text':
        return ' AND full text[sb]';
      case 'any':
      default:
        return '';
    }
  }

  String _buildArticleTypeClause(String articleType) {
    switch (articleType) {
      case 'clinical_trial':
        return ' AND "Clinical Trial"[pt]';
      case 'meta_analysis':
        return ' AND "Meta-Analysis"[pt]';
      case 'randomized_controlled_trial':
        return ' AND "Randomized Controlled Trial"[pt]';
      case 'review':
        return ' AND "Review"[pt]';
      case 'systematic_review':
        return ' AND "Systematic Review"[pt]';
      case 'any':
      default:
        return '';
    }
  }

  bool _isBroadEnough(String dateFilter) {
    return dateFilter == "1y" || dateFilter == "5y" || dateFilter == "10y" || dateFilter == "all";
  }

  String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y/$m/$day';
  }

  String _firstText(XmlElement node, String tag) {
    final elems = node.findAllElements(tag);
    return elems.isNotEmpty ? elems.first.innerText.trim() : "";
  }

  String _extractAuthors(XmlElement node) {
    return node.findAllElements("Author").map((a) {
      final last = a.findElements("LastName").isNotEmpty
          ? a.findElements("LastName").first.innerText.trim()
          : "";
      final first = a.findElements("ForeName").isNotEmpty
          ? a.findElements("ForeName").first.innerText.trim()
          : "";
      final collective = a.findElements("CollectiveName").isNotEmpty
          ? a.findElements("CollectiveName").first.innerText.trim()
          : "";

      if (collective.isNotEmpty) return collective;
      return (first + " " + last).trim();
    }).where((x) => x.isNotEmpty).join(", ");
  }

  String _extractPubDate(XmlElement node) {
    final pubDates = node.findAllElements("PubDate");
    if (pubDates.isEmpty) return "";

    final d = pubDates.first;
    final year = d.findElements("Year").isNotEmpty
        ? d.findElements("Year").first.innerText.trim()
        : "";
    final month = d.findElements("Month").isNotEmpty
        ? d.findElements("Month").first.innerText.trim()
        : "";
    final day = d.findElements("Day").isNotEmpty
        ? d.findElements("Day").first.innerText.trim()
        : "";
    final medline = d.findElements("MedlineDate").isNotEmpty
        ? d.findElements("MedlineDate").first.innerText.trim()
        : "";

    final built = [year, month, day].where((x) => x.isNotEmpty).join(" ");
    return built.isNotEmpty ? built : medline;
  }
String _extractPublicationType(XmlElement node) {
  final pubTypes = node.findAllElements("PublicationType");

  if (pubTypes.isEmpty) return "";

  return pubTypes.map((e) => e.innerText).join(" ");
}
Map<String, dynamic> _summaryItem(
  Map<String, dynamic> summaryResult,
  String pmid,
) {
  final item = summaryResult[pmid];
  if (item is Map<String, dynamic>) return item;
  if (item is Map) return item.cast<String, dynamic>();
  return <String, dynamic>{};
}

String _extractPubTypesFromSummary(Map<String, dynamic> summaryItem) {
  final pubTypes = summaryItem['pubtype'];
  if (pubTypes is List) {
    return pubTypes.map((e) => e.toString()).join(' ');
  }
  return '';
}

String _extractPmcIdFromSummary(Map<String, dynamic> summaryItem) {
  final articleIds = summaryItem['articleids'];
  if (articleIds is List) {
    for (final item in articleIds) {
      if (item is Map) {
        final idType = (item['idtype'] ?? '').toString().toLowerCase();
        final value = (item['value'] ?? '').toString().trim();
        if (idType == 'pmc' && value.isNotEmpty) {
          return value.startsWith('PMC') ? value : 'PMC$value';
        }
      }
    }
  }
  return '';
}

bool _isFreeFromSummary(Map<String, dynamic> summaryItem) {
  final attrs = summaryItem['attributes'];
  if (attrs is List) {
    final lowered = attrs.map((e) => e.toString().toLowerCase()).join(' ');
    if (lowered.contains('free')) return true;
  }

  final articleIds = summaryItem['articleids'];
  if (articleIds is List) {
    for (final item in articleIds) {
      if (item is Map) {
        final idType = (item['idtype'] ?? '').toString().toLowerCase();
        if (idType == 'pmc') return true;
      }
    }
  }

  return false;
}
  String _extractStructuredAbstract(XmlElement node) {
    final sections = node.findAllElements("AbstractText").toList();
    if (sections.isEmpty) return "No abstract available.";

    final buffer = StringBuffer();

    for (final s in sections) {
      final label = s.getAttribute("Label");
      final nlmCategory = s.getAttribute("NlmCategory");
      final text = s.innerText.trim();

      if (text.isEmpty) continue;

      final heading = (label ?? nlmCategory ?? "").trim();
      if (heading.isNotEmpty) {
        buffer.writeln(heading.toUpperCase() + ":");
      }
      buffer.writeln(text);
      buffer.writeln();
    }

    final out = buffer.toString().trim();
    return out.isNotEmpty ? out : "No abstract available.";
  }
}
