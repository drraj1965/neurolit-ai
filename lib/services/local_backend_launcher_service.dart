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
    final bindHost = baseUri.host.toLowerCase() == 'localhost'
        ? '127.0.0.1'
        : baseUri.host;
    final port = baseUri.hasPort ? baseUri.port : 8000;
    final target = _findLaunchTarget();

    if (target == null) {
      throw Exception(
        'The app could not locate a local engineering backend package or launcher script.',
      );
    }

    if (target.type == _BackendLaunchType.packagedExe) {
      await Process.start(
        target.path,
        ['--host', bindHost, '--port', '$port'],
        workingDirectory: target.workingDirectory,
        mode: ProcessStartMode.detached,
      );
    } else {
      final powershellExe = _resolvePowerShellExecutable();
      final result = await Process.run(
        powershellExe,
        [
          '-NoProfile',
          '-WindowStyle',
          'Hidden',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          target.path,
          '-BindHost',
          bindHost,
          '-Port',
          '$port',
        ],
        workingDirectory: target.workingDirectory,
      ).timeout(const Duration(seconds: 45));

      if (result.exitCode != 0) {
        final details = _preferredOutput(result.stderr, result.stdout);
        throw Exception(
          details.isEmpty
              ? 'The engineering backend could not be started automatically.'
              : details,
        );
      }
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

  _BackendLaunchTarget? _findLaunchTarget() {
    final roots = <Directory>{};

    roots.add(Directory.current.absolute);

    try {
      roots.add(File(Platform.resolvedExecutable).parent.absolute);
    } catch (_) {
      // Ignore and fall back to the current directory.
    }

    for (final root in roots) {
      final packaged = _findUpward(
        root,
        ['backend_runtime', 'neurolit_backend.exe'],
      );
      if (packaged != null) {
        return _BackendLaunchTarget(
          type: _BackendLaunchType.packagedExe,
          path: packaged.path,
          workingDirectory: packaged.parent.path,
        );
      }

      final packagedDev = _findUpward(
        root,
        ['backend', 'dist', 'neurolit_backend', 'neurolit_backend.exe'],
      );
      if (packagedDev != null) {
        return _BackendLaunchTarget(
          type: _BackendLaunchType.packagedExe,
          path: packagedDev.path,
          workingDirectory: packagedDev.parent.path,
        );
      }

      final script = _findUpward(
        root,
        ['backend', 'run_backend.ps1'],
      );
      if (script != null) {
        return _BackendLaunchTarget(
          type: _BackendLaunchType.powershellScript,
          path: script.path,
          workingDirectory: script.parent.parent.path,
        );
      }
    }

    return null;
  }

  File? _findUpward(Directory start, List<String> relativeParts) {
    var current = start.absolute;
    for (var depth = 0; depth < 8; depth++) {
      final candidate = File(_joinPath(current.path, relativeParts));
      if (candidate.existsSync()) {
        return candidate;
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
      final candidate = _joinPath(windowsDir, [
        'System32',
        'WindowsPowerShell',
        'v1.0',
        'powershell.exe',
      ]);
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

  String _joinPath(String root, List<String> parts) {
    return <String>[root, ...parts].join(Platform.pathSeparator);
  }
}

enum _BackendLaunchType {
  packagedExe,
  powershellScript,
}

class _BackendLaunchTarget {
  const _BackendLaunchTarget({
    required this.type,
    required this.path,
    required this.workingDirectory,
  });

  final _BackendLaunchType type;
  final String path;
  final String workingDirectory;
}
