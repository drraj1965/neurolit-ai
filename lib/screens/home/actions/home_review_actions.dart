// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api, use_build_context_synchronously

part of '../../home_screen.dart';

extension HomeReviewActions on _HomeScreenState {
Future<void> saveGeneratedReviewToSummaries(
  String result, {
  required String filePrefix,
}) async {
  final now = DateTime.now();
  final topicName = currentTopic ?? "General";
  final summariesDir = await workspaceService.getSummariesDirectory(
    mode: literatureMode,
    date: now,
    topic: topicName,
  );

  final fileName = "${filePrefix}_${now.toIso8601String().replaceAll(":", "-")}.txt";

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

  await ModalService.showPathDialog(
    context: context,
    title: "Saved",
    path: file.path,
    onPathTap: () => openFileProper(file.path),
    actions: [
      ModalDialogAction(
        label: "Show in Folder",
        onPressed: (_) => showInFolder(file.path),
      ),
    ],
  );
}

Future<void> generateSummary() async {
  final selectedArticles = selectedArticlesGlobal.values.toList();

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

  if (!await ensureAiProviderReady(providerOverrideId: runProviderOverrideId)) {
    return;
  }

  ModalService.showProgressDialog(
    context: context,
    title: outputMode == "teaching"
        ? "Generating Teaching Synopsis"
        : "Generating Review",
    message: "Please wait... AI is generating the output.",
  );

  try {
    late final String result;

    if (outputMode == "teaching") {
      result = await summary.generateTeachingSynopsis(
        payload,
        providerOverrideId: runProviderOverrideId,
      );
      setState(() {});
    } else {
      result = await summary.generateMultiArticleSummary(
        payload,
        providerOverrideId: runProviderOverrideId,
      );
      setState(() {});
    }

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

    await ModalService.showTextContentDialog(
      context: context,
      title: outputMode == "teaching" ? "TEACHING SYNOPSIS" : "AI SUMMARY",
      text: result,
      actions: [
        ModalDialogAction(
          label: "Save",
          onPressed: (_) async {
            await appendToSession(result);
            final now = DateTime.now();
            final topicName = currentTopic ?? "General";
            final summariesDir = await workspaceService.getSummariesDirectory(
              mode: literatureMode,
              date: now,
              topic: topicName,
            );

            final fileName = "review_${now.toIso8601String().replaceAll(":", "-")}.txt";

            final file = File("${summariesDir.path}/$fileName");

            await file.writeAsString(result);
            await showInFolder(file.path);

            if (!mounted) return;

            await ModalService.showPathDialog(
              context: context,
              title: "Saved",
              path: file.path,
              introText: "Saved to:",
              onPathTap: () => showInFolder(file.path),
              actions: [
                ModalDialogAction(
                  label: "Open File",
                  onPressed: (_) => showInFolder(file.path),
                ),
              ],
            );
          },
        ),
        ModalDialogAction(
          label: "Copy",
          onPressed: (_) async {
            await Clipboard.setData(ClipboardData(text: result));
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("Output copied")));
          },
        ),
        ModalDialogAction(
          label: "Save as New File",
          onPressed: (_) => saveAsNewFile(result, selectedArticles),
        ),
      ],
    );
  } catch (e) {
    if (!mounted) return;
    Navigator.pop(context);

    await ModalService.showErrorDialog(
      context: context,
      title: "Generation failed",
      message: e.toString(),
    );
  }
}

Future<void> generateFromFolder() async {
  final now = DateTime.now();
  final base = await workspaceService.getTopicDirectory(
    mode: literatureMode,
    date: now,
    topic: currentTopic ?? "General",
    create: false,
  );

  if (!await base.exists()) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("No topic folder found")));
    return;
  }

  final files = base.listSync(recursive: true);
  final abstracts = <Map<String, String>>[];

  for (final f in files) {
    if (f is File && f.path.contains("abstracts") && f.path.endsWith(".txt")) {
      final content = await f.readAsString();

      final entries = content.split(
        "------------------------------------------------------------",
      );

      for (final entry in entries) {
        if (!entry.contains("TITLE:")) continue;

        var title = "";
        var authors = "";
        var abstractText = "";

        final lines = entry.split("\n");

        var abstractStarted = false;

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
            abstractText += "${line.trim()} ";
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

  if (!await ensureAiProviderReady(providerOverrideId: runProviderOverrideId)) {
    return;
  }

  ModalService.showProgressDialog(
    context: context,
    title: "Generating Review",
    message: "Analyzing folder...",
  );

  try {
    final result = await summary.generateMultiArticleSummary(
      abstracts,
      providerOverrideId: runProviderOverrideId,
    );
    setState(() {});

    lastGeneratedReview = result;

    if (!mounted) return;
    Navigator.pop(context);

    await ModalService.showTextContentDialog(
      context: context,
      title: "FOLDER REVIEW",
      text: result,
      actions: [
        ModalDialogAction(
          label: "Save",
          onPressed: (_) async {
            final now = DateTime.now();
            final topicFolder = await workspaceService.getSummariesDirectory(
              mode: literatureMode,
              date: now,
              topic: currentTopic ?? "General",
            );

            final fileName = "review_${now.toIso8601String().replaceAll(":", "-")}.txt";

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
        ),
        ModalDialogAction(
          label: "Copy",
          onPressed: (_) async {
            await Clipboard.setData(ClipboardData(text: result));
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("Copied")));
          },
        ),
        ModalDialogAction(
          label: "Open Folder",
          onPressed: (_) async {
            final now = DateTime.now();
            final summariesDir = await workspaceService.getSummariesDirectory(
              mode: literatureMode,
              date: now,
              topic: currentTopic ?? "General",
            );

            await Process.run("explorer", [summariesDir.path]);
          },
        ),
      ],
    );
  } catch (e) {
    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Folder review failed: $e")));
  }
}

Future<void> runAIOnCollection(List<Map<String, String>> abstracts) async {
  if (!await ensureAiProviderReady(providerOverrideId: runProviderOverrideId)) {
    return;
  }

  ModalService.showProgressDialog(
    context: context,
    title: "Generating Collection Review",
    message: "Analyzing collection...",
  );

  try {
    final result = await summary.generateMultiArticleSummary(
      abstracts,
      providerOverrideId: runProviderOverrideId,
    );
    setState(() {});

    lastGeneratedReview = result;

    if (!mounted) return;
    Navigator.pop(context);

    await ModalService.showTextContentDialog(
      context: context,
      title: "COLLECTION REVIEW",
      text: result,
      actions: [
        ModalDialogAction(
          label: "Save",
          onPressed: (_) => saveGeneratedReviewToSummaries(
            result,
            filePrefix: "collection_review",
          ),
        ),
        ModalDialogAction(
          label: "Copy",
          onPressed: (_) async {
            await Clipboard.setData(ClipboardData(text: result));
          },
        ),
      ],
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
  if (isUpdateMode) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Review generation is disabled in Update Collection mode"),
      ),
    );
    return;
  }

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
          "abstract": a.abstractText.trim().isNotEmpty
              ? a.abstractText
              : "No abstract available. Use title to infer content.",
        },
      )
      .toList();

  if (!await ensureAiProviderReady(providerOverrideId: runProviderOverrideId)) {
    return;
  }

  ModalService.showProgressDialog(
    context: context,
    title: "Generating Selected Review",
    message: "Analyzing selected abstracts...",
  );

  try {
    final result = await summary.generateMultiArticleSummary(
      payload,
      providerOverrideId: runProviderOverrideId,
    );
    setState(() {});

    lastGeneratedReview = result;

    if (!mounted) return;
    Navigator.pop(context);

    await ModalService.showTextContentDialog(
      context: context,
      title: "SELECTED REVIEW",
      text: result,
      actions: [
        ModalDialogAction(
          label: "Save",
          onPressed: (_) async {
            await appendToSession(result);
            final now = DateTime.now();
            final summariesDir = await workspaceService.getSummariesDirectory(
              mode: literatureMode,
              date: now,
              topic: currentTopic ?? "General",
            );

            await Process.run("explorer", [summariesDir.path]);
          },
        ),
        ModalDialogAction(
          label: "Copy",
          onPressed: (_) async {
            await Clipboard.setData(ClipboardData(text: result));
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("Copied")));
          },
        ),
      ],
    );
  } catch (e) {
    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Selected review failed: $e")));
  }
}
}
