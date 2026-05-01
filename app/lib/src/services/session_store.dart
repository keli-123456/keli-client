import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models.dart';
import 'endpoint_resolver.dart';

class SessionStore {
  SessionStore({
    Directory? root,
    SessionSecretStore? secretStore,
  })  : root = root ?? defaultAppDataDirectory(),
        _secretStore = secretStore ?? SessionSecretStore.forCurrentPlatform();

  final Directory root;
  final SessionSecretStore _secretStore;

  File get _sessionFile =>
      File('${root.path}${Platform.pathSeparator}session.json');
  File get _endpointFile =>
      File('${root.path}${Platform.pathSeparator}endpoint.json');
  File get _announcementStateFile =>
      File('${root.path}${Platform.pathSeparator}announcement_state.json');

  Future<ApiSession?> load() async {
    try {
      if (!await _sessionFile.exists()) {
        return null;
      }
      final raw = await _sessionFile.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final sessionJson = Map<String, Object?>.from(decoded);
      final protectedAuthData = sessionJson['auth_data_protected'];
      if ((sessionJson['auth_data'] == null ||
              '${sessionJson['auth_data']}'.isEmpty) &&
          protectedAuthData is String &&
          protectedAuthData.isNotEmpty) {
        final authData = await _secretStore.unprotect(
          protectedAuthData,
          storageKind: '${sessionJson['auth_data_storage'] ?? ''}',
        );
        if (authData == null || authData.isEmpty) {
          return null;
        }
        sessionJson['auth_data'] = authData;
      }
      return ApiSession.fromJson(sessionJson);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(ApiSession session) async {
    await root.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    final sessionJson = session.toJson();
    final protectedAuthData = await _secretStore.protect(session.authData);
    if (protectedAuthData != null && protectedAuthData.isNotEmpty) {
      sessionJson
        ..remove('auth_data')
        ..['auth_data_protected'] = protectedAuthData
        ..['auth_data_storage'] = _secretStore.storageKind;
    } else {
      sessionJson['auth_data_storage'] = 'plain';
    }
    await _sessionFile.writeAsString(encoder.convert(sessionJson));
  }

  Future<void> clear() async {
    if (await _sessionFile.exists()) {
      await _sessionFile.delete();
    }
  }

  Future<ApiEndpointConfig?> loadEndpointConfig() async {
    try {
      if (!await _endpointFile.exists()) {
        return null;
      }
      final raw = await _endpointFile.readAsString();
      return ApiEndpointConfig.fromJson(jsonDecode(raw), source: 'cache');
    } catch (_) {
      return null;
    }
  }

  Future<void> saveEndpointConfig(ApiEndpointConfig config) async {
    await root.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _endpointFile.writeAsString(encoder.convert(config.toJson()));
  }

  Future<Set<String>> loadDismissedAnnouncementKeys() async {
    try {
      if (!await _announcementStateFile.exists()) {
        return <String>{};
      }
      final decoded = jsonDecode(await _announcementStateFile.readAsString());
      if (decoded is Map && decoded['dismissed'] is List) {
        return (decoded['dismissed'] as List)
            .map((item) => '$item')
            .where((item) => item.isNotEmpty)
            .toSet();
      }
      if (decoded is List) {
        return decoded
            .map((item) => '$item')
            .where((item) => item.isNotEmpty)
            .toSet();
      }
    } catch (_) {
      return <String>{};
    }
    return <String>{};
  }

  Future<void> saveDismissedAnnouncementKeys(Set<String> keys) async {
    await root.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _announcementStateFile.writeAsString(
      encoder.convert(<String, Object?>{
        'dismissed': keys.toList()..sort(),
      }),
    );
  }

  static Directory defaultAppDataDirectory() {
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        return Directory('$localAppData${Platform.pathSeparator}KeliClient');
      }
    }
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      return Directory('$home${Platform.pathSeparator}.keli-client');
    }
    return Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}keli-client');
  }
}

abstract interface class SessionSecretStore {
  String get storageKind;

  Future<String?> protect(String value);

  Future<String?> unprotect(
    String value, {
    required String storageKind,
  });

  static SessionSecretStore forCurrentPlatform() {
    if (Platform.isAndroid) {
      return const AndroidKeystoreSessionSecretStore();
    }
    if (Platform.isWindows) {
      return const WindowsDpapiSessionSecretStore();
    }
    return const PlainSessionSecretStore();
  }
}

class PlainSessionSecretStore implements SessionSecretStore {
  const PlainSessionSecretStore();

  @override
  String get storageKind => 'plain';

  @override
  Future<String?> protect(String value) async => null;

  @override
  Future<String?> unprotect(
    String value, {
    required String storageKind,
  }) async {
    return storageKind == this.storageKind ? value : null;
  }
}

class AndroidKeystoreSessionSecretStore implements SessionSecretStore {
  const AndroidKeystoreSessionSecretStore();

  static const MethodChannel _channel =
      MethodChannel('com.keli.keli_client/session');

  @override
  String get storageKind => 'android-keystore-v1';

  @override
  Future<String?> protect(String value) async {
    try {
      return await _channel.invokeMethod<String>(
        'protect',
        <String, Object?>{'value': value},
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> unprotect(
    String value, {
    required String storageKind,
  }) async {
    if (storageKind != this.storageKind) {
      return null;
    }
    try {
      return await _channel.invokeMethod<String>(
        'unprotect',
        <String, Object?>{'value': value},
      );
    } catch (_) {
      return null;
    }
  }
}

class WindowsDpapiSessionSecretStore implements SessionSecretStore {
  const WindowsDpapiSessionSecretStore();

  @override
  String get storageKind => 'windows-dpapi-current-user-v1';

  @override
  Future<String?> protect(String value) {
    return _runPowerShellDpapiScript(
      r'''
Add-Type -AssemblyName System.Security
$plain = [Console]::In.ReadToEnd()
$bytes = [Text.Encoding]::UTF8.GetBytes($plain)
$protected = [Security.Cryptography.ProtectedData]::Protect($bytes, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
[Convert]::ToBase64String($protected)
''',
      value,
    );
  }

  @override
  Future<String?> unprotect(
    String value, {
    required String storageKind,
  }) {
    if (storageKind != this.storageKind) {
      return Future<String?>.value(null);
    }
    return _runPowerShellDpapiScript(
      r'''
Add-Type -AssemblyName System.Security
$protectedText = [Console]::In.ReadToEnd()
$protected = [Convert]::FromBase64String($protectedText.Trim())
$bytes = [Security.Cryptography.ProtectedData]::Unprotect($protected, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
[Text.Encoding]::UTF8.GetString($bytes)
''',
      value,
    );
  }

  Future<String?> _runPowerShellDpapiScript(
    String script,
    String input,
  ) async {
    try {
      final process = await Process.start(
        'powershell.exe',
        <String>['-NoProfile', '-NonInteractive', '-Command', script],
      );
      process.stdin.write(input);
      await process.stdin.close();
      final stdout = await utf8.decoder.bind(process.stdout).join();
      await process.stderr.drain<void>();
      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        return null;
      }
      final result = stdout.trim();
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }
}
