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
}

class MockKeliApi implements KeliApi {
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
      nodes: const [],
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
