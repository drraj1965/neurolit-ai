# ==============================
# PHASE 5.10 — TEXT AVAILABILITY + ARTICLE TYPE FILTERS
# ==============================

Write-Host "=== PHASE 5.10 FILTERS UPGRADE ==="

$BackupDir = "_phase5_10_backup"

if (Test-Path $BackupDir) {
    Remove-Item $BackupDir -Recurse -Force
}

New-Item -ItemType Directory -Path $BackupDir | Out-Null

$homeFile = "lib/screens/home_screen.dart"
$apiFile  = "lib/services/api_service.dart"

if (Test-Path $homeFile) {
    Copy-Item $homeFile "$BackupDir/home_screen.dart.bak"
}
if (Test-Path $apiFile) {
    Copy-Item $apiFile "$BackupDir/api_service.dart.bak"
}

Write-Host "Backup created."

# ==============================
# WRITE api_service.dart
# ==============================

@'
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
'@ | Set-Content $apiFile -Encoding UTF8

# ==============================
# WRITE home_screen.dart
# ==============================

@'
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/summary_service.dart';
import '../models/article.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService api = ApiService();
  final SummaryService summary = SummaryService();

  List<Article> articles = [];
  Set<int> selected = {};

  final TextEditingController controller = TextEditingController();

  String currentSessionFile = "";
  String dateFilter = "1y";
  bool autoExpand = false;

  DateTimeRange? customRange;

  String textAvailability = 'any';
  String articleType = 'any';

  List<Map<String, dynamic>> recentSearches = [];

  int currentPage = 0;
  final int pageSize = 10;

  @override
  void initState() {
    super.initState();
    loadRecentSearches();
  }

  Future<void> loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('recent_searches_v1') ?? [];

    final parsed = raw.map((e) {
      try {
        return jsonDecode(e) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((e) => e.isNotEmpty).toList();

    if (!mounted) return;
    setState(() {
      recentSearches = parsed;
    });
  }

  Future<void> saveRecentSearch(
    String query,
    String filter, {
    DateTimeRange? range,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final entry = <String, dynamic>{
      'query': query,
      'filter': filter,
      'from': range?.start.toIso8601String(),
      'to': range?.end.toIso8601String(),
      'textAvailability': textAvailability,
      'articleType': articleType,
    };

    recentSearches.removeWhere((e) =>
        e['query'] == entry['query'] &&
        e['filter'] == entry['filter'] &&
        e['from'] == entry['from'] &&
        e['to'] == entry['to'] &&
        e['textAvailability'] == entry['textAvailability'] &&
        e['articleType'] == entry['articleType']);

    recentSearches.insert(0, entry);

    if (recentSearches.length > 10) {
      recentSearches = recentSearches.take(10).toList();
    }

    await prefs.setStringList(
      'recent_searches_v1',
      recentSearches.map((e) => jsonEncode(e)).toList(),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> applyRecentSearch(Map<String, dynamic> entry) async {
    controller.text = (entry['query'] ?? '').toString();

    final filter = (entry['filter'] ?? '1y').toString();
    final ta = (entry['textAvailability'] ?? 'any').toString();
    final at = (entry['articleType'] ?? 'any').toString();

    DateTimeRange? range;
    final from = entry['from']?.toString();
    final to = entry['to']?.toString();

    if (from != null && to != null && from.isNotEmpty && to.isNotEmpty) {
      range = DateTimeRange(
        start: DateTime.parse(from),
        end: DateTime.parse(to),
      );
    }

    setState(() {
      dateFilter = filter;
      customRange = range;
      textAvailability = ta;
      articleType = at;
    });

    await search();
  }

  Future<void> pickCustomDateRange() async {
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: now,
      initialDateRange: customRange,
    );

    if (picked != null) {
      setState(() {
        customRange = picked;
        dateFilter = 'custom';
      });
    }
  }

  String customRangeLabel() {
    if (customRange == null) return "Pick date range";
    return _fmtDate(customRange!.start) + " → " + _fmtDate(customRange!.end);
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _monthFolderName(DateTime d) {
    return "${d.month}-${d.year}";
  }

  String _dayFolderName(DateTime d) {
    return "${d.day} ${d.month} ${d.year}";
  }

  String _safeFileNamePart(String input) {
    return input
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  String _sessionTimestamp(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    final ss = d.second.toString().padLeft(2, '0');
    return "$yyyy-$mm-$dd $hh-$min-$ss";
  }

  Future<void> createSessionFile(String query) async {
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();

    final yearFolder = dir.path + "/NeuroLit/" + now.year.toString();
    final monthFolder = yearFolder + "/" + _monthFolderName(now);
    final dayFolder = monthFolder + "/" + _dayFolderName(now);

    final folder = Directory(dayFolder);

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final fileName =
        "NeuroLit_" +
        _safeFileNamePart(query) +
        "_" +
        _sessionTimestamp(now) +
        ".txt";

    final file = File(folder.path + "/" + fileName);

    String header = "";
    header += "============================================================\n";
    header += "NEUROLIT SESSION FILE\n";
    header += "============================================================\n";
    header += "SEARCH: " + query + "\n";
    header += "DATE FILTER: " + dateFilter + "\n";
    header += "TEXT AVAILABILITY: " + textAvailability + "\n";
    header += "ARTICLE TYPE: " + articleType + "\n";
    if (dateFilter == 'custom' && customRange != null) {
      header += "FROM: " + _fmtDate(customRange!.start) + "\n";
      header += "TO: " + _fmtDate(customRange!.end) + "\n";
    }
    header += "CREATED: " + now.toString() + "\n";
    header += "============================================================\n\n";

    await file.writeAsString(header);
    currentSessionFile = file.path;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Session created")),
    );
  }

  Future<void> appendToSession(String text) async {
    if (currentSessionFile.isEmpty) return;

    final file = File(currentSessionFile);
    if (!await file.exists()) return;

    await file.writeAsString(
      "\n------------------------------------------------------------\n" +
          text +
          "\n------------------------------------------------------------\n",
      mode: FileMode.append,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Saved to session")),
    );
  }

  String buildAbstractBlock(Article a) {
    return ""
        "ABSTRACT ENTRY\n"
        "TITLE: ${a.title}\n"
        "AUTHORS: ${a.authors}\n"
        "JOURNAL: ${a.journal}\n"
        "DATE: ${a.date}\n"
        "PMID: ${a.pmid}\n"
        "LINK: ${a.link}\n\n"
        "${a.abstractText}";
  }

  Future<void> openPubMedLink(String link) async {
    if (link.trim().isEmpty) return;

    final uri = Uri.parse(link);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open PubMed link")),
      );
    }
  }

  Future<void> clearFilters() async {
    setState(() {
      dateFilter = '1y';
      customRange = null;
      textAvailability = 'any';
      articleType = 'any';
      autoExpand = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Filters cleared")),
    );
  }

  Future<void> search() async {
    final query = controller.text.trim();
    if (query.isEmpty) return;

    if (dateFilter == 'custom' && customRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please pick a custom date range first")),
      );
      return;
    }

    await saveRecentSearch(query, dateFilter, range: customRange);
    await createSessionFile(query);

    final result = await api.searchArticles(
      query,
      dateFilter,
      fallback: autoExpand,
      customFrom: customRange?.start,
      customTo: customRange?.end,
      textAvailability: textAvailability,
      articleType: articleType,
    );

    if (result.isEmpty) {
      final hint = await api.getLatestArticleHint(query);

      if (!mounted) return;
      setState(() {
        articles = [];
        selected.clear();
        currentPage = 0;
      });

      await appendToSession("NO RESULTS\n\n" + hint);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("No results found"),
          content: SelectableText(hint),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      articles = result;
      selected.clear();
      currentPage = 0;
    });

    final buffer = StringBuffer();
    buffer.writeln("SEARCH RESULTS");
    buffer.writeln();

    for (final a in result) {
      buffer.writeln(a.title);
      buffer.writeln(a.authors);
      buffer.writeln(a.journal + " • " + a.date);
      buffer.writeln("PMID: " + a.pmid);
      buffer.writeln(a.link);
      buffer.writeln();
    }

    await appendToSession(buffer.toString());
  }

  void openAbstract(Article a) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(a.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.authors),
              const SizedBox(height: 8),
              Text(a.journal + " • " + a.date),
              const SizedBox(height: 8),
              SelectableText(a.abstractText),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => openPubMedLink(a.link),
                child: Text(
                  a.link,
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => appendToSession(buildAbstractBlock(a)),
            child: const Text("Save"),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: a.abstractText));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Abstract copied")),
              );
            },
            child: const Text("Copy"),
          ),
          TextButton(
            onPressed: () => openPubMedLink(a.link),
            child: const Text("Open in PubMed"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> generateSummary() async {
    final selectedArticles = selected.map((i) => articles[i]).toList();
    if (selectedArticles.isEmpty) return;

    final result = await summary.generateMultiArticleSummary(
      selectedArticles
          .map(
            (a) => {
              "title": a.title,
              "authors": a.authors,
              "abstract": a.abstractText,
            },
          )
          .toList(),
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("AI SUMMARY"),
        content: SingleChildScrollView(
          child: SelectableText(result),
        ),
        actions: [
          TextButton(
            onPressed: () => appendToSession(
              "AI SUMMARY\n\n" + result,
            ),
            child: const Text("Save"),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: result));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Summary copied")),
              );
            },
            child: const Text("Copy"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  String previewSnippet(String abstractText) {
    final lines = abstractText
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (lines.isEmpty) return "No abstract available.";
    return lines.first;
  }

  List<Article> get pagedArticles {
    final start = currentPage * pageSize;
    if (start >= articles.length) return [];
    final end = (start + pageSize) > articles.length
        ? articles.length
        : (start + pageSize);
    return articles.sublist(start, end);
  }

  int get totalPages {
    if (articles.isEmpty) return 1;
    return ((articles.length - 1) ~/ pageSize) + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("NeuroLit AI"),
        actions: [
          IconButton(
            icon: const Icon(Icons.description),
            onPressed: () {
              if (currentSessionFile.isNotEmpty) {
                Process.start('notepad.exe', [currentSessionFile]);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.folder),
            onPressed: () async {
              final dir = await getApplicationDocumentsDirectory();
              final folderPath = dir.path + "/NeuroLit";
              Process.start('explorer.exe', [folderPath.replaceAll('/', '\\')]);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: "Search topic",
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: search,
              ),
            ),
            onSubmitted: (_) => search(),
          ),

          if (recentSearches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: recentSearches.map((entry) {
                    final query = (entry['query'] ?? '').toString();
                    final filter = (entry['filter'] ?? '').toString();
                    final ta = (entry['textAvailability'] ?? 'any').toString();
                    final at = (entry['articleType'] ?? 'any').toString();

                    String label = query + " • " + filter;
                    if (ta != 'any') label += " • " + ta;
                    if (at != 'any') label += " • " + at;

                    return ActionChip(
                      label: Text(label),
                      onPressed: () => applyRecentSearch(entry),
                    );
                  }).toList(),
                ),
              ),
            ),

          DropdownButton<String>(
            value: dateFilter,
            items: const [
              DropdownMenuItem(value: "1w", child: Text("1 Week")),
              DropdownMenuItem(value: "1m", child: Text("1 Month")),
              DropdownMenuItem(value: "3m", child: Text("3 Months")),
              DropdownMenuItem(value: "6m", child: Text("6 Months")),
              DropdownMenuItem(value: "1y", child: Text("1 Year")),
              DropdownMenuItem(value: "5y", child: Text("5 Years")),
              DropdownMenuItem(value: "10y", child: Text("10 Years")),
              DropdownMenuItem(value: "all", child: Text("All Time")),
              DropdownMenuItem(value: "custom", child: Text("Custom Range")),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                dateFilter = v;
              });
            },
          ),

          if (dateFilter == 'custom')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(customRangeLabel()),
                  ),
                  ElevatedButton(
                    onPressed: pickCustomDateRange,
                    child: const Text("Pick Range"),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: DropdownButtonFormField<String>(
              value: textAvailability,
              decoration: const InputDecoration(
                labelText: "Text availability",
              ),
              items: const [
                DropdownMenuItem(value: "any", child: Text("Any")),
                DropdownMenuItem(value: "abstract", child: Text("Abstract")),
                DropdownMenuItem(value: "free_full_text", child: Text("Free full text")),
                DropdownMenuItem(value: "full_text", child: Text("Full text")),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  textAvailability = v;
                });
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: DropdownButtonFormField<String>(
              value: articleType,
              decoration: const InputDecoration(
                labelText: "Article type",
              ),
              items: const [
                DropdownMenuItem(value: "any", child: Text("Any")),
                DropdownMenuItem(value: "clinical_trial", child: Text("Clinical Trial")),
                DropdownMenuItem(value: "meta_analysis", child: Text("Meta-Analysis")),
                DropdownMenuItem(value: "randomized_controlled_trial", child: Text("Randomized Controlled Trial")),
                DropdownMenuItem(value: "review", child: Text("Review")),
                DropdownMenuItem(value: "systematic_review", child: Text("Systematic Review")),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  articleType = v;
                });
              },
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Text("Auto-expand search by 1 year if empty"),
                  value: autoExpand,
                  onChanged: (v) {
                    setState(() {
                      autoExpand = v ?? false;
                    });
                  },
                ),
              ),
              TextButton(
                onPressed: clearFilters,
                child: const Text("Clear filters"),
              ),
            ],
          ),

          ElevatedButton(
            onPressed: generateSummary,
            child: const Text("Generate AI Summary"),
          ),

          if (articles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: currentPage > 0
                        ? () {
                            setState(() {
                              currentPage--;
                            });
                          }
                        : null,
                    child: const Text("Previous"),
                  ),
                  const SizedBox(width: 12),
                  Text("Page ${currentPage + 1} of $totalPages"),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: currentPage < totalPages - 1
                        ? () {
                            setState(() {
                              currentPage++;
                            });
                          }
                        : null,
                    child: const Text("Next"),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ListView.builder(
              itemCount: pagedArticles.length,
              itemBuilder: (context, index) {
                final a = pagedArticles[index];
                final originalIndex = articles.indexOf(a);

                return ListTile(
                  leading: Checkbox(
                    value: selected.contains(originalIndex),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          selected.add(originalIndex);
                        } else {
                          selected.remove(originalIndex);
                        }
                      });
                    },
                  ),
                  title: Text(a.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.authors),
                      Text(a.journal + " • " + a.date),
                      Text("PMID: " + a.pmid),
                      const SizedBox(height: 4),
                      Text(
                        previewSnippet(a.abstractText),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => openPubMedLink(a.link),
                        child: Text(
                          a.link,
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () => openAbstract(a),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
'@ | Set-Content $homeFile -Encoding UTF8

Write-Host ""
Write-Host "✅ PHASE 5.10 PATCH APPLIED"
Write-Host ""
Write-Host "Rollback if needed:"
Write-Host "Copy-Item $BackupDir\home_screen.dart.bak lib\screens\home_screen.dart -Force"
Write-Host "Copy-Item $BackupDir\api_service.dart.bak lib\services\api_service.dart -Force"
Write-Host ""
Write-Host "Now run:"
Write-Host "flutter clean"
Write-Host "flutter run -d windows"