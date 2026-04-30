import 'dart:convert';
import 'dart:io';

import '../models.dart';

class SessionStore {
  SessionStore({Directory? root}) : root = root ?? defaultAppDataDirectory();

  final Directory root;

  File get _sessionFile =>
      File('${root.path}${Platform.pathSeparator}session.json');

  Future<ApiSession?> load() async {
    try {
      if (!await _sessionFile.exists()) {
        return null;
      }
      final raw = await _sessionFile.readAsString();
      return ApiSession.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(ApiSession session) async {
    await root.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _sessionFile.writeAsString(encoder.convert(session.toJson()));
  }

  Future<void> clear() async {
    if (await _sessionFile.exists()) {
      await _sessionFile.delete();
    }
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
