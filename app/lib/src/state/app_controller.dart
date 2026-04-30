import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/core_manager.dart';
import '../services/keli_api.dart';
import '../services/session_store.dart';

const int latencyTestConcurrency = 4;

class _LatencyMeasurement {
  const _LatencyMeasurement({
    required this.index,
    required this.node,
    required this.latencyMs,
    required this.failureReason,
  });

  final int index;
  final ProxyNode node;
  final int? latencyMs;
  final String? failureReason;
}

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
  bool isTestingLatency = false;
  bool isRefreshingStore = false;
  bool isPurchasing = false;
  String? storeError;
  List<StorePlan> storePlans = const [];
  List<StoreOrder> storeOrders = const [];
  List<PaymentMethod> paymentMethods = const [];
  String? selectedPaymentMethodId;
  bool discountUpgradeEnabled = false;
  List<ProxyNode> nodes = const [];
  int selectedNodeId = 0;
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
    LogEntry(time: DateTime.now(), level: 'INFO', message: '客户端已启动'),
  ];
  Timer? _runtimeTimer;
  StreamSubscription<CoreTrafficSample>? _trafficSubscription;
  DateTime? _connectedAt;

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
      NodeFilter.lowLatency =>
        nodes.where((node) => (node.latencyMs ?? 99999) < 300).toList(),
      NodeFilter.favorite => nodes.where((node) => node.isFavorite).toList(),
      NodeFilter.hysteria2 =>
        nodes.where((node) => node.protocol == 'Hysteria2').toList(),
      NodeFilter.vless =>
        nodes.where((node) => node.protocol == 'VLESS').toList(),
    };
  }

  StoreOrder? get pendingOrder {
    for (final order in storeOrders) {
      if (order.isPending) {
        return order;
      }
    }
    return null;
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
    storePlans = const [];
    storeOrders = const [];
    paymentMethods = const [];
    selectedPaymentMethodId = null;
    discountUpgradeEnabled = false;
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

  void selectPaymentMethod(String? methodId) {
    selectedPaymentMethodId = methodId;
    notifyListeners();
  }

  Future<void> refreshStore() async {
    isRefreshingStore = true;
    storeError = null;
    notifyListeners();
    try {
      storePlans = await api.fetchPlans();
      await refreshOrders(notify: false);
      try {
        final config = await api.fetchUserConfig();
        discountUpgradeEnabled = _discountUpgradeEnabled(config);
      } catch (error) {
        discountUpgradeEnabled = false;
        _log('WARN', '升级配置加载失败: $error');
      }
      try {
        paymentMethods = await api.fetchPaymentMethods();
      } catch (error) {
        paymentMethods = const [];
        _log('WARN', '支付方式加载失败: $error');
      }
      if (paymentMethods.isNotEmpty &&
          !paymentMethods
              .any((method) => method.id == selectedPaymentMethodId)) {
        selectedPaymentMethodId = defaultPaymentMethodId(paymentMethods);
      }
      _log('INFO', '商店套餐已更新，套餐 ${storePlans.length} 个');
    } catch (error) {
      storeError = '$error';
      _log('ERROR', '商店加载失败: $error');
    } finally {
      isRefreshingStore = false;
      notifyListeners();
    }
  }

  Future<void> refreshOrders({bool notify = true}) async {
    try {
      storeOrders = await api.fetchOrders();
    } catch (error) {
      storeOrders = const [];
      _log('WARN', '订单列表加载失败: $error');
    } finally {
      if (notify) {
        notifyListeners();
      }
    }
  }

  bool isUpgradeTarget(StorePlan plan) {
    final current = profile;
    return discountUpgradeEnabled &&
        current != null &&
        current.hasActiveSubscription &&
        plan.id != current.planId &&
        current.upgradeTargetPlanIds.contains(plan.id) &&
        plan.hasRecurringOptions;
  }

  Future<UpgradePreview> previewUpgrade(
    StorePlan plan,
    PlanPeriodOption period,
  ) async {
    if (!isUpgradeTarget(plan)) {
      throw const ApiException('当前套餐不支持补差价升级到此套餐');
    }
    if (!recurringUpgradePeriodKeys.contains(period.period)) {
      throw const ApiException('升级只支持包月类周期');
    }
    return api.previewUpgrade(targetPlanId: plan.id, period: period.period);
  }

  Future<String> createPlanOrder(
    StorePlan plan,
    PlanPeriodOption period,
  ) async {
    if (isPurchasing) {
      throw const ApiException('正在处理上一个订单');
    }
    final pending = pendingOrder;
    if (pending != null) {
      throw ApiException('已有待支付订单 ${pending.tradeNo}，请先支付或取消后再创建新订单');
    }
    isPurchasing = true;
    storeError = null;
    notifyListeners();
    try {
      final tradeNo =
          await api.createOrder(planId: plan.id, period: period.period);
      storeOrders = [
        StoreOrder(
          planId: plan.id,
          planName: plan.name,
          tradeNo: tradeNo,
          period: period.period,
          status: 0,
          totalAmountCents: period.priceCents,
          createdAt: DateTime.now(),
        ),
        ...storeOrders.where((order) => order.tradeNo != tradeNo),
      ];
      _log('INFO', '订单已创建: $tradeNo');
      return tradeNo;
    } catch (error) {
      storeError = '$error';
      _log('ERROR', '创建订单失败: $error');
      rethrow;
    } finally {
      isPurchasing = false;
      notifyListeners();
    }
  }

  Future<String> createUpgradeOrder({required String quoteToken}) async {
    if (isPurchasing) {
      throw const ApiException('正在处理上一个订单');
    }
    final pending = pendingOrder;
    if (pending != null) {
      throw ApiException('已有待支付订单 ${pending.tradeNo}，请先支付或取消后再创建新订单');
    }
    if (quoteToken.trim().isEmpty) {
      throw const ApiException('请先完成升级预览');
    }
    isPurchasing = true;
    storeError = null;
    notifyListeners();
    try {
      final tradeNo = await api.confirmUpgrade(quoteToken: quoteToken);
      unawaited(refreshOrders());
      _log('INFO', '升级订单已创建: $tradeNo');
      return tradeNo;
    } catch (error) {
      storeError = '$error';
      _log('ERROR', '创建升级订单失败: $error');
      rethrow;
    } finally {
      isPurchasing = false;
      notifyListeners();
    }
  }

  Future<PurchaseResult> payOrder({
    required String tradeNo,
    String? paymentMethodId,
    bool allowNoPaymentMethod = false,
    String successMessage = '支付成功，套餐已刷新',
    String externalMessage = '正在打开支付页面',
  }) async {
    if (isPurchasing) {
      return const PurchaseResult(message: '正在处理上一个订单');
    }
    isPurchasing = true;
    storeError = null;
    notifyListeners();
    try {
      return await _checkoutTradeNo(
        tradeNo: tradeNo,
        paymentMethodId: paymentMethodId,
        allowNoPaymentMethod: allowNoPaymentMethod,
        successMessage: successMessage,
        externalMessage: externalMessage,
      );
    } catch (error) {
      storeError = '$error';
      _log('ERROR', '支付订单失败: $error');
      return PurchaseResult(message: '支付失败: $error', tradeNo: tradeNo);
    } finally {
      isPurchasing = false;
      notifyListeners();
    }
  }

  Future<void> cancelStoreOrder(String tradeNo) async {
    if (tradeNo.trim().isEmpty) {
      return;
    }
    try {
      await api.cancelOrder(tradeNo: tradeNo);
      await refreshOrders(notify: false);
      _log('INFO', '订单已取消: $tradeNo');
    } catch (error) {
      storeError = '$error';
      _log('ERROR', '取消订单失败: $error');
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<int> checkStoreOrder(String tradeNo) {
    return api.checkOrder(tradeNo: tradeNo);
  }

  Future<PurchaseResult> purchasePlan(
    StorePlan plan,
    PlanPeriodOption period, {
    String? paymentMethodId,
  }) async {
    if (isPurchasing) {
      return const PurchaseResult(message: '正在处理上一个订单');
    }
    isPurchasing = true;
    storeError = null;
    notifyListeners();
    try {
      final pending = pendingOrder;
      if (pending != null) {
        return PurchaseResult(
          message: '已有待支付订单，请先支付或取消后再创建新订单',
          tradeNo: pending.tradeNo,
          copyText: pending.tradeNo,
        );
      }
      final tradeNo =
          await api.createOrder(planId: plan.id, period: period.period);
      storeOrders = [
        StoreOrder(
          planId: plan.id,
          planName: plan.name,
          tradeNo: tradeNo,
          period: period.period,
          status: 0,
          totalAmountCents: period.priceCents,
          createdAt: DateTime.now(),
        ),
        ...storeOrders.where((order) => order.tradeNo != tradeNo),
      ];
      _log('INFO', '订单已创建: $tradeNo');
      return await _checkoutTradeNo(
        tradeNo: tradeNo,
        paymentMethodId: paymentMethodId,
        allowNoPaymentMethod: period.priceCents <= 0,
        successMessage: '购买成功，套餐已刷新',
        externalMessage: '订单已创建，正在打开支付页面',
      );
    } catch (error) {
      storeError = '$error';
      _log('ERROR', '购买失败: $error');
      return PurchaseResult(message: '购买失败: $error');
    } finally {
      isPurchasing = false;
      notifyListeners();
    }
  }

  Future<PurchaseResult> purchaseUpgrade(
    StorePlan plan,
    PlanPeriodOption period, {
    required String quoteToken,
    String? paymentMethodId,
    int? payableAmountCents,
  }) async {
    if (isPurchasing) {
      return const PurchaseResult(message: '正在处理上一个订单');
    }
    if (quoteToken.trim().isEmpty) {
      return const PurchaseResult(message: '购买失败: 请先完成升级预览');
    }
    isPurchasing = true;
    storeError = null;
    notifyListeners();
    try {
      final pending = pendingOrder;
      if (pending != null) {
        return PurchaseResult(
          message: '已有待支付订单，请先支付或取消后再创建新订单',
          tradeNo: pending.tradeNo,
          copyText: pending.tradeNo,
        );
      }
      final tradeNo = await api.confirmUpgrade(quoteToken: quoteToken);
      unawaited(refreshOrders());
      _log('INFO', '升级订单已创建: $tradeNo');
      return await _checkoutTradeNo(
        tradeNo: tradeNo,
        paymentMethodId: paymentMethodId,
        allowNoPaymentMethod: false,
        successMessage: '升级成功，套餐已刷新',
        externalMessage: '升级订单已创建，正在打开支付页面',
      );
    } catch (error) {
      storeError = '$error';
      _log('ERROR', '升级购买失败: $error');
      return PurchaseResult(message: '购买失败: $error');
    } finally {
      isPurchasing = false;
      notifyListeners();
    }
  }

  Future<PurchaseResult> _checkoutTradeNo({
    required String tradeNo,
    required String? paymentMethodId,
    required bool allowNoPaymentMethod,
    required String successMessage,
    required String externalMessage,
  }) async {
    PaymentMethod? selectedMethod;
    final methodId = paymentMethodId ?? selectedPaymentMethodId;
    for (final method in paymentMethods) {
      if (method.id == methodId) {
        selectedMethod = method;
        break;
      }
    }
    if (selectedMethod == null) {
      if (allowNoPaymentMethod) {
        final checkout = await api.checkoutOrder(
          tradeNo: tradeNo,
          method: '',
        );
        if (checkout.type == -1) {
          await bootstrap();
          await refreshOrders(notify: false);
          return PurchaseResult(message: successMessage, tradeNo: tradeNo);
        }
      }
      return PurchaseResult(
        message: '请选择支付方式，或复制订单号到面板支付',
        tradeNo: tradeNo,
        copyText: tradeNo,
      );
    }

    final checkout = await api.checkoutOrder(
      tradeNo: tradeNo,
      method: selectedMethod.id,
    );

    if (checkout.type == -1) {
      await bootstrap();
      await refreshOrders(notify: false);
      return PurchaseResult(message: successMessage, tradeNo: tradeNo);
    }

    final data = checkout.data;
    final externalUrl = checkoutExternalUrl(data);
    if (checkout.type == 1 && externalUrl != null) {
      return PurchaseResult(
          message: externalMessage, tradeNo: tradeNo, externalUrl: externalUrl);
    }

    final qrPayload = checkoutQrPayload(data);
    if (checkout.type == 0 && qrPayload != null) {
      return PurchaseResult(
        message: '订单已创建，请扫码支付',
        tradeNo: tradeNo,
        qrPayload: qrPayload,
      );
    }

    final paymentText = checkoutDataText(data);
    if (checkout.type == 0 && paymentText.isNotEmpty) {
      return PurchaseResult(
          message: '订单已创建，支付信息已复制', tradeNo: tradeNo, copyText: paymentText);
    }

    return PurchaseResult(
      message: '订单已创建，请复制订单号到面板支付',
      tradeNo: tradeNo,
      copyText: tradeNo,
    );
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
        .map((item) => item.id == node.id
            ? item.copyWith(isFavorite: !item.isFavorite)
            : item)
        .toList();
    notifyListeners();
  }

  Future<void> connect() async {
    final node = selectedNode;
    if (node == null) {
      return;
    }
    _stopRuntimeTimer();
    stats = const RuntimeStats(
      uploadSpeed: '0 KB/s',
      downloadSpeed: '0 KB/s',
      duration: Duration.zero,
    );
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
      if (applied.clashApiAddress != null) {
        _log('INFO', '本地核心 API ${applied.clashApiAddress}');
      }
      await coreManager.connect(node: node, mode: proxyMode);
      connectionState = ConnectionStateKind.connected;
      _startRuntimeTimer();
      _log('INFO', '连接成功: ${node.name}');
    } catch (error) {
      _stopRuntimeTimer();
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
    _stopRuntimeTimer();
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
    if (isTestingLatency) {
      return;
    }
    isTestingLatency = true;
    _log('INFO', '开始测试节点延迟，并发 $latencyTestConcurrency 个');
    notifyListeners();
    final snapshot = List<ProxyNode>.of(nodes);
    final updated = List<ProxyNode>.of(snapshot);
    final failures = <String, List<String>>{};
    var measured = 0;
    try {
      for (var start = 0;
          start < snapshot.length;
          start += latencyTestConcurrency) {
        final end = start + latencyTestConcurrency > snapshot.length
            ? snapshot.length
            : start + latencyTestConcurrency;
        final results = await Future.wait([
          for (var index = start; index < end; index++)
            _measureNodeLatencyResult(index, snapshot[index]),
        ]);
        for (final result in results) {
          if (result.latencyMs != null) {
            measured++;
          } else if (result.failureReason != null) {
            failures
                .putIfAbsent(result.failureReason!, () => <String>[])
                .add(result.node.name);
          }
          updated[result.index] = result.node.copyWith(
            latencyMs: result.latencyMs,
            clearLatency: result.latencyMs == null,
          );
        }
        nodes = List<ProxyNode>.of(updated);
        notifyListeners();
      }
      if (measured == 0) {
        _log('WARN', '真实节点测速未成功：${latencyFailureSummary(failures)}');
      } else {
        _log('INFO', '延迟测试完成，成功 $measured/${snapshot.length} 个');
        if (failures.isNotEmpty) {
          _log('WARN', '部分节点测速未成功：${latencyFailureSummary(failures)}');
        }
      }
    } finally {
      isTestingLatency = false;
      notifyListeners();
    }
  }

  Future<_LatencyMeasurement> _measureNodeLatencyResult(
    int index,
    ProxyNode node,
  ) async {
    try {
      final latency = await _measureNodeLatency(node);
      return _LatencyMeasurement(
        index: index,
        node: node,
        latencyMs: latency,
        failureReason: latency == null ? '未返回延迟' : null,
      );
    } catch (error) {
      return _LatencyMeasurement(
        index: index,
        node: node,
        latencyMs: null,
        failureReason: latencyFailureReason(error),
      );
    }
  }

  Future<void> testSelectedNodeLatency() async {
    final node = selectedNode;
    if (node == null || isTestingLatency) {
      return;
    }
    isTestingLatency = true;
    _log('INFO', '开始测试当前节点 ${node.name}');
    notifyListeners();
    try {
      final latency = await _measureNodeLatency(node);
      nodes = nodes
          .map((item) => item.id == node.id
              ? item.copyWith(
                  latencyMs: latency,
                  clearLatency: latency == null,
                )
              : item)
          .toList();
      if (latency == null) {
        _log('WARN', '当前节点测速未成功: ${node.name}');
      } else {
        _log('INFO', '当前节点测速完成: ${node.name} ${latency}ms');
      }
    } catch (error) {
      final reason = latencyFailureReason(error);
      _log('WARN', '当前节点测速未成功：$reason · ${node.name}');
    } finally {
      isTestingLatency = false;
      notifyListeners();
    }
  }

  Future<int?> _measureNodeLatency(ProxyNode node) async {
    final config = await api.fetchSingBoxConfig(
      serverId: node.id,
      platform: proxyMode == ProxyMode.vpn ? 'android' : 'windows',
      coreVersion: '1.13.11',
    );
    return coreManager.testLatency(node, config: config, mode: proxyMode);
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
        ..writeln('clash_api: ${diagnostic.clashApiAddress ?? '-'}')
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

  void _startRuntimeTimer() {
    _runtimeTimer?.cancel();
    _trafficSubscription?.cancel();
    _connectedAt = DateTime.now();
    stats = const RuntimeStats(
      uploadSpeed: '0 KB/s',
      downloadSpeed: '0 KB/s',
      duration: Duration.zero,
    );
    _runtimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final connectedAt = _connectedAt;
      if (connectedAt == null ||
          connectionState != ConnectionStateKind.connected) {
        return;
      }
      stats = stats.copyWith(duration: DateTime.now().difference(connectedAt));
      notifyListeners();
    });
    _trafficSubscription = coreManager.watchTraffic().listen(
      (sample) {
        final connectedAt = _connectedAt;
        stats = stats.copyWith(
          uploadSpeed: byteRateText(sample.uploadBytesPerSecond),
          downloadSpeed: byteRateText(sample.downloadBytesPerSecond),
          sessionTraffic: byteSizeText(sample.sessionTotalBytes),
          duration: connectedAt == null
              ? stats.duration
              : DateTime.now().difference(connectedAt),
        );
        notifyListeners();
      },
      onError: (Object error) {
        _log('WARN', '运行流量采集失败: $error');
      },
    );
  }

  void _stopRuntimeTimer() {
    _runtimeTimer?.cancel();
    _runtimeTimer = null;
    _trafficSubscription?.cancel();
    _trafficSubscription = null;
    _connectedAt = null;
  }

  @override
  void dispose() {
    _stopRuntimeTimer();
    unawaited(coreManager.disconnect());
    super.dispose();
  }

  void _log(String level, String message) {
    logs.insert(
        0, LogEntry(time: DateTime.now(), level: level, message: message));
    if (logs.length > 200) {
      logs.removeRange(200, logs.length);
    }
  }
}

String latencyFailureReason(Object error) {
  final message = '$error';
  if (message.contains('HTTP 404')) {
    return '核心 API 未返回该代理';
  }
  if (message.contains('HTTP 408') ||
      message.contains('HTTP 504') ||
      message.contains('TimeoutException') ||
      message.contains('Timeout')) {
    return '节点超时';
  }
  if (message.contains('Clash API 未就绪')) {
    return '核心 API 未就绪';
  }
  if (message.contains('缺少真实节点出站')) {
    return '配置缺少出站';
  }
  if (message.contains('测速进程已退出')) {
    return '测速核心启动失败';
  }
  return '其他错误';
}

String latencyFailureSummary(Map<String, List<String>> failures) {
  if (failures.isEmpty) {
    return '无具体错误';
  }
  return failures.entries.map((entry) {
    final samples = entry.value.take(3).join('、');
    final suffix = entry.value.length > 3 ? ' 等' : '';
    return '${entry.key} ${entry.value.length} 个（$samples$suffix）';
  }).join('；');
}

String byteRateText(int bytesPerSecond) {
  return '${byteSizeText(bytesPerSecond)}/s';
}

String byteSizeText(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  if (unitIndex == 0) {
    return '${value.toStringAsFixed(0)} ${units[unitIndex]}';
  }
  final precision = value >= 100 ? 0 : 1;
  return '${value.toStringAsFixed(precision)} ${units[unitIndex]}';
}

String? defaultPaymentMethodId(List<PaymentMethod> methods) {
  if (methods.isEmpty) {
    return null;
  }
  for (final method in methods) {
    if (method.payment != 'balance') {
      return method.id;
    }
  }
  return methods.first.id;
}

String? checkoutExternalUrl(Object? data) {
  if (data is String && data.trim().isNotEmpty) {
    return data.trim();
  }
  if (data is Map) {
    for (final key in ['payment_url', 'paymentUrl', 'url', 'checkout_url']) {
      final value = data[key];
      if (value != null && '$value'.trim().isNotEmpty) {
        return '$value'.trim();
      }
    }
  }
  return null;
}

CheckoutQrPayload? checkoutQrPayload(Object? data) {
  if (data is String) {
    final value = data.trim();
    return value.isEmpty ? null : CheckoutQrPayload(qrData: value);
  }
  if (data is! Map) {
    return null;
  }

  final qrData = _readString(
    data,
    ['qr_data', 'qrData', 'address', 'token', 'payment_url', 'paymentUrl'],
  );
  if (qrData == null) {
    return null;
  }

  return CheckoutQrPayload(
    qrData: qrData,
    address: _readString(data, ['address', 'token']),
    amount: _readString(data, ['amount', 'actual_amount']),
    fiatAmount: _readString(data, ['fiat_amount', 'fiatAmount']),
    fiat: _readString(data, ['fiat']),
    currency: _readString(data, ['currency']),
    network: _readString(data, ['network']),
    tradeType: _readString(data, ['trade_type', 'tradeType']),
    tradeId: _readString(data, ['trade_id', 'tradeId']),
    paymentUrl: _readString(data, ['payment_url', 'paymentUrl']),
    expirationTime: _readInt(data, ['expiration_time', 'expirationTime']),
  );
}

String checkoutDataText(Object? data) {
  if (data == null) {
    return '';
  }
  if (data is String) {
    return data;
  }
  if (data is Map) {
    final parts = <String>[];
    for (final key in [
      'payment_url',
      'qr_data',
      'address',
      'token',
      'amount',
      'actual_amount',
      'fiat_amount',
      'fiat',
      'currency',
      'network',
      'trade_type',
      'trade_id',
      'expiration_time',
      'trade_no',
    ]) {
      final value = data[key];
      if (value != null && '$value'.trim().isNotEmpty) {
        parts.add('$key: $value');
      }
    }
    if (parts.isNotEmpty) {
      return parts.join('\n');
    }
    return data.toString();
  }
  return '$data';
}

String? _readString(Map data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is num && value.isFinite) {
      return '$value';
    }
  }
  return null;
}

int? _readInt(Map data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is int) {
      return value;
    }
    if (value is num && value.isFinite) {
      return value.round();
    }
    if (value is String && value.trim().isNotEmpty) {
      final parsed = num.tryParse(value.trim());
      if (parsed != null && parsed.isFinite) {
        return parsed.round();
      }
    }
  }
  return null;
}

bool _discountUpgradeEnabled(Map<String, Object?> config) {
  return _featureFlag(config['upgrade_v2_enable']) &&
      _featureFlag(config['plan_change_enable'], defaultValue: true);
}

bool _featureFlag(Object? value, {bool defaultValue = false}) {
  if (value == null) {
    return defaultValue;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return defaultValue;
    }
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'on';
  }
  return false;
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
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppControllerScope>();
    assert(scope != null, 'AppControllerScope not found');
    return scope!.notifier!;
  }
}
