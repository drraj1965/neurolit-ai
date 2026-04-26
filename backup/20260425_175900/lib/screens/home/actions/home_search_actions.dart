part of '../../home_screen.dart';

extension HomeSearchActions on _HomeScreenState {
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

  if (recentSearches.length > 20) {
    recentSearches = recentSearches.sublist(0, 20);
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
  return "${_fmtDate(customRange!.start)} → ${_fmtDate(customRange!.end)}";
}

String _fmtDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

Future<void> createSessionFile(String query) async {
  final dir = await getApplicationDocumentsDirectory();
  final now = DateTime.now();

  final year = now.year.toString();
  final monthName = _monthName(now.month);
  final dayFolder = "${now.day} $monthName ${now.year}";

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

Future<void> appendToSession(String text) async {
  if (currentSessionFile.isEmpty) return;

  final file = File(currentSessionFile);

  if (!await file.exists()) {
    await file.create(recursive: true);
  }

  await file.writeAsString(
    "\n------------------------------------------------------------\n"
        "$text\n"
        "------------------------------------------------------------\n",
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
    });

    await appendToSession("NO RESULTS\n\n$hint");

    await ModalService.showTextContentDialog(
      context: context,
      title: "No results found",
      text: hint,
    );
    return;
  }

  setState(() {
    if (isUpdateMode) {
      hasCollectionChanged = true;

      result.sort((a, b) => b.date.compareTo(a.date));

      for (final a in result) {
        selectedArticlesGlobal[a.pmid] = a;
      }

      articles = selectedArticlesGlobal.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
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
    buffer.writeln("${a.journal} • ${a.date}");
    buffer.writeln("PMID: ${a.pmid}");
    buffer.writeln(a.link);
    buffer.writeln();
  }

  await appendToSession(buffer.toString());
}

void openAbstract(Article a) {
  ModalService.showArticleDetailsDialog(
    context: context,
    article: a,
    onSave: () async {
      await appendToSession(buildAbstractBlock(a));

      setState(() {
        sessionAbstractCount++;
      });
    },
    onCopy: () async {
      await Clipboard.setData(ClipboardData(text: a.abstractText));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Abstract copied")));
    },
    onOpenPubMed: () => openPubMedLink(a.link),
    onDownloadFullText: a.canDownloadFullText
        ? () async {
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
          }
        : null,
    onOpenFullTextFolder: () async {
      final dir = await getApplicationDocumentsDirectory();
      final path = "${dir.path}/NeuroLit/FullText";
      await Process.run("explorer", [path]);
    },
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

Future<void> showMoreRecentSearches() async {
  await ModalService.showRecentSearchesDialog(
    context: context,
    recentSearches: recentSearches,
    onSelect: (entry) async {
      controller.text = (entry['query'] ?? '').toString();
      await search();
    },
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
}
