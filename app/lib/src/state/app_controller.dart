import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/core_manager.dart';
import '../services/keli_api.dart';
import '../services/session_store.dart';

class AppController extends ChangeNotifier {
  AppController({
    required this.api,
    required this.coreManager,
    required this.sessionStore,
  });

  final KeliApi api;
  final CoreManager coreManager;
  final SessionStore sessionStore;

  bool isBootstrapping = true;
  bool isAuthenticated = false;
  bool isLoggingIn = false;
  String? lastError;
  ApiSession? session;
  AppProfile? profile;
  CoreDiagnostics? diagnostics;
  bool isRefreshingDiagnostics = false;
  List<ProxyNode> nodes = const [];
  int selectedNodeId = 49;
  int selectedPage = 0;
  NodeFilter nodeFilter = NodeFilter.all;
  ProxyMode proxyMode = ProxyMode.system;
  ConnectionStateKind connectionState = ConnectionStateKind.disconnected;
  RuntimeStats stats = const RuntimeStats(
    uploadSpeed: '0 KB/s',
    downloadSpeed: '0 KB/s',
    duration: Duration.zero,
  );
  final List<LogEntry> logs = <LogEntry>[
    LogEntry(time: DateTime(2026, 4, 29, 19, 20), level: 'INFO', message: '客户端已启动'),
  ];

  ProxyNode? get selectedNode {
    for (final node in nodes) {
      if (node.id == selectedNodeId) {
        return node;
      }
    }
    return nodes.isEmpty ? null : nodes.first;
  }

  List<ProxyNode> get filteredNodes {
    return switch (nodeFilter) {
      NodeFilter.all => nodes,
      NodeFilter.lowLatency => nodes.where((node) => (node.latencyMs ?? 99999) < 300).toList(),
      NodeFilter.favorite => nodes.where((node) => node.isFavorite).toList(),
      NodeFilter.hysteria2 => nodes.where((node) => node.protocol == 'Hysteria2').toList(),
      NodeFilter.vless => nodes.where((node) => node.protocol == 'VLESS').toList(),
    };
  }

  Future<void> bootstrap() async {
    isBootstrapping = true;
    lastError = null;
    notifyListeners();
    try {
      final payload = await api.bootstrap();
      profile = payload.profile;
      nodes = payload.nodes;
      if (nodes.isNotEmpty) {
        selectedNodeId = nodes.first.id;
      }
      _log('INFO', '已加载用户和节点数据，节点 ${nodes.length} 个');
      if (nodes.isEmpty) {
        _log('WARN', '节点列表为空，请确认账号套餐有效且面板已分配可用节点');
      }
      unawaited(refreshDiagnostics(logResult: false));
    } catch (error) {
      lastError = '$error';
      _log('ERROR', '启动数据加载失败: $error');
    } finally {
      isBootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    isBootstrapping = true;
    notifyListeners();
    session = await sessionStore.load();
    if (api is RealKeliApi) {
      (api as RealKeliApi).session = session;
    }
    if (session == null) {
      isAuthenticated = false;
      isBootstrapping = false;
      notifyListeners();
      return;
    }
    isAuthenticated = true;
    await bootstrap();
  }

  Future<void> login({
    required String baseUrl,
    required String apiPrefix,
    required String email,
    required String password,
  }) async {
    isLoggingIn = true;
    lastError = null;
    notifyListeners();
    try {
      final result = await api.login(
        baseUrl: baseUrl,
        apiPrefix: apiPrefix,
        email: email,
        password: password,
      );
      session = result.session;
      await sessionStore.save(result.session);
      isAuthenticated = true;
      _log('INFO', '登录成功');
      await bootstrap();
    } catch (error) {
      lastError = '$error';
      _log('ERROR', '登录失败: $error');
    } finally {
      isLoggingIn = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await disconnect();
    await sessionStore.clear();
    if (api is RealKeliApi) {
      (api as RealKeliApi).session = null;
    }
    session = null;
    isAuthenticated = false;
    profile = null;
    diagnostics = null;
    nodes = const [];
    selectedPage = 0;
    _log('INFO', '已退出登录');
    notifyListeners();
  }

  void selectPage(int page) {
    selectedPage = page;
    notifyListeners();
  }

  void selectFilter(NodeFilter filter) {
    nodeFilter = filter;
    notifyListeners();
  }

  void selectMode(ProxyMode mode) {
    proxyMode = mode;
    _log('INFO', '代理模式切换为 ${mode.label}');
    notifyListeners();
  }

  Future<void> selectNode(ProxyNode node) async {
    selectedNodeId = node.id;
    _log('INFO', '已选择节点 ${node.name}');
    notifyListeners();

    if (connectionState == ConnectionStateKind.connected) {
      await connect();
    }
  }

  void toggleFavorite(ProxyNode node) {
    nodes = nodes
        .map((item) => item.id == node.id ? item.copyWith(isFavorite: !item.isFavorite) : item)
        .toList();
    notifyListeners();
  }

  Future<void> connect() async {
    final node = selectedNode;
    if (node == null) {
      return;
    }
    connectionState = ConnectionStateKind.connecting;
    _log('INFO', '正在连接 ${node.name}');
    notifyListeners();

    try {
      final config = await api.fetchSingBoxConfig(
        serverId: node.id,
        platform: proxyMode == ProxyMode.vpn ? 'android' : 'windows',
        coreVersion: '1.13.11',
      );
      await coreManager.prepare();
      final applied = await coreManager.applyConfig(config, mode: proxyMode);
      _log('INFO', '配置已写入 ${applied.configFile.path}');
      _log('INFO', '本地代理 ${applied.localProxyType}:${applied.localProxyPort}');
      await coreManager.connect(node: node, mode: proxyMode);
      connectionState = ConnectionStateKind.connected;
      stats = const RuntimeStats(
        uploadSpeed: '42 KB/s',
        downloadSpeed: '1.8 MB/s',
        duration: Duration(minutes: 3, seconds: 18),
      );
      _log('INFO', '连接成功: ${node.name}');
    } catch (error) {
      connectionState = ConnectionStateKind.error;
      _log('ERROR', '连接失败: $error');
    } finally {
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    connectionState = ConnectionStateKind.connecting;
    _log('INFO', '正在断开连接');
    notifyListeners();
    await coreManager.disconnect();
    connectionState = ConnectionStateKind.disconnected;
    stats = const RuntimeStats(
      uploadSpeed: '0 KB/s',
      downloadSpeed: '0 KB/s',
      duration: Duration.zero,
    );
    _log('INFO', '连接已断开');
    unawaited(refreshDiagnostics(logResult: false));
    notifyListeners();
  }

  Future<void> testAllLatency() async {
    _log('INFO', '开始测试节点延迟');
    final updated = <ProxyNode>[];
    for (final node in nodes) {
      final latency = await coreManager.testLatency(node);
      updated.add(node.copyWith(latencyMs: latency));
    }
    nodes = updated;
    _log('INFO', '延迟测试完成');
    notifyListeners();
  }

  Future<void> refreshDiagnostics({bool logResult = true}) async {
    isRefreshingDiagnostics = true;
    notifyListeners();
    try {
      diagnostics = await coreManager.diagnostics();
      if (logResult) {
        _log('INFO', '诊断信息已刷新');
      }
    } catch (error) {
      if (logResult) {
        _log('ERROR', '刷新诊断失败: $error');
      }
    } finally {
      isRefreshingDiagnostics = false;
      notifyListeners();
    }
  }

  String diagnosticReport() {
    final diagnostic = diagnostics;
    final buffer = StringBuffer()
      ..writeln('Keli Client Diagnostic')
      ..writeln('time: ${DateTime.now().toIso8601String()}')
      ..writeln('base_url: ${session?.baseUrl ?? '-'}')
      ..writeln('api_prefix: ${session?.apiPrefix ?? '-'}')
      ..writeln('authenticated: $isAuthenticated')
      ..writeln('connection_state: ${connectionState.name}')
      ..writeln('proxy_mode: ${proxyMode.name}')
      ..writeln('selected_node: ${selectedNode?.name ?? '-'}')
      ..writeln('node_count: ${nodes.length}');

    if (diagnostic != null) {
      buffer
        ..writeln('runtime_root: ${diagnostic.runtimeRoot}')
        ..writeln('core_path: ${diagnostic.corePath}')
        ..writeln('core_exists: ${diagnostic.coreExists}')
        ..writeln('config_path: ${diagnostic.configPath}')
        ..writeln('config_exists: ${diagnostic.configExists}')
        ..writeln('log_path: ${diagnostic.logPath}')
        ..writeln('log_exists: ${diagnostic.logExists}')
        ..writeln('process_running: ${diagnostic.processRunning}')
        ..writeln('local_proxy: ${diagnostic.localProxyDisplay}')
        ..writeln('system_proxy_enabled: ${diagnostic.systemProxyEnabled}')
        ..writeln('system_proxy_server: ${diagnostic.systemProxyServer ?? '-'}')
        ..writeln('config_check: ${diagnostic.configCheckStatus}')
        ..writeln('config_check_output:')
        ..writeln(diagnostic.configCheckOutput)
        ..writeln('log_tail:')
        ..writeln(diagnostic.logTail.join('\n'));
    } else {
      buffer.writeln('diagnostics: not loaded');
    }

    return buffer.toString();
  }

  void _log(String level, String message) {
    logs.insert(0, LogEntry(time: DateTime.now(), level: level, message: message));
    if (logs.length > 200) {
      logs.removeRange(200, logs.length);
    }
  }
}

extension ProxyModeLabel on ProxyMode {
  String get label {
    return switch (this) {
      ProxyMode.system => '系统代理',
      ProxyMode.tun => 'TUN模式',
      ProxyMode.vpn => 'VPN模式',
    };
  }
}

class AppControllerScope extends InheritedNotifier<AppController> {
  const AppControllerScope({
    required AppController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppControllerScope>();
    assert(scope != null, 'AppControllerScope not found');
    return scope!.notifier!;
  }
}
