import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/literature_mode.dart';

class ModeWorkspaceService {
  Future<Directory> getAppRoot() async {
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory('${dir.path}/NeuroLit');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  Future<Directory> getModeRoot(
    LiteratureMode mode, {
    bool create = true,
  }) async {
    final appRoot = await getAppRoot();
    final root = Directory('${appRoot.path}/${mode.workspaceFolderName}');
    if (create && !await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  Future<Directory> getCollectionsDirectory(
    LiteratureMode mode, {
    bool create = true,
  }) async {
    final modeRoot = await getModeRoot(mode, create: create);
    final dir = Directory('${modeRoot.path}/Collections');
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getLegacyCollectionsDirectory({bool create = true}) async {
    final appRoot = await getAppRoot();
    final dir = Directory('${appRoot.path}/Collections');
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getExportsDirectory(
    LiteratureMode mode, {
    bool create = true,
  }) async {
    final modeRoot = await getModeRoot(mode, create: create);
    final dir = Directory('${modeRoot.path}/Exports');
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getFullTextRoot(
    LiteratureMode mode, {
    bool create = true,
  }) async {
    final modeRoot = await getModeRoot(mode, create: create);
    final dir = Directory('${modeRoot.path}/FullText');
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getLegacyFullTextRoot({bool create = true}) async {
    final appRoot = await getAppRoot();
    final dir = Directory('${appRoot.path}/FullText');
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getTopicDirectory({
    required LiteratureMode mode,
    required DateTime date,
    required String topic,
    bool create = true,
  }) async {
    final fullTextRoot = await getFullTextRoot(mode, create: create);
    final month = monthName(date.month);
    final dayFolder = '${date.day} $month ${date.year}';
    final topicDir = Directory(
      '${fullTextRoot.path}/${date.year}/$month/$dayFolder/$topic',
    );
    if (create && !await topicDir.exists()) {
      await topicDir.create(recursive: true);
    }
    return topicDir;
  }

  Future<Directory> getSummariesDirectory({
    required LiteratureMode mode,
    required DateTime date,
    required String topic,
    bool create = true,
  }) async {
    final topicDir = await getTopicDirectory(
      mode: mode,
      date: date,
      topic: topic,
      create: create,
    );
    final dir = Directory('${topicDir.path}/summaries');
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getPptDirectory({
    required LiteratureMode mode,
    required DateTime date,
    required String topic,
    bool create = true,
  }) async {
    final topicDir = await getTopicDirectory(
      mode: mode,
      date: date,
      topic: topic,
      create: create,
    );
    final dir = Directory('${topicDir.path}/PPTx');
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getFullTextArtifactsDirectory({
    required LiteratureMode mode,
    required DateTime date,
    required String topic,
    bool create = true,
  }) async {
    final topicDir = await getTopicDirectory(
      mode: mode,
      date: date,
      topic: topic,
      create: create,
    );
    final dir = Directory('${topicDir.path}/fulltext');
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String recentSearchPreferenceKey(LiteratureMode mode) {
    return 'recent_searches_${mode.storageValue}_v2';
  }

  String get legacyRecentSearchPreferenceKey => 'recent_searches_v1';

  String monthName(int month) {
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[month];
  }
}
