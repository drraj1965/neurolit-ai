import 'dart:io';

import '../models/literature_mode.dart';
import 'storage/neuro_lit_path_service.dart';

class ModeWorkspaceService {
  ModeWorkspaceService({
    NeuroLitPathService? pathService,
  }) : pathService = pathService ?? NeuroLitPathService();

  final NeuroLitPathService pathService;

  Future<Directory> getAppRoot() => pathService.getRootFolder();

  Future<Directory> getModeRoot(
    LiteratureMode mode, {
    bool create = true,
  }) async {
    return pathService.getModeRootFolder(mode, create: create);
  }

  Future<Directory> getCollectionsDirectory(
    LiteratureMode mode, {
    bool create = true,
  }) async {
    return pathService.getCollectionsFolder(mode: mode, create: create);
  }

  Future<Directory> getLegacyCollectionsDirectory({bool create = true}) async {
    return pathService.getCollectionsFolder(create: create);
  }

  Future<Directory> getExportsDirectory(
    LiteratureMode mode, {
    bool create = true,
  }) async {
    return pathService.getExportsFolder(mode: mode, create: create);
  }

  Future<Directory> getFullTextRoot(
    LiteratureMode mode, {
    bool create = true,
  }) async {
    return pathService.getFullTextFolder(mode: mode, create: create);
  }

  Future<Directory> getLegacyFullTextRoot({bool create = true}) async {
    return pathService.getFullTextFolder(create: create);
  }

  Future<Directory> getTopicDirectory({
    required LiteratureMode mode,
    required DateTime date,
    required String topic,
    bool create = true,
  }) async {
    return pathService.getTopicFolder(
      mode: mode,
      date: date,
      topic: topic,
      create: create,
    );
  }

  Future<Directory> getSummariesDirectory({
    required LiteratureMode mode,
    required DateTime date,
    required String topic,
    bool create = true,
  }) async {
    return pathService.getSummariesFolder(
      mode: mode,
      date: date,
      topic: topic,
      create: create,
    );
  }

  Future<Directory> getPptDirectory({
    required LiteratureMode mode,
    required DateTime date,
    required String topic,
    bool create = true,
  }) async {
    return pathService.getPptFolder(
      mode: mode,
      date: date,
      topic: topic,
      create: create,
    );
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
    return pathService.monthName(month);
  }
}
