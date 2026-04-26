# ==============================
# PHASE 5.4 REPAIR - STABLE FULL FILE REPLACEMENT
# ==============================

Write-Host "=== PHASE 5.4 REPAIR ==="

$BackupDir = "_phase5_4_repair_backup"

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
  }) async {
    final filter = _buildDateClause(dateFilter);

    final searchUrl = Uri.parse(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
      "?db=pubmed&retmode=json&retmax=20&sort=pub+date&term=" +
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
        return await searchArticles(query, '1y', fallback: false);
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

    return "No results in the selected date range.\n\nLatest available article:\n$title\n$pubdate\n\nSuggestion: widen the date range.";
  }

  String _buildDateClause(String dateFilter) {
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
      case "all":
      default:
        return '';
    }
  }

  bool _isBroadEnough(String dateFilter) {
    return dateFilter == "1y" || dateFilter == "5y" || dateFilter == "all";
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
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
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

  Future<void> createSessionFile(String query) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(dir.path + "/NeuroLit");

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final file = File(
      folder.path +
          "/Session_" +
          DateTime.now().millisecondsSinceEpoch.toString() +
          ".txt",
    );

    await file.writeAsString("SEARCH: " + query + "\nDATE FILTER: " + dateFilter + "\n\n");
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

    await file.writeAsString("\n\n" + text, mode: FileMode.append);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Saved to session")),
    );
  }

  Future<void> search() async {
    final query = controller.text.trim();
    if (query.isEmpty) return;

    await createSessionFile(query);

    final result = await api.searchArticles(
      query,
      dateFilter,
      fallback: autoExpand,
    );

    if (result.isEmpty) {
      final hint = await api.getLatestArticleHint(query);

      if (!mounted) return;
      setState(() {
        articles = [];
        selected.clear();
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
    });

    final buffer = StringBuffer();
    buffer.writeln("RESULTS:");
    buffer.writeln();

    for (final a in result) {
      buffer.writeln(a.title);
      buffer.writeln(a.authors);
      buffer.writeln(a.journal + " • " + a.date);
      buffer.writeln("PMID: " + a.pmid);
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
              SelectableText(
                a.link,
                style: const TextStyle(color: Colors.blue),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => appendToSession(a.abstractText),
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
            onPressed: () => appendToSession(result),
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

          DropdownButton<String>(
            value: dateFilter,
            items: const [
              DropdownMenuItem(value: "1w", child: Text("1 Week")),
              DropdownMenuItem(value: "1m", child: Text("1 Month")),
              DropdownMenuItem(value: "3m", child: Text("3 Months")),
              DropdownMenuItem(value: "6m", child: Text("6 Months")),
              DropdownMenuItem(value: "1y", child: Text("1 Year")),
              DropdownMenuItem(value: "5y", child: Text("5 Years")),
              DropdownMenuItem(value: "all", child: Text("All Time")),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                dateFilter = v;
              });
            },
          ),

          CheckboxListTile(
            title: const Text("Auto-expand search by 1 year if empty"),
            value: autoExpand,
            onChanged: (v) {
              setState(() {
                autoExpand = v ?? false;
              });
            },
          ),

          ElevatedButton(
            onPressed: generateSummary,
            child: const Text("Generate AI Summary"),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: articles.length,
              itemBuilder: (context, index) {
                final a = articles[index];

                return ListTile(
                  leading: Checkbox(
                    value: selected.contains(index),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          selected.add(index);
                        } else {
                          selected.remove(index);
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
Write-Host "✅ PHASE 5.4 REPAIR COMPLETE"
Write-Host ""
Write-Host "If you need rollback:"
Write-Host "Copy-Item $BackupDir\home_screen.dart.bak lib\screens\home_screen.dart -Force"
Write-Host "Copy-Item $BackupDir\api_service.dart.bak lib\services\api_service.dart -Force"
Write-Host ""
Write-Host "Now run:"
Write-Host "flutter clean"
Write-Host "flutter run -d windows"