import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/article.dart';

class SavedCollection {
  final File file;
  final String name;
  final DateTime? created;
  final int declaredCount;
  final int parsedCount;

  SavedCollection({
    required this.file,
    required this.name,
    required this.created,
    required this.declaredCount,
    required this.parsedCount,
  });

  String get fileName => file.uri.pathSegments.last;
}

class CollectionService {
  Future<Directory> getCollectionDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final collectionDir = Directory("${dir.path}/NeuroLit/Collections");

    if (!await collectionDir.exists()) {
      await collectionDir.create(recursive: true);
    }

    return collectionDir;
  }

  Future<List<SavedCollection>> listCollections() async {
    final dir = await getCollectionDirectory();
    final files = await dir
        .list()
        .where(
          (entity) =>
              entity is File && entity.path.toLowerCase().endsWith('.txt'),
        )
        .cast<File>()
        .toList();

    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    final collections = <SavedCollection>[];
    for (final file in files) {
      collections.add(await inspectCollection(file));
    }

    return collections;
  }

  Future<SavedCollection> inspectCollection(File file) async {
    final text = await file.readAsString();
    final articles = parseCollectionText(text);

    final nameMatch = RegExp(
      r'^Name:\s*(.+)$',
      multiLine: true,
    ).firstMatch(text);
    final createdMatch = RegExp(
      r'^Created:\s*(.+)$',
      multiLine: true,
    ).firstMatch(text);
    final countMatch = RegExp(
      r'^Count:\s*(\d+)$',
      multiLine: true,
    ).firstMatch(text);

    final fallbackName = _nameFromFile(file);

    return SavedCollection(
      file: file,
      name: (nameMatch?.group(1) ?? fallbackName).trim(),
      created: DateTime.tryParse((createdMatch?.group(1) ?? '').trim()),
      declaredCount:
          int.tryParse((countMatch?.group(1) ?? '').trim()) ?? articles.length,
      parsedCount: articles.length,
    );
  }

  Future<List<Article>> loadArticles(File file) async {
    final text = await file.readAsString();
    return parseCollectionText(text);
  }

  List<Article> parseCollectionText(String text) {
    final blocks = text.split(RegExp(r'\r?\n-{10,}\r?\n'));
    final articles = <Article>[];

    for (final rawBlock in blocks) {
      final lines = rawBlock.split(RegExp(r'\r?\n'));
      final firstTitleIndex = lines.indexWhere(
        (line) => line.startsWith('TITLE:'),
      );
      if (firstTitleIndex == -1) continue;

      final articleLines = lines.sublist(firstTitleIndex);
      final metadata = <String, String>{};
      final abstractLines = <String>[];
      var readingAbstract = false;

      for (final line in articleLines) {
        if (!readingAbstract && line.trim().isEmpty) {
          readingAbstract = true;
          continue;
        }

        if (!readingAbstract) {
          final separatorIndex = line.indexOf(':');
          if (separatorIndex == -1) continue;

          final key = line.substring(0, separatorIndex).trim().toUpperCase();
          final value = line.substring(separatorIndex + 1).trim();
          metadata[key] = value;
          continue;
        }

        abstractLines.add(line);
      }

      final title = (metadata['TITLE'] ?? '').trim();
      final pmid = (metadata['PMID'] ?? '').trim();
      final abstractText = abstractLines.join('\n').trim();

      if (title.isEmpty && pmid.isEmpty && abstractText.isEmpty) continue;

      final link = (metadata['LINK'] ?? '').trim().isNotEmpty
          ? metadata['LINK']!.trim()
          : (pmid.isNotEmpty ? 'https://pubmed.ncbi.nlm.nih.gov/$pmid/' : '');

      articles.add(
        Article(
          title: title.isNotEmpty ? title : 'Untitled article',
          abstractText: abstractText,
          journal: (metadata['JOURNAL'] ?? '').trim(),
          date: (metadata['DATE'] ?? '').trim(),
          authors: (metadata['AUTHORS'] ?? '').trim(),
          pmid: pmid.isNotEmpty ? pmid : 'collection-${articles.length + 1}',
          link: link,
        ),
      );
    }

    return articles;
  }

  Future<File> saveCollection({
    required String name,
    required Iterable<Article> articles,
  }) async {
    final dir = await getCollectionDirectory();
    final now = DateTime.now();
    final fileName =
        "${_safeFileName(name)}_${now.toIso8601String().replaceAll(":", "-")}.txt";
    final file = File("${dir.path}/$fileName");
    final buffer = StringBuffer();

    buffer.writeln("=== COLLECTION ===");
    buffer.writeln("Name: $name");
    buffer.writeln("Created: $now");
    buffer.writeln("Count: ${articles.length}");
    buffer.writeln("==================\n");

    for (final a in articles) {
      buffer.writeln("TITLE: ${a.title}");
      buffer.writeln("AUTHORS: ${a.authors}");
      if (a.journal.trim().isNotEmpty) buffer.writeln("JOURNAL: ${a.journal}");
      if (a.date.trim().isNotEmpty) buffer.writeln("DATE: ${a.date}");
      buffer.writeln("PMID: ${a.pmid}");
      if (a.link.trim().isNotEmpty) buffer.writeln("LINK: ${a.link}");
      buffer.writeln();
      buffer.writeln(a.abstractText);
      buffer.writeln("\n------------------------------------\n");
    }

    await file.writeAsString(buffer.toString());
    return file;
  }

  Future<File> renameCollection(File file, String newName) async {
    final text = await file.readAsString();
    final updatedText = text.contains(RegExp(r'^Name:', multiLine: true))
        ? text.replaceFirst(
            RegExp(r'^Name:\s*.*$', multiLine: true),
            'Name: $newName',
          )
        : text.replaceFirst(
            '=== COLLECTION ===',
            '=== COLLECTION ===\nName: $newName',
          );

    await file.writeAsString(updatedText);

    final newPath = await _uniquePath(
      file.parent,
      '${_safeFileName(newName)}.txt',
    );
    return file.rename(newPath);
  }

  Future<void> deleteCollection(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _nameFromFile(File file) {
    final baseName = file.uri.pathSegments.last.replaceFirst(
      RegExp(r'\.txt$'),
      '',
    );
    return baseName.replaceAll('_', ' ');
  }

  String _safeFileName(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return cleaned.isEmpty ? 'Collection' : cleaned;
  }

  Future<String> _uniquePath(Directory dir, String fileName) async {
    final dotIndex = fileName.lastIndexOf('.');
    final base = dotIndex == -1 ? fileName : fileName.substring(0, dotIndex);
    final extension = dotIndex == -1 ? '' : fileName.substring(dotIndex);
    var candidate = File("${dir.path}/$fileName");

    if (!await candidate.exists()) return candidate.path;

    var counter = 2;
    while (true) {
      candidate = File("${dir.path}/${base}_$counter$extension");
      if (!await candidate.exists()) return candidate.path;
      counter++;
    }
  }
}
