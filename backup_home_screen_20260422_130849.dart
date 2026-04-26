import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/summary_service.dart';
import '../services/export_service.dart';
import '../services/fulltext_service.dart';
import '../services/collection_service.dart';
import '../models/article.dart';
import '../services/slide_structure_service.dart';


class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 🔹 Phase 7.1 — Topic system
  String? currentTopic;
  bool isRelatedMode = false;

  final ApiService api = ApiService();
  final SummaryService summary = SummaryService();
  final CollectionService collectionService = CollectionService();

  List<Article> articles = [];
  Set<String> selectedPmids = {};
  Map<String, Article> selectedArticlesGlobal = {};
  Set<String> selectedForCollection = {};
  bool showSelectedOnly = false;

  final TextEditingController controller = TextEditingController();
  final FullTextService fullTextService = FullTextService();
  String currentSessionFile = "";
  String currentSearchQuery = "";
  int sessionAbstractCount = 0;
  String dateFilter = "1y";
  bool autoExpand = false;

  DateTimeRange? customRange;

  bool isUpdateMode = false;
  SavedCollection? activeCollection;

  String textAvailability = 'any';
  String articleType = 'any';
  
  String outputMode = "review";
  
  String? lastGeneratedReview;

  String postFilterTextAvailability = 'any';
  String postFilterArticleType = 'any';

  List<Map<String, dynamic>> recentSearches = [];
  List<SavedCollection> savedCollections = [];
  Set<String> selectedCollectionPaths = {};
  bool collectionsLoading = false;

  int currentPage = 0;
  double topPanelWidth = 240;
  double filterPanelWidth = 240;
  final int pageSize = 10;

  @override
  void initState() {
    super.initState();
    loadRecentSearches();
    loadCollections();
  }


  Future<void> openFileProper(String path) async {
  final winPath = path.replaceAll('/', '\\');

  await Process.start(
    'cmd',
    ['/c', 'start', '', '"$winPath"'],
    runInShell: true,
  );
}

  Future<void> showInFolder(String path) async {
  final winPath = path.replaceAll('/', '\\');

  await Process.start(
    'explorer.exe',
    ['/select,', winPath],
  );
}
  

  Future<void> generatePptFromSlides(String jsonText) async {
  final decoded = jsonDecode(jsonText);

  final dir = await getApplicationDocumentsDirectory();
  final now = DateTime.now();

  final year = now.year.toString();
  final monthName = _monthName(now.month);
  final dayFolder = "${now.day} $monthName ${now.year}";
  final topicName = currentTopic ?? "General";

  final basePath =
      "${dir.path}/NeuroLit/FullText/$year/$monthName/$dayFolder/$topicName";

  final pptDirPath = "$basePath/PPTx";

  try {
    // 🔍 CHECK IF PPT ALREADY EXISTS
    final existingFile = await getLatestPptFile(pptDirPath);

    if (existingFile != null) {
      final winPath = existingFile.path.replaceAll('/', '\\');

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("PPT Already Exists"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Opening existing file:"),
              const SizedBox(height: 6),
              SelectableText(existingFile.path),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await openFileProper(existingFile.path);
              },
              child: const Text("Open"),
            ),
            TextButton(
              onPressed: () async {
                await showInFolder(existingFile.path);
              },
              child: const Text("Show in Folder"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Opened existing PPT file")),
      );

      return;
    }

    // 🚀 GENERATE NEW PPT
        final tempJsonFile = File("$pptDirPath\\temp_slide_input.json");

    await tempJsonFile.writeAsString(jsonEncode({
      "slides": decoded["slides"],
      "topic": decoded["topic"],
      "base_path": basePath,
    }));

    final process = await Process.run(
      "python",
      [
        "C:\\NeuroLitBackend\\generate_ppt.py",
        tempJsonFile.path,
      ],
    );

    if (process.exitCode != 0) {
      throw Exception(
        "STDOUT: ${process.stdout}\nSTDERR: ${process.stderr}",
      );
    }

    final filePath = process.stdout.toString().trim();

    if (filePath.isEmpty) {
      throw Exception("Python script returned empty file path");
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("PPT Generated Successfully"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Saved to:"),
              const SizedBox(height: 6),
                            InkWell(
                onTap: () async {
                  await openFileProper(filePath);
                },
                child: Text(
                  filePath,
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
            onPressed: () {
              Clipboard.setData(ClipboardData(text: filePath));
              Navigator.pop(context);
            },
            child: const Text("Copy Path"),
          ),
          TextButton(
            onPressed: () async {
              await showInFolder(filePath);
            },
            child: const Text("Open File"),
          ),
          TextButton(
            onPressed: () async {
              await openFileProper(filePath);
            },
            child: const Text("Open"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("PPT generated successfully")),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("PPT generation failed: $e")),
    );
  }
}

  Future<void> loadCollections() async {
    setState(() {
      collectionsLoading = true;
    });

    final collections = await collectionService.listCollections();

    if (!mounted) return;
    setState(() {
      savedCollections = collections;
      selectedCollectionPaths.removeWhere(
        (path) =>
            !collections.any((collection) => collection.file.path == path),
      );
      collectionsLoading = false;
    });
  }

  Future<void> loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('recent_searches_v1') ?? [];

    final parsed = raw
        .map((e) {
          try {
            return jsonDecode(e) as Map<String, dynamic>;
          } catch (_) {
            return <String, dynamic>{};
          }
        })
        .where((e) => e.isNotEmpty)
        .toList();

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

    recentSearches.removeWhere(
      (e) =>
          e['query'] == entry['query'] &&
          e['filter'] == entry['filter'] &&
          e['from'] == entry['from'] &&
          e['to'] == entry['to'] &&
          e['textAvailability'] == entry['textAvailability'] &&
          e['articleType'] == entry['articleType'],
    );

    recentSearches.insert(0, entry);

    // Limit to last 5 searches
    if (recentSearches.length > 20) {
      recentSearches = recentSearches.sublist(0, 20);
    }

    // Save to preferences
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
    return _fmtDate(customRange!.start) + " â†’ " + _fmtDate(customRange!.end);
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

    final year = now.year.toString();
    final monthName = _monthName(now.month);
    final dayFolder = "${now.day} $monthName ${now.year}";

    // Decide topic
    if (!isRelatedMode ||
        currentTopic == null ||
        currentTopic!.trim().isEmpty) {
      currentTopic = _generateTopicName(query);
    }

    final topicPath =
        "${dir.path}/NeuroLit/FullText/$year/$monthName/$dayFolder/${currentTopic ?? "General"}";

    final folder = Directory(topicPath);

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    if (isRelatedMode) {
      currentSessionFile = "${folder.path}/abstracts.txt";
    } else {
      final timestamp = now
          .toIso8601String()
          .replaceAll(":", "-")
          .replaceAll(".", "-");
      currentSessionFile = "${folder.path}/abstracts_$timestamp.txt";
    }

    final file = File(currentSessionFile);

    if (!await file.exists()) {
      await file.writeAsString(
        "SESSION START\n"
        "SEARCH: $query\n"
        "CREATED: ${now.toString()}\n"
        "TOPIC: ${currentTopic ?? "General"}\n\n",
        mode: FileMode.write,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Session created:\n${file.path}")));
  }

  Future<void> tryLoadExistingReview(SavedCollection collection) async {
  try {
    final dir = collection.file.parent;

    final now = DateTime.now();

final year = now.year.toString();
final monthName = _monthName(now.month);
final dayFolder = "${now.day} $monthName ${now.year}";
final topicName = currentTopic ?? "General";

final summariesDir = Directory(
  "${(await getApplicationDocumentsDirectory()).path}"
  "/NeuroLit/FullText/$year/$monthName/$dayFolder/$topicName/summaries",
);

    final files = summariesDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains("collection_review"))
        .toList();

    if (files.isEmpty) return;

    files.sort(
      (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
    );

    final latest = files.first;

    final content = await latest.readAsString();

    setState(() {
      lastGeneratedReview = content;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Loaded existing review")),
    );
  } catch (e) {
    print("Review load error: $e");
  }
}

  Future<void> appendToSession(String text) async {
    if (currentSessionFile.isEmpty) return;

    final file = File(currentSessionFile);

    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    await file.writeAsString(
      "\n------------------------------------------------------------\n" +
          text +
          "\n------------------------------------------------------------\n",
      mode: FileMode.append,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Saved to session:\n${file.path}")));
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Filters cleared")));
  }

  void showSelectionManager() {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Selected Articles"),
          content: SizedBox(
            width: 500,
            height: 400,
            child: selectedArticlesGlobal.isEmpty
                ? const Center(child: Text("No selected articles"))
                : ListView(
                    children: selectedArticlesGlobal.values.map((a) {
                      return CheckboxListTile(
                        value: selectedForCollection.contains(a.pmid),
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              selectedForCollection.add(a.pmid);
                            } else {
                              selectedForCollection.remove(a.pmid);
                            }
                          });
                        },
                        title: Text(
                          a.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          "PMID: ${a.pmid}",
                          style: const TextStyle(fontSize: 12),
                        ),
                        secondary: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setDialogState(() {
                              selectedArticlesGlobal.remove(a.pmid);
                              selectedForCollection.remove(a.pmid);
                            });
                            Navigator.pop(context);
                            showSelectionManager();
                          },
                        ),
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: selectedForCollection.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context);
                      promptSaveCollection();
                    },
              child: const Text("Save as Collection"),
            ),

            TextButton(
              onPressed: () {
                setState(() {
                  selectedArticlesGlobal.clear();
                });
                Navigator.pop(context);
              },
              child: const Text("Clear All"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> promptSaveCollection() async {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Save Collection"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter collection name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              Navigator.pop(context);
              await saveCollection(name);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> saveCollection(String name) async {
    final selectedArticles = selectedForCollection
        .map((pmid) => selectedArticlesGlobal[pmid])
        .whereType<Article>()
        .toList();

    if (selectedArticles.isEmpty) return;

    final file = await collectionService.saveCollection(
      name: name,
      articles: selectedArticles,
    );

    final winPath = file.path.replaceAll('/', '\\');

    await openFileProper(file.path);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Collection Saved"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Saved to:"),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  await openFileProper(file.path);
                  
                },
                child: Text(
                  file.path,
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
            onPressed: () {
              Clipboard.setData(ClipboardData(text: file.path));
              Navigator.pop(context);
            },
            child: const Text("Copy Path"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );

    selectedForCollection.clear();
    await loadCollections();
  }

  void showCollectionManager() {
    loadCollections();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Collection Manager"),
          content: SizedBox(
            width: 760,
            height: 520,
            child: collectionsLoading
                ? const Center(child: CircularProgressIndicator())
                : savedCollections.isEmpty
                ? const Center(child: Text("No saved collections yet"))
                : ListView.separated(
                    itemCount: savedCollections.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final collection = savedCollections[index];
                      final isSelected = selectedCollectionPaths.contains(
                        collection.file.path,
                      );

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    selectedCollectionPaths.add(
                                      collection.file.path,
                                    );
                                  } else {
                                    selectedCollectionPaths.remove(
                                      collection.file.path,
                                    );
                                  }
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    collection.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${collection.parsedCount} articles"
                                    " | saved count: ${collection.declaredCount}"
                                    " | ${_collectionDateLabel(collection.created)}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    collection.file.path,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Wrap(
                              spacing: 4,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await loadCollectionIntoSelection(
                                      collection,
                                      replace: true,
                                    );
                                    if (!mounted) return;
                                    showSelectionManager();
                                  },
                                  child: const Text("Load"),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await loadCollectionIntoSelection(
                                      collection,
                                      replace: false,
                                    );
                                    if (!mounted) return;
                                    setDialogState(() {});
                                  },
                                  child: const Text("Merge"),
                                ),
                                IconButton(
                                  tooltip: "Rename",
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () async {
                                    await promptRenameCollection(collection);
                                    if (!mounted) return;
                                    setDialogState(() {});
                                  },
                                ),
                                IconButton(
                                  tooltip: "Delete",
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    await confirmDeleteCollection(collection);
                                    if (!mounted) return;
                                    setDialogState(() {});
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await loadCollections();
                if (!mounted) return;
                setDialogState(() {});
              },
              child: const Text("Refresh"),
            ),
            TextButton(
              onPressed: selectedCollectionPaths.isEmpty
                  ? null
                  : () async {
                      await mergeSelectedCollectionsIntoSelection();
                      if (!mounted) return;
                      setDialogState(() {});
                    },
              child: const Text("Merge Selected"),
            ),
            TextButton(
              onPressed: selectedCollectionPaths.length < 2
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await promptSaveMergedCollection();
                    },
              child: const Text("Save Merged"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      ),
    );
  }

  String _collectionDateLabel(DateTime? created) {
    if (created == null) return "date unknown";
    return _fmtDate(created);
  }

  Future<void> loadCollectionIntoSelection(
    SavedCollection collection, {
    required bool replace,
  }) async {
    final loadedArticles = await collectionService.loadArticles(
      collection.file,
    );

    if (!mounted) return;
    setState(() {
  if (replace) {
    selectedArticlesGlobal.clear();
    selectedForCollection.clear();
  }

  for (final article in loadedArticles) {
    selectedArticlesGlobal[article.pmid] = article;
  }

  showSelectedOnly = true;
  currentPage = 0;

  // 🔥 ADD THESE 2 LINES HERE
  activeCollection = collection;
  isUpdateMode = false;
});

    await tryLoadExistingReview(collection);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          replace
              ? "Loaded ${loadedArticles.length} articles from ${collection.name}"
              : "Merged ${loadedArticles.length} articles from ${collection.name}",
        ),
      ),
    );
  }

  Future<void> mergeSelectedCollectionsIntoSelection() async {
    final selectedCollections = savedCollections
        .where(
          (collection) =>
              selectedCollectionPaths.contains(collection.file.path),
        )
        .toList();

    var loadedCount = 0;
    final merged = <String, Article>{};

    for (final collection in selectedCollections) {
      final articles = await collectionService.loadArticles(collection.file);
      loadedCount += articles.length;
      for (final article in articles) {
        merged[article.pmid] = article;
      }
    }

    if (!mounted) return;
    setState(() {
      selectedArticlesGlobal.addAll(merged);
      showSelectedOnly = true;
      currentPage = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Merged ${merged.length} unique articles into Selection Manager"
          " ($loadedCount loaded)",
        ),
      ),
    );
  }

  Future<void> promptSaveMergedCollection() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Save Merged Collection"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Enter merged collection name",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              Navigator.pop(context);
              await saveMergedCollection(name);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> saveMergedCollection(String name) async {
    final selectedCollections = savedCollections
        .where(
          (collection) =>
              selectedCollectionPaths.contains(collection.file.path),
        )
        .toList();

    final merged = <String, Article>{};
    for (final collection in selectedCollections) {
      final articles = await collectionService.loadArticles(collection.file);
      for (final article in articles) {
        merged[article.pmid] = article;
      }
    }

    if (merged.isEmpty) return;

    final file = await collectionService.saveCollection(
      name: name,
      articles: merged.values,
    );

    await loadCollections();

    final winPath = file.path.replaceAll('/', '\\');
    await openFileProper(file.path);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Merged collection saved: ${file.path}")),
    );
  }

  Future<void> promptRenameCollection(SavedCollection collection) async {
    final controller = TextEditingController(text: collection.name);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rename Collection"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter collection name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              Navigator.pop(context);
              await collectionService.renameCollection(collection.file, name);
              await loadCollections();
            },
            child: const Text("Rename"),
          ),
        ],
      ),
    );
  }

  Future<void> updateCurrentCollection() async {
  if (activeCollection == null) return;

  final updatedArticles = selectedArticlesGlobal.values.toList();

  await collectionService.saveCollection(
    name: activeCollection!.name,
    articles: updatedArticles,
  );

  setState(() {
  isUpdateMode = false;
});

ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text("Collection updated")),
);
}

  Future<void> confirmDeleteCollection(SavedCollection collection) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Collection"),
        content: Text("Delete \"${collection.name}\"?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await collectionService.deleteCollection(collection.file);
              selectedCollectionPaths.remove(collection.file.path);
              await loadCollections();
            },
            child: const Text("Delete"),
          ),
        ],
      ),
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
    currentSearchQuery = query;
    sessionAbstractCount = 0;

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
        selectedPmids.clear();
        // currentPage = 0;
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
  if (isUpdateMode) {
    for (final a in result) {
      selectedArticlesGlobal[a.pmid] = a;
    }
  } else {
    articles = result;
  }

  currentPage = 0;
});

    final buffer = StringBuffer();
    buffer.writeln("SEARCH RESULTS");
    buffer.writeln();

    for (final a in result) {
      buffer.writeln(a.title);
      buffer.writeln(a.authors);
      buffer.writeln(a.journal + " â€¢ " + a.date);
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
              Text("${a.journal} • ${a.date}"),
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
            onPressed: () async {
              await appendToSession(buildAbstractBlock(a));

              setState(() {
                sessionAbstractCount++;
              });
            },
            child: const Text("Save"),
          ),

          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: a.abstractText));
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("Abstract copied")));
            },
            child: const Text("Copy"),
          ),

          TextButton(
            onPressed: () => openPubMedLink(a.link),
            child: const Text("Open in PubMed"),
          ),

          if (a.canDownloadFullText)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);

                final result = await fullTextService.downloadFullText(
                  pmid: a.pmid,
                  title: a.title,
                  pmcId: a.pmcId,
                  topic: currentTopic,
                );

                if (!mounted) return;

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(result)));
              },
              child: const Text("Download Full Text"),
            ),

          TextButton(
            onPressed: () async {
              final dir = await getApplicationDocumentsDirectory();
              final path = "${dir.path}/NeuroLit/FullText";
              await Process.run("explorer", [path]);
            },
            child: const Text("Open FullText Folder"),
          ),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> saveAsNewFile(
    String contentText,
    List<Article> selectedArticles,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();

    final folder = Directory('${dir.path}/NeuroLit/Exports');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final file = File(
      '${folder.path}/NeuroLit_${outputMode}_${now.millisecondsSinceEpoch}.txt',
    );

    final exporter = ExportService();

    await exporter.exportAsText(selectedArticles, contentText, outputMode);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved as new file')));
  }

  Future<void> saveGeneratedReviewToSummaries(
    String result, {
    required String filePrefix,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();

    final year = now.year.toString();
    final monthName = _monthName(now.month);
    final dayFolder = "${now.day} $monthName ${now.year}";
    final topicName = currentTopic ?? "General";

    final summariesDir = Directory(
      "${dir.path}/NeuroLit/FullText/$year/$monthName/$dayFolder/$topicName/summaries",
    );

    if (!await summariesDir.exists()) {
      await summariesDir.create(recursive: true);
    }

    final fileName =
        "${filePrefix}_${now.toIso8601String().replaceAll(":", "-")}.txt";

    final file = File("${summariesDir.path}/$fileName");

    final metadata =
        "=== GENERATED OUTPUT ===\n"
        "Topic: $topicName\n"
        "Generated: ${DateTime.now()}\n"
        "Type: $filePrefix\n"
        "========================\n\n";

    await file.writeAsString(metadata + result);

    final winPath = file.path.replaceAll('/', '\\');
    await Process.start('explorer.exe', ['/select, "$winPath"']);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Saved"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Saved to:"),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final winPath = file.path.replaceAll('/', '\\');
                  await openFileProper(file.path);
                },
                child: Text(
                  file.path,
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
            onPressed: () {
              Clipboard.setData(ClipboardData(text: file.path));
              Navigator.pop(context);
            },
            child: const Text("Copy Path"),
          ),
          TextButton(
            onPressed: () async {
              await showInFolder(file.path);
            },
            child: const Text("Show in Folder"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<File?> getLatestPptFile(String pptDirPath) async {
  final dir = Directory(pptDirPath);

  if (!await dir.exists()) return null;

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith(".pptx"))
      .toList();

  if (files.isEmpty) return null;

  files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

  return files.first;
}

  Future<void> saveSlideJsonToFolder(String jsonText) async {
  final dir = await getApplicationDocumentsDirectory();
  final now = DateTime.now();

  final year = now.year.toString();
  final monthName = _monthName(now.month);
  final dayFolder = "${now.day} $monthName ${now.year}";
  final topicName = currentTopic ?? "General";

  final pptDir = Directory(
    "${dir.path}/NeuroLit/FullText/$year/$monthName/$dayFolder/$topicName/PPTx",
  );

  if (!await pptDir.exists()) {
    await pptDir.create(recursive: true);
  }

    final existingFiles = pptDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith(".json"))
      .toList();

  if (existingFiles.isNotEmpty) {
    existingFiles.sort(
      (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
    );

    final latest = existingFiles.first;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Existing Slides Found"),
        content: const Text("Use existing slides JSON?"),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openFileProper(latest.path);
            },
            child: const Text("Open Existing"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Create New"),
          ),
        ],
      ),
    );

    return;
  }

  final fileName =
      "slides_${now.toIso8601String().replaceAll(":", "-")}.json";

  final file = File("${pptDir.path}/$fileName");

  await file.writeAsString(jsonText);

  final winPath = file.path.replaceAll('/', '\\');

  if (!mounted) return;

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Slides Saved"),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Saved to:"),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                await openFileProper(file.path);
              },
              child: Text(
                file.path,
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
          onPressed: () {
            Clipboard.setData(ClipboardData(text: file.path));
            Navigator.pop(context);
          },
          child: const Text("Copy Path"),
        ),
        TextButton(
          onPressed: () async {
            await showInFolder(file.path);
          },
          child: const Text("Show in Folder"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    ),
  );

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Slide JSON saved successfully")),
  );
}

  Future<void> generateSummary() async {
    final selectedArticles = articles
        .where((a) => selectedPmids.contains(a.pmid))
        .toList();

    if (selectedArticles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one article")),
      );
      return;
    }

    final payload = selectedArticles
        .map(
          (a) => {
            "title": a.title,
            "authors": a.authors,
            "abstract": a.abstractText,
          },
        )
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(
          outputMode == "teaching"
              ? "Generating Teaching Synopsis"
              : "Generating Review",
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Please wait... AI is generating the output."),
          ],
        ),
      ),
    );

    try {
      String result;
if (outputMode == "teaching") {
  result = await summary.generateTeachingSynopsis(payload);
} else {
  result = await summary.generateMultiArticleSummary(payload);
}

// 🔥 STORE FOR PPT GENERATION
lastGeneratedReview = result;

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outputMode == "teaching"
                ? "Teaching synopsis generated"
                : "Review generated",
          ),
        ),
      );

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(
            outputMode == "teaching" ? "TEACHING SYNOPSIS" : "AI SUMMARY",
          ),
          content: SingleChildScrollView(child: SelectableText(result)),
          actions: [
            TextButton(
              onPressed: () async {
                await appendToSession(result);

                final dir = await getApplicationDocumentsDirectory();
                final now = DateTime.now();

                final year = now.year.toString();
                final monthName = _monthName(now.month);
                final dayFolder = "${now.day} $monthName ${now.year}";
                final topicName = currentTopic ?? "General";

                final summariesDir = Directory(
                  "${dir.path}/NeuroLit/FullText/$year/$monthName/$dayFolder/$topicName/summaries",
                );

                if (!await summariesDir.exists()) {
                  await summariesDir.create(recursive: true);
                }

                final fileName =
                    "review_${now.toIso8601String().replaceAll(":", "-")}.txt";

                final file = File("${summariesDir.path}/$fileName");

                await file.writeAsString(result);

                final winPath = file.path.replaceAll('/', '\\');

                await showInFolder(file.path);

                if (!mounted) return;

                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Saved"),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Saved to:"),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final winPath = file.path.replaceAll('/', '\\');
                              await showInFolder(file.path);
                            },
                            child: Text(
                              file.path,
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
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: file.path));
                          Navigator.pop(context);
                        },
                        child: const Text("Copy Path"),
                      ),
                      TextButton(
                        onPressed: () async {
                          await showInFolder(file.path);
                        },
                        child: const Text("Open File"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Close"),
                      ),
                    ],
                  ),
                );
              },
              child: const Text("Save"),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: result));
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Output copied")));
              },
              child: const Text("Copy"),
            ),
            TextButton(
              onPressed: () => saveAsNewFile(result, selectedArticles),
              child: const Text("Save as New File"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Generation failed"),
          content: SelectableText(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      );
    }
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
    final base = showSelectedOnly
        ? selectedArticlesGlobal.values.toList()
        : articles;

    final filtered = base.where((a) {
      bool matchText = true;
      bool matchType = true;

      if (postFilterTextAvailability == 'abstract') {
        matchText = a.abstractText.trim().isNotEmpty;
      } else if (postFilterTextAvailability == 'free_full_text') {
        matchText = a.isFree || a.isPMC;
      }

      if (postFilterArticleType == 'review') {
        matchType = a.journal.toLowerCase().contains('review');
      }

      return matchText && matchType;
    }).toList();

    final start = currentPage * pageSize;
    if (start >= filtered.length) return [];

    final end = (start + pageSize) > filtered.length
        ? filtered.length
        : (start + pageSize);

    return filtered.sublist(start, end);
  }

  int get totalPages {
    final base = showSelectedOnly
        ? selectedArticlesGlobal.values.toList()
        : articles;

    final filtered = base.where((a) {
      bool matchText = true;
      bool matchType = true;

      if (postFilterTextAvailability == 'abstract') {
        matchText = a.abstractText.trim().isNotEmpty;
      } else if (postFilterTextAvailability == 'free_full_text') {
        matchText = a.isFree || a.isPMC;
      }

      if (postFilterArticleType == 'review') {
        matchType = a.journal.toLowerCase().contains('review');
      }

      return matchText && matchType;
    }).toList();

    if (filtered.isEmpty) return 1;

    return ((filtered.length - 1) ~/ pageSize) + 1;
  }

  Widget buildArticleBadges(Article a) {
    final badges = <Widget>[];

    if (a.isFree) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text("Free article", style: TextStyle(fontSize: 12)),
        ),
      );
    }

    if (a.isPMC) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text("PMC", style: TextStyle(fontSize: 12)),
        ),
      );
    }

    if (a.publicationType.toLowerCase().contains('review')) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text("Review", style: TextStyle(fontSize: 12)),
        ),
      );
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: badges
            .map(
              (b) =>
                  Padding(padding: const EdgeInsets.only(bottom: 4), child: b),
            )
            .toList(),
      ),
    );
  }

  Widget buildFilterPanel() {
    return Container(
      width: filterPanelWidth,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Filters",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: dateFilter,
              decoration: const InputDecoration(labelText: "Publication date"),
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

            if (dateFilter == 'custom') ...[
              const SizedBox(height: 8),
              Text(customRangeLabel()),
              const SizedBox(height: 8),

              ElevatedButton(
                onPressed: pickCustomDateRange,
                child: const Text("Pick Range"),
              ),
            ],

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: textAvailability,
              decoration: const InputDecoration(labelText: "Text availability"),
              items: const [
                DropdownMenuItem(value: "any", child: Text("Any")),
                DropdownMenuItem(value: "abstract", child: Text("Abstract")),
                DropdownMenuItem(
                  value: "free_full_text",
                  child: Text("Free full text"),
                ),
                DropdownMenuItem(value: "full_text", child: Text("Full text")),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  textAvailability = v;
                });
              },
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: articleType,
              decoration: const InputDecoration(labelText: "Article type"),
              items: const [
                DropdownMenuItem(value: "any", child: Text("Any")),
                DropdownMenuItem(
                  value: "clinical_trial",
                  child: Text("Clinical Trial"),
                ),
                DropdownMenuItem(
                  value: "meta_analysis",
                  child: Text("Meta-Analysis"),
                ),
                DropdownMenuItem(
                  value: "randomized_controlled_trial",
                  child: Text("Randomized Controlled Trial"),
                ),
                DropdownMenuItem(value: "review", child: Text("Review")),
                DropdownMenuItem(
                  value: "systematic_review",
                  child: Text("Systematic Review"),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  articleType = v;
                });
              },
            ),

            const SizedBox(height: 12),

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Auto-expand by 1 year if empty"),
              value: autoExpand,
              onChanged: (v) {
                setState(() {
                  autoExpand = v ?? false;
                });
              },
            ),

            const SizedBox(height: 8),

            OutlinedButton(
              onPressed: clearFilters,
              child: const Text("Clear filters"),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedArticlesGlobal.isEmpty
                    ? null
                    : () {
                        showSelectionManager();
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: Text(
                  "Manage Selection (${selectedArticlesGlobal.length})",
                ),
              ),
            ),
            const SizedBox(height: 6),

SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: loadCollectionFromFile,
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 10),
      textStyle: const TextStyle(fontSize: 12),
    ),
    child: const Text("Load Collection"),
  ),
),

   const SizedBox(height: 6),

SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: activeCollection == null
        ? null
        : () {
            setState(() {
              isUpdateMode = true;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Update mode enabled")),
            );
          },
    child: const Text("Update Collection"),
  ),
),

  const SizedBox(height: 6),

SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: isUpdateMode ? updateCurrentCollection : null,
    child: const Text("Save Updated Collection"),
  ),
),

          ],
        ),
      ),
    );
  }

  Widget buildTopSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔍 Search box
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13),
          maxLines: 2,
          minLines: 1,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            hintText: "Search topic",
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => search(),
            ),
          ),
          onSubmitted: (_) => search(),
        ),

        const SizedBox(height: 8),

        // 🔗 Related search row (fixed)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Checkbox(
                value: isRelatedMode,
                onChanged: (v) {
                  setState(() {
                    isRelatedMode = v ?? false;
                    if (!isRelatedMode) currentTopic = null;
                  });
                },
              ),
              const Text("Related searches"),
              if (currentTopic != null)
                SizedBox(
                  width: 120,
                  child: Text(
                    "Topic: $currentTopic",
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // 🔽 Filter
        DropdownButtonFormField<String>(
          value: postFilterTextAvailability,
          decoration: const InputDecoration(labelText: "Filter Results"),
          items: const [
            DropdownMenuItem(value: "any", child: Text("All Results")),
            DropdownMenuItem(
              value: "abstract",
              child: Text("Abstract Available"),
            ),
            DropdownMenuItem(
              value: "free_full_text",
              child: Text("Free Full Text"),
            ),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              postFilterTextAvailability = v;
              currentPage = 0;
            });
          },
        ),

        // 🔍 Recent Searches (with More)
        if (recentSearches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Recent Searches",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),

                ...recentSearches.take(3).map((entry) {
                  final query = (entry['query'] ?? '').toString();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      onTap: () async {
                        await applyRecentSearch(entry);
                      },
                      child: Text(
                        query,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }),

                if (recentSearches.length > 3)
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Recent Searches"),
                          content: SizedBox(
                            width: 400,
                            child: ListView(
                              shrinkWrap: true,
                              children: recentSearches.map((e) {
                                final text = (e['query'] ?? '').toString();

                                return ListTile(
                                  title: Text(text),
                                  onTap: () async {
                                    controller.text = text;
                                    Navigator.pop(context);
                                    await search();
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text("More"),
                  ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // 🔽 Output Mode (RESTORED)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DropdownButtonFormField<String>(
            value: outputMode,
            decoration: const InputDecoration(labelText: "Output mode"),
            items: const [
              DropdownMenuItem(value: "review", child: Text("Review")),
              DropdownMenuItem(
                value: "teaching",
                child: Text("Teaching Synopsis"),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                outputMode = v;
              });
            },
          ),
        ),

        const SizedBox(height: 8),

        const SizedBox(height: 8),

        // 🧠 Buttons (vertical, compact)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                "Selected: ${selectedArticlesGlobal.length}",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: generateSummary,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text("Generate AI Summary"),
              ),
            ),

            const SizedBox(height: 6),

SizedBox(
  height: 32,
  child: ElevatedButton(
    onPressed: () async {
  if (lastGeneratedReview == null ||
      lastGeneratedReview!.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No AI review available")),
    );
    return;
  }

  final deck = SlideStructureService.generateSlideDeck(
    topic: currentTopic ?? "NeuroLit Topic",
    reviewText: lastGeneratedReview!,
  );

  final jsonText = deck.toPrettyJson();

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Slide Structure"),
      content: SizedBox(
        width: 600,
        height: 400,
        child: SingleChildScrollView(
          child: SelectableText(jsonText),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: jsonText));
          },
          child: const Text("Copy"),
        ),
        TextButton(
          onPressed: () async {
            await saveSlideJsonToFolder(jsonText);
          },
          child: const Text("Save"),
        ), 

        TextButton(
          onPressed: () async {
            await generatePptFromSlides(jsonText);
          },
          child: const Text("Generate PPT"),
        ),

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    ),
  );
},
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      textStyle: const TextStyle(fontSize: 12),
    ),
    child: const Text("Generate Slides"),
  ),
),

            const SizedBox(height: 6),

            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: generateFromFolder,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text("Review from Folder"),
              ),
            ),

            const SizedBox(height: 6),

            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: generateFromSelection,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text("Review Selected"),
              ),
            ),

            const SizedBox(height: 6),

            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: showCollectionManager,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: Text("Collections (${savedCollections.length})"),
              ),
            ),

            const SizedBox(height: 6),

            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    showSelectedOnly = !showSelectedOnly;
                    currentPage = 0;
                  });
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: Text(
                  showSelectedOnly ? "Show All Articles" : "Show Selected Only",
                ),
              ),
            ),
            const SizedBox(height: 6),

            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedArticlesGlobal.clear();
                  });
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 12),
                  backgroundColor: Colors.grey.shade400,
                ),
                child: const Text("Clear Selection"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildArticlesList() {
    return Column(
      children: [
        if (articles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 30,
                  child: ElevatedButton(
                    onPressed: currentPage > 0
                        ? () {
                            setState(() {
                              currentPage--;
                            });
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text("Previous"),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "Page ${currentPage + 1} of $totalPages",
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 30,
                  child: ElevatedButton(
                    onPressed: currentPage < totalPages - 1
                        ? () {
                            setState(() {
                              currentPage++;
                            });
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text("Next"),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: pagedArticles.length,
            itemBuilder: (context, index) {
              final a = pagedArticles[index];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: InkWell(
                  onTap: () => openAbstract(a),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: selectedArticlesGlobal.containsKey(a.pmid),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                selectedArticlesGlobal[a.pmid] = a;
                              } else {
                                selectedArticlesGlobal.remove(a.pmid);
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                a.authors,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                a.journal + " • " + a.date,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "PMID: " + a.pmid,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              buildArticleBadges(a),
                              const SizedBox(height: 8),

                              Text(
                                previewSnippet(a.abstractText),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => openPubMedLink(a.link),
                                child: Text(
                                  a.link,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _generateTopicName(String input) {
    final words = input
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '')
        .split(' ')
        .where((w) => w.trim().isNotEmpty)
        .take(6)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .toList();

    return words.join('_');
  }

  Widget buildSessionPanel() {
    if (currentSearchQuery.isEmpty) return const SizedBox();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SESSION", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),

          Text(currentSearchQuery, style: const TextStyle(fontSize: 12)),

          const SizedBox(height: 6),

          Text(
            "Abstracts: $sessionAbstractCount",
            style: const TextStyle(fontSize: 12),
          ),

          const SizedBox(height: 6),

          Text(
            currentSessionFile,
            style: const TextStyle(fontSize: 10),
            softWrap: true,
          ),
        ],
      ),
    );
  }

  String _monthName(int m) {
    const names = [
      "",
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    return names[m];
  }

  

  // 🔥 Phase 7.3 — Folder Review
  Future<void> generateFromFolder() async {
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();

    final monthName = _monthName(now.month);
    final dayFolder = "${now.day} $monthName ${now.year}";

    final topicPath =
        "${dir.path}/NeuroLit/FullText/${now.year}/$monthName/$dayFolder/${currentTopic ?? "General"}";

    final base = Directory(topicPath);

    if (!await base.exists()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No topic folder found")));
      return;
    }

    final files = base.listSync(recursive: true);
    final abstracts = <Map<String, String>>[];

    for (final f in files) {
      if (f is File &&
          f.path.contains("abstracts") &&
          f.path.endsWith(".txt")) {
        final content = await f.readAsString();

        final entries = content.split(
          "------------------------------------------------------------",
        );

        for (final entry in entries) {
          if (!entry.contains("TITLE:")) continue;

          String title = "";
          String authors = "";
          String abstractText = "";

          final lines = entry.split("\n");

          bool abstractStarted = false;

          for (final line in lines) {
            if (line.startsWith("TITLE:")) {
              title = line.replaceFirst("TITLE:", "").trim();
            } else if (line.startsWith("AUTHORS:")) {
              authors = line.replaceFirst("AUTHORS:", "").trim();
            } else if (line.trim().isEmpty) {
              continue;
            } else if (!line.contains(":")) {
              abstractStarted = true;
            }

            if (abstractStarted) {
              abstractText += line.trim() + " ";
            }
          }

          if (title.isNotEmpty && abstractText.isNotEmpty) {
            abstracts.add({
              "title": title,
              "authors": authors,
              "abstract": abstractText.trim(),
            });
          }
        }
      }
    }

    if (abstracts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No abstracts found")));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text("Generating Review"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Analyzing folder..."),
          ],
        ),
      ),
    );

    try {
      final result = await summary.generateMultiArticleSummary(abstracts);

      lastGeneratedReview = result;

      if (!mounted) return;
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("FOLDER REVIEW"),
          content: SingleChildScrollView(child: SelectableText(result)),
          actions: [
            TextButton(
              onPressed: () async {
                final dir = await getApplicationDocumentsDirectory();
                final now = DateTime.now();

                final year = now.year.toString();
                final monthName = _monthName(now.month);
                final dayFolder = "${now.day} $monthName ${now.year}";

                final topicFolder = Directory(
                  "${dir.path}/NeuroLit/FullText/$year/$monthName/$dayFolder/${currentTopic ?? "General"}/summaries",
                );

                if (!await topicFolder.exists()) {
                  await topicFolder.create(recursive: true);
                }

                final fileName =
                    "review_${now.toIso8601String().replaceAll(":", "-")}.txt";

                final file = File("${topicFolder.path}/$fileName");

                final metadata =
                    "=== REVIEW METADATA ===\n"
                    "Topic: ${currentTopic ?? "General"}\n"
                    "Generated: ${DateTime.now()}\n"
                    "========================\n\n";

                await file.writeAsString(metadata + result);

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Saved to:\n${file.path}")),
                );
              },
              child: const Text("Save"),
            ),

            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: result));
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Copied")));
              },
              child: const Text("Copy"),
            ),

            TextButton(
              onPressed: () async {
                final dir = await getApplicationDocumentsDirectory();
                final now = DateTime.now();

                final monthName = _monthName(now.month);
                final dayFolder = "${now.day} $monthName ${now.year}";

                final path =
                    "${dir.path}/NeuroLit/FullText/${now.year}/$monthName/$dayFolder/${currentTopic ?? "General"}/summaries";

                await Process.run("explorer", [path]);
              },
              child: const Text("Open Folder"),
            ),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Folder review failed: $e")));
    }
  }

Future<void> loadCollectionFromFile() async {
  final dir = await getApplicationDocumentsDirectory();
  final collectionDir = Directory("${dir.path}/NeuroLit/Collections");

  if (!await collectionDir.exists()) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No collections found")),
    );
    return;
  }

  final files = collectionDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith(".txt"))
      .toList();

  if (files.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No collection files found")),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Load Collection"),
      content: SizedBox(
        width: 400,
        child: ListView(
          shrinkWrap: true,
          children: files.map((f) {
            return ListTile(
              title: Text(
                f.path.split("\\").last,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                Navigator.pop(context);
                await loadCollectionFile(f);
              },
            );
          }).toList(),
        ),
      ),
    ),
  );
}

Future<void> loadCollectionFile(File file) async {
  final content = await file.readAsString();

  final entries = content.split("------------------------------------");

  final abstracts = <Map<String, String>>[];

  for (final entry in entries) {
    if (!entry.contains("TITLE:")) continue;

    String title = "";
    String authors = "";
    String abstractText = "";

    final lines = entry.split("\n");

    for (final line in lines) {
      if (line.startsWith("TITLE:")) {
        title = line.replaceFirst("TITLE:", "").trim();
      } else if (line.startsWith("AUTHORS:")) {
        authors = line.replaceFirst("AUTHORS:", "").trim();
      } else {
        abstractText += line.trim() + " ";
      }
    }

    if (title.isNotEmpty && abstractText.isNotEmpty) {
      abstracts.add({
        "title": title,
        "authors": authors,
        "abstract": abstractText.trim(),
      });
    }
  }

  if (abstracts.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invalid or empty collection")),
    );
    return;
  }

  await runAIOnCollection(abstracts);
}

Future<void> runAIOnCollection(List<Map<String, String>> abstracts) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      title: Text("Generating Collection Review"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Analyzing collection..."),
        ],
      ),
    ),
  );

  try {
    final result = await summary.generateMultiArticleSummary(abstracts);

    lastGeneratedReview = result;

    if (!mounted) return;
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("COLLECTION REVIEW"),
        content: SingleChildScrollView(
          child: SelectableText(result),
        ),
        actions: [
          TextButton(
  onPressed: () async {
    await saveGeneratedReviewToSummaries(
      result,
      filePrefix: "collection_review",
    );
  },
  child: const Text("Save"),
),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: result));
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
  } catch (e) {
    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Collection analysis failed: $e")),
    );
  }
}

  Future<void> generateFromSelection() async {
    if (selectedArticlesGlobal.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No articles selected")));
      return;
    }

    final selectedArticles = selectedArticlesGlobal.values.toList();

    if (selectedArticles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No matching articles found")),
      );
      return;
    }

    final payload = selectedArticles
        .map(
          (a) => {
            "title": a.title,
            "authors": a.authors,
            "abstract": a.abstractText,
          },
        )
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text("Generating Selected Review"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Analyzing selected abstracts..."),
          ],
        ),
      ),
    );

    try {
      final result = await summary.generateMultiArticleSummary(payload);

      lastGeneratedReview = result;

      if (!mounted) return;
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("SELECTED REVIEW"),
          content: SingleChildScrollView(child: SelectableText(result)),
          actions: [
            TextButton(
              onPressed: () async {
                await appendToSession(result);

                final dir = await getApplicationDocumentsDirectory();
                final now = DateTime.now();

                final monthName = _monthName(now.month);
                final dayFolder = "${now.day} $monthName ${now.year}";

                final path =
                    "${dir.path}/NeuroLit/FullText/${now.year}/$monthName/$dayFolder/${currentTopic ?? "General"}/summaries";

                await Process.run("explorer", [path]);
              },
              child: const Text("Save"),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: result));
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Copied")));
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
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Selected review failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = buildFilterPanel();
    final content = Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: topPanelWidth,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildTopSection(),
                  buildSessionPanel(), // 👈 move here
                ],
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                setState(() {
                  topPanelWidth = (topPanelWidth + details.delta.dx).clamp(
                    180.0,
                    500.0,
                  );
                });
              },
              child: Container(
                width: 10,
                height: double.infinity,
                alignment: Alignment.center,
                child: Container(width: 2, color: Colors.grey.shade400),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: buildArticlesList()),
        ],
      ),
    );

    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text("NeuroLit AI"),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.filter_alt),
              onPressed: () {
                if (!isWide) {
                  Scaffold.of(context).openEndDrawer();
                }
              },
            ),
          ),
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
              final dir = Directory(
                'C:/Users/${Platform.environment['USERNAME']}/Documents',
              );
              final folderPath = dir.path + "/NeuroLit";
              Process.start('explorer.exe', [folderPath.replaceAll('/', '\\')]);
            },
          ),
        ],
      ),
      endDrawer: isWide ? null : Drawer(child: filters),
      body: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                filters,

                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        filterPanelWidth = (filterPanelWidth + details.delta.dx)
                            .clamp(180.0, 420.0);
                      });
                    },
                    child: Container(
                      width: 10,
                      height: double.infinity,
                      alignment: Alignment.center,
                      child: Container(width: 2, color: Colors.grey.shade400),
                    ),
                  ),
                ),

                Expanded(child: content),
              ],
            )
          : content,
    );
  }
}
