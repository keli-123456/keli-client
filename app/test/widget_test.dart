import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keli_client/src/models.dart';
import 'package:keli_client/src/services/core_manager.dart';
import 'package:keli_client/src/services/keli_api.dart';
import 'package:keli_client/src/services/session_store.dart';
import 'package:keli_client/src/state/app_controller.dart';

void main() {
  test('Keli Client bootstraps through injected services', () async {
    final temp = await Directory.systemTemp.createTemp('keli-client-test-');
    final controller = AppController(
      api: MockKeliApi(),
      coreManager: MockCoreManager(),
      sessionStore: SessionStore(root: temp),
    );

    try {
      await controller.bootstrap();

      expect(controller.isBootstrapping, isFalse);
      expect(controller.profile?.email, 'test@example.com');
      expect(controller.nodes, isEmpty);
      expect(controller.lastError, isNull);
    } finally {
      controller.dispose();
      await temp.delete(recursive: true);
    }
  });

  test('latency failure reason keeps core API timeout distinct', () {
    expect(
      latencyFailureReason(
        const CoreException(
          'Clash API 未就绪: TimeoutException after 0:00:01.000000',
        ),
      ),
      '核心 API 未就绪',
    );
  });

  test('unsupported latency testing records a node-level reason', () async {
    final temp = await Directory.systemTemp.createTemp('keli-client-test-');
    final controller = AppController(
      api: MockKeliApi(
        nodes: const [
          ProxyNode(
            id: 1,
            name: '测试节点',
            protocol: 'Hysteria2',
            rate: 1,
            isOnline: true,
            latencyMs: null,
          ),
        ],
      ),
      coreManager: UnsupportedLatencyCoreManager(),
      sessionStore: SessionStore(root: temp),
    );

    try {
      await controller.bootstrap();
      await controller.testAllLatency();

      expect(controller.latencyAttemptedFor(1), isTrue);
      expect(controller.latencyFailureFor(1), '平台暂不支持测速');
    } finally {
      controller.dispose();
      await temp.delete(recursive: true);
    }
  });

  test('connection failure reason classifies Android VPN startup issues', () {
    expect(
      connectionFailureReason(
        const CoreException('Android VPNService 启动超时：状态 starting · 节点 测试'),
      ),
      'VPN 服务启动超时',
    );
    expect(
      connectionFailureReason(
        const CoreException('Android sing-box config is empty'),
      ),
      '配置为空',
    );
    expect(
      connectionFailureReason(
        const CoreException('Android sing-box core is missing'),
      ),
      '移动端核心缺失',
    );
  });
}

class MockKeliApi implements KeliApi {
  const MockKeliApi({this.nodes = const []});

  final List<ProxyNode> nodes;

  @override
  Future<BootstrapPayload> bootstrap() async {
    return BootstrapPayload(
      profile: AppProfile(
        email: 'test@example.com',
        planName: '测试套餐',
        expireAt: DateTime(2099),
        usedTrafficGb: 0,
        totalTrafficGb: 100,
        resetDay: 1,
      ),
      nodes: nodes,
    );
  }

  @override
  Future<void> cancelOrder({required String tradeNo}) async {}

  @override
  Future<int> checkOrder({required String tradeNo}) async => 0;

  @override
  Future<CheckoutResult> checkoutOrder({
    required String tradeNo,
    required String method,
  }) async {
    return const CheckoutResult(type: -1, data: true);
  }

  @override
  Future<String> confirmUpgrade({required String quoteToken}) async {
    return 'upgrade-trade-no';
  }

  @override
  Future<String> createOrder({
    required int planId,
    required String period,
  }) async {
    return 'trade-no';
  }

  @override
  Future<List<PaymentMethod>> fetchPaymentMethods() async => const [];

  @override
  Future<List<StoreOrder>> fetchOrders() async => const [];

  @override
  Future<List<StorePlan>> fetchPlans() async => const [];

  @override
  Future<List<ProxyNode>> fetchServers() async => const [];

  @override
  Future<Map<String, Object?>> fetchSingBoxBatchConfig({
    required String platform,
    String? coreVersion,
  }) async {
    return const <String, Object?>{};
  }

  @override
  Future<Map<String, Object?>> fetchSingBoxConfig({
    required int serverId,
    required String platform,
    String? coreVersion,
  }) async {
    return const <String, Object?>{};
  }

  @override
  Future<Map<String, Object?>> fetchUserConfig() async {
    return const <String, Object?>{};
  }

  @override
  Future<LoginResult> login({
    required String baseUrl,
    required String apiPrefix,
    required String email,
    required String password,
  }) async {
    return const LoginResult(
      session: ApiSession(
        baseUrl: 'https://example.com',
        apiPrefix: '/api/v1',
        authData: 'Bearer test',
      ),
    );
  }

  @override
  Future<UpgradePreview> previewUpgrade({
    required int targetPlanId,
    required String period,
  }) async {
    return const UpgradePreview(allowUpgrade: false);
  }
}

class MockCoreManager implements CoreManager {
  @override
  bool get supportsLatencyTesting => true;

  @override
  Future<CoreApplyResult> applyConfig(
    Map<String, Object?> config, {
    ProxyMode mode = ProxyMode.system,
  }) async {
    return CoreApplyResult(
      configFile: File('test-sing-box.json'),
      localProxyPort: 20808,
    );
  }

  @override
  Future<void> connect({
    required ProxyNode node,
    required ProxyMode mode,
  }) async {}

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
      localProxyType: 'mixed',
      localProxyListen: '127.0.0.1',
      localProxyPort: 20808,
      clashApiAddress: null,
      systemProxyEnabled: false,
      systemProxyServer: null,
      configCheckStatus: 'skipped',
      configCheckOutput: '',
      logTail: const [],
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> prepare() async {}

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
  Future<int?> testLatency(
    ProxyNode node, {
    Map<String, Object?>? config,
    ProxyMode mode = ProxyMode.system,
    LatencyTestMode testMode = LatencyTestMode.quick,
  }) async {
    return null;
  }

  @override
  Stream<CoreTrafficSample> watchTraffic() {
    return const Stream<CoreTrafficSample>.empty();
  }
}

class UnsupportedLatencyCoreManager extends MockCoreManager {
  @override
  bool get supportsLatencyTesting => false;
}
