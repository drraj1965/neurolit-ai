import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

class LocalBackendLauncherService {
  LocalBackendLauncherService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  Future<void>? _pendingLaunch;

  Future<void> ensureEngineeringBackendRunning({
    required String baseUrl,
  }) async {
    final uri = Uri.parse(baseUrl);
    if (!_canManage(uri)) {
      return;
    }

    if (await _isHealthy(uri)) {
      return;
    }

    if (_pendingLaunch != null) {
      return _pendingLaunch!;
    }

    final launchFuture = _startBackend(uri);
    _pendingLaunch = launchFuture;

    try {
      await launchFuture;
    } finally {
      if (identical(_pendingLaunch, launchFuture)) {
        _pendingLaunch = null;
      }
    }
  }

  bool _canManage(Uri uri) {
    if (!Platform.isWindows) {
      return false;
    }

    if (uri.scheme.toLowerCase() != 'http') {
      return false;
    }

    final host = uri.host.toLowerCase();
    return host == '127.0.0.1' || host == 'localhost';
  }

  Future<void> _startBackend(Uri baseUri) async {
    final projectRoot = _findProjectRoot();
    if (projectRoot == null) {
      throw Exception(
        'The app could not locate the local NeuroLit project folder needed to start the engineering backend automatically.',
      );
    }

    final launcherFile = File(_joinPath(projectRoot.path, 'backend', 'run_backend.ps1'));
    if (!launcherFile.existsSync()) {
      throw Exception(
        'The engineering backend launcher was not found at:\n${launcherFile.path}',
      );
    }

    final powershellExe = _resolvePowerShellExecutable();
    final bindHost = baseUri.host.toLowerCase() == 'localhost'
        ? '127.0.0.1'
        : baseUri.host;
    final port = baseUri.hasPort ? baseUri.port : 8000;

    final result = await Process.run(
      powershellExe,
      [
        '-NoProfile',
        '-WindowStyle',
        'Hidden',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        launcherFile.path,
        '-BindHost',
        bindHost,
        '-Port',
        '$port',
      ],
      workingDirectory: projectRoot.path,
    ).timeout(const Duration(seconds: 45));

    if (result.exitCode != 0) {
      final details = _preferredOutput(result.stderr, result.stdout);
      throw Exception(
        details.isEmpty
            ? 'The engineering backend could not be started automatically.'
            : details,
      );
    }

    final ready = await _waitForHealthy(baseUri);
    if (!ready) {
      throw Exception(
        'The engineering backend start command completed, but the local service did not respond in time.',
      );
    }
  }

  Future<bool> _waitForHealthy(Uri baseUri) async {
    for (var attempt = 0; attempt < 30; attempt++) {
      if (await _isHealthy(baseUri)) {
        return true;
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    return false;
  }

  Future<bool> _isHealthy(Uri baseUri) async {
    final healthUri = baseUri.replace(path: '/', queryParameters: null);

    try {
      final response = await _client
          .get(healthUri)
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Directory? _findProjectRoot() {
    final roots = <String>{};

    roots.add(Directory.current.path);

    try {
      roots.add(File(Platform.resolvedExecutable).parent.path);
    } catch (_) {
      // Ignore and fall back to other candidates.
    }

    for (final root in roots) {
      final match = _walkUpToProjectRoot(Directory(root));
      if (match != null) {
        return match;
      }
    }

    return null;
  }

  Directory? _walkUpToProjectRoot(Directory start) {
    var current = start.absolute;
    for (var depth = 0; depth < 8; depth++) {
      final launcherPath = _joinPath(current.path, 'backend', 'run_backend.ps1');
      if (File(launcherPath).existsSync()) {
        return current;
      }

      final parent = current.parent;
      if (parent.path == current.path) {
        break;
      }
      current = parent;
    }

    return null;
  }

  String _resolvePowerShellExecutable() {
    final windowsDir = Platform.environment['WINDIR'];
    if (windowsDir != null && windowsDir.trim().isNotEmpty) {
      final candidate = _joinPath(
        windowsDir,
        'System32',
        'WindowsPowerShell',
        'v1.0',
        'powershell.exe',
      );
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    return 'powershell.exe';
  }

  String _preferredOutput(Object? stderr, Object? stdout) {
    final errorText = stderr?.toString().trim() ?? '';
    if (errorText.isNotEmpty) {
      return errorText;
    }

    return stdout?.toString().trim() ?? '';
  }

  String _joinPath(String first, String second, [String? third, String? fourth, String? fifth]) {
    final parts = <String>[first, second];
    for (final value in [third, fourth, fifth]) {
      if (value != null) {
        parts.add(value);
      }
    }

    return parts.join(Platform.pathSeparator);
  }
}
