// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api, use_build_context_synchronously, avoid_print

part of '../../home_screen.dart';

extension HomeCollectionActions on _HomeScreenState {
Future<void> loadCollections() async {
  setState(() {
    collectionsLoading = true;
  });

  final collections = await collectionService.listCollections(literatureMode);

  if (!mounted) return;
  setState(() {
    savedCollections = collections;
    selectedCollectionPaths.removeWhere(
      (path) => !collections.any((collection) => collection.file.path == path),
    );
    collectionsLoading = false;
  });
}

Future<void> tryLoadExistingReview(SavedCollection collection) async {
  try {
    final now = DateTime.now();
    final topicName = currentTopic ?? "General";
    final summariesDir = await workspaceService.getSummariesDirectory(
      mode: literatureMode,
      date: now,
      topic: topicName,
      create: false,
    );

    if (!await summariesDir.exists()) return;

    final files = summariesDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains("collection_review"))
        .toList();

    if (files.isEmpty) return;

    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

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

void showSelectionManager() {
  ModalService.showSelectionManagerDialog(
    context: context,
    selectedArticles: selectedArticlesGlobal,
    initiallySelectedForCollection: selectedForCollection,
    onSaveAsCollection: (selectedPmids) async {
      setState(() {
        selectedForCollection = Set<String>.from(selectedPmids);
      });
      await promptSaveCollection();
    },
    onDeleteArticle: (article) async {
      setState(() {
        selectedArticlesGlobal.remove(article.pmid);
        selectedForCollection.remove(article.pmid);
      });
    },
    onClearAll: () async {
      setState(() {
        selectedArticlesGlobal.clear();
        selectedForCollection.clear();
      });
    },
  );
}

Future<void> promptSaveCollection() async {
  final name = await ModalService.showTextInputDialog(
    context: context,
    title: "Save Collection",
    hintText: "Enter collection name",
    confirmLabel: "Save",
  );

  if (name == null) return;
  await saveCollection(name);
}

Future<void> saveCollection(String name) async {
  final selectedArticles = selectedForCollection
      .map((pmid) => selectedArticlesGlobal[pmid])
      .whereType<Article>()
      .toList();

  if (selectedArticles.isEmpty) return;

  final file = await collectionService.saveCollection(
    mode: literatureMode,
    name: name,
    articles: selectedArticles,
  );

  await openFileProper(file.path);

  if (!mounted) return;

  await ModalService.showPathDialog(
    context: context,
    title: "Collection Saved",
    path: file.path,
    onPathTap: () => openFileProper(file.path),
    actions: const <ModalDialogAction>[],
  );

  selectedForCollection.clear();
  await loadCollections();
}

Future<void> showCollectionManager() async {
  await loadCollections();
  if (!mounted) return;

  await ModalService.showCollectionManagerDialog(
    context: context,
    initialCollections: savedCollections,
    initialLoading: collectionsLoading,
    initialSelectedPaths: selectedCollectionPaths,
    onRefreshCollections: () async {
      await loadCollections();
      return savedCollections;
    },
    onSelectionChanged: (selectedPaths) {
      selectedCollectionPaths = Set<String>.from(selectedPaths);
    },
    onLoadCollection: (collection, action) async {
      if (action == CollectionLoadAction.generateReview) {
        setState(() {
          isUpdateMode = false;
          hasCollectionChanged = false;
          activeCollection = collection;
        });

        await loadCollectionIntoSelection(collection, replace: true);
        await generateFromSelection();
        return;
      }

      await loadCollectionIntoSelection(collection, replace: true);

      setState(() {
        isUpdateMode = true;
        hasCollectionChanged = false;
        activeCollection = collection;
        lastGeneratedReview = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Update mode enabled")),
      );
    },
    onMergeCollection: (collection) async {
      await loadCollectionIntoSelection(collection, replace: false);
    },
    onRenameCollection: promptRenameCollection,
    onDeleteCollection: confirmDeleteCollection,
    onMergeSelected: (selectedPaths) async {
      setState(() {
        selectedCollectionPaths = Set<String>.from(selectedPaths);
      });
      await mergeSelectedCollectionsIntoSelection();
    },
    onSaveMerged: (selectedPaths) async {
      setState(() {
        selectedCollectionPaths = Set<String>.from(selectedPaths);
      });
      await promptSaveMergedCollection();
    },
    dateLabelBuilder: _collectionDateLabel,
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
  final loadedArticles = await collectionService.loadArticles(collection.file);

  if (!mounted) return;
  setState(() {
    if (replace) {
      selectedArticlesGlobal.clear();
      selectedForCollection.clear();
      activeCollection = collection;
      hasCollectionChanged = false;
    }

    for (final article in loadedArticles) {
      selectedArticlesGlobal[article.pmid] = article;
    }

    showSelectedOnly = true;
    currentPage = 0;
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
        (collection) => selectedCollectionPaths.contains(collection.file.path),
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
  final name = await ModalService.showTextInputDialog(
    context: context,
    title: "Save Merged Collection",
    hintText: "Enter merged collection name",
    confirmLabel: "Save",
  );

  if (name == null) return;
  await saveMergedCollection(name);
}

Future<void> saveMergedCollection(String name) async {
  final selectedCollections = savedCollections
      .where(
        (collection) => selectedCollectionPaths.contains(collection.file.path),
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
    mode: literatureMode,
    name: name,
    articles: merged.values,
  );

  await loadCollections();

  await openFileProper(file.path);

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("Merged collection saved: ${file.path}")),
  );
}

Future<void> promptRenameCollection(SavedCollection collection) async {
  final name = await ModalService.showTextInputDialog(
    context: context,
    title: "Rename Collection",
    hintText: "Enter collection name",
    confirmLabel: "Rename",
    initialValue: collection.name,
  );

  if (name == null) return;

  await collectionService.renameCollection(collection.file, name);
  await loadCollections();
}

Future<void> updateCurrentCollection() async {
  if (activeCollection == null) return;

  final updatedArticles = selectedArticlesGlobal.values.toList();

  await collectionService.saveCollection(
    mode: literatureMode,
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
  final confirmed = await ModalService.showConfirmationDialog(
    context: context,
    title: "Delete Collection",
    message: "Delete \"${collection.name}\"?",
    confirmLabel: "Delete",
  );

  if (confirmed != true) return;

  await collectionService.deleteCollection(collection.file);
  selectedCollectionPaths.remove(collection.file.path);
  await loadCollections();
}

Future<void> loadCollectionFromFile() async {
  await loadCollections();
  final files = savedCollections.map((collection) => collection.file).toList();

  if (files.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "No ${literatureMode.displayName.toLowerCase()} collection files found",
        ),
      ),
    );
    return;
  }

  await ModalService.showCollectionFilesDialog(
    context: context,
    files: files,
    onSelectAction: (file, action) async {
      if (action == CollectionLoadAction.generateReview) {
        setState(() {
          isUpdateMode = false;
          hasCollectionChanged = false;
          lastGeneratedReview = null;
        });

        await loadCollectionFile(file);
        await generateFromSelection();
        return;
      }

      await loadCollectionFile(file);

      setState(() {
        isUpdateMode = true;
        hasCollectionChanged = false;
        lastGeneratedReview = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Update mode enabled")),
      );
    },
  );
}

Future<void> loadCollectionFile(File file) async {
  final loadedArticles = await collectionService.loadArticles(file);

  if (loadedArticles.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invalid or empty collection")),
    );
    return;
  }

  SavedCollection? matchedCollection;
  for (final collection in savedCollections) {
    if (collection.file.path == file.path) {
      matchedCollection = collection;
      break;
    }
  }

  if (!mounted) return;
  setState(() {
    selectedArticlesGlobal.clear();
    selectedForCollection.clear();

    for (final article in loadedArticles) {
      selectedArticlesGlobal[article.pmid] = article;
    }

    showSelectedOnly = true;
    currentPage = 0;
    activeCollection = matchedCollection;
  });

  if (matchedCollection != null) {
    await tryLoadExistingReview(matchedCollection);
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        "Loaded ${loadedArticles.length} articles from ${file.path.split("\\").last}",
      ),
    ),
  );
}
}
