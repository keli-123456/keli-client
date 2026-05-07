import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keli_client/src/models.dart';
import 'package:keli_client/src/services/core_manager.dart';
import 'package:keli_client/src/services/endpoint_resolver.dart';
import 'package:keli_client/src/services/keli_api.dart';
import 'package:keli_client/src/services/session_store.dart';
import 'package:keli_client/src/state/app_controller.dart';
import 'package:keli_client/src/ui/app_shell.dart';
import 'package:keli_client/src/ui/login_screen.dart';

void main() {
  test('login screen remains exported after shell split', () {
    expect(const LoginScreen(), isA<LoginScreen>());
  });

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

  test('runtime speed samples keep a bounded recent history', () {
    var samples = const <int>[];
    for (var i = 0; i < runtimeSpeedSampleLimit + 5; i++) {
      samples = appendRuntimeSpeedSample(samples, i);
    }

    expect(samples.length, runtimeSpeedSampleLimit);
    expect(samples.first, 5);
    expect(samples.last, runtimeSpeedSampleLimit + 4);
    expect(appendRuntimeSpeedSample(samples, -12).last, 0);
  });

  test('session store protects auth data when the platform supports it',
      () async {
    final temp = await Directory.systemTemp.createTemp('keli-client-test-');
    final store = SessionStore(
      root: temp,
      secretStore: const FakeSessionSecretStore(),
    );

    try {
      await store.save(
        const ApiSession(
          baseUrl: 'https://panel.example',
          apiPrefix: '/api/v1',
          authData: 'Bearer secret-token',
          subscribeToken: 'subscribe-token',
        ),
      );

      final sessionFile =
          File('${temp.path}${Platform.pathSeparator}session.json');
      final decoded = jsonDecode(await sessionFile.readAsString()) as Map;

      expect(decoded['auth_data'], isNull);
      expect(decoded['auth_data_storage'], 'fake-session-v1');
      expect(decoded['auth_data_protected'], 'protected:Bearer secret-token');

      final loaded = await store.load();
      expect(loaded?.authData, 'Bearer secret-token');
      expect(loaded?.subscribeToken, 'subscribe-token');
    } finally {
      await temp.delete(recursive: true);
    }
  });

  test('session store keeps legacy plaintext session files readable', () async {
    final temp = await Directory.systemTemp.createTemp('keli-client-test-');
    final store = SessionStore(
      root: temp,
      secretStore: const FakeSessionSecretStore(),
    );

    try {
      await temp.create(recursive: true);
      final sessionFile =
          File('${temp.path}${Platform.pathSeparator}session.json');
      await sessionFile.writeAsString(
        jsonEncode(
          <String, Object?>{
            'base_url': 'https://panel.example',
            'api_prefix': '/api/v1',
            'auth_data': 'Bearer legacy-token',
          },
        ),
      );

      final loaded = await store.load();
      expect(loaded?.authData, 'Bearer legacy-token');
      expect(loaded?.baseUrl, 'https://panel.example');
    } finally {
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
    expect(
      latencyFailureReason(
        const CoreException('节点超时: Connection refused'),
      ),
      '节点超时',
    );
  });

  test('recharge orders do not offer balance as a payment method', () {
    const methods = <PaymentMethod>[
      PaymentMethod(id: '1', name: '余额', payment: 'balance'),
      PaymentMethod(id: '2', name: 'Stripe', payment: 'stripe'),
    ];
    final rechargeOrder = StoreOrder(
      planId: 0,
      tradeNo: 'R202605010001',
      period: 'recharge',
      status: 0,
      totalAmountCents: 1000,
      createdAt: DateTime(2026, 5, 1),
    );
    final planOrder = StoreOrder(
      planId: 1,
      tradeNo: 'K202605010001',
      period: 'month_price',
      status: 0,
      totalAmountCents: 1000,
      createdAt: DateTime(2026, 5, 1),
    );

    expect(
      paymentMethodsForOrder(methods, rechargeOrder)
          .map((method) => method.payment),
      <String>['stripe'],
    );
    expect(
      paymentMethodsForOrder(methods, planOrder)
          .map((method) => method.payment),
      <String>['balance', 'stripe'],
    );
  });

  test('recharge creation is guarded by an existing pending order', () async {
    final temp = await Directory.systemTemp.createTemp('keli-client-test-');
    final pendingOrder = StoreOrder(
      planId: 1,
      tradeNo: 'K202605010001',
      period: 'month_price',
      status: 0,
      totalAmountCents: 1000,
      createdAt: DateTime(2026, 5, 1),
    );
    final controller = AppController(
      api: MockKeliApi(orders: [pendingOrder]),
      coreManager: MockCoreManager(),
      sessionStore: SessionStore(root: temp),
    );

    try {
      await controller.refreshOrders();

      expect(controller.pendingOrder?.tradeNo, 'K202605010001');
      await expectLater(
        controller.createRechargeOrder(amountCents: 1000),
        throwsA(isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('已有待支付订单'),
        )),
      );
    } finally {
      controller.dispose();
      await temp.delete(recursive: true);
    }
  });

  test('traffic options expose reset only for the current active plan', () {
    final profile = AppProfile(
      email: 'test@example.com',
      planName: 'Current',
      expireAt: DateTime(2099, 12, 31),
      usedTrafficGb: 1,
      totalTrafficGb: 100,
      resetDay: 10,
      planId: 1,
    );
    const currentPlan = StorePlan(
      id: 1,
      name: 'Current',
      content: '',
      prices: <String, int>{
        'month_price': 1200,
        'reset_price': 200,
      },
      transferEnable: 100,
      speedLimit: null,
      deviceLimit: null,
      sell: true,
      renew: true,
      sort: 1,
    );
    const otherPlan = StorePlan(
      id: 2,
      name: 'Other',
      content: '',
      prices: <String, int>{
        'month_price': 1600,
        'reset_price': 300,
      },
      transferEnable: 100,
      speedLimit: null,
      deviceLimit: null,
      sell: true,
      renew: true,
      sort: 2,
    );

    expect(
      storeTrafficOptions(currentPlan, profile).map((option) => option.period),
      <String>['reset_price'],
    );
    expect(storeTrafficOptions(otherPlan, profile), isEmpty);
    expect(
      storeOrderUnavailableReason(
        profile,
        otherPlan,
        otherPlan.periodOptions.last,
      ),
      '只能为当前有效套餐购买流量重置包',
    );
  });

  test('active current plan with renew disabled is blocked before checkout',
      () {
    final profile = AppProfile(
      email: 'test@example.com',
      planName: 'Legacy',
      expireAt: DateTime(2099, 12, 31),
      usedTrafficGb: 1,
      totalTrafficGb: 100,
      resetDay: 10,
      planId: 1,
    );
    const plan = StorePlan(
      id: 1,
      name: 'Legacy',
      content: '',
      prices: <String, int>{'month_price': 1200},
      transferEnable: 100,
      speedLimit: null,
      deviceLimit: null,
      sell: true,
      renew: false,
      sort: 1,
    );

    expect(
      storeOrderUnavailableReason(profile, plan, plan.periodOptions.single),
      '当前套餐不允许续费，请选择其他套餐',
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

  test('manual latency retry preserves node-level failure reasons', () async {
    final temp = await Directory.systemTemp.createTemp('keli-client-test-');
    final controller = AppController(
      api: MockKeliApi(
        nodes: const [
          ProxyNode(
            id: 1,
            name: '缺失代理节点',
            protocol: 'Hysteria2',
            rate: 1,
            isOnline: true,
            latencyMs: null,
          ),
          ProxyNode(
            id: 2,
            name: '超时节点',
            protocol: 'VLESS',
            rate: 1,
            isOnline: true,
            latencyMs: null,
          ),
        ],
      ),
      coreManager: ClassifyingLatencyCoreManager(),
      sessionStore: SessionStore(root: temp),
    );

    try {
      await controller.bootstrap();
      await controller.testAllLatency();

      expect(controller.latencyFailureFor(1), '核心 API 未返回该代理');
      expect(controller.latencyFailureFor(2), '节点超时');
    } finally {
      controller.dispose();
      await temp.delete(recursive: true);
    }
  });

  test('selected node latency retries after quick timeout', () async {
    final temp = await Directory.systemTemp.createTemp('keli-client-test-');
    final controller = AppController(
      api: MockKeliApi(
        nodes: const [
          ProxyNode(
            id: 1,
            name: '重试节点',
            protocol: 'Hysteria2',
            rate: 1,
            isOnline: true,
            latencyMs: null,
          ),
        ],
      ),
      coreManager: SelectedNodeRetryCoreManager(),
      sessionStore: SessionStore(root: temp),
    );

    try {
      await controller.bootstrap();
      await controller.testSelectedNodeLatency();

      expect(controller.nodes.single.latencyMs, 88);
      expect(controller.latencyFailureFor(1), isNull);
    } finally {
      controller.dispose();
      await temp.delete(recursive: true);
    }
  });

  test('announcements load during bootstrap and can be dismissed', () async {
    final temp = await Directory.systemTemp.createTemp('keli-client-test-');
    final controller = AppController(
      api: MockKeliApi(
        announcements: [
          Announcement(
            id: 'notice-1',
            title: '维护通知',
            content: '<p>今晚维护</p>',
            createdAt: DateTime(2026, 5, 1),
            show: true,
            popup: true,
            tags: const [],
          ),
        ],
      ),
      coreManager: MockCoreManager(),
      sessionStore: SessionStore(root: temp),
    );

    try {
      await controller.bootstrap();

      expect(controller.visibleAnnouncements.single.title, '维护通知');
      expect(controller.popupAnnouncement?.id, 'notice-1');

      await controller
          .dismissAnnouncement(controller.visibleAnnouncements.single);

      expect(controller.visibleAnnouncements, isEmpty);
      controller.announcements = [
        Announcement(
          id: 'notice-1',
          title: '维护通知',
          content: '<p>明晚维护</p>',
          createdAt: DateTime(2026, 5, 1),
          show: true,
          popup: true,
          tags: const [],
        ),
      ];
      expect(
        controller.visibleAnnouncements.single.content,
        '<p>明晚维护</p>',
      );
      final cachedKeys =
          await SessionStore(root: temp).loadDismissedAnnouncementKeys();
      expect(cachedKeys, isNotEmpty);
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

  test('connection failure reason classifies desktop core setup issues', () {
    expect(
      connectionFailureReason(
        const CoreException('darwin 暂未接入本地核心'),
      ),
      '平台暂未接入核心',
    );
    expect(
      connectionFailureReason(
        const CoreException('sing-box 配置文件不存在，请先拉取节点配置'),
      ),
      '配置未写入',
    );
    expect(
      connectionFailureReason(
        const CoreException('sing-box 启动失败，退出码 1，请查看日志'),
      ),
      '核心启动失败',
    );
    expect(
      connectionFailureReason(
        const CoreException('修改系统代理失败: access denied'),
      ),
      '系统代理设置失败',
    );
    expect(
      connectionFailureReason(
        const CoreException('没有可用的本地 TCP 端口'),
      ),
      '本地端口不可用',
    );
    expect(
      connectionFailureReason(
        const CoreException('下载失败: HTTP 503'),
      ),
      '核心准备失败',
    );
  });

  test('disconnect failure does not leave connection state stuck', () async {
    final temp = await Directory.systemTemp.createTemp('keli-client-test-');
    final controller = AppController(
      api: MockKeliApi(),
      coreManager: DisconnectFailingCoreManager(),
      sessionStore: SessionStore(root: temp),
    );

    try {
      controller.connectionState = ConnectionStateKind.connected;
      await controller.disconnect();

      expect(controller.connectionState, ConnectionStateKind.error);
      expect(controller.lastError, '断开连接失败');
    } finally {
      controller.dispose();
      await temp.delete(recursive: true);
    }
  });

  test('connect prefers full auto-select config when multiple nodes exist',
      () async {
    final temp = await Directory.systemTemp.createTemp('keli-client-test-');
    final api = RecordingConnectionApi(
      nodes: const [
        ProxyNode(
          id: 1,
          name: 'edge-a',
          protocol: 'VLESS',
          rate: 1,
          isOnline: true,
          latencyMs: null,
        ),
        ProxyNode(
          id: 2,
          name: 'edge-b',
          protocol: 'Trojan',
          rate: 1,
          isOnline: true,
          latencyMs: null,
        ),
      ],
    );
    final core = RecordingConnectionCoreManager();
    final controller = AppController(
      api: api,
      coreManager: core,
      sessionStore: SessionStore(root: temp),
    );

    try {
      await controller.bootstrap();
      await controller.connect();

      expect(api.batchConfigFetches, 1);
      expect(api.singleConfigFetches, 0);
      expect(core.appliedConfig?['source'], 'batch');
      expect(core.connectedNode?.name, '自动选择');
      expect(controller.connectionState, ConnectionStateKind.connected);
    } finally {
      controller.dispose();
      await temp.delete(recursive: true);
    }
  });

  test('manual node selection still pins a single-node config', () async {
    final temp = await Directory.systemTemp.createTemp('keli-client-test-');
    const nodes = [
      ProxyNode(
        id: 1,
        name: 'edge-a',
        protocol: 'VLESS',
        rate: 1,
        isOnline: true,
        latencyMs: null,
      ),
      ProxyNode(
        id: 2,
        name: 'edge-b',
        protocol: 'Trojan',
        rate: 1,
        isOnline: true,
        latencyMs: null,
      ),
    ];
    final api = RecordingConnectionApi(nodes: nodes);
    final core = RecordingConnectionCoreManager();
    final controller = AppController(
      api: api,
      coreManager: core,
      sessionStore: SessionStore(root: temp),
    );

    try {
      await controller.bootstrap();
      await controller.selectNode(nodes.last);
      await controller.connect();

      expect(api.batchConfigFetches, 0);
      expect(api.singleConfigFetches, 1);
      expect(api.lastSingleServerId, 2);
      expect(core.appliedConfig?['source'], 'single');
      expect(core.connectedNode?.name, 'edge-b');
    } finally {
      controller.dispose();
      await temp.delete(recursive: true);
    }
  });

  test('endpoint resolver combines cache, well-known, txt and bootstrap',
      () async {
    final resolver = ApiEndpointResolver(
      bootstrapUrls: const ['https://panel.example/bootstrap/keli-client.json'],
      client: FakeDiscoveryClient(
        jsonByUrl: <String, Map<String, Object?>>{
          'https://panel.example/.well-known/keli-client.json':
              <String, Object?>{
            'api_base': 'https://well-known-api.example',
            'api_prefix': '/api/v2',
            'backup_api_bases': ['https://well-known-backup.example'],
            'ttl': 3600,
          },
          'https://dns.example/keli-client.json': <String, Object?>{
            'api_base': 'https://dns-api.example',
            'api_prefix': '/api/v1',
          },
          'https://panel.example/bootstrap/keli-client.json': <String, Object?>{
            'api_base': 'https://bootstrap-api.example',
            'api_prefix': '/api/v1',
          },
        },
        txtByName: const <String, List<String>>{
          '_keli-client.panel.example': [
            'v=keli1; u=https://dns.example/keli-client.json',
          ],
        },
      ),
    );

    final candidates = await resolver.resolveLoginCandidates(
      panelUrl: 'panel.example',
      apiPrefix: '/api/v1',
      cached: ApiEndpointConfig(
        apiBase: 'https://cached.example',
        apiPrefix: '/api/v1',
        backupApiBases: const ['https://cached-backup.example'],
        panelHost: 'panel.example',
        source: 'cache',
        updatedAt: DateTime.now(),
      ),
    );

    expect(
      candidates.map((candidate) => candidate.baseUrl),
      containsAllInOrder([
        'https://cached.example',
        'https://cached-backup.example',
        'https://panel.example',
        'https://well-known-api.example',
        'https://well-known-backup.example',
        'https://dns-api.example',
        'https://bootstrap-api.example',
      ]),
    );
  });

  test('endpoint resolver accepts Ed25519 signed discovery config', () async {
    final publicKey = await _ed25519TestPublicKey();
    final signedConfig = await _ed25519SignedDiscoveryConfig(<String, Object?>{
      'api_base': 'https://signed-api.example',
      'api_prefix': '/api/v1',
      'backup_api_bases': ['https://signed-backup.example'],
      'panel_host': 'panel.example',
    });

    final resolver = ApiEndpointResolver(
      signatureVerifier: DiscoverySignatureVerifier(publicKey: publicKey),
      client: FakeDiscoveryClient(
        jsonByUrl: <String, Map<String, Object?>>{
          'https://panel.example/.well-known/keli-client.json': signedConfig,
        },
      ),
    );

    final candidates = await resolver.resolveLoginCandidates(
      panelUrl: 'https://panel.example',
      apiPrefix: '/api/v1',
    );

    expect(
      candidates.map((candidate) => candidate.baseUrl),
      containsAll(
          ['https://signed-api.example', 'https://signed-backup.example']),
    );
  });

  test('endpoint resolver ignores invalid signed discovery config', () async {
    final publicKey = await _ed25519TestPublicKey();
    final resolver = ApiEndpointResolver(
      signatureVerifier: DiscoverySignatureVerifier(publicKey: publicKey),
      client: FakeDiscoveryClient(
        jsonByUrl: <String, Map<String, Object?>>{
          'https://panel.example/.well-known/keli-client.json':
              <String, Object?>{
            'api_base': 'https://tampered-api.example',
            'api_prefix': '/api/v1',
            'panel_host': 'panel.example',
            'signature': 'ed25519:bad',
          },
        },
      ),
    );

    final candidates = await resolver.resolveLoginCandidates(
      panelUrl: 'https://panel.example',
      apiPrefix: '/api/v1',
    );

    expect(
      candidates.map((candidate) => candidate.baseUrl),
      isNot(contains('https://tampered-api.example')),
    );
  });

  test(
      'endpoint resolver requires TXT api signature when public key is configured',
      () async {
    final publicKey = await _ed25519TestPublicKey();
    final signedTxtConfig = <String, Object?>{
      'api_base': 'https://signed-txt.example',
      'api_prefix': '/api/v1',
      'panel_host': 'panel.example',
    };
    final signedTxtSignature =
        await _ed25519DiscoverySignature(signedTxtConfig);
    final resolver = ApiEndpointResolver(
      signatureVerifier: DiscoverySignatureVerifier(publicKey: publicKey),
      client: FakeDiscoveryClient(
        txtByName: <String, List<String>>{
          '_keli-client.panel.example': [
            'v=keli1; api=https://unsigned-txt.example',
            'v=keli1; api=https://signed-txt.example; sig=$signedTxtSignature',
          ],
        },
      ),
    );

    final candidates = await resolver.resolveLoginCandidates(
      panelUrl: 'https://panel.example',
      apiPrefix: '/api/v1',
    );

    final bases = candidates.map((candidate) => candidate.baseUrl);
    expect(bases, contains('https://signed-txt.example'));
    expect(bases, isNot(contains('https://unsigned-txt.example')));
  });

  test('login falls back across resolved API candidates and caches winner',
      () async {
    final temp = await Directory.systemTemp.createTemp('keli-client-test-');
    final store = SessionStore(root: temp);
    final api = RecordingLoginApi(successBaseUrl: 'https://alive.example');
    final controller = AppController(
      api: api,
      coreManager: MockCoreManager(),
      sessionStore: store,
      endpointResolver: StaticEndpointResolver(
        const [
          ApiEndpointCandidate(
            baseUrl: 'https://dead.example',
            apiPrefix: '/api/v1',
            source: 'cache',
          ),
          ApiEndpointCandidate(
            baseUrl: 'https://alive.example',
            apiPrefix: '/api/v1',
            source: 'well-known',
          ),
        ],
      ),
    );

    try {
      await controller.login(
        baseUrl: 'https://panel.example',
        apiPrefix: '/api/v1',
        email: 'test@example.com',
        password: 'password',
      );

      expect(
          api.loginBaseUrls, ['https://dead.example', 'https://alive.example']);
      expect(controller.isAuthenticated, isTrue);
      final cached = await store.loadEndpointConfig();
      expect(cached?.apiBase, 'https://alive.example');
      expect(cached?.panelHost, 'panel.example');
      expect(cached?.source, 'well-known');
    } finally {
      controller.dispose();
      await temp.delete(recursive: true);
    }
  });

  test('built-in bootstrap is skipped for a different user panel', () async {
    final resolver = ApiEndpointResolver(
      bootstrapUrls: const ['https://sp.huhu.icu/.well-known/keli-client.json'],
      client: const FakeDiscoveryClient(
        jsonByUrl: <String, Map<String, Object?>>{
          'https://sp.huhu.icu/.well-known/keli-client.json': <String, Object?>{
            'api_base': 'https://sp.huhu.icu',
            'api_prefix': '/api/v1',
          },
        },
      ),
    );

    final candidates = await resolver.resolveLoginCandidates(
      panelUrl: 'https://custom.example',
      apiPrefix: '/api/v1',
    );

    expect(
      candidates.map((candidate) => candidate.baseUrl),
      isNot(contains('https://sp.huhu.icu')),
    );
  });
}

const List<int> _ed25519Seed = <int>[
  0,
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  19,
  20,
  21,
  22,
  23,
  24,
  25,
  26,
  27,
  28,
  29,
  30,
  31,
];

Future<String> _ed25519TestPublicKey() async {
  final keyPair = await Ed25519().newKeyPairFromSeed(_ed25519Seed);
  final publicKey = await keyPair.extractPublicKey();
  return 'ed25519:${_base64UrlNoPadding(publicKey.bytes)}';
}

Future<Map<String, Object?>> _ed25519SignedDiscoveryConfig(
  Map<String, Object?> config,
) async {
  final signed = Map<String, Object?>.from(config);
  signed['signature'] = await _ed25519DiscoverySignature(signed);
  return signed;
}

Future<String> _ed25519DiscoverySignature(
  Map<String, Object?> config,
) async {
  final keyPair = await Ed25519().newKeyPairFromSeed(_ed25519Seed);
  final signature = await Ed25519().sign(
    utf8.encode(const DiscoverySignatureVerifier().signingPayload(config)),
    keyPair: keyPair,
  );
  return 'ed25519:${_base64UrlNoPadding(signature.bytes)}';
}

String _base64UrlNoPadding(List<int> bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

class FakeDiscoveryClient implements EndpointDiscoveryClient {
  const FakeDiscoveryClient({
    this.jsonByUrl = const <String, Map<String, Object?>>{},
    this.txtByName = const <String, List<String>>{},
  });

  final Map<String, Map<String, Object?>> jsonByUrl;
  final Map<String, List<String>> txtByName;

  @override
  Future<Map<String, Object?>?> fetchJson(Uri uri) async {
    return jsonByUrl['$uri'];
  }

  @override
  Future<List<String>> lookupTxt(String name) async {
    return txtByName[name] ?? const <String>[];
  }
}

class StaticEndpointResolver implements EndpointResolver {
  const StaticEndpointResolver(this.candidates);

  final List<ApiEndpointCandidate> candidates;

  @override
  Future<List<ApiEndpointCandidate>> resolveLoginCandidates({
    required String panelUrl,
    required String apiPrefix,
    ApiEndpointConfig? cached,
  }) async {
    return candidates;
  }
}

class MockKeliApi implements KeliApi {
  const MockKeliApi({
    this.nodes = const [],
    this.announcements = const [],
    this.orders = const [],
  });

  final List<ProxyNode> nodes;
  final List<Announcement> announcements;
  final List<StoreOrder> orders;

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
    String? couponCode,
  }) async {
    return 'trade-no';
  }

  @override
  Future<String> createRechargeOrder({required int amountCents}) async {
    return 'recharge-trade-no';
  }

  @override
  Future<Coupon> checkCoupon({
    required String code,
    required int planId,
    required String period,
  }) async {
    return const Coupon(type: 1, value: 100);
  }

  @override
  Future<List<PaymentMethod>> fetchPaymentMethods() async => const [];

  @override
  Future<List<StoreOrder>> fetchOrders() async => orders;

  @override
  Future<List<Announcement>> fetchAnnouncements({int maxItems = 50}) async {
    return announcements.take(maxItems).toList();
  }

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

class RecordingLoginApi extends MockKeliApi {
  RecordingLoginApi({required this.successBaseUrl});

  final String successBaseUrl;
  final List<String> loginBaseUrls = <String>[];

  @override
  Future<LoginResult> login({
    required String baseUrl,
    required String apiPrefix,
    required String email,
    required String password,
  }) async {
    loginBaseUrls.add(baseUrl);
    if (baseUrl != successBaseUrl) {
      throw const ApiException('network unavailable');
    }
    return LoginResult(
      session: ApiSession(
        baseUrl: baseUrl,
        apiPrefix: apiPrefix,
        authData: 'Bearer test',
      ),
    );
  }
}

class RecordingConnectionApi extends MockKeliApi {
  RecordingConnectionApi({required super.nodes});

  int batchConfigFetches = 0;
  int singleConfigFetches = 0;
  int? lastSingleServerId;

  @override
  Future<Map<String, Object?>> fetchSingBoxBatchConfig({
    required String platform,
    String? coreVersion,
  }) async {
    batchConfigFetches++;
    return <String, Object?>{'source': 'batch'};
  }

  @override
  Future<Map<String, Object?>> fetchSingBoxConfig({
    required int serverId,
    required String platform,
    String? coreVersion,
  }) async {
    singleConfigFetches++;
    lastSingleServerId = serverId;
    return <String, Object?>{'source': 'single', 'server_id': serverId};
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

class RecordingConnectionCoreManager extends MockCoreManager {
  Map<String, Object?>? appliedConfig;
  ProxyNode? connectedNode;

  @override
  Future<CoreApplyResult> applyConfig(
    Map<String, Object?> config, {
    ProxyMode mode = ProxyMode.system,
  }) async {
    appliedConfig = config;
    return super.applyConfig(config, mode: mode);
  }

  @override
  Future<void> connect({
    required ProxyNode node,
    required ProxyMode mode,
  }) async {
    connectedNode = node;
  }
}

class UnsupportedLatencyCoreManager extends MockCoreManager {
  @override
  bool get supportsLatencyTesting => false;
}

class ClassifyingLatencyCoreManager extends MockCoreManager {
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
    if (node.id == 1) {
      throw const CoreException('HTTP 404: proxy not found');
    }
    throw const CoreException('HTTP 504: timeout');
  }
}

class SelectedNodeRetryCoreManager extends MockCoreManager {
  @override
  Future<int?> testLatency(
    ProxyNode node, {
    Map<String, Object?>? config,
    ProxyMode mode = ProxyMode.system,
    LatencyTestMode testMode = LatencyTestMode.quick,
  }) async {
    if (testMode == LatencyTestMode.quick) {
      throw const CoreException('节点超时: Connection refused');
    }
    return 88;
  }
}

class DisconnectFailingCoreManager extends MockCoreManager {
  @override
  Future<void> disconnect() async {
    throw const CoreException('restore proxy failed');
  }
}

class FakeSessionSecretStore implements SessionSecretStore {
  const FakeSessionSecretStore();

  @override
  String get storageKind => 'fake-session-v1';

  @override
  Future<String?> protect(String value) async => 'protected:$value';

  @override
  Future<String?> unprotect(
    String value, {
    required String storageKind,
  }) async {
    if (storageKind != this.storageKind || !value.startsWith('protected:')) {
      return null;
    }
    return value.substring('protected:'.length);
  }
}
