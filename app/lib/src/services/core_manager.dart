import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models.dart';
import 'session_store.dart';

enum LatencyTestMode {
  quick,
  retry,
}

abstract interface class CoreManager {
  bool get supportsLatencyTesting;

  Future<void> prepare();

  Future<CoreApplyResult> applyConfig(
    Map<String, Object?> config, {
    ProxyMode mode = ProxyMode.system,
  });

  Future<void> connect({
    required ProxyNode node,
    required ProxyMode mode,
  });

  Future<void> disconnect();

  Future<int?> testLatency(
    ProxyNode node, {
    Map<String, Object?>? config,
    ProxyMode mode = ProxyMode.system,
    LatencyTestMode testMode = LatencyTestMode.quick,
  });

  Future<Map<int, int?>> testLatencies(
    List<ProxyNode> nodes, {
    Map<String, Object?>? config,
    ProxyMode mode = ProxyMode.system,
    LatencyTestMode testMode = LatencyTestMode.quick,
    int concurrency = 5,
  });

  Stream<CoreTrafficSample> watchTraffic();

  Future<CoreDiagnostics> diagnostics();
}

class CoreApplyResult {
  const CoreApplyResult({
    required this.configFile,
    required this.localProxyPort,
    this.localProxyType = 'mixed',
    this.clashApiAddress,
  });

  final File configFile;
  final int localProxyPort;
  final String localProxyType;
  final String? clashApiAddress;
}

CoreManager createCoreManager() {
  if (Platform.isAndroid) {
    return AndroidCoreManager();
  }
  if (Platform.isWindows) {
    return WindowsCoreManager();
  }
  if (Platform.isMacOS) {
    return MacOSCoreManager();
  }
  return UnsupportedCoreManager();
}

class AndroidCoreManager implements CoreManager {
  AndroidCoreManager({Directory? runtimeRoot})
      : runtimeRoot = runtimeRoot ??
            Directory(
                '${SessionStore.defaultAppDataDirectory().path}${Platform.pathSeparator}runtime');

  static const MethodChannel _channel =
      MethodChannel('com.keli.keli_client/core');

  final Directory runtimeRoot;
  bool _prepared = false;
  bool _configApplied = false;
  bool _running = false;
  String _status = 'idle';
  String? _lastMessage;
  String? _nativeConfigPath;

  Directory get _configDir =>
      Directory('${runtimeRoot.path}${Platform.pathSeparator}config');
  File get _configFile =>
      File('${_configDir.path}${Platform.pathSeparator}sing-box-android.json');

  @override
  bool get supportsLatencyTesting => false;

  @override
  Future<void> prepare() async {
    await runtimeRoot.create(recursive: true);
    await _configDir.create(recursive: true);
    final result = await _invokeMap('prepare');
    _prepared = result['prepared'] == true;
    _status = _prepared ? 'prepared' : 'permission-required';
    _lastMessage = result['message'] as String?;
    if (!_prepared && result['permissionRequired'] == true) {
      throw const CoreException('需要先授予 Android VPN 权限，请确认系统弹窗后再连接');
    }
  }

  @override
  Future<CoreApplyResult> applyConfig(
    Map<String, Object?> config, {
    ProxyMode mode = ProxyMode.system,
  }) async {
    await _configDir.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    final configText = encoder.convert(config);
    await _configFile.writeAsString(configText);
    final result = await _invokeMap(
      'applyConfig',
      <String, Object?>{
        'config': configText,
        'mode': mode.name,
      },
    );
    _configApplied = result['applied'] != false;
    _status = _configApplied ? 'configured' : 'config-error';
    _lastMessage = result['message'] as String?;
    _nativeConfigPath = _stringValue(result['configPath']) ?? _nativeConfigPath;
    return CoreApplyResult(
      configFile: _configFile,
      localProxyPort: 0,
      localProxyType: 'vpn',
    );
  }

  @override
  Future<void> connect({
    required ProxyNode node,
    required ProxyMode mode,
  }) async {
    if (!_configApplied) {
      throw const CoreException('Android sing-box 配置尚未写入');
    }
    final result = await _invokeMap(
      'connect',
      <String, Object?>{
        'config_path': _nativeConfigPath ?? _configFile.path,
        'node_id': node.id,
        'node_name': node.name,
        'mode': mode.name,
      },
    );
    _prepared = result['prepared'] == true || _prepared;
    _lastMessage = result['message'] as String?;
    if (result['permissionRequired'] == true) {
      throw const CoreException('需要先授予 Android VPN 权限，请确认系统弹窗后再连接');
    }
    if (result['coreEmbedded'] == false) {
      throw CoreException(_lastMessage ?? 'Android 核心 AAR 未打包');
    }
    if (result['configReady'] == false) {
      throw CoreException(_lastMessage ?? 'Android sing-box 配置为空');
    }
    if (result['started'] == false && result['connected'] != true) {
      throw CoreException(_lastMessage ?? 'Android VPNService 启动失败');
    }
    final status = await _waitForRunningStatus(nodeName: node.name);
    _updateStatusCache(status);
  }

  @override
  Future<void> disconnect() async {
    final result = await _invokeMap('disconnect');
    _running = false;
    _status = 'stopped';
    _lastMessage = result['message'] as String?;
  }

  @override
  Future<int?> testLatency(
    ProxyNode node, {
    Map<String, Object?>? config,
    ProxyMode mode = ProxyMode.system,
    LatencyTestMode testMode = LatencyTestMode.quick,
  }) async {
    throw const CoreException(
      'Android 当前暂不支持本地延迟测速：移动端核心未开放 Clash API',
    );
  }

  @override
  Future<Map<int, int?>> testLatencies(
    List<ProxyNode> nodes, {
    Map<String, Object?>? config,
    ProxyMode mode = ProxyMode.system,
    LatencyTestMode testMode = LatencyTestMode.quick,
    int concurrency = 5,
  }) async {
    throw const CoreException(
      'Android 当前暂不支持本地延迟测速：移动端核心未开放 Clash API',
    );
  }

  @override
  Stream<CoreTrafficSample> watchTraffic() {
    return const Stream<CoreTrafficSample>.empty();
  }

  @override
  Future<CoreDiagnostics> diagnostics() async {
    Map<String, Object?> status = const <String, Object?>{};
    try {
      status = await _invokeMap('status');
    } catch (_) {}
    final configExists = await _configFile.exists();
    final nativeStatus = status['status'] as String?;
    final coreEmbedded = status['coreEmbedded'] == true;
    final nativeConfigPath = _stringValue(status['configPath']);
    final nativeConfigExists = status['configExists'] == true;
    final nativeConfigBytes = _intValue(status['configBytes']) ?? 0;
    if (nativeConfigPath != null && nativeConfigPath.isNotEmpty) {
      _nativeConfigPath = nativeConfigPath;
    }
    return CoreDiagnostics(
      updatedAt: DateTime.now(),
      runtimeRoot: runtimeRoot.path,
      corePath: 'Android VPNService',
      coreExists: coreEmbedded,
      configPath: nativeConfigPath ?? _configFile.path,
      configExists: nativeConfigExists || configExists,
      logPath: '',
      logExists: false,
      processRunning: status['running'] == true || _running,
      localProxyType: 'vpn',
      localProxyListen: 'android-vpn',
      localProxyPort: 0,
      clashApiAddress: null,
      systemProxyEnabled: false,
      systemProxyServer: null,
      configCheckStatus: nativeStatus ?? _status,
      configCheckOutput: (status['message'] as String?) ??
          _lastMessage ??
          (coreEmbedded ? 'Android VPN 通道已初始化' : 'Android 核心 AAR 未打包'),
      logTail: const [],
      detailItems: <String, String>{
        'VPN 权限': status['vpnPrepared'] == true ? '已授权' : '未授权',
        '移动端核心': coreEmbedded ? '已打包' : '缺失',
        '平台测速': supportsLatencyTesting ? '支持' : '不支持',
        'VPN Service': _androidRunningText(status),
        '原生配置': nativeConfigExists
            ? '已写入 (${_byteCountText(nativeConfigBytes)})'
            : '未写入',
        '节点': _stringValue(status['nodeName'])?.isNotEmpty == true
            ? _stringValue(status['nodeName'])!
            : '-',
      },
    );
  }

  Future<Map<String, Object?>> _waitForRunningStatus({
    required String nodeName,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final deadline = DateTime.now().add(timeout);
    Map<String, Object?> latest = const <String, Object?>{};
    while (DateTime.now().isBefore(deadline)) {
      latest = await _invokeMap('status');
      _updateStatusCache(latest);
      if (latest['permissionRequired'] == true) {
        throw const CoreException('需要先授予 Android VPN 权限，请确认系统弹窗后再连接');
      }
      if (latest['running'] == true) {
        return latest;
      }
      final status = _stringValue(latest['status']) ?? '';
      if (status == 'error' ||
          status == 'revoked' ||
          status == 'missing-core' ||
          status == 'config-error') {
        throw CoreException(_androidStatusMessage(latest));
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    throw CoreException(
      'Android VPNService 启动超时：${_androidStatusMessage(latest, fallbackNodeName: nodeName)}',
    );
  }

  void _updateStatusCache(Map<String, Object?> status) {
    _running = status['running'] == true;
    _prepared = status['vpnPrepared'] == true || _prepared;
    _status =
        _stringValue(status['status']) ?? (_running ? 'running' : _status);
    _lastMessage = _stringValue(status['message']) ?? _lastMessage;
    final nativeConfigPath = _stringValue(status['configPath']);
    if (nativeConfigPath != null && nativeConfigPath.isNotEmpty) {
      _nativeConfigPath = nativeConfigPath;
    }
  }

  String _androidStatusMessage(
    Map<String, Object?> status, {
    String? fallbackNodeName,
  }) {
    final message = _stringValue(status['message']);
    final nativeStatus = _stringValue(status['status']);
    final nodeName = _stringValue(status['nodeName']) ?? fallbackNodeName;
    final parts = <String>[
      if (nativeStatus != null && nativeStatus.isNotEmpty) '状态 $nativeStatus',
      if (message != null && message.isNotEmpty) message,
      if (nodeName != null && nodeName.isNotEmpty) '节点 $nodeName',
    ];
    return parts.isEmpty ? 'Android VPNService 未进入运行状态' : parts.join(' · ');
  }

  String _androidRunningText(Map<String, Object?> status) {
    if (status['running'] == true) {
      return '运行中';
    }
    final nativeStatus = _stringValue(status['status']);
    if (nativeStatus == null || nativeStatus.isEmpty) {
      return '未运行';
    }
    return nativeStatus;
  }

  String? _stringValue(Object? value) => value == null ? null : '$value';

  int? _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return num.tryParse(value)?.toInt();
    }
    return null;
  }

  String _byteCountText(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<Map<String, Object?>> _invokeMap(
    String method, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        method,
        arguments,
      );
      return result ?? const <String, Object?>{};
    } on PlatformException catch (error) {
      throw CoreException(error.message ?? error.code);
    }
  }
}

class UnsupportedCoreManager implements CoreManager {
  @override
  bool get supportsLatencyTesting => false;

  @override
  Future<void> prepare() async {}

  @override
  Future<CoreApplyResult> applyConfig(
    Map<String, Object?> config, {
    ProxyMode mode = ProxyMode.system,
  }) async {
    throw CoreException('${Platform.operatingSystem} 暂未接入本地核心');
  }

  @override
  Future<void> connect({
    required ProxyNode node,
    required ProxyMode mode,
  }) async {
    throw CoreException('${Platform.operatingSystem} 暂未接入本地核心');
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<int?> testLatency(
    ProxyNode node, {
    Map<String, Object?>? config,
    ProxyMode mode = ProxyMode.system,
    LatencyTestMode testMode = LatencyTestMode.quick,
  }) async {
    return null;
  }

  @override
  Future<Map<int, int?>> testLatencies(
    List<ProxyNode> nodes, {
    Map<String, Object?>? config,
    ProxyMode mode = ProxyMode.system,
    LatencyTestMode testMode = LatencyTestMode.quick,
    int concurrency = 5,
  }) async {
    return <int, int?>{
      for (final node in nodes) node.id: null,
    };
  }

  @override
  Stream<CoreTrafficSample> watchTraffic() {
    return const Stream<CoreTrafficSample>.empty();
  }

  @override
  Future<CoreDiagnostics> diagnostics() async {
    return CoreDiagnostics(
      updatedAt: DateTime.now(),
      runtimeRoot: '',
      corePath: '',
      coreExists: false,
      configPath: '',
      configExists: false,
      logPath: '',
      logExists: false,
      processRunning: false,
      localProxyType: 'unsupported',
      localProxyListen: Platform.operatingSystem,
      localProxyPort: 0,
      clashApiAddress: null,
      systemProxyEnabled: false,
      systemProxyServer: null,
      configCheckStatus: 'unsupported',
      configCheckOutput: '${Platform.operatingSystem} 暂未接入本地核心',
      logTail: const [],
    );
  }
}

class WindowsCoreManager implements CoreManager {
  WindowsCoreManager({Directory? runtimeRoot})
      : runtimeRoot = runtimeRoot ??
            Directory(
                '${SessionStore.defaultAppDataDirectory().path}${Platform.pathSeparator}runtime');

  final Directory runtimeRoot;
  Process? _process;
  IOSink? _logSink;
  int _localProxyPort = 20808;
  String _localProxyType = 'mixed';
  String _localProxyListen = '127.0.0.1';
  int _clashApiPort = 0;
  String _clashApiListen = '127.0.0.1';
  final Set<int> _reservedLatencyPorts = <int>{};

  Directory get _coreDir =>
      Directory('${runtimeRoot.path}${Platform.pathSeparator}core');
  Directory get _configDir =>
      Directory('${runtimeRoot.path}${Platform.pathSeparator}config');
  Directory get _logsDir =>
      Directory('${runtimeRoot.path}${Platform.pathSeparator}logs');
  File get _configFile =>
      File('${_configDir.path}${Platform.pathSeparator}sing-box.json');
  File get _logFile =>
      File('${_logsDir.path}${Platform.pathSeparator}sing-box.log');
  File get _proxyStateFile =>
      File('${runtimeRoot.path}${Platform.pathSeparator}proxy-state.json');
  File get _coreExe =>
      File('${_coreDir.path}${Platform.pathSeparator}sing-box.exe');

  @override
  bool get supportsLatencyTesting => true;

  @override
  Future<void> prepare() async {
    await runtimeRoot.create(recursive: true);
    await _coreDir.create(recursive: true);
    await _configDir.create(recursive: true);
    await _logsDir.create(recursive: true);

    if (!Platform.isWindows && !Platform.isMacOS) {
      return;
    }
    if (!await _coreExe.exists()) {
      await _downloadSingBox();
    }
  }

  @override
  Future<CoreApplyResult> applyConfig(
    Map<String, Object?> config, {
    ProxyMode mode = ProxyMode.system,
  }) async {
    await _configDir.create(recursive: true);
    final normalized = _normalizeConfigForMode(config, mode);
    final localProxy =
        _detectLocalProxyEndpoint(normalized) ?? _addMixedInbound(normalized);
    final clashApiPort = await _availableTcpPort(preferred: 9090);
    _ensureClashApi(normalized, port: clashApiPort);
    _localProxyPort = localProxy.port;
    _localProxyType = localProxy.type;
    _localProxyListen = localProxy.listen;
    _clashApiPort = clashApiPort;
    _clashApiListen = '127.0.0.1';
    const encoder = JsonEncoder.withIndent('  ');
    await _configFile.writeAsString(encoder.convert(normalized));
    return CoreApplyResult(
      configFile: _configFile,
      localProxyPort: _localProxyPort,
      localProxyType: _localProxyType,
      clashApiAddress: _clashApiAddress,
    );
  }

  @override
  Future<void> connect({
    required ProxyNode node,
    required ProxyMode mode,
  }) async {
    if (!Platform.isWindows && !Platform.isMacOS) {
      throw CoreException('当前平台暂未接入本地核心');
    }
    if (!await _coreExe.exists()) {
      await prepare();
    }
    if (!await _configFile.exists()) {
      throw CoreException('sing-box 配置文件不存在，请先拉取节点配置');
    }
    await disconnect();
    await _logsDir.create(recursive: true);
    _logSink = _logFile.openWrite(mode: FileMode.append);
    _writeLog('Starting sing-box for ${node.name}');
    final process = await Process.start(
      _coreExe.path,
      ['run', '-c', _configFile.path],
      workingDirectory: runtimeRoot.path,
      runInShell: false,
      environment: _singBoxEnvironment(),
    );
    _process = process;
    process.stdout
        .transform(utf8.decoder)
        .listen((line) => _writeLog(line.trimRight()));
    process.stderr
        .transform(utf8.decoder)
        .listen((line) => _writeLog(line.trimRight()));
    unawaited(process.exitCode.then((code) {
      _writeLog('sing-box exited with code $code');
      _process = null;
    }));
    await _ensureProcessStarted(process);
    if (mode == ProxyMode.system) {
      await _enableSystemProxy();
    } else if (mode == ProxyMode.tun) {
      _writeLog(
          'TUN mode selected; sing-box config must include a tun inbound and may require administrator privileges.');
    }
  }

  @override
  Future<void> disconnect({bool restoreProxy = true}) async {
    if (restoreProxy && (Platform.isWindows || Platform.isMacOS)) {
      await _restoreSystemProxy();
    }
    final process = _process;
    _process = null;
    if (process != null) {
      _writeLog('Stopping sing-box');
      process.kill();
      try {
        await process.exitCode.timeout(const Duration(seconds: 5));
      } catch (_) {
        process.kill(ProcessSignal.sigkill);
      }
    }
    await _logSink?.flush();
    await _logSink?.close();
    _logSink = null;
  }

  @override
  Future<int?> testLatency(
    ProxyNode node, {
    Map<String, Object?>? config,
    ProxyMode mode = ProxyMode.system,
    LatencyTestMode testMode = LatencyTestMode.quick,
  }) async {
    if ((!Platform.isWindows && !Platform.isMacOS) ||
        config == null ||
        !node.isOnline) {
      return null;
    }
    if (!await _coreExe.exists()) {
      await prepare();
    }

    final profile = _latencyProfile(testMode);
    final normalized = _normalizeConfigForMode(config, ProxyMode.system);
    final reservedPorts = <int>{};

    File? file;

    Process? process;
    try {
      await _rebindLocalProxyInbounds(normalized, reservedPorts: reservedPorts);
      final clashApiPort = await _availableTcpPort(
          preferred: 19090, reservedPorts: reservedPorts);
      _ensureClashApi(normalized, port: clashApiPort);
      final proxyCandidates = _delayTestProxyCandidates(normalized);
      if (proxyCandidates.isEmpty) {
        return null;
      }

      await _configDir.create(recursive: true);
      file = File(
          '${_configDir.path}${Platform.pathSeparator}latency-${node.id}-${DateTime.now().millisecondsSinceEpoch}.json');
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(normalized));

      process = await Process.start(
        _coreExe.path,
        ['run', '-c', file.path],
        workingDirectory: runtimeRoot.path,
        runInShell: false,
        environment: _singBoxEnvironment(),
      );
      process.stdout.drain<void>();
      process.stderr.drain<void>();
      final proxies = await _waitForClashApi(
        port: clashApiPort,
        process: process,
        timeout: profile.apiReadyTimeout,
      );
      final proxyNames = _delayTestProxyNames(
        proxies,
        proxyCandidates,
        maxNames: profile.maxProxyCandidates,
      );
      return await _queryFirstProxyDelay(
        port: clashApiPort,
        proxyNames: proxyNames,
        profile: profile,
      );
    } finally {
      process?.kill();
      try {
        await process?.exitCode.timeout(const Duration(seconds: 3));
      } catch (_) {
        process?.kill(ProcessSignal.sigkill);
      }
      try {
        final currentFile = file;
        if (currentFile != null && await currentFile.exists()) {
          await currentFile.delete();
        }
      } catch (_) {}
      _reservedLatencyPorts.removeAll(reservedPorts);
    }
  }

  @override
  Future<Map<int, int?>> testLatencies(
    List<ProxyNode> nodes, {
    Map<String, Object?>? config,
    ProxyMode mode = ProxyMode.system,
    LatencyTestMode testMode = LatencyTestMode.quick,
    int concurrency = 5,
  }) async {
    final results = <int, int?>{
      for (final node in nodes) node.id: null,
    };
    final onlineNodes = nodes.where((node) => node.isOnline).toList();
    if ((!Platform.isWindows && !Platform.isMacOS) ||
        config == null ||
        onlineNodes.isEmpty) {
      return results;
    }
    if (!await _coreExe.exists()) {
      await prepare();
    }

    final profile = _latencyProfile(testMode);
    final normalized = _normalizeConfigForMode(config, ProxyMode.system);
    final reservedPorts = <int>{};

    File? file;
    Process? process;
    try {
      await _rebindLocalProxyInbounds(normalized, reservedPorts: reservedPorts);
      final clashApiPort = await _availableTcpPort(
          preferred: 19090, reservedPorts: reservedPorts);
      _ensureClashApi(normalized, port: clashApiPort);

      await _configDir.create(recursive: true);
      file = File(
          '${_configDir.path}${Platform.pathSeparator}latency-batch-${DateTime.now().millisecondsSinceEpoch}.json');
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(normalized));

      process = await Process.start(
        _coreExe.path,
        ['run', '-c', file.path],
        workingDirectory: runtimeRoot.path,
        runInShell: false,
        environment: _singBoxEnvironment(),
      );
      process.stdout.drain<void>();
      process.stderr.drain<void>();

      final proxies = await _waitForClashApi(
        port: clashApiPort,
        process: process,
        timeout: profile.apiReadyTimeout,
      );
      final limit = concurrency <= 0 ? 1 : concurrency;
      for (var start = 0; start < onlineNodes.length; start += limit) {
        final end = start + limit > onlineNodes.length
            ? onlineNodes.length
            : start + limit;
        final chunk = onlineNodes.sublist(start, end);
        final chunkResults = await Future.wait([
          for (final node in chunk)
            _queryNodeDelay(
              port: clashApiPort,
              proxies: proxies,
              node: node,
              profile: profile,
            ),
        ]);
        for (var index = 0; index < chunk.length; index++) {
          results[chunk[index].id] = chunkResults[index];
        }
      }
      return results;
    } finally {
      process?.kill();
      try {
        await process?.exitCode.timeout(const Duration(seconds: 3));
      } catch (_) {
        process?.kill(ProcessSignal.sigkill);
      }
      try {
        final currentFile = file;
        if (currentFile != null && await currentFile.exists()) {
          await currentFile.delete();
        }
      } catch (_) {}
      _reservedLatencyPorts.removeAll(reservedPorts);
    }
  }

  @override
  Stream<CoreTrafficSample> watchTraffic() async* {
    if (_clashApiPort <= 0) {
      return;
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    var sessionUpload = 0;
    var sessionDownload = 0;
    try {
      final request = await client.getUrl(_clashApiUri('/traffic'));
      final response =
          await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CoreException('Clash API traffic HTTP ${response.statusCode}');
      }
      await for (final line
          in response.transform(utf8.decoder).transform(const LineSplitter())) {
        final raw = line.trim();
        if (raw.isEmpty) {
          continue;
        }
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          continue;
        }
        final up = _intValue(decoded['up']) ?? 0;
        final down = _intValue(decoded['down']) ?? 0;
        sessionUpload += up;
        sessionDownload += down;
        yield CoreTrafficSample(
          uploadBytesPerSecond: up,
          downloadBytesPerSecond: down,
          sessionUploadBytes: sessionUpload,
          sessionDownloadBytes: sessionDownload,
        );
      }
    } catch (error) {
      _writeLog('Traffic stream closed: $error');
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<CoreDiagnostics> diagnostics() async {
    final coreExists = await _coreExe.exists();
    final configExists = await _configFile.exists();
    final logExists = await _logFile.exists();
    final proxyEnable = await _queryRegValue('ProxyEnable');
    final proxyServer = await _queryRegValue('ProxyServer');
    final check =
        await _checkConfig(coreExists: coreExists, configExists: configExists);

    return CoreDiagnostics(
      updatedAt: DateTime.now(),
      runtimeRoot: runtimeRoot.path,
      corePath: _coreExe.path,
      coreExists: coreExists,
      configPath: _configFile.path,
      configExists: configExists,
      logPath: _logFile.path,
      logExists: logExists,
      processRunning: _process != null,
      localProxyType: _localProxyType,
      localProxyListen: _localProxyListen,
      localProxyPort: _localProxyPort,
      clashApiAddress: _clashApiAddress,
      systemProxyEnabled: proxyEnable == '1' || proxyEnable == '0x1',
      systemProxyServer: proxyServer,
      configCheckStatus: check.status,
      configCheckOutput: check.output,
      logTail: await _readLogTail(logExists: logExists),
    );
  }

  Future<_ConfigCheckResult> _checkConfig({
    required bool coreExists,
    required bool configExists,
  }) async {
    if (!Platform.isWindows && !Platform.isMacOS) {
      return const _ConfigCheckResult(
          status: 'skipped', output: '当前平台未接入本地 sing-box 校验');
    }
    if (!coreExists) {
      return const _ConfigCheckResult(
          status: 'missing-core', output: 'sing-box.exe 不存在');
    }
    if (!configExists) {
      return const _ConfigCheckResult(
          status: 'missing-config', output: 'sing-box.json 不存在');
    }

    try {
      final result = await Process.run(
        _coreExe.path,
        ['check', '-c', _configFile.path],
        workingDirectory: runtimeRoot.path,
        environment: _singBoxEnvironment(),
      ).timeout(const Duration(seconds: 12));
      final output = [
        '${result.stdout}'.trim(),
        '${result.stderr}'.trim(),
      ].where((line) => line.isNotEmpty).join('\n');
      return _ConfigCheckResult(
        status: result.exitCode == 0 ? 'ok' : 'failed',
        output: output.isEmpty ? 'exit=${result.exitCode}' : _stripAnsi(output),
      );
    } on TimeoutException {
      return const _ConfigCheckResult(
          status: 'timeout', output: 'sing-box check 超时');
    } catch (error) {
      return _ConfigCheckResult(status: 'error', output: '$error');
    }
  }

  Future<List<String>> _readLogTail({required bool logExists}) async {
    if (!logExists) {
      return const <String>[];
    }
    try {
      final lines = await _logFile.readAsLines();
      final start = lines.length > 120 ? lines.length - 120 : 0;
      return lines.sublist(start).map(_stripAnsi).toList(growable: false);
    } catch (error) {
      return <String>['读取日志失败: $error'];
    }
  }

  String _stripAnsi(String value) {
    return value.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '');
  }

  Future<void> _downloadSingBox() async {
    final asset = await _resolveLatestWindowsAsset();
    final zipFile = File(
        '${runtimeRoot.path}${Platform.pathSeparator}sing-box-windows-amd64.zip');
    _writeLog('Downloading sing-box ${asset.version}');
    await _downloadFile(Uri.parse(asset.url), zipFile);
    final extractDir = Directory(
        '${runtimeRoot.path}${Platform.pathSeparator}sing-box-extract');
    if (await extractDir.exists()) {
      await extractDir.delete(recursive: true);
    }
    await extractDir.create(recursive: true);
    final result = await Process.run(
      'powershell.exe',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        'Expand-Archive -LiteralPath ${_psQuote(zipFile.path)} -DestinationPath ${_psQuote(extractDir.path)} -Force',
      ],
    );
    if (result.exitCode != 0) {
      throw CoreException('解压 sing-box 失败: ${result.stderr}');
    }
    final exe = await _findFile(extractDir, 'sing-box.exe');
    if (exe == null) {
      throw CoreException('sing-box 压缩包中没有找到 sing-box.exe');
    }
    await _coreDir.create(recursive: true);
    await exe.copy(_coreExe.path);
    await extractDir.delete(recursive: true);
    await zipFile.delete();
  }

  Future<_SingBoxAsset> _resolveLatestWindowsAsset() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    final request = await client.getUrl(Uri.parse(
        'https://api.github.com/repos/SagerNet/sing-box/releases/latest'));
    request.headers
        .set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    request.headers.set(HttpHeaders.userAgentHeader, 'KeliClient/0.1.0');
    final response = await request.close();
    final raw = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CoreException('获取 sing-box 最新版本失败: HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw CoreException('GitHub release 响应格式错误');
    }
    final assets = decoded['assets'];
    if (assets is! List) {
      throw CoreException('GitHub release 缺少 assets');
    }
    for (final asset in assets) {
      if (asset is! Map) {
        continue;
      }
      final name = '${asset['name']}';
      if (name.endsWith('windows-amd64.zip') && !name.contains('legacy')) {
        final url = '${asset['browser_download_url']}';
        if (url.startsWith('http')) {
          return _SingBoxAsset(version: '${decoded['tag_name']}', url: url);
        }
      }
    }
    throw CoreException('没有找到 sing-box windows-amd64.zip 发布包');
  }

  Future<void> _downloadFile(Uri uri, File destination) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, 'KeliClient/0.1.0');
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CoreException('下载失败: HTTP ${response.statusCode}');
    }
    await destination.parent.create(recursive: true);
    final sink = destination.openWrite();
    await response.pipe(sink);
  }

  Future<File?> _findFile(Directory root, String fileName) async {
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File &&
          entity.uri.pathSegments.last.toLowerCase() ==
              fileName.toLowerCase()) {
        return entity;
      }
    }
    return null;
  }

  Map<String, Object?> _normalizeConfigForMode(
      Map<String, Object?> config, ProxyMode mode) {
    final normalized = Map<String, Object?>.from(config);
    final rawInbounds = normalized['inbounds'];
    final inbounds =
        rawInbounds is List ? List<Object?>.from(rawInbounds) : <Object?>[];
    normalized['inbounds'] = inbounds;

    if (mode == ProxyMode.system) {
      inbounds.removeWhere(
          (item) => item is Map && '${item['type']}'.toLowerCase() == 'tun');
      if (_detectLocalProxyEndpoint(normalized,
              preferredTypes: const ['mixed', 'http']) ==
          null) {
        final endpoint = _addMixedInbound(normalized);
        _prependRouteRules(normalized, <Map<String, Object?>>[
          <String, Object?>{
            'inbound': endpoint.tag,
            'action': 'resolve',
            'strategy': 'prefer_ipv4'
          },
          <String, Object?>{'inbound': endpoint.tag, 'action': 'sniff'},
        ]);
      }
    }

    _migrateLegacyInboundFields(normalized);
    _migrateLegacySpecialOutbounds(normalized);
    _validateOutboundReferences(normalized);

    return normalized;
  }

  _LocalProxyEndpoint _addMixedInbound(Map<String, Object?> config) {
    final rawInbounds = config['inbounds'];
    final inbounds = rawInbounds is List ? rawInbounds : <Object?>[];
    if (rawInbounds is! List) {
      config['inbounds'] = inbounds;
    }
    final port = _nextLocalPort(inbounds);
    const tag = 'keli-mixed-in';
    inbounds.add(<String, Object?>{
      'type': 'mixed',
      'tag': tag,
      'listen': '127.0.0.1',
      'listen_port': port,
      'users': <Object?>[],
    });
    return _LocalProxyEndpoint(
        type: 'mixed', tag: tag, listen: '127.0.0.1', port: port);
  }

  void _ensureClashApi(Map<String, Object?> config, {required int port}) {
    final rawExperimental = config['experimental'];
    final experimental = rawExperimental is Map
        ? Map<String, Object?>.from(rawExperimental)
        : <String, Object?>{};
    final rawClashApi = experimental['clash_api'];
    final clashApi = rawClashApi is Map
        ? Map<String, Object?>.from(rawClashApi)
        : <String, Object?>{};
    clashApi['external_controller'] = '127.0.0.1:$port';
    clashApi['secret'] = '';
    experimental['clash_api'] = clashApi;
    config['experimental'] = experimental;
  }

  Future<void> _rebindLocalProxyInbounds(
    Map<String, Object?> config, {
    Set<int>? reservedPorts,
  }) async {
    final inbounds = config['inbounds'];
    if (inbounds is! List) {
      return;
    }
    var preferredPort = 22080;
    for (final item in inbounds) {
      if (item is! Map) {
        continue;
      }
      final type = '${item['type']}'.toLowerCase();
      if (type != 'mixed' && type != 'http' && type != 'socks') {
        continue;
      }
      item['listen'] = '127.0.0.1';
      item['listen_port'] = await _availableTcpPort(
        preferred: preferredPort,
        reservedPorts: reservedPorts,
      );
      preferredPort++;
    }
  }

  Future<int> _availableTcpPort({
    required int preferred,
    Set<int>? reservedPorts,
  }) async {
    Future<int?> tryPort(int port) async {
      ServerSocket? socket;
      var reservedPort = 0;
      try {
        if (reservedPorts != null && port > 0) {
          if (_reservedLatencyPorts.contains(port)) {
            return null;
          }
          _reservedLatencyPorts.add(port);
          reservedPorts.add(port);
          reservedPort = port;
        }
        socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, port,
            shared: false);
        final selected = socket.port;
        if (reservedPorts != null && port == 0) {
          if (_reservedLatencyPorts.contains(selected)) {
            await socket.close();
            return null;
          }
          _reservedLatencyPorts.add(selected);
          reservedPorts.add(selected);
          reservedPort = selected;
        }
        await socket.close();
        return selected;
      } catch (_) {
        await socket?.close();
        if (reservedPort > 0) {
          _reservedLatencyPorts.remove(reservedPort);
          reservedPorts?.remove(reservedPort);
        }
        return null;
      }
    }

    if (preferred > 0) {
      final selected = await tryPort(preferred);
      if (selected != null) {
        return selected;
      }
    }

    for (var attempt = 0; attempt < 8; attempt++) {
      final dynamicPort = await tryPort(0);
      if (dynamicPort != null) {
        return dynamicPort;
      }
    }
    throw const CoreException('没有可用的本地 TCP 端口');
  }

  List<String> _delayTestProxyCandidates(Map<String, Object?> config) {
    final outbounds = config['outbounds'];
    if (outbounds is! List) {
      return const [];
    }

    final real = <String>[];
    final groups = <String>[];
    final fallback = <String>[];
    for (final item in outbounds) {
      if (item is! Map) {
        continue;
      }
      final tag = _stringValue(item['tag']);
      if (tag == null || tag.isEmpty) {
        continue;
      }
      final type = '${item['type']}'.toLowerCase();
      if (type == 'direct' || type == 'block' || type == 'dns') {
        continue;
      }
      if (type == 'selector' || type == 'urltest') {
        groups.add(tag);
        continue;
      }
      real.add(tag);
    }
    for (final item in outbounds.whereType<Map>()) {
      final tag = _stringValue(item['tag']);
      if (tag != null && tag.isNotEmpty) {
        fallback.add(tag);
      }
    }
    return <String>{
      ...real,
      ...groups,
      ...fallback,
    }.toList(growable: false);
  }

  int _nextLocalPort(List<Object?> inbounds) {
    final used = <int>{};
    for (final item in inbounds) {
      if (item is! Map) {
        continue;
      }
      final port = _portValue(item['listen_port']);
      if (port != null) {
        used.add(port);
      }
    }
    for (final candidate in const [2334, 20808, 20809, 20810]) {
      if (!used.contains(candidate)) {
        return candidate;
      }
    }
    return 20808;
  }

  _LocalProxyEndpoint? _detectLocalProxyEndpoint(
    Map<String, Object?> config, {
    List<String> preferredTypes = const ['mixed', 'http', 'socks'],
  }) {
    final inbounds = config['inbounds'];
    if (inbounds is! List) {
      return null;
    }
    for (final preferredType in preferredTypes) {
      for (final item in inbounds) {
        if (item is! Map) {
          continue;
        }
        final type = '${item['type']}'.toLowerCase();
        if (type != preferredType) {
          continue;
        }
        final port = _portValue(item['listen_port']);
        if (port != null) {
          return _LocalProxyEndpoint(
            type: type,
            tag: _inboundTag(item, type, inbounds.indexOf(item)),
            listen: _safeProxyHost(item['listen']),
            port: port,
          );
        }
      }
    }
    return null;
  }

  void _migrateLegacyInboundFields(Map<String, Object?> config) {
    final inbounds = config['inbounds'];
    if (inbounds is! List) {
      return;
    }

    final routeRules = <Map<String, Object?>>[];
    for (var index = 0; index < inbounds.length; index++) {
      final item = inbounds[index];
      if (item is! Map) {
        continue;
      }
      final inbound = Map<String, Object?>.from(item);
      inbounds[index] = inbound;
      final type = '${inbound['type']}'.toLowerCase();
      final tag = _inboundTag(inbound, type, index);
      inbound['tag'] = tag;

      final strategy = _stringValue(inbound.remove('domain_strategy'));
      final sniff = _boolValue(inbound.remove('sniff'));
      final sniffTimeout = _stringValue(inbound.remove('sniff_timeout'));
      inbound.remove('sniff_override_destination');

      if (strategy != null && strategy.isNotEmpty) {
        routeRules.add(<String, Object?>{
          'inbound': tag,
          'action': 'resolve',
          'strategy': strategy,
        });
      }
      if (sniff) {
        routeRules.add(<String, Object?>{
          'inbound': tag,
          'action': 'sniff',
          if (sniffTimeout != null && sniffTimeout.isNotEmpty)
            'timeout': sniffTimeout,
        });
      }
    }

    if (routeRules.isNotEmpty) {
      _prependRouteRules(config, routeRules);
    }
  }

  void _migrateLegacySpecialOutbounds(Map<String, Object?> config) {
    final outbounds = config['outbounds'];
    if (outbounds is! List) {
      return;
    }

    final removedActions = <String, String>{};
    final kept = <Object?>[];
    for (final item in outbounds) {
      if (item is! Map) {
        kept.add(item);
        continue;
      }
      final outbound = Map<String, Object?>.from(item);
      final type = '${outbound['type']}'.toLowerCase();
      final tag = _stringValue(outbound['tag']);
      if (tag != null && type == 'dns') {
        removedActions[tag] = 'hijack-dns';
        continue;
      }
      if (tag != null && type == 'block') {
        removedActions[tag] = 'reject';
        continue;
      }
      kept.add(outbound);
    }
    config['outbounds'] = kept;

    if (removedActions.isEmpty) {
      return;
    }

    for (final item in kept) {
      if (item is Map) {
        _removeOutboundChildren(item, removedActions.keys.toSet());
      }
    }
    _rewriteRemovedOutboundRules(config, removedActions);
  }

  void _removeOutboundChildren(Map outbound, Set<String> removedTags) {
    final children = outbound['outbounds'];
    if (children is! List) {
      return;
    }
    outbound['outbounds'] =
        children.where((item) => !removedTags.contains('$item')).toList();
  }

  void _rewriteRemovedOutboundRules(
      Map<String, Object?> config, Map<String, String> removedActions) {
    final route = _ensureRoute(config);
    final rules = route['rules'];
    if (rules is! List) {
      return;
    }
    for (var index = 0; index < rules.length; index++) {
      final item = rules[index];
      if (item is! Map) {
        continue;
      }
      final rule = Map<String, Object?>.from(item);
      final outbound = _stringValue(rule['outbound']);
      final action = outbound == null ? null : removedActions[outbound];
      if (action != null) {
        rule.remove('outbound');
        rule['action'] = action;
        rules[index] = rule;
      }
    }
  }

  void _prependRouteRules(
      Map<String, Object?> config, List<Map<String, Object?>> newRules) {
    if (newRules.isEmpty) {
      return;
    }
    final route = _ensureRoute(config);
    final existing = route['rules'];
    route['rules'] = <Object?>[
      ...newRules,
      if (existing is List) ...existing,
    ];
  }

  Map<String, Object?> _ensureRoute(Map<String, Object?> config) {
    final current = config['route'];
    if (current is Map) {
      final route = Map<String, Object?>.from(current);
      config['route'] = route;
      return route;
    }
    final route = <String, Object?>{};
    config['route'] = route;
    return route;
  }

  void _validateOutboundReferences(Map<String, Object?> config) {
    final outbounds = config['outbounds'];
    if (outbounds is! List) {
      throw const CoreException('sing-box 配置缺少 outbounds');
    }
    final tags = outbounds
        .whereType<Map>()
        .map((item) => _stringValue(item['tag']))
        .whereType<String>()
        .toSet();
    final missing = <String>{};
    final emptyGroups = <String>[];

    for (final item in outbounds.whereType<Map>()) {
      final type = '${item['type']}'.toLowerCase();
      if (type != 'selector' && type != 'urltest') {
        continue;
      }
      final tag = _stringValue(item['tag']) ?? type;
      final children = item['outbounds'];
      if (children is! List || children.isEmpty) {
        emptyGroups.add(tag);
        continue;
      }
      for (final child in children) {
        final childTag = '$child';
        if (!tags.contains(childTag)) {
          missing.add(childTag);
        }
      }
    }

    if (emptyGroups.isNotEmpty || missing.isNotEmpty) {
      throw CoreException(
        '服务端返回的 sing-box 配置缺少真实节点出站，请更新面板端 /app/config。'
        '空出站组: ${emptyGroups.join(', ')}; 缺失标签: ${missing.join(', ')}',
      );
    }
  }

  int? _portValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  String _safeProxyHost(Object? listen) {
    final value = listen == null ? '' : '$listen'.trim();
    if (value.isEmpty ||
        value == '::' ||
        value == '0.0.0.0' ||
        value == '[::]') {
      return '127.0.0.1';
    }
    return value;
  }

  String? get _clashApiAddress =>
      _clashApiPort <= 0 ? null : '$_clashApiListen:$_clashApiPort';

  Uri _clashApiUri(String path,
      {int? port, Map<String, String>? queryParameters}) {
    return Uri(
      scheme: 'http',
      host: _clashApiListen,
      port: port ?? _clashApiPort,
      path: path,
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, Object?>> _waitForClashApi({
    required int port,
    Process? process,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      try {
        final decoded = await _getJson(_clashApiUri('/proxies', port: port),
            timeout: const Duration(seconds: 2));
        final proxies = _extractClashProxies(decoded);
        if (proxies.isNotEmpty) {
          return proxies;
        }
        lastError = '代理列表为空';
      } catch (error) {
        lastError = error;
      }
      if (process != null) {
        final exitCode = await process.exitCode.timeout(
          const Duration(milliseconds: 1),
          onTimeout: () => -999999,
        );
        if (exitCode != -999999) {
          throw CoreException('sing-box 测速进程已退出，退出码 $exitCode');
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
    throw CoreException('Clash API 未就绪: $lastError');
  }

  List<String> _delayTestProxyNames(
    Map<String, Object?> proxies,
    List<String> candidates, {
    int? maxNames,
  }) {
    final names = <String>[];
    for (final candidate in candidates) {
      if (proxies.containsKey(candidate)) {
        names.add(candidate);
      }
    }

    for (final entry in proxies.entries) {
      if (names.contains(entry.key)) {
        continue;
      }
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      final type = '${value['type']}'.toLowerCase();
      if (type == 'direct' ||
          type == 'reject' ||
          type == 'selector' ||
          type == 'urltest') {
        continue;
      }
      names.add(entry.key);
    }

    if (names.isEmpty) {
      names.addAll(proxies.keys);
    }
    final selected = maxNames == null || names.length <= maxNames
        ? names
        : names.take(maxNames);
    return selected.toList(growable: false);
  }

  Map<String, Object?> _extractClashProxies(Object? decoded) {
    if (decoded is Map) {
      final proxies = decoded['proxies'];
      if (proxies is Map) {
        return Map<String, Object?>.from(proxies);
      }
      return Map<String, Object?>.from(decoded);
    }
    return <String, Object?>{};
  }

  _LatencyTestProfile _latencyProfile(LatencyTestMode mode) {
    return switch (mode) {
      LatencyTestMode.quick => const _LatencyTestProfile(
          apiReadyTimeout: Duration(seconds: 4),
          requestTimeout: Duration(milliseconds: 2200),
          delayTimeoutMs: 1600,
          maxProxyCandidates: 2,
          urls: <String>[
            'https://cp.cloudflare.com/generate_204',
            'http://www.gstatic.com/generate_204',
          ],
        ),
      LatencyTestMode.retry => const _LatencyTestProfile(
          apiReadyTimeout: Duration(seconds: 8),
          requestTimeout: Duration(milliseconds: 5500),
          delayTimeoutMs: 4000,
          maxProxyCandidates: 4,
          urls: <String>[
            'https://cp.cloudflare.com/generate_204',
            'http://www.gstatic.com/generate_204',
            'http://www.msftconnecttest.com/connecttest.txt',
            'http://detectportal.firefox.com/success.txt',
          ],
        ),
    };
  }

  Future<int?> _queryFirstProxyDelay({
    required int port,
    required List<String> proxyNames,
    required _LatencyTestProfile profile,
  }) async {
    Object? lastError;
    Object? proxyMissingError;
    var onlyReachabilityFailures = true;
    for (final proxyName in proxyNames) {
      try {
        final latency = await _queryProxyDelay(
          port: port,
          proxyName: proxyName,
          profile: profile,
        );
        if (latency != null) {
          return latency;
        }
        lastError = '代理 $proxyName 未返回 delay';
      } catch (error) {
        lastError = error;
        final message = '$error';
        if (_isDelayRetryableFailure(message)) {
          continue;
        }
        if (message.contains('HTTP 404')) {
          proxyMissingError = error;
          continue;
        }
        onlyReachabilityFailures = false;
        rethrow;
      }
    }
    if (proxyMissingError != null) {
      throw CoreException('$proxyMissingError');
    }
    if (onlyReachabilityFailures && lastError != null) {
      throw CoreException('节点超时: $lastError');
    }
    if (lastError != null) {
      throw CoreException('$lastError');
    }
    return null;
  }

  Future<int?> _queryNodeDelay({
    required int port,
    required Map<String, Object?> proxies,
    required ProxyNode node,
    required _LatencyTestProfile profile,
  }) async {
    final proxyNames = <String>[];
    void addCandidate(String? value) {
      final name = value?.trim();
      if (name == null || name.isEmpty || proxyNames.contains(name)) {
        return;
      }
      if (proxies.containsKey(name)) {
        proxyNames.add(name);
      }
    }

    addCandidate(node.name);
    for (final tag in node.tags) {
      addCandidate(tag);
    }

    if (proxyNames.isEmpty) {
      return null;
    }

    try {
      return await _queryFirstProxyDelay(
        port: port,
        proxyNames: proxyNames,
        profile: profile,
      );
    } catch (_) {
      return null;
    }
  }

  Future<int?> _queryProxyDelay({
    required int port,
    required String proxyName,
    required _LatencyTestProfile profile,
  }) async {
    final completer = Completer<int?>();
    var pending = profile.urls.length;
    Object? lastError;

    void finishOne({int? delay, Object? error}) {
      if (completer.isCompleted) {
        return;
      }
      if (delay != null) {
        completer.complete(delay);
        return;
      }
      if (error != null) {
        lastError = error;
      }
      pending--;
      if (pending <= 0) {
        if (lastError != null) {
          completer.completeError(CoreException('$lastError'));
        } else {
          completer.complete(null);
        }
      }
    }

    for (final testUrl in profile.urls) {
      final uri = Uri(
        scheme: 'http',
        host: _clashApiListen,
        port: port,
        pathSegments: <String>['proxies', proxyName, 'delay'],
        queryParameters: <String, String>{
          'url': testUrl,
          'timeout': '${profile.delayTimeoutMs}',
        },
      );
      unawaited((() async {
        final decoded = await _getJson(uri, timeout: profile.requestTimeout);
        if (decoded is Map) {
          final delay = _intValue(decoded['delay']);
          if (delay != null) {
            finishOne(delay: delay);
            return;
          }
          finishOne(error: '代理 $proxyName 使用 $testUrl 未返回 delay');
          return;
        }
        finishOne(error: '代理 $proxyName 使用 $testUrl 返回非 JSON 对象');
      })()
          .catchError((Object error) {
        if (!completer.isCompleted && !_isDelayRetryableFailure('$error')) {
          completer.completeError(error);
          return;
        }
        finishOne(error: error);
      }));
    }

    return completer.future.timeout(
      profile.requestTimeout + const Duration(milliseconds: 350),
      onTimeout: () => null,
    );
  }

  bool _isDelayRetryableFailure(String message) {
    return message.contains('HTTP 408') ||
        message.contains('HTTP 504') ||
        message.contains('TimeoutException') ||
        message.contains('Timeout') ||
        message.contains('Connection closed') ||
        message.contains('Connection reset') ||
        message.contains('Connection refused');
  }

  Future<Object?> _getJson(Uri uri, {required Duration timeout}) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      final raw =
          await response.transform(utf8.decoder).join().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CoreException('HTTP ${response.statusCode}: $raw');
      }
      if (raw.trim().isEmpty) {
        return <String, Object?>{};
      }
      return jsonDecode(raw);
    } finally {
      client.close(force: true);
    }
  }

  String _inboundTag(Map inbound, String type, int index) {
    final tag = _stringValue(inbound['tag']);
    if (tag != null && tag.isNotEmpty) {
      return tag;
    }
    return 'keli-$type-in-$index';
  }

  String? _stringValue(Object? value) => value == null ? null : '$value';

  int? _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return num.tryParse(value)?.toInt();
    }
    return null;
  }

  bool _boolValue(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }

  Map<String, String> _singBoxEnvironment() {
    return <String, String>{
      'ENABLE_DEPRECATED_LEGACY_DNS_SERVERS': 'true',
      'ENABLE_DEPRECATED_OUTBOUND_DNS_RULE_ITEM': 'true',
      'ENABLE_DEPRECATED_MISSING_DOMAIN_RESOLVER': 'true',
    };
  }

  Future<void> _ensureProcessStarted(Process process) async {
    const running = -999999;
    final exitCode = await process.exitCode.timeout(
      const Duration(milliseconds: 1400),
      onTimeout: () => running,
    );
    if (exitCode == running) {
      return;
    }
    _process = null;
    await _logSink?.flush();
    throw CoreException('sing-box 启动失败，退出码 $exitCode，请查看日志: ${_logFile.path}');
  }

  Future<void> _enableSystemProxy() async {
    await _saveCurrentProxyState();
    final proxy = _localProxyType == 'socks'
        ? 'socks=$_localProxyListen:$_localProxyPort'
        : '$_localProxyListen:$_localProxyPort';
    await _runReg([
      'add',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
      '/v',
      'ProxyEnable',
      '/t',
      'REG_DWORD',
      '/d',
      '1',
      '/f'
    ]);
    await _runReg([
      'add',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
      '/v',
      'ProxyServer',
      '/t',
      'REG_SZ',
      '/d',
      proxy,
      '/f'
    ]);
    await _notifyProxyChanged();
    _writeLog('System proxy enabled: $proxy');
  }

  Future<void> _saveCurrentProxyState() async {
    if (await _proxyStateFile.exists()) {
      return;
    }
    final enable = await _queryRegValue('ProxyEnable');
    final server = await _queryRegValue('ProxyServer');
    const encoder = JsonEncoder.withIndent('  ');
    await _proxyStateFile.parent.create(recursive: true);
    await _proxyStateFile.writeAsString(encoder.convert(<String, Object?>{
      'proxy_enable': enable,
      'proxy_server': server,
    }));
  }

  Future<void> _restoreSystemProxy() async {
    if (!await _proxyStateFile.exists()) {
      return;
    }
    try {
      final raw = await _proxyStateFile.readAsString();
      final state = jsonDecode(raw);
      if (state is Map) {
        final enable = state['proxy_enable'];
        final server = state['proxy_server'];
        if (enable == null || '$enable'.isEmpty) {
          await _runReg([
            'delete',
            r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
            '/v',
            'ProxyEnable',
            '/f'
          ], allowFailure: true);
        } else {
          await _runReg([
            'add',
            r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
            '/v',
            'ProxyEnable',
            '/t',
            'REG_DWORD',
            '/d',
            '$enable',
            '/f'
          ]);
        }
        if (server == null || '$server'.isEmpty) {
          await _runReg([
            'delete',
            r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
            '/v',
            'ProxyServer',
            '/f'
          ], allowFailure: true);
        } else {
          await _runReg([
            'add',
            r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
            '/v',
            'ProxyServer',
            '/t',
            'REG_SZ',
            '/d',
            '$server',
            '/f'
          ]);
        }
        await _notifyProxyChanged();
      }
    } finally {
      await _proxyStateFile.delete();
    }
  }

  Future<String?> _queryRegValue(String name) async {
    final result = await Process.run('reg.exe', [
      'query',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
      '/v',
      name
    ]);
    if (result.exitCode != 0) {
      return null;
    }
    final output = '${result.stdout}';
    final line = output.split(RegExp(r'\r?\n')).firstWhere(
          (item) => item.contains(name),
          orElse: () => '',
        );
    final parts = line.trim().split(RegExp(r'\s{2,}'));
    if (parts.length >= 3) {
      return parts.last.trim();
    }
    return null;
  }

  Future<void> _runReg(List<String> args, {bool allowFailure = false}) async {
    final result = await Process.run('reg.exe', args);
    if (result.exitCode != 0 && !allowFailure) {
      throw CoreException('修改系统代理失败: ${result.stderr}');
    }
  }

  Future<void> _notifyProxyChanged() async {
    final script = r'''
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class NativeMethods {
  [DllImport("wininet.dll", SetLastError=true)]
  public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
}
"@
[NativeMethods]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
[NativeMethods]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null
''';
    await Process.run('powershell.exe',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script]);
  }

  void _writeLog(String message) {
    if (message.trim().isEmpty) {
      return;
    }
    final line = '[${DateTime.now().toIso8601String()}] $message';
    _logSink?.writeln(line);
  }

  String _psQuote(String value) => "'${value.replaceAll("'", "''")}'";
}

class MacOSCoreManager extends WindowsCoreManager {
  MacOSCoreManager({super.runtimeRoot});

  @override
  File get _coreExe =>
      File('${_coreDir.path}${Platform.pathSeparator}sing-box');

  @override
  Future<void> _downloadSingBox() async {
    final asset = await _resolveLatestMacOSAsset();
    final archiveFile =
        File('${runtimeRoot.path}${Platform.pathSeparator}sing-box-macos.tgz');
    _writeLog('Downloading sing-box ${asset.version} for macOS');
    await _downloadFile(Uri.parse(asset.url), archiveFile);
    final extractDir = Directory(
        '${runtimeRoot.path}${Platform.pathSeparator}sing-box-extract');
    if (await extractDir.exists()) {
      await extractDir.delete(recursive: true);
    }
    await extractDir.create(recursive: true);
    final result = await Process.run(
      'tar',
      ['-xzf', archiveFile.path, '-C', extractDir.path],
    );
    if (result.exitCode != 0) {
      throw CoreException('解压 sing-box 失败: ${result.stderr}');
    }
    final binary = await _findFile(extractDir, 'sing-box');
    if (binary == null) {
      throw const CoreException('sing-box 压缩包中没有找到 sing-box');
    }
    await _coreDir.create(recursive: true);
    await binary.copy(_coreExe.path);
    await Process.run('chmod', ['+x', _coreExe.path]);
    await extractDir.delete(recursive: true);
    await archiveFile.delete();
  }

  Future<_SingBoxAsset> _resolveLatestMacOSAsset() async {
    final arch = _macOSAssetArch();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    final request = await client.getUrl(Uri.parse(
        'https://api.github.com/repos/SagerNet/sing-box/releases/latest'));
    request.headers
        .set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    request.headers.set(HttpHeaders.userAgentHeader, 'KeliClient/0.1.0');
    final response = await request.close();
    final raw = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CoreException('获取 sing-box 最新版本失败: HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const CoreException('GitHub release 响应格式错误');
    }
    final assets = decoded['assets'];
    if (assets is! List) {
      throw const CoreException('GitHub release 缺少 assets');
    }

    _SingBoxAsset? legacyFallback;
    for (final asset in assets) {
      if (asset is! Map) {
        continue;
      }
      final name = '${asset['name']}';
      final url = '${asset['browser_download_url']}';
      if (!url.startsWith('http')) {
        continue;
      }
      if (name.endsWith('darwin-$arch.tar.gz') && !name.contains('legacy')) {
        return _SingBoxAsset(version: '${decoded['tag_name']}', url: url);
      }
      if (arch == 'amd64' &&
          name.contains('darwin-amd64-legacy') &&
          name.endsWith('.tar.gz')) {
        legacyFallback =
            _SingBoxAsset(version: '${decoded['tag_name']}', url: url);
      }
    }

    if (legacyFallback != null) {
      return legacyFallback;
    }
    throw CoreException('没有找到 sing-box darwin-$arch.tar.gz 发布包');
  }

  String _macOSAssetArch() {
    return switch (Abi.current()) {
      Abi.macosArm64 => 'arm64',
      Abi.macosX64 => 'amd64',
      _ => 'amd64',
    };
  }

  @override
  Future<void> _enableSystemProxy() async {
    final services = await _macOSNetworkServices();
    if (services.isEmpty) {
      throw const CoreException('没有找到 macOS 网络服务，无法设置系统代理');
    }
    await _saveMacOSProxyState(services);
    for (final service in services) {
      await _setMacOSProxy(service, 'web', enabled: true);
      await _setMacOSProxy(service, 'secureWeb', enabled: true);
      await _setMacOSProxy(service, 'socks', enabled: true);
    }
    _writeLog(
        'macOS system proxy enabled: $_localProxyListen:$_localProxyPort');
  }

  @override
  Future<void> _restoreSystemProxy() async {
    if (!await _proxyStateFile.exists()) {
      return;
    }
    try {
      final raw = await _proxyStateFile.readAsString();
      final state = jsonDecode(raw);
      if (state is! Map || state['services'] is! List) {
        return;
      }
      for (final item in (state['services'] as List)) {
        if (item is! Map) {
          continue;
        }
        final service = _stringValue(item['name']);
        if (service == null || service.isEmpty) {
          continue;
        }
        await _restoreMacOSProxy(service, 'web', item['web']);
        await _restoreMacOSProxy(service, 'secureWeb', item['secure_web']);
        await _restoreMacOSProxy(service, 'socks', item['socks']);
      }
    } finally {
      await _proxyStateFile.delete();
    }
  }

  Future<void> _saveMacOSProxyState(List<String> services) async {
    if (await _proxyStateFile.exists()) {
      return;
    }
    final states = <Map<String, Object?>>[];
    for (final service in services) {
      states.add(<String, Object?>{
        'name': service,
        'web': (await _getMacOSProxyState(service, 'web')).toJson(),
        'secure_web':
            (await _getMacOSProxyState(service, 'secureWeb')).toJson(),
        'socks': (await _getMacOSProxyState(service, 'socks')).toJson(),
      });
    }
    const encoder = JsonEncoder.withIndent('  ');
    await _proxyStateFile.parent.create(recursive: true);
    await _proxyStateFile.writeAsString(
      encoder.convert(<String, Object?>{'services': states}),
    );
  }

  Future<List<String>> _macOSNetworkServices() async {
    final result =
        await Process.run('networksetup', ['-listallnetworkservices']);
    if (result.exitCode != 0) {
      throw CoreException('读取 macOS 网络服务失败: ${result.stderr}');
    }
    return '${result.stdout}'
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) =>
            line.isNotEmpty &&
            !line.startsWith('An asterisk') &&
            !line.startsWith('*'))
        .toList(growable: false);
  }

  Future<_MacOSProxyState> _getMacOSProxyState(
      String service, String kind) async {
    final command = switch (kind) {
      'web' => '-getwebproxy',
      'secureWeb' => '-getsecurewebproxy',
      'socks' => '-getsocksfirewallproxy',
      _ => throw ArgumentError.value(kind, 'kind'),
    };
    final result = await Process.run('networksetup', [command, service]);
    if (result.exitCode != 0) {
      return const _MacOSProxyState(enabled: false);
    }
    bool enabled = false;
    String? server;
    int? port;
    for (final line in '${result.stdout}'.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.startsWith('Enabled:')) {
        final value = trimmed.substring('Enabled:'.length).trim().toLowerCase();
        enabled = value == 'yes' || value == '1' || value == 'on';
      } else if (trimmed.startsWith('Server:')) {
        server = trimmed.substring('Server:'.length).trim();
      } else if (trimmed.startsWith('Port:')) {
        port = int.tryParse(trimmed.substring('Port:'.length).trim());
      }
    }
    return _MacOSProxyState(enabled: enabled, server: server, port: port);
  }

  Future<void> _setMacOSProxy(
    String service,
    String kind, {
    required bool enabled,
  }) async {
    final setCommand = switch (kind) {
      'web' => '-setwebproxy',
      'secureWeb' => '-setsecurewebproxy',
      'socks' => '-setsocksfirewallproxy',
      _ => throw ArgumentError.value(kind, 'kind'),
    };
    if (enabled) {
      await _runNetworkSetup(
        [setCommand, service, _localProxyListen, '$_localProxyPort'],
      );
    }
    await _setMacOSProxyState(service, kind, enabled: enabled);
  }

  Future<void> _restoreMacOSProxy(
      String service, String kind, Object? rawState) async {
    final state = _MacOSProxyState.fromJson(rawState);
    if (state.enabled && state.server != null && state.port != null) {
      await _setMacOSProxyValue(
        service,
        kind,
        server: state.server!,
        port: state.port!,
      );
      await _setMacOSProxyState(service, kind, enabled: true);
    } else {
      await _setMacOSProxyState(service, kind, enabled: false);
    }
  }

  Future<void> _setMacOSProxyValue(
    String service,
    String kind, {
    required String server,
    required int port,
  }) async {
    final setCommand = switch (kind) {
      'web' => '-setwebproxy',
      'secureWeb' => '-setsecurewebproxy',
      'socks' => '-setsocksfirewallproxy',
      _ => throw ArgumentError.value(kind, 'kind'),
    };
    await _runNetworkSetup([setCommand, service, server, '$port']);
  }

  Future<void> _setMacOSProxyState(
    String service,
    String kind, {
    required bool enabled,
  }) async {
    final stateCommand = switch (kind) {
      'web' => '-setwebproxystate',
      'secureWeb' => '-setsecurewebproxystate',
      'socks' => '-setsocksfirewallproxystate',
      _ => throw ArgumentError.value(kind, 'kind'),
    };
    await _runNetworkSetup([stateCommand, service, enabled ? 'on' : 'off']);
  }

  Future<void> _runNetworkSetup(List<String> args) async {
    final result = await Process.run('networksetup', args);
    if (result.exitCode != 0) {
      throw CoreException('修改 macOS 系统代理失败: ${result.stderr}');
    }
  }

  @override
  Future<String?> _queryRegValue(String name) async {
    final services = await _macOSNetworkServices();
    if (services.isEmpty) {
      return null;
    }
    final states = <String>[];
    var anyEnabled = false;
    for (final service in services) {
      for (final kind in const ['web', 'secureWeb', 'socks']) {
        final state = await _getMacOSProxyState(service, kind);
        if (state.enabled) {
          anyEnabled = true;
          if (state.server != null && state.port != null) {
            states.add('$service ${kind == 'secureWeb' ? 'https' : kind} '
                '${state.server}:${state.port}');
          }
        }
      }
    }
    if (name == 'ProxyEnable') {
      return anyEnabled ? '1' : '0';
    }
    if (name == 'ProxyServer') {
      return states.isEmpty ? null : states.join('; ');
    }
    return null;
  }

  @override
  Future<void> _notifyProxyChanged() async {}
}

class _MacOSProxyState {
  const _MacOSProxyState({
    required this.enabled,
    this.server,
    this.port,
  });

  final bool enabled;
  final String? server;
  final int? port;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'enabled': enabled,
      if (server != null) 'server': server,
      if (port != null) 'port': port,
    };
  }

  static _MacOSProxyState fromJson(Object? raw) {
    if (raw is! Map) {
      return const _MacOSProxyState(enabled: false);
    }
    return _MacOSProxyState(
      enabled: raw['enabled'] == true,
      server: raw['server'] == null ? null : '${raw['server']}',
      port: raw['port'] is int
          ? raw['port'] as int
          : int.tryParse('${raw['port']}'),
    );
  }
}

class CoreException implements Exception {
  const CoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _LatencyTestProfile {
  const _LatencyTestProfile({
    required this.apiReadyTimeout,
    required this.requestTimeout,
    required this.delayTimeoutMs,
    required this.maxProxyCandidates,
    required this.urls,
  });

  final Duration apiReadyTimeout;
  final Duration requestTimeout;
  final int delayTimeoutMs;
  final int maxProxyCandidates;
  final List<String> urls;
}

class _SingBoxAsset {
  const _SingBoxAsset({
    required this.version,
    required this.url,
  });

  final String version;
  final String url;
}

class _ConfigCheckResult {
  const _ConfigCheckResult({
    required this.status,
    required this.output,
  });

  final String status;
  final String output;
}

class _LocalProxyEndpoint {
  const _LocalProxyEndpoint({
    required this.type,
    required this.tag,
    required this.listen,
    required this.port,
  });

  final String type;
  final String tag;
  final String listen;
  final int port;
}
