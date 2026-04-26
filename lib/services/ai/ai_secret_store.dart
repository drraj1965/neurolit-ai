import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class AiSecretStore {
  static const _fileName = 'ai_provider_secrets_v1.json';
  static const _windowsSecurePrefix = 'win_ps_secure:';
  static const _windowsLegacyPrefix = 'win_legacy_dpapi:';

  Future<void> writeSecret(String secretId, String secret) async {
    final payload = await _readPayload();
    payload[secretId] = Platform.isWindows
        ? '$_windowsSecurePrefix${await _protectForWindows(secret)}'
        : secret;
    await _writePayload(payload);
  }

  Future<String?> readSecret(String secretId) async {
    final payload = await _readPayload();
    final raw = payload[secretId];
    if (raw == null || raw.trim().isEmpty) return null;

    if (!Platform.isWindows) {
      return raw;
    }

    if (raw.startsWith(_windowsSecurePrefix)) {
      return _unprotectForWindows(raw.substring(_windowsSecurePrefix.length));
    }

    if (raw.startsWith(_windowsLegacyPrefix)) {
      return _unprotectLegacyForWindows(
        raw.substring(_windowsLegacyPrefix.length),
      );
    }

    try {
      return await _unprotectForWindows(raw);
    } catch (_) {
      return _unprotectLegacyForWindows(raw);
    }
  }

  Future<void> deleteSecret(String secretId) async {
    final payload = await _readPayload();
    payload.remove(secretId);
    await _writePayload(payload);
  }

  Future<Map<String, String>> _readPayload() async {
    final file = await _getSecretsFile();
    if (!await file.exists()) {
      return <String, String>{};
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return <String, String>{};

      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _writePayload(Map<String, String> payload) async {
    final file = await _getSecretsFile();
    await file.writeAsString(jsonEncode(payload));
  }

  Future<File> _getSecretsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final secretDir = Directory('${dir.path}/NeuroLit');

    if (!await secretDir.exists()) {
      await secretDir.create(recursive: true);
    }

    return File('${secretDir.path}/$_fileName');
  }

  Future<String> _protectForWindows(String plainText) async {
    final plainBase64 = base64Encode(utf8.encode(plainText));
    final script = '''
\$plain = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$plainBase64'))
\$secure = ConvertTo-SecureString \$plain -AsPlainText -Force
[Console]::Write((\$secure | ConvertFrom-SecureString))
''';

    final result = await Process.run(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-EncodedCommand',
        _encodePowerShellScript(script),
      ],
    );

    if (result.exitCode != 0) {
      throw Exception(
        'Failed to protect provider secret on Windows: ${result.stderr}',
      );
    }

    return result.stdout.toString().trim();
  }

  Future<String?> _unprotectForWindows(String protectedBase64) async {
    final protectedScriptBase64 = base64Encode(utf8.encode(protectedBase64));
    final script = '''
\$protected = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$protectedScriptBase64'))
\$secure = ConvertTo-SecureString \$protected
\$credential = New-Object System.Management.Automation.PSCredential('__secret__', \$secure)
[Console]::Write(\$credential.GetNetworkCredential().Password)
''';

    final result = await Process.run(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-EncodedCommand',
        _encodePowerShellScript(script),
      ],
    );

    if (result.exitCode != 0) {
      throw Exception(
        'Failed to read provider secret on Windows: ${result.stderr}',
      );
    }

    final output = result.stdout.toString();
    return output.isEmpty ? null : output;
  }

  Future<String?> _unprotectLegacyForWindows(String protectedBase64) async {
    final script = '''
Add-Type -AssemblyName System.Security
\$protected = [Convert]::FromBase64String('$protectedBase64')
\$plain = [System.Security.Cryptography.ProtectedData]::Unprotect(\$protected, \$null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
[Console]::Write([System.Text.Encoding]::UTF8.GetString(\$plain))
''';

    final result = await Process.run(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-EncodedCommand',
        _encodePowerShellScript(script),
      ],
    );

    if (result.exitCode != 0) {
      throw Exception(
        'Failed to read provider secret on Windows: ${result.stderr}',
      );
    }

    final output = result.stdout.toString();
    return output.isEmpty ? null : output;
  }

  String _encodePowerShellScript(String script) {
    final bytes = Uint8List.fromList(script.codeUnits.expand((unit) {
      return [unit & 0xff, unit >> 8];
    }).toList());
    return base64Encode(bytes);
  }
}
