import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../app_metadata.dart';

const String defaultApiPrefix = '/api/v1';
const List<String> builtInBootstrapUrls = <String>[
  'https://sp.huhu.icu/.well-known/keli-client.json',
];

abstract interface class EndpointResolver {
  Future<List<ApiEndpointCandidate>> resolveLoginCandidates({
    required String panelUrl,
    required String apiPrefix,
    ApiEndpointConfig? cached,
  });
}

class ApiEndpointCandidate {
  const ApiEndpointCandidate({
    required this.baseUrl,
    required this.apiPrefix,
    required this.source,
  });

  final String baseUrl;
  final String apiPrefix;
  final String source;

  String get key => '${baseUrl.toLowerCase()}|$apiPrefix';

  ApiEndpointConfig toCacheConfig({
    required String panelHost,
    List<String> backupApiBases = const [],
    List<String> bootstrapUrls = const [],
  }) {
    return ApiEndpointConfig(
      apiBase: baseUrl,
      apiPrefix: apiPrefix,
      backupApiBases: backupApiBases,
      bootstrapUrls: bootstrapUrls,
      panelHost: panelHost,
      source: source,
      updatedAt: DateTime.now(),
    );
  }
}

class ApiEndpointConfig {
  const ApiEndpointConfig({
    required this.apiBase,
    required this.apiPrefix,
    required this.source,
    required this.updatedAt,
    this.backupApiBases = const [],
    this.bootstrapUrls = const [],
    this.panelHost,
    this.expiresAt,
    this.signature,
  });

  final String apiBase;
  final String apiPrefix;
  final List<String> backupApiBases;
  final List<String> bootstrapUrls;
  final String? panelHost;
  final String source;
  final DateTime updatedAt;
  final DateTime? expiresAt;
  final String? signature;

  bool get isExpired {
    final expires = expiresAt;
    return expires != null && !expires.isAfter(DateTime.now());
  }

  ApiEndpointCandidate get primaryCandidate {
    return ApiEndpointCandidate(
      baseUrl: apiBase,
      apiPrefix: apiPrefix,
      source: source,
    );
  }

  Iterable<ApiEndpointCandidate> backupCandidates() sync* {
    for (final base in backupApiBases) {
      yield ApiEndpointCandidate(
        baseUrl: base,
        apiPrefix: apiPrefix,
        source: '$source backup',
      );
    }
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'api_base': apiBase,
      'api_prefix': apiPrefix,
      'backup_api_bases': backupApiBases,
      'bootstrap_urls': bootstrapUrls,
      'panel_host': panelHost,
      'source': source,
      'updated_at': updatedAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'signature': signature,
    };
  }

  static ApiEndpointConfig? fromJson(Object? value, {String source = 'cache'}) {
    if (value is! Map) {
      return null;
    }
    final map = Map<String, Object?>.from(value);
    final apiBase = _stringValue(
      map['api_base'] ?? map['apiBase'] ?? map['base_url'] ?? map['baseUrl'],
    );
    if (apiBase == null || apiBase.trim().isEmpty) {
      return null;
    }
    final apiPrefix = _stringValue(
          map['api_prefix'] ?? map['apiPrefix'] ?? map['prefix'],
        ) ??
        defaultApiPrefix;
    final ttlSeconds = _intValue(map['ttl'] ?? map['ttl_seconds']);
    final updatedAt = _dateTimeValue(map['updated_at']) ?? DateTime.now();
    return ApiEndpointConfig(
      apiBase: normalizeBaseUrl(apiBase),
      apiPrefix: normalizeApiPrefix(apiPrefix),
      backupApiBases: _stringList(
        map['backup_api_bases'] ?? map['backupApiBases'] ?? map['backups'],
      ).map(normalizeBaseUrl).toList(),
      bootstrapUrls: _stringList(
        map['bootstrap_urls'] ?? map['bootstrapUrls'] ?? map['bootstrap'],
      ),
      panelHost: _stringValue(map['panel_host'] ?? map['panelHost']),
      source: _stringValue(map['source']) ?? source,
      updatedAt: updatedAt,
      expiresAt: _dateTimeValue(map['expires_at']) ??
          (ttlSeconds == null
              ? null
              : updatedAt.add(Duration(seconds: ttlSeconds))),
      signature: _stringValue(map['signature']),
    );
  }
}

class ApiEndpointResolver implements EndpointResolver {
  ApiEndpointResolver({
    EndpointDiscoveryClient? client,
    List<String> bootstrapUrls = builtInBootstrapUrls,
  })  : _client = client ?? HttpEndpointDiscoveryClient(),
        _bootstrapUrls = bootstrapUrls;

  final EndpointDiscoveryClient _client;
  final List<String> _bootstrapUrls;

  @override
  Future<List<ApiEndpointCandidate>> resolveLoginCandidates({
    required String panelUrl,
    required String apiPrefix,
    ApiEndpointConfig? cached,
  }) async {
    final candidates = <ApiEndpointCandidate>[];
    final seen = <String>{};

    void add(ApiEndpointCandidate candidate) {
      if (seen.add(candidate.key)) {
        candidates.add(candidate);
      }
    }

    final normalizedPanel = normalizeBaseUrl(panelUrl);
    final normalizedPrefix = normalizeApiPrefix(apiPrefix);

    if (cached != null &&
        !cached.isExpired &&
        _cacheMatchesPanel(cached, normalizedPanel)) {
      add(cached.primaryCandidate);
      for (final backup in cached.backupCandidates()) {
        add(backup);
      }
    }

    add(ApiEndpointCandidate(
      baseUrl: normalizedPanel,
      apiPrefix: normalizedPrefix,
      source: 'manual',
    ));

    await _appendWellKnownCandidates(
      normalizedPanel,
      source: 'well-known',
      add: add,
    );
    await _appendTxtCandidates(normalizedPanel, add: add);

    final bootstrapUrls = <String>{
      if (cached != null && _cacheMatchesPanel(cached, normalizedPanel))
        ...cached.bootstrapUrls,
      if (_shouldUseBuiltInBootstrap(normalizedPanel)) ..._bootstrapUrls,
    };
    for (final bootstrapUrl in bootstrapUrls) {
      await _appendRemoteConfigCandidates(
        bootstrapUrl,
        source: 'bootstrap',
        add: add,
      );
    }

    return candidates;
  }

  bool _cacheMatchesPanel(ApiEndpointConfig cached, String panelUrl) {
    final panelHost = Uri.parse(panelUrl).host.toLowerCase();
    final cachedPanelHost = cached.panelHost?.toLowerCase();
    if (cachedPanelHost != null && cachedPanelHost.isNotEmpty) {
      return cachedPanelHost == panelHost;
    }
    return Uri.parse(cached.apiBase).host.toLowerCase() == panelHost;
  }

  bool _shouldUseBuiltInBootstrap(String panelUrl) {
    final panelHost = Uri.parse(panelUrl).host.toLowerCase();
    return _bootstrapUrls.any((url) {
      try {
        return Uri.parse(url).host.toLowerCase() == panelHost;
      } catch (_) {
        return false;
      }
    });
  }

  Future<void> _appendWellKnownCandidates(
    String panelUrl, {
    required String source,
    required void Function(ApiEndpointCandidate) add,
  }) async {
    final uri = Uri.parse(panelUrl).replace(
      pathSegments: <String>[
        ...Uri.parse(panelUrl)
            .pathSegments
            .where((segment) => segment.isNotEmpty),
        '.well-known',
        'keli-client.json',
      ],
      queryParameters: null,
    );
    final config = await _fetchConfig(uri, source);
    _appendConfigCandidates(config, add);
  }

  Future<void> _appendTxtCandidates(
    String panelUrl, {
    required void Function(ApiEndpointCandidate) add,
  }) async {
    final host = Uri.parse(panelUrl).host;
    if (host.isEmpty) {
      return;
    }
    final records = await _client.lookupTxt('_keli-client.$host');
    for (final record in records) {
      final parsed = _parseTxtRecord(record);
      final configUrl = parsed['u'] ?? parsed['url'] ?? parsed['bootstrap'];
      if (configUrl != null && configUrl.startsWith('https://')) {
        final config = await _fetchConfig(Uri.parse(configUrl), 'dns-txt');
        _appendConfigCandidates(config, add);
      }
      final apiBase = parsed['api'] ?? parsed['api_base'] ?? parsed['base'];
      if (apiBase != null) {
        final prefix =
            parsed['prefix'] ?? parsed['api_prefix'] ?? defaultApiPrefix;
        try {
          add(ApiEndpointCandidate(
            baseUrl: normalizeBaseUrl(apiBase),
            apiPrefix: normalizeApiPrefix(prefix),
            source: 'dns-txt',
          ));
        } catch (_) {
          // Ignore malformed TXT records.
        }
      }
    }
  }

  Future<void> _appendRemoteConfigCandidates(
    String url, {
    required String source,
    required void Function(ApiEndpointCandidate) add,
  }) async {
    Uri uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      return;
    }
    if (uri.scheme != 'https') {
      return;
    }
    final config = await _fetchConfig(uri, source);
    _appendConfigCandidates(config, add);
  }

  Future<ApiEndpointConfig?> _fetchConfig(Uri uri, String source) async {
    try {
      final json = await _client.fetchJson(uri);
      return ApiEndpointConfig.fromJson(json, source: source);
    } catch (_) {
      return null;
    }
  }

  void _appendConfigCandidates(
    ApiEndpointConfig? config,
    void Function(ApiEndpointCandidate) add,
  ) {
    if (config == null || config.isExpired) {
      return;
    }
    add(config.primaryCandidate);
    for (final backup in config.backupCandidates()) {
      add(backup);
    }
  }

  Map<String, String> _parseTxtRecord(String record) {
    final normalized = record.replaceAll('" "', '').replaceAll('"', '').trim();
    final parts = normalized.split(';');
    final values = <String, String>{};
    for (final part in parts) {
      final index = part.indexOf('=');
      if (index <= 0) {
        continue;
      }
      final key = part.substring(0, index).trim().toLowerCase();
      final value = part.substring(index + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        values[key] = value;
      }
    }
    if (values['v'] != null && values['v'] != 'keli1') {
      return const <String, String>{};
    }
    return values;
  }
}

abstract interface class EndpointDiscoveryClient {
  Future<Map<String, Object?>?> fetchJson(Uri uri);

  Future<List<String>> lookupTxt(String name);
}

class HttpEndpointDiscoveryClient implements EndpointDiscoveryClient {
  HttpEndpointDiscoveryClient({HttpClient? client})
      : _client = client ?? HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 8);
  }

  final HttpClient _client;

  @override
  Future<Map<String, Object?>?> fetchJson(Uri uri) async {
    final request =
        await _client.getUrl(uri).timeout(const Duration(seconds: 10));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.userAgentHeader, keliClientUserAgent);
    final response = await request.close().timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final raw = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return Map<String, Object?>.from(decoded);
    }
    return null;
  }

  @override
  Future<List<String>> lookupTxt(String name) async {
    final answers = <String>[];
    for (final uri in <Uri>[
      Uri.https('cloudflare-dns.com', '/dns-query',
          <String, String>{'name': name, 'type': 'TXT'}),
      Uri.https('dns.google', '/resolve',
          <String, String>{'name': name, 'type': 'TXT'}),
    ]) {
      try {
        final request =
            await _client.getUrl(uri).timeout(const Duration(seconds: 8));
        request.headers.set(HttpHeaders.acceptHeader, 'application/dns-json');
        request.headers.set(HttpHeaders.userAgentHeader, keliClientUserAgent);
        final response =
            await request.close().timeout(const Duration(seconds: 10));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }
        final raw = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(raw);
        if (decoded is! Map || decoded['Answer'] is! List) {
          continue;
        }
        for (final answer in (decoded['Answer'] as List).whereType<Map>()) {
          final data = answer['data'];
          if (data is String && data.trim().isNotEmpty) {
            answers.add(data.trim());
          }
        }
        if (answers.isNotEmpty) {
          break;
        }
      } catch (_) {
        continue;
      }
    }
    return answers;
  }
}

String normalizeBaseUrl(String value) {
  var url = value.trim();
  if (url.isEmpty) {
    throw const EndpointResolutionException('请输入面板地址');
  }
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'https://$url';
  }
  return url.replaceAll(RegExp(r'/+$'), '');
}

String normalizeApiPrefix(String value) {
  var prefix = value.trim();
  if (prefix.isEmpty) {
    prefix = defaultApiPrefix;
  }
  if (!prefix.startsWith('/')) {
    prefix = '/$prefix';
  }
  return prefix.replaceAll(RegExp(r'/+$'), '');
}

class EndpointResolutionException implements Exception {
  const EndpointResolutionException(this.message);

  final String message;

  @override
  String toString() => message;
}

String? _stringValue(Object? value) => value == null ? null : '$value';

int? _intValue(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return num.tryParse(value)?.toInt();
  }
  return null;
}

DateTime? _dateTimeValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
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

List<String> _stringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const <String>[];
}
