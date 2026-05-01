import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models.dart';

abstract interface class KeliApi {
  Future<LoginResult> login({
    required String baseUrl,
    required String apiPrefix,
    required String email,
    required String password,
  });

  Future<BootstrapPayload> bootstrap();

  Future<List<ProxyNode>> fetchServers();

  Future<List<StorePlan>> fetchPlans();

  Future<List<PaymentMethod>> fetchPaymentMethods();

  Future<List<StoreOrder>> fetchOrders();

  Future<Map<String, Object?>> fetchUserConfig();

  Future<String> createOrder({
    required int planId,
    required String period,
  });

  Future<UpgradePreview> previewUpgrade({
    required int targetPlanId,
    required String period,
  });

  Future<String> confirmUpgrade({
    required String quoteToken,
  });

  Future<CheckoutResult> checkoutOrder({
    required String tradeNo,
    required String method,
  });

  Future<int> checkOrder({
    required String tradeNo,
  });

  Future<void> cancelOrder({
    required String tradeNo,
  });

  Future<Map<String, Object?>> fetchSingBoxConfig({
    required int serverId,
    required String platform,
    String? coreVersion,
  });

  Future<Map<String, Object?>> fetchSingBoxBatchConfig({
    required String platform,
    String? coreVersion,
  });
}

class LoginResult {
  const LoginResult({
    required this.session,
  });

  final ApiSession session;
}

class BootstrapPayload {
  const BootstrapPayload({
    required this.profile,
    required this.nodes,
  });

  final AppProfile profile;
  final List<ProxyNode> nodes;
}

class RealKeliApi implements KeliApi {
  RealKeliApi({
    ApiSession? session,
    HttpClient? client,
  })  : _session = session,
        _client = client ?? HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 15);
  }

  ApiSession? _session;
  final HttpClient _client;

  ApiSession? get session => _session;

  set session(ApiSession? value) {
    _session = value;
  }

  @override
  Future<LoginResult> login({
    required String baseUrl,
    required String apiPrefix,
    required String email,
    required String password,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    final prefix = _normalizeApiPrefix(apiPrefix);
    final body = await _request(
      'POST',
      normalized,
      prefix,
      '/passport/auth/login',
      body: <String, Object?>{
        'email': email.trim(),
        'password': password,
      },
      authenticated: false,
    );
    final data = _extractDataMap(body);
    final authData = _stringValue(data['auth_data']);
    if (authData == null || authData.isEmpty) {
      throw ApiException('登录成功但响应缺少 auth_data');
    }
    final session = ApiSession(
      baseUrl: normalized,
      apiPrefix: prefix,
      authData: authData,
      subscribeToken: _stringValue(data['token']),
    );
    _session = session;
    return LoginResult(session: session);
  }

  @override
  Future<BootstrapPayload> bootstrap() async {
    try {
      final body = await _requestWithSession('GET', '/app/bootstrap');
      final data = _extractDataMap(body);
      final profile = _parseProfile(data);
      final nodes =
          _parseNodes(data['servers'] ?? data['nodes'] ?? data['data']);
      if (nodes.isNotEmpty) {
        return BootstrapPayload(profile: profile, nodes: nodes);
      }
    } catch (_) {
      // Older Xboard deployments may not expose the app bootstrap endpoint yet.
    }

    final infoBody = await _requestWithSession('GET', '/user/info');
    final subscribeBody =
        await _requestWithSession('GET', '/user/getSubscribe');
    final info = _extractDataMap(infoBody);
    final subscribe = _extractDataMap(subscribeBody);
    final profile = _parseProfile(<String, Object?>{
      'user': info,
      'subscribe': subscribe,
    });
    final nodes = await fetchServers();
    return BootstrapPayload(profile: profile, nodes: nodes);
  }

  @override
  Future<List<ProxyNode>> fetchServers() async {
    final body = await _requestWithSession('GET', '/user/server/fetch');
    final payload = _extractPayload(body);
    return _parseNodes(payload);
  }

  @override
  Future<List<StorePlan>> fetchPlans() async {
    final body = await _requestWithSession('GET', '/user/plan/fetch');
    final payload = _extractPayload(body);
    return _parsePlans(payload);
  }

  @override
  Future<List<PaymentMethod>> fetchPaymentMethods() async {
    final body =
        await _requestWithSession('GET', '/user/order/getPaymentMethod');
    final payload = _extractPayload(body);
    return _parsePaymentMethods(payload);
  }

  @override
  Future<List<StoreOrder>> fetchOrders() async {
    final body = await _requestWithSession('GET', '/user/order/fetch');
    final payload = _extractPayload(body);
    return _parseOrders(payload);
  }

  @override
  Future<Map<String, Object?>> fetchUserConfig() async {
    final body = await _requestWithSession('GET', '/user/comm/config');
    final payload = _extractPayload(body);
    if (payload is Map) {
      return Map<String, Object?>.from(payload);
    }
    return <String, Object?>{};
  }

  @override
  Future<String> createOrder({
    required int planId,
    required String period,
  }) async {
    final body = await _requestWithSession(
      'POST',
      '/user/order/save',
      body: <String, Object?>{
        'plan_id': planId,
        'period': period,
      },
    );
    final payload = _extractPayload(body);
    final tradeNo = _tradeNoFromPayload(payload);
    if (tradeNo == null || tradeNo.isEmpty) {
      throw ApiException('订单创建成功但缺少 trade_no');
    }
    return tradeNo;
  }

  @override
  Future<UpgradePreview> previewUpgrade({
    required int targetPlanId,
    required String period,
  }) async {
    final body = await _requestWithSession(
      'POST',
      '/user/order/upgrade/preview',
      body: <String, Object?>{
        'target_plan_id': targetPlanId,
        'period': period,
      },
    );
    final payload = _extractPayload(body);
    if (payload is! Map) {
      throw ApiException('升级预览响应格式错误');
    }
    return _parseUpgradePreview(Map<String, Object?>.from(payload));
  }

  @override
  Future<String> confirmUpgrade({
    required String quoteToken,
  }) async {
    final body = await _requestWithSession(
      'POST',
      '/user/order/upgrade/confirm',
      body: <String, Object?>{'quote_token': quoteToken},
    );
    final payload = _extractPayload(body);
    final tradeNo = _tradeNoFromPayload(payload);
    if (tradeNo == null || tradeNo.isEmpty) {
      throw ApiException('升级订单创建成功但缺少 trade_no');
    }
    return tradeNo;
  }

  @override
  Future<CheckoutResult> checkoutOrder({
    required String tradeNo,
    required String method,
  }) async {
    final body = await _requestWithSession(
      'POST',
      '/user/order/checkout',
      body: <String, Object?>{
        'trade_no': tradeNo,
        'method': method,
      },
    );
    final payload = _extractPayload(body);
    if (payload is Map) {
      final map = Map<String, Object?>.from(payload);
      return CheckoutResult(
        type: _intValue(map['type']) ?? _intValue(body['type']) ?? 0,
        data: map.containsKey('data') ? map['data'] : body['data'],
      );
    }
    return CheckoutResult(
      type: _intValue(body['type']) ?? 0,
      data: body['data'],
    );
  }

  @override
  Future<int> checkOrder({
    required String tradeNo,
  }) async {
    final body = await _requestWithSession(
      'GET',
      '/user/order/check',
      query: <String, String>{'trade_no': tradeNo},
    );
    return _intValue(_extractPayload(body)) ?? 0;
  }

  @override
  Future<void> cancelOrder({
    required String tradeNo,
  }) async {
    await _requestWithSession(
      'POST',
      '/user/order/cancel',
      body: <String, Object?>{'trade_no': tradeNo},
    );
  }

  @override
  Future<Map<String, Object?>> fetchSingBoxConfig({
    required int serverId,
    required String platform,
    String? coreVersion,
  }) async {
    return _fetchSingBoxConfig(
      platform: platform,
      coreVersion: coreVersion,
      serverId: serverId,
    );
  }

  @override
  Future<Map<String, Object?>> fetchSingBoxBatchConfig({
    required String platform,
    String? coreVersion,
  }) async {
    return _fetchSingBoxConfig(
      platform: platform,
      coreVersion: coreVersion,
    );
  }

  Future<Map<String, Object?>> _fetchSingBoxConfig({
    required String platform,
    String? coreVersion,
    int? serverId,
  }) async {
    final query = <String, String>{
      'core': 'sing-box',
      'platform': platform,
      if (serverId != null) 'server_id': '$serverId',
      if (coreVersion != null && coreVersion.isNotEmpty)
        'core_version': coreVersion,
    };
    final body = await _requestWithSession('GET', '/app/config', query: query);
    final data = _extractDataMap(body);
    return Map<String, Object?>.from(data);
  }

  Future<Map<String, Object?>> _requestWithSession(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final session = _session;
    if (session == null) {
      throw ApiException('未登录或登录已过期');
    }
    return _request(
      method,
      session.baseUrl,
      session.apiPrefix,
      path,
      query: query,
      body: body,
      authenticated: true,
    );
  }

  Future<Map<String, Object?>> _request(
    String method,
    String baseUrl,
    String apiPrefix,
    String path, {
    Map<String, String>? query,
    Object? body,
    required bool authenticated,
  }) async {
    final uri = _buildUri(baseUrl, apiPrefix, path, query);
    final request =
        await _client.openUrl(method, uri).timeout(const Duration(seconds: 20));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.userAgentHeader, 'KeliClient/0.1.0');
    if (authenticated) {
      final authData = _session?.authData;
      if (authData == null || authData.isEmpty) {
        throw ApiException('未登录或登录已过期');
      }
      request.headers.set(HttpHeaders.authorizationHeader, authData);
    }
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }

    final response = await request.close().timeout(const Duration(seconds: 30));
    final raw = await response.transform(utf8.decoder).join();
    if (response.statusCode == 304) {
      return <String, Object?>{
        'status': 'success',
        'data': <String, Object?>{}
      };
    }
    final decoded = _decodeJson(raw);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
          _messageFrom(decoded) ?? 'HTTP ${response.statusCode}');
    }
    if (decoded is Map<String, Object?>) {
      final status = decoded['status'];
      if (status is String && status.toLowerCase() == 'fail') {
        throw ApiException(_messageFrom(decoded) ?? '请求失败');
      }
      return decoded;
    }
    throw ApiException('响应格式不是 JSON 对象');
  }

  Uri _buildUri(String baseUrl, String apiPrefix, String path,
      Map<String, String>? query) {
    final base = Uri.parse(baseUrl);
    final segments = <String>[
      ...base.pathSegments.where((segment) => segment.isNotEmpty),
      ...apiPrefix.split('/').where((segment) => segment.isNotEmpty),
      ...path.split('/').where((segment) => segment.isNotEmpty),
    ];
    return base.replace(pathSegments: segments, queryParameters: query);
  }

  Object? _decodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      throw ApiException(raw.isEmpty ? '服务端返回空响应' : '服务端返回非 JSON 响应');
    }
  }

  Object? _extractPayload(Map<String, Object?> body) {
    if (body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  Map<String, Object?> _extractDataMap(Map<String, Object?> body) {
    final data = body['data'];
    if (data is Map) {
      return Map<String, Object?>.from(data);
    }
    if (body.containsKey('servers') || body.containsKey('nodes')) {
      return body;
    }
    return <String, Object?>{};
  }

  AppProfile _parseProfile(Map<String, Object?> data) {
    final user = data['user'] is Map
        ? Map<String, Object?>.from(data['user'] as Map)
        : <String, Object?>{};
    final subscribe = data['subscribe'] is Map
        ? Map<String, Object?>.from(data['subscribe'] as Map)
        : <String, Object?>{};
    final plan = subscribe['plan'] is Map
        ? Map<String, Object?>.from(subscribe['plan'] as Map)
        : <String, Object?>{};
    final upload = _numValue(subscribe['u']) ?? 0;
    final download = _numValue(subscribe['d']) ?? 0;
    final total = _numValue(subscribe['transfer_enable']) ?? 0;
    final expiredAt =
        _intValue(subscribe['expired_at']) ?? _intValue(user['expired_at']);
    final nextResetAt =
        _dateTimeValue(subscribe['next_reset_at'] ?? user['next_reset_at']);
    final resetDays = nextResetAt == null
        ? 0
        : nextResetAt.difference(DateTime.now()).inDays.clamp(0, 9999).toInt();
    return AppProfile(
      email: _stringValue(user['email']) ??
          _stringValue(subscribe['email']) ??
          '未登录',
      uuid: _stringValue(subscribe['uuid']) ?? _stringValue(user['uuid']),
      avatarUrl: _stringValue(user['avatar_url']),
      planName: _stringValue(plan['name']) ?? '未订阅',
      planId: _intValue(subscribe['plan_id']) ??
          _intValue(user['plan_id']) ??
          _intValue(plan['id']) ??
          0,
      upgradeTargetPlanIds: _intList(plan['upgrade_to_plan_ids']),
      deviceLimit: _intValue(subscribe['device_limit']) ??
          _intValue(user['device_limit']) ??
          _intValue(plan['device_limit']),
      speedLimit: (_numValue(subscribe['speed_limit']) ??
              _numValue(user['speed_limit']) ??
              _numValue(plan['speed_limit']))
          ?.toDouble(),
      nextResetAt: nextResetAt,
      expireAt: expiredAt == null || expiredAt <= 0
          ? DateTime(2099, 12, 31)
          : DateTime.fromMillisecondsSinceEpoch(expiredAt * 1000),
      usedTrafficGb: _bytesToGb(upload + download),
      totalTrafficGb: _bytesToGb(total),
      resetDay: _intValue(subscribe['reset_day']) ?? resetDays,
    );
  }

  List<StorePlan> _parsePlans(Object? value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((raw) => _parsePlan(Map<String, Object?>.from(raw)))
          .where((plan) => plan.sell)
          .toList()
        ..sort((a, b) => a.sort.compareTo(b.sort));
    }
    if (value is Map) {
      if (value['data'] != null) {
        return _parsePlans(value['data']);
      }
      return value.values
          .whereType<Map>()
          .map((raw) => _parsePlan(Map<String, Object?>.from(raw)))
          .where((plan) => plan.sell)
          .toList()
        ..sort((a, b) => a.sort.compareTo(b.sort));
    }
    return const [];
  }

  StorePlan _parsePlan(Map<String, Object?> raw) {
    return StorePlan(
      id: _intValue(raw['id']) ?? 0,
      name: _stringValue(raw['name']) ?? '未命名套餐',
      content: _stringValue(raw['content']) ?? '',
      prices: _parsePlanPrices(raw),
      transferEnable: (_numValue(raw['transfer_enable']) ?? 0).toDouble(),
      speedLimit: _numValue(raw['speed_limit'])?.toDouble(),
      deviceLimit: _intValue(raw['device_limit']),
      sell: raw.containsKey('sell') ? _boolValue(raw['sell']) : true,
      renew: raw.containsKey('renew') ? _boolValue(raw['renew']) : true,
      sort: _intValue(raw['sort']) ?? 999,
      resetTrafficMethod: _intValue(raw['reset_traffic_method']),
      tags: _parseTags(raw['tags']),
    );
  }

  Map<String, int> _parsePlanPrices(Map<String, Object?> raw) {
    final prices = <String, int>{};
    final modern = raw['prices'];
    if (modern is Map) {
      const mapping = <String, String>{
        'monthly': 'month_price',
        'quarterly': 'quarter_price',
        'half_yearly': 'half_year_price',
        'yearly': 'year_price',
        'two_yearly': 'two_year_price',
        'three_yearly': 'three_year_price',
        'onetime': 'onetime_price',
        'reset_traffic': 'reset_price',
      };
      for (final entry in modern.entries) {
        final key = mapping['${entry.key}'] ?? '${entry.key}';
        final value = _intValue(entry.value) ?? 0;
        if (value > 0) {
          prices[key] = value;
        }
      }
    }

    for (final definition in planPeriodDefinitions) {
      final value = _intValue(raw[definition.period]) ?? 0;
      if (value > 0) {
        prices[definition.period] = value;
      }
    }
    return prices;
  }

  List<PaymentMethod> _parsePaymentMethods(Object? value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((raw) => _parsePaymentMethod(Map<String, Object?>.from(raw)))
          .where((method) => method.id.isNotEmpty)
          .toList();
    }
    if (value is Map && value['data'] != null) {
      return _parsePaymentMethods(value['data']);
    }
    return const [];
  }

  PaymentMethod _parsePaymentMethod(Map<String, Object?> raw) {
    return PaymentMethod(
      id: _stringValue(raw['id']) ?? '',
      name: _stringValue(raw['name']) ?? _stringValue(raw['payment']) ?? '支付方式',
      payment: _stringValue(raw['payment']) ?? '',
    );
  }

  List<StoreOrder> _parseOrders(Object? value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((raw) => _parseOrder(Map<String, Object?>.from(raw)))
          .where((order) => order.tradeNo.isNotEmpty)
          .toList();
    }
    if (value is Map) {
      if (value['data'] != null) {
        return _parseOrders(value['data']);
      }
      return value.values
          .whereType<Map>()
          .map((raw) => _parseOrder(Map<String, Object?>.from(raw)))
          .where((order) => order.tradeNo.isNotEmpty)
          .toList();
    }
    return const [];
  }

  StoreOrder _parseOrder(Map<String, Object?> raw) {
    final plan = raw['plan'] is Map
        ? Map<String, Object?>.from(raw['plan'] as Map)
        : <String, Object?>{};
    final upgradeSnapshot = raw['upgrade_pricing_snapshot'] is Map
        ? Map<String, Object?>.from(raw['upgrade_pricing_snapshot'] as Map)
        : <String, Object?>{};
    final sourcePlan = upgradeSnapshot['source_plan'] is Map
        ? Map<String, Object?>.from(upgradeSnapshot['source_plan'] as Map)
        : <String, Object?>{};
    final targetPlan = upgradeSnapshot['target_plan'] is Map
        ? Map<String, Object?>.from(upgradeSnapshot['target_plan'] as Map)
        : <String, Object?>{};
    return StoreOrder(
      id: _intValue(raw['id']),
      planId: _intValue(raw['plan_id']),
      type: _intValue(raw['type']),
      planName: _stringValue(plan['name']),
      upgradeSourcePlanName: _stringValue(sourcePlan['name']),
      upgradeTargetPlanName: _stringValue(targetPlan['name']),
      tradeNo: _stringValue(raw['trade_no']) ?? '',
      period: _stringValue(raw['period']) ?? '',
      status: _intValue(raw['status']) ?? 0,
      totalAmountCents: _intValue(raw['total_amount']) ?? 0,
      handlingAmountCents: _intValue(raw['handling_amount']),
      balanceAmountCents: _intValue(raw['balance_amount']),
      discountAmountCents: _intValue(raw['discount_amount']),
      upgradeCreditAmountCents: _intValue(raw['upgrade_credit_amount']),
      createdAt: _dateTimeValue(raw['created_at']),
    );
  }

  UpgradePreview _parseUpgradePreview(Map<String, Object?> raw) {
    final pricing = raw['pricing_detail'] is Map
        ? Map<String, Object?>.from(raw['pricing_detail'] as Map)
        : <String, Object?>{};
    final sourcePlan = raw['source_plan'] is Map
        ? Map<String, Object?>.from(raw['source_plan'] as Map)
        : <String, Object?>{};
    final targetPlan = raw['target_plan'] is Map
        ? Map<String, Object?>.from(raw['target_plan'] as Map)
        : <String, Object?>{};
    return UpgradePreview(
      allowUpgrade: _boolValue(raw['allow_upgrade'] ?? raw['allowUpgrade']),
      reason: _stringValue(raw['reason']),
      quoteToken: _stringValue(raw['quote_token'] ?? raw['quoteToken']),
      payableAmountCents: _intValue(raw['payable_amount'] ??
          raw['quoted_payable_amount'] ??
          pricing['final_pay_amount']),
      targetPriceCents:
          _intValue(pricing['target_price'] ?? raw['target_price']),
      upgradeCreditAmountCents: _intValue(
          pricing['upgrade_credit_amount'] ?? raw['upgrade_credit_amount']),
      sourcePlanName: _stringValue(sourcePlan['name']),
      targetPlanName: _stringValue(targetPlan['name']),
    );
  }

  List<ProxyNode> _parseNodes(Object? value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((raw) => _parseNode(Map<String, Object?>.from(raw)))
          .toList();
    }
    if (value is Map) {
      if (value['servers'] != null) {
        return _parseNodes(value['servers']);
      }
      if (value['nodes'] != null) {
        return _parseNodes(value['nodes']);
      }
      if (value['data'] != null) {
        return _parseNodes(value['data']);
      }
      final nodes = <ProxyNode>[];
      for (final entry in value.entries) {
        final grouped = entry.value;
        if (grouped is List) {
          for (final item in grouped.whereType<Map>()) {
            final raw = Map<String, Object?>.from(item);
            raw.putIfAbsent('type', () => '${entry.key}');
            nodes.add(_parseNode(raw));
          }
        }
      }
      return nodes;
    }
    return const [];
  }

  ProxyNode _parseNode(Map<String, Object?> raw) {
    final type = _stringValue(raw['type']) ?? 'unknown';
    final version = _intValue(raw['version']);
    return ProxyNode(
      id: _intValue(raw['id']) ?? 0,
      name: _stringValue(raw['name']) ?? '未命名节点',
      protocol: _displayProtocol(type, version),
      rate: (_numValue(raw['rate']) ?? 1).toDouble(),
      isOnline: _boolValue(raw['is_online']),
      latencyMs: null,
      tags: _parseTags(raw['tags']),
    );
  }

  List<String> _parseTags(Object? value) {
    if (value is List) {
      return value
          .map((item) => '$item')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((item) => '$item')
              .where((item) => item.isNotEmpty)
              .toList();
        }
      } catch (_) {
        return value
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }

  String _displayProtocol(String type, int? version) {
    return switch (type.toLowerCase()) {
      'hysteria' => version == 2 ? 'Hysteria2' : 'Hysteria',
      'vless' => 'VLESS',
      'vmess' => 'VMess',
      'trojan' => 'Trojan',
      'shadowsocks' => 'Shadowsocks',
      'tuic' => 'TUIC',
      'anytls' => 'AnyTLS',
      _ => type,
    };
  }

  static String _normalizeBaseUrl(String value) {
    var url = value.trim();
    if (url.isEmpty) {
      throw ApiException('请输入面板地址');
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    return url.replaceAll(RegExp(r'/+$'), '');
  }

  static String _normalizeApiPrefix(String value) {
    var prefix = value.trim();
    if (prefix.isEmpty) {
      prefix = '/api/v1';
    }
    if (!prefix.startsWith('/')) {
      prefix = '/$prefix';
    }
    return prefix.replaceAll(RegExp(r'/+$'), '');
  }

  String? _messageFrom(Object? decoded) {
    if (decoded is Map) {
      final message = decoded['message'] ?? decoded['error'];
      if (message != null) {
        return '$message';
      }
    }
    return null;
  }

  String? _stringValue(Object? value) => value == null ? null : '$value';

  num? _numValue(Object? value) {
    if (value is num) {
      return value;
    }
    if (value is String) {
      return num.tryParse(value);
    }
    return null;
  }

  int? _intValue(Object? value) => _numValue(value)?.toInt();

  DateTime? _dateTimeValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      if (value <= 0) {
        return null;
      }
      final milliseconds =
          value > 10000000000 ? value.toInt() : value.toInt() * 1000;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }
    final raw = '$value'.trim();
    if (raw.isEmpty) {
      return null;
    }
    final parsedNum = num.tryParse(raw);
    if (parsedNum != null) {
      return _dateTimeValue(parsedNum);
    }
    return DateTime.tryParse(raw)?.toLocal();
  }

  String? _tradeNoFromPayload(Object? payload) {
    if (payload is Map) {
      for (final key in ['trade_no', 'tradeNo', 'tradeNoStr']) {
        final value = _stringValue(payload[key]);
        if (value != null && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      final nested = payload['data'];
      if (nested != null && nested != payload) {
        return _tradeNoFromPayload(nested);
      }
      return null;
    }
    final value = _stringValue(payload);
    return value == null || value.trim().isEmpty ? null : value.trim();
  }

  List<int> _intList(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return const [];
      }
      try {
        return _intList(jsonDecode(trimmed));
      } catch (_) {
        return trimmed
            .split(',')
            .map((item) => int.tryParse(item.trim()) ?? 0)
            .where((item) => item > 0)
            .toSet()
            .toList();
      }
    }
    if (value is List) {
      return value
          .map((item) => _intValue(item) ?? 0)
          .where((item) => item > 0)
          .toSet()
          .toList();
    }
    return const [];
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

  double _bytesToGb(num value) => value <= 0 ? 0 : value / 1024 / 1024 / 1024;
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
