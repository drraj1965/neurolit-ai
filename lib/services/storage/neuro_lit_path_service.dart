import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/literature_mode.dart';

class NeuroLitPathService {
  static const dataFolderOverrideKey = 'neurolit_data_folder_override_v1';
  static const providerSecretsFileName = 'ai_provider_secrets_v1.json';
  static const tokenUsageFileName = 'token_usage.json';

  Future<String?> getOverridePath() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(dataFolderOverrideKey)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> setOverridePath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = path?.trim() ?? '';
    if (normalized.isEmpty) {
      await prefs.remove(dataFolderOverrideKey);
      return;
    }
    await prefs.setString(dataFolderOverrideKey, normalized);
  }

  Future<String> getDefaultRootPath() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    return _joinPath(documentsDir.path, ['NeuroLit']);
  }

  Future<String> getActiveRootPath() async {
    return (await getOverridePath()) ?? await getDefaultRootPath();
  }

  Future<Directory> getRootFolder({bool create = true}) async {
    final directory = Directory(await getActiveRootPath());
    if (create) {
      await ensureDirectoryExists(directory);
    }
    return directory;
  }

  Future<Directory> getModeRootFolder(
    LiteratureMode mode, {
    bool create = true,
  }) async {
    final root = await getRootFolder(create: create);
    final directory = Directory(_joinPath(root.path, [mode.workspaceFolderName]));
    if (create) {
      await ensureDirectoryExists(directory);
    }
    return directory;
  }

  Future<Directory> getCollectionsFolder({
    LiteratureMode? mode,
    bool create = true,
  }) async {
    final base = mode == null
        ? await getRootFolder(create: create)
        : await getModeRootFolder(mode, create: create);
    final directory = Directory(_joinPath(base.path, ['Collections']));
    if (create) {
      await ensureDirectoryExists(directory);
    }
    return directory;
  }

  Future<Directory> getExportsFolder({
    LiteratureMode? mode,
    bool create = true,
  }) async {
    final base = mode == null
        ? await getRootFolder(create: create)
        : await getModeRootFolder(mode, create: create);
    final directory = Directory(_joinPath(base.path, ['Exports']));
    if (create) {
      await ensureDirectoryExists(directory);
    }
    return directory;
  }

  Future<Directory> getFullTextFolder({
    LiteratureMode? mode,
    bool create = true,
  }) async {
    final base = mode == null
        ? await getRootFolder(create: create)
        : await getModeRootFolder(mode, create: create);
    final directory = Directory(_joinPath(base.path, ['FullText']));
    if (create) {
      await ensureDirectoryExists(directory);
    }
    return directory;
  }

  Future<Directory> getTopicFolder({
    required LiteratureMode mode,
    required DateTime date,
    required String topic,
    bool create = true,
  }) async {
    final fullTextRoot = await getFullTextFolder(mode: mode, create: create);
    final month = monthName(date.month);
    final dayFolder = '${date.day} $month ${date.year}';
    final directory = Directory(
      _joinPath(fullTextRoot.path, [
        '${date.year}',
        month,
        dayFolder,
        topic,
      ]),
    );
    if (create) {
      await ensureDirectoryExists(directory);
    }
    return directory;
  }

  Future<Directory> getSummariesFolder({
    required LiteratureMode mode,
    required DateTime date,
    required String topic,
    bool create = true,
  }) async {
    final topicFolder = await getTopicFolder(
      mode: mode,
      date: date,
      topic: topic,
      create: create,
    );
    final directory = Directory(_joinPath(topicFolder.path, ['summaries']));
    if (create) {
      await ensureDirectoryExists(directory);
    }
    return directory;
  }

  Future<Directory> getPptFolder({
    required LiteratureMode mode,
    required DateTime date,
    required String topic,
    bool create = true,
  }) async {
    final topicFolder = await getTopicFolder(
      mode: mode,
      date: date,
      topic: topic,
      create: create,
    );
    final directory = Directory(_joinPath(topicFolder.path, ['PPTx']));
    if (create) {
      await ensureDirectoryExists(directory);
    }
    return directory;
  }

  Future<File> getProviderSecretsFile() async {
    final root = await getRootFolder(create: true);
    return File(_joinPath(root.path, [providerSecretsFileName]));
  }

  Future<File> getTokenUsageFile() async {
    final root = await getRootFolder(create: true);
    return File(_joinPath(root.path, [tokenUsageFileName]));
  }

  Future<void> ensureDirectoryExists(Directory directory) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  Future<String?> chooseFolderPath() {
    return getDirectoryPath(confirmButtonText: 'Use Folder');
  }

  Future<void> openFolderPath(String path) async {
    final directory = Directory(path);
    await ensureDirectoryExists(directory);

    if (Platform.isWindows) {
      await Process.start(
        'explorer.exe',
        [directory.path.replaceAll('/', '\\')],
      );
      return;
    }

    throw UnsupportedError('Opening folders is only configured for Windows.');
  }

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

  String _joinPath(String root, List<String> parts) {
    return <String>[root, ...parts].join(Platform.pathSeparator);
  }
}
