// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, avoid_print

part of '../../home_screen.dart';

extension HomeFileActions on _HomeScreenState {
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
  late final Map<String, dynamic> decoded;

  try {
    var actualJson = jsonText;

    // Detect if the input is a path to a JSON file and load it first.
    if (jsonText.trim().endsWith(".json") && File(jsonText).existsSync()) {
      actualJson = await File(jsonText).readAsString();
      print("📂 Loaded JSON from file: $jsonText");
    }

    var cleaned = actualJson.trim();

    if (cleaned.startsWith("```")) {
      cleaned = cleaned.replaceAll("```json", "");
      cleaned = cleaned.replaceAll("```", "");
    }

    final start = cleaned.indexOf("{");
    final end = cleaned.lastIndexOf("}");

    if (start != -1 && end != -1 && end > start) {
      cleaned = cleaned.substring(start, end + 1);
    }

    print("🧪 CLEANED JSON:\n$cleaned");

    decoded = jsonDecode(cleaned);
  } catch (e) {
    print("❌ JSON PARSE ERROR: $e");

    await ModalService.showInvalidJsonDialog(context, jsonText);

    return;
  }

  final now = DateTime.now();
  final topicName = currentTopic ?? "General";
  final topicDir = await workspaceService.getTopicDirectory(
    mode: literatureMode,
    date: now,
    topic: topicName,
  );
  final basePath = topicDir.path;
  final pptDir = await workspaceService.getPptDirectory(
    mode: literatureMode,
    date: now,
    topic: topicName,
  );
  final pptDirPath = pptDir.path;

  try {
    final existingFile = await getLatestPptFile(pptDirPath);

    if (existingFile != null) {
      if (!mounted) return;

      await ModalService.showPathDialog(
        context: context,
        title: "PPT Already Exists",
        path: existingFile.path,
        introText: "Opening existing file:",
        onPathTap: () => openFileProper(existingFile.path),
        actions: [
          ModalDialogAction(
            label: "Open",
            onPressed: (_) => openFileProper(existingFile.path),
          ),
          ModalDialogAction(
            label: "Show in Folder",
            onPressed: (_) => showInFolder(existingFile.path),
          ),
        ],
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Opened existing PPT file")),
      );

      return;
    }

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

    await ModalService.showPathDialog(
      context: context,
      title: "PPT Generated Successfully",
      path: filePath,
      onPathTap: () => openFileProper(filePath),
      actions: [
        ModalDialogAction(
          label: "Open File",
          onPressed: (_) => showInFolder(filePath),
        ),
        ModalDialogAction(
          label: "Open",
          onPressed: (_) => openFileProper(filePath),
        ),
      ],
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("PPT generated successfully")),
    );
  } catch (e) {
    print("❌ PPT ERROR: $e");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("PPT generation failed")),
    );

    await ModalService.showErrorDialog(
      context: context,
      title: "PPT Generation Error",
      message: e.toString(),
    );
  }
}

Future<void> saveAsNewFile(
  String contentText,
  List<Article> selectedArticles,
) async {
  final exporter = ExportService();

  await exporter.exportAsText(
    selectedArticles,
    contentText,
    outputMode: outputMode,
    literatureMode: literatureMode,
  );

  if (!mounted) return;

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Saved as new file')));
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
  final now = DateTime.now();
  final topicName = currentTopic ?? "General";

  final pptDir = await workspaceService.getPptDirectory(
    mode: literatureMode,
    date: now,
    topic: topicName,
  );

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

    final choice = await ModalService.showExistingSlidesDialog(context);
    if (choice == ExistingFileChoice.openExisting) {
      await openFileProper(latest.path);
      return;
    }
    if (choice != ExistingFileChoice.createNew) {
      return;
    }
  }

  final fileName = "slides_${now.toIso8601String().replaceAll(":", "-")}.json";

  final file = File("${pptDir.path}/$fileName");

  await file.writeAsString(jsonText);

  if (!mounted) return;

  await ModalService.showPathDialog(
    context: context,
    title: "Slides Saved",
    path: file.path,
    onPathTap: () => openFileProper(file.path),
    actions: [
      ModalDialogAction(
        label: "Show in Folder",
        onPressed: (_) => showInFolder(file.path),
      ),
    ],
  );

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Slide JSON saved successfully")),
  );
}

Future<void> generateSlidesFromReview() async {
  if (lastGeneratedReview == null || lastGeneratedReview!.trim().isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("No AI review available")));
    return;
  }

  final deck = SlideStructureService.generateSlideDeck(
    topic: currentTopic ?? "NeuroLit Topic",
    reviewText: lastGeneratedReview!,
  );

  final jsonText = deck.toPrettyJson();

  await ModalService.showSlideStructureDialog(
    context: context,
    jsonText: jsonText,
    onSave: () => saveSlideJsonToFolder(jsonText),
    onGeneratePpt: () => generatePptFromSlides(jsonText),
  );
}
}
