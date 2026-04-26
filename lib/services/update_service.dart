import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_update_models.dart';
import 'app_version_service.dart';

class UpdateService {
  static const _frequencyKey = 'app_update_frequency_v1';
  static const _lastCheckedAtKey = 'app_update_last_checked_at_v1';

  String get currentVersion => AppVersionService.currentVersion;

  Future<UpdateSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return UpdateSettings(
      frequency: UpdateFrequencyX.fromStorage(prefs.getString(_frequencyKey)),
      lastCheckedAt: _parseDate(prefs.getString(_lastCheckedAtKey)),
    );
  }

  Future<void> saveFrequency(UpdateFrequency frequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_frequencyKey, frequency.storageValue);
  }

  Future<bool> shouldCheckAutomatically() async {
    final settings = await loadSettings();
    final interval = settings.frequency.interval;
    if (interval == null) return false;

    final lastCheckedAt = settings.lastCheckedAt;
    if (lastCheckedAt == null) return true;

    return DateTime.now().difference(lastCheckedAt) >= interval;
  }

  Future<UpdateCheckResult> checkForUpdates({
    bool ignoreSchedule = false,
    bool markChecked = true,
  }) async {
    if (!ignoreSchedule && !await shouldCheckAutomatically()) {
      return UpdateCheckResult(
        currentVersion: currentVersion,
        isUpdateAvailable: false,
        wasSkippedBySchedule: true,
      );
    }

    final uri = Uri.parse(AppVersionService.updateJsonUrl);
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'Unable to fetch update information (${response.statusCode}).',
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Update metadata is not a valid JSON object.');
    }

    final info = UpdateInfo.fromJson(decoded);
    if (info.latestVersion.isEmpty || info.downloadUrl.isEmpty) {
      throw Exception(
        'Update metadata is missing latest_version or download_url.',
      );
    }

    if (markChecked) {
      await _saveLastCheckedAt(DateTime.now());
    }

    return UpdateCheckResult(
      currentVersion: currentVersion,
      updateInfo: info,
      isUpdateAvailable:
          _compareVersions(info.latestVersion, currentVersion) > 0,
    );
  }

  Future<File> downloadInstaller(UpdateInfo info) async {
    final uri = Uri.parse(info.downloadUrl);
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to download installer (${response.statusCode}).');
    }

    final updatesDir = await _ensureUpdatesDirectory();
    final file = File(
      '${updatesDir.path}\\NeuroLit_Setup_${_sanitizeVersion(info.latestVersion)}.exe',
    );
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

  Future<File> createUpdaterScript({
    required File installerFile,
    required String currentExecutablePath,
  }) async {
    final updatesDir = await _ensureUpdatesDirectory();
    final script = File('${updatesDir.path}\\run_update.bat');
    final executableName = _basename(currentExecutablePath);

    final content = [
      '@echo off',
      'setlocal',
      'set "APP_EXE=$currentExecutablePath"',
      'set "APP_NAME=$executableName"',
      'set "INSTALLER=${installerFile.path}"',
      ':wait_for_exit',
      'tasklist /FI "IMAGENAME eq %APP_NAME%" | find /I "%APP_NAME%" >nul',
      'if %ERRORLEVEL%==0 (',
      '  timeout /t 2 /nobreak >nul',
      '  goto wait_for_exit',
      ')',
      'start "" "%INSTALLER%"',
      'endlocal',
    ].join('\r\n');

    await script.writeAsString(content, flush: true);
    return script;
  }

  Future<void> launchInstaller(UpdateInfo info) async {
    final installer = await downloadInstaller(info);
    final currentExecutablePath = Platform.resolvedExecutable;
    final script = await createUpdaterScript(
      installerFile: installer,
      currentExecutablePath: currentExecutablePath,
    );

    await Process.start(
      'cmd',
      ['/c', 'start', '', '/min', script.path],
      mode: ProcessStartMode.detached,
      runInShell: true,
    );
  }

  int compareVersions(String a, String b) => _compareVersions(a, b);

  Future<void> _saveLastCheckedAt(DateTime value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCheckedAtKey, value.toIso8601String());
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  Future<Directory> _ensureUpdatesDirectory() async {
    final baseDir = Directory(
      '${Directory.systemTemp.path}\\NeuroLitAI\\updates',
    );
    await baseDir.create(recursive: true);
    return baseDir;
  }

  int _compareVersions(String left, String right) {
    final leftParts = _normalizedParts(left);
    final rightParts = _normalizedParts(right);
    final maxLength = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (var index = 0; index < maxLength; index++) {
      final leftValue = index < leftParts.length ? leftParts[index] : 0;
      final rightValue = index < rightParts.length ? rightParts[index] : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }

    return 0;
  }

  List<int> _normalizedParts(String version) {
    return version
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }

  String _sanitizeVersion(String version) {
    return version.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
  }

  String _basename(String path) {
    final normalized = path.replaceAll('/', '\\');
    final lastSeparator = normalized.lastIndexOf('\\');
    if (lastSeparator == -1) return normalized;
    return normalized.substring(lastSeparator + 1);
  }
}
