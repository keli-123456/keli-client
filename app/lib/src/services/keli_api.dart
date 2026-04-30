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

  Future<Map<String, Object?>> fetchSingBoxConfig({
    required int serverId,
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
      final nodes = _parseNodes(data['servers'] ?? data['nodes'] ?? data['data']);
      if (nodes.isNotEmpty) {
        return BootstrapPayload(profile: profile, nodes: nodes);
      }
    } catch (_) {
      // Older Xboard deployments may not expose the app bootstrap endpoint yet.
    }

    final infoBody = await _requestWithSession('GET', '/user/info');
    final subscribeBody = await _requestWithSession('GET', '/user/getSubscribe');
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
  Future<Map<String, Object?>> fetchSingBoxConfig({
    required int serverId,
    required String platform,
    String? coreVersion,
  }) async {
    final query = <String, String>{
      'core': 'sing-box',
      'platform': platform,
      'server_id': '$serverId',
      if (coreVersion != null && coreVersion.isNotEmpty) 'core_version': coreVersion,
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
    final request = await _client.openUrl(method, uri).timeout(const Duration(seconds: 20));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.userAgentHeader, 'KeliClient/0.1.0');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    if (authenticated) {
      final authData = _session?.authData;
      if (authData == null || authData.isEmpty) {
        throw ApiException('未登录或登录已过期');
      }
      request.headers.set(HttpHeaders.authorizationHeader, authData);
    }

    final response = await request.close().timeout(const Duration(seconds: 30));
    final raw = await response.transform(utf8.decoder).join();
    if (response.statusCode == 304) {
      return <String, Object?>{'status': 'success', 'data': <String, Object?>{}};
    }
    final decoded = _decodeJson(raw);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_messageFrom(decoded) ?? 'HTTP ${response.statusCode}');
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

  Uri _buildUri(String baseUrl, String apiPrefix, String path, Map<String, String>? query) {
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
    final user = data['user'] is Map ? Map<String, Object?>.from(data['user'] as Map) : <String, Object?>{};
    final subscribe = data['subscribe'] is Map ? Map<String, Object?>.from(data['subscribe'] as Map) : <String, Object?>{};
    final plan = subscribe['plan'] is Map ? Map<String, Object?>.from(subscribe['plan'] as Map) : <String, Object?>{};
    final upload = _numValue(subscribe['u']) ?? 0;
    final download = _numValue(subscribe['d']) ?? 0;
    final total = _numValue(subscribe['transfer_enable']) ?? 0;
    final expiredAt = _intValue(subscribe['expired_at']);
    return AppProfile(
      email: _stringValue(user['email']) ?? _stringValue(subscribe['email']) ?? '未登录',
      planName: _stringValue(plan['name']) ?? '未订阅',
      expireAt: expiredAt == null || expiredAt <= 0
          ? DateTime(2099, 12, 31)
          : DateTime.fromMillisecondsSinceEpoch(expiredAt * 1000),
      usedTrafficGb: _bytesToGb(upload + download),
      totalTrafficGb: _bytesToGb(total),
      resetDay: _intValue(subscribe['reset_day']) ?? 0,
    );
  }

  List<ProxyNode> _parseNodes(Object? value) {
    if (value is List) {
      return value.whereType<Map>().map((raw) => _parseNode(Map<String, Object?>.from(raw))).toList();
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
      return value.map((item) => '$item').where((item) => item.isNotEmpty).toList();
    }
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((item) => '$item').where((item) => item.isNotEmpty).toList();
        }
      } catch (_) {
        return value.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
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

class MockKeliApi implements KeliApi {
  @override
  Future<LoginResult> login({
    required String baseUrl,
    required String apiPrefix,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return LoginResult(
      session: ApiSession(
        baseUrl: baseUrl,
        apiPrefix: apiPrefix,
        authData: 'Bearer mock-auth-data',
        subscribeToken: 'mock-token',
      ),
    );
  }

  @override
  Future<BootstrapPayload> bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    return BootstrapPayload(
      profile: AppProfile(
        email: 'user@996cloud.huhu.icu',
        planName: '旗舰套餐',
        expireAt: DateTime(2026, 6, 30, 23, 59, 59),
        usedTrafficGb: 321.6,
        totalTrafficGb: 1024,
        resetDay: 12,
      ),
      nodes: _nodes,
    );
  }

  @override
  Future<List<ProxyNode>> fetchServers() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return _nodes;
  }

  @override
  Future<Map<String, Object?>> fetchSingBoxConfig({
    required int serverId,
    required String platform,
    String? coreVersion,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return <String, Object?>{
      'log': <String, Object?>{'level': 'info'},
      'inbounds': <Object?>[
        <String, Object?>{
          'type': 'mixed',
          'listen': '127.0.0.1',
          'listen_port': 20808,
        },
      ],
      'outbounds': <Object?>[
        <String, Object?>{
          'type': 'selector',
          'tag': '节点选择',
          'default': 'server-$serverId',
          'outbounds': <String>['server-$serverId'],
        },
      ],
      'route': <String, Object?>{'auto_detect_interface': true},
      'platform': platform,
      'core_version': coreVersion,
    };
  }

  static const _nodes = <ProxyNode>[
    ProxyNode(
      id: 49,
      name: '日本-HY2-49',
      protocol: 'Hysteria2',
      rate: 1,
      isOnline: true,
      latencyMs: 304,
      tags: ['日本', '低延迟'],
    ),
    ProxyNode(
      id: 50,
      name: '日本-HY2-50',
      protocol: 'Hysteria2',
      rate: 1,
      isOnline: true,
      latencyMs: 589,
      tags: ['日本'],
    ),
    ProxyNode(
      id: 51,
      name: '日本-HY2-51',
      protocol: 'Hysteria2',
      rate: 1,
      isOnline: true,
      latencyMs: 1075,
      isFavorite: true,
      tags: ['日本', '二进制'],
    ),
    ProxyNode(
      id: 55,
      name: '新加坡-HY2-55',
      protocol: 'Hysteria2',
      rate: 1.2,
      isOnline: false,
      latencyMs: null,
      tags: ['新加坡'],
    ),
    ProxyNode(
      id: 62,
      name: '美国-VLESS-62',
      protocol: 'VLESS',
      rate: 1,
      isOnline: true,
      latencyMs: 268,
      tags: ['美国', '低延迟'],
    ),
  ];
}
