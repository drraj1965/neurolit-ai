// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api, use_build_context_synchronously

part of '../../home_screen.dart';

extension HomeSearchActions on _HomeScreenState {
  Future<void> loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyRecentSearches(prefs);
    final raw = prefs.getStringList(
          workspaceService.recentSearchPreferenceKey(literatureMode),
        ) ??
        [];

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
    final storageKey = workspaceService.recentSearchPreferenceKey(literatureMode);

    final entry = <String, dynamic>{
      'query': query,
      'filter': filter,
      'from': range?.start.toIso8601String(),
      'to': range?.end.toIso8601String(),
      'textAvailability': textAvailability,
      'articleType': articleType,
      'literatureMode': literatureMode.storageValue,
    };

    recentSearches.removeWhere(
      (e) =>
          e['query'] == entry['query'] &&
          e['filter'] == entry['filter'] &&
          e['from'] == entry['from'] &&
          e['to'] == entry['to'] &&
          e['textAvailability'] == entry['textAvailability'] &&
          e['articleType'] == entry['articleType'] &&
          e['literatureMode'] == entry['literatureMode'],
    );

    recentSearches.insert(0, entry);

    if (recentSearches.length > 20) {
      recentSearches = recentSearches.sublist(0, 20);
    }

    await prefs.setStringList(
      storageKey,
      recentSearches.map((e) => jsonEncode(e)).toList(),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> applyRecentSearch(Map<String, dynamic> entry) async {
    final previousMode = literatureMode;
    controller.text = (entry['query'] ?? '').toString();

    final filter = (entry['filter'] ?? '1y').toString();
    final ta = (entry['textAvailability'] ?? 'any').toString();
    final at = (entry['articleType'] ?? 'any').toString();
    final mode = literatureModeFromValue(
      (entry['literatureMode'] ?? 'medical').toString(),
    );

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
      literatureMode = mode;
    });

    if (previousMode != mode) {
      await loadRecentSearches();
      await loadCollections();
    }

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
    return "${_fmtDate(customRange!.start)} -> ${_fmtDate(customRange!.end)}";
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> createSessionFile(String query) async {
    final now = DateTime.now();

    if (!isRelatedMode || currentTopic == null || currentTopic!.trim().isEmpty) {
      currentTopic = _generateTopicName(query);
    }

    final folder = await workspaceService.getTopicDirectory(
      mode: literatureMode,
      date: now,
      topic: currentTopic ?? "General",
    );

    final timestamp = now
        .toIso8601String()
        .replaceAll(":", "-")
        .replaceAll(".", "-");

    if (literatureMode == LiteratureMode.engineering) {
      currentSessionFile = "${folder.path}/EngineeringSession_$timestamp.txt";
    } else if (isRelatedMode) {
      currentSessionFile = "${folder.path}/abstracts.txt";
    } else {
      currentSessionFile = "${folder.path}/abstracts_$timestamp.txt";
    }

    final file = File(currentSessionFile);

    if (!await file.exists()) {
      await file.writeAsString(
        "SESSION START\n"
        "MODE: ${literatureMode.displayName}\n"
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
    final buffer = StringBuffer()
      ..writeln("ABSTRACT ENTRY")
      ..writeln("MODE: ${a.literatureMode.displayName}")
      ..writeln("TITLE: ${a.title}")
      ..writeln("AUTHORS: ${a.authors}")
      ..writeln("JOURNAL: ${a.journal}")
      ..writeln("DATE: ${a.date}")
      ..writeln("SOURCE: ${a.displaySource}")
      ..writeln("ID: ${a.selectionKey}")
      ..writeln("${a.displayIdentifierLabel}: ${a.displayIdentifierValue}");

    if (a.literatureMode == LiteratureMode.medical) {
      buffer.writeln("PMID: ${a.displayIdentifierValue}");
    }

    if (a.link.trim().isNotEmpty) {
      buffer.writeln("LINK: ${a.link}");
    }

    if (a.pdfUrl.trim().isNotEmpty) {
      buffer.writeln("PDF_URL: ${a.pdfUrl}");
    }

    buffer
      ..writeln()
      ..write(a.abstractText);

    return buffer.toString();
  }

  Future<void> openArticleLink(String link) async {
    if (link.trim().isEmpty) return;

    final uri = Uri.parse(link);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open article link")),
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

    if (literatureMode == LiteratureMode.medical &&
        dateFilter == 'custom' &&
        customRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please pick a custom date range first")),
      );
      return;
    }

    await saveRecentSearch(query, dateFilter, range: customRange);
    await createSessionFile(query);
    currentSearchQuery = query;
    sessionAbstractCount = 0;

    final response = await searchService.search(
      mode: literatureMode,
      query: query,
      dateFilter: dateFilter,
      fallback: autoExpand,
      customFrom: customRange?.start,
      customTo: customRange?.end,
      textAvailability: textAvailability,
      articleType: articleType,
    );

    final result = response.articles;

    if (result.isEmpty) {
      if (!mounted) return;
      setState(() {
        articles = [];
        selectedPmids.clear();
      });

      await appendToSession("NO RESULTS\n\n${response.emptyMessage}");

      await ModalService.showTextContentDialog(
        context: context,
        title: "No results found",
        text: response.emptyMessage,
      );
      return;
    }

    setState(() {
      if (isUpdateMode) {
        hasCollectionChanged = true;

        result.sort((a, b) => b.date.compareTo(a.date));

        for (final a in result) {
          selectedArticlesGlobal[a.selectionKey] = a;
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
    buffer.writeln("MODE: ${literatureMode.displayName}");
    buffer.writeln();

    for (final a in result) {
      buffer.writeln(a.title);
      buffer.writeln(a.authors);
      buffer.writeln("${a.journal} • ${a.date}");
      buffer.writeln("SOURCE: ${a.displaySource}");
      buffer.writeln("${a.displayIdentifierLabel}: ${a.displayIdentifierValue}");
      if (a.link.trim().isNotEmpty) {
        buffer.writeln(a.link);
      }
      if (a.pdfUrl.trim().isNotEmpty) {
        buffer.writeln("PDF: ${a.pdfUrl}");
      }
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
      onOpenPubMed: () => openArticleLink(a.link),
      onDownloadFullText: a.canDownloadFullText
          ? () async {
              final result = await fullTextService.downloadForArticle(
                article: a,
                topic: currentTopic,
              );

              if (!mounted) return;

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(result)));
            }
          : null,
      onOpenFullTextFolder: () async {
        final dir = await workspaceService.getFullTextRoot(literatureMode);
        await Process.run("explorer", [dir.path]);
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
      onSelect: applyRecentSearch,
    );
  }

  Future<void> _migrateLegacyRecentSearches(SharedPreferences prefs) async {
    final medicalKey = workspaceService.recentSearchPreferenceKey(
      LiteratureMode.medical,
    );
    final engineeringKey = workspaceService.recentSearchPreferenceKey(
      LiteratureMode.engineering,
    );

    final medicalExisting = prefs.getStringList(medicalKey) ?? const [];
    final engineeringExisting = prefs.getStringList(engineeringKey) ?? const [];
    if (medicalExisting.isNotEmpty || engineeringExisting.isNotEmpty) {
      return;
    }

    final legacyEntries =
        prefs.getStringList(workspaceService.legacyRecentSearchPreferenceKey) ??
            const [];
    if (legacyEntries.isEmpty) {
      return;
    }

    final medicalEntries = <String>[];
    final engineeringEntries = <String>[];

    for (final rawEntry in legacyEntries) {
      try {
        final decoded = jsonDecode(rawEntry);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }

        final mode = literatureModeFromValue(
          (decoded['literatureMode'] ?? 'medical').toString(),
        );
        if (mode == LiteratureMode.engineering) {
          engineeringEntries.add(rawEntry);
        } else {
          medicalEntries.add(rawEntry);
        }
      } catch (_) {
        medicalEntries.add(rawEntry);
      }
    }

    if (medicalEntries.isNotEmpty) {
      await prefs.setStringList(medicalKey, medicalEntries);
    }
    if (engineeringEntries.isNotEmpty) {
      await prefs.setStringList(engineeringKey, engineeringEntries);
    }
  }

  String _generateTopicName(String input) {
    final words = input
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), ' ')
        .split(' ')
        .where((w) => w.trim().isNotEmpty)
        .take(6)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .toList();

    final prefix =
        literatureMode == LiteratureMode.medical ? 'Medical' : 'Engineering';
    return [prefix, ...words].join('_');
  }
}
