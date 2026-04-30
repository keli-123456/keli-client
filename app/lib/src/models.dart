enum ConnectionStateKind {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

enum ProxyMode {
  system,
  tun,
  vpn,
}

enum NodeFilter {
  all,
  lowLatency,
  favorite,
  hysteria2,
  vless,
}

class ApiSession {
  const ApiSession({
    required this.baseUrl,
    required this.apiPrefix,
    required this.authData,
    this.subscribeToken,
  });

  final String baseUrl;
  final String apiPrefix;
  final String authData;
  final String? subscribeToken;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'base_url': baseUrl,
      'api_prefix': apiPrefix,
      'auth_data': authData,
      'subscribe_token': subscribeToken,
    };
  }

  static ApiSession? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final baseUrl = value['base_url'];
    final apiPrefix = value['api_prefix'];
    final authData = value['auth_data'];
    if (baseUrl is! String || baseUrl.isEmpty || authData is! String || authData.isEmpty) {
      return null;
    }
    return ApiSession(
      baseUrl: baseUrl,
      apiPrefix: apiPrefix is String && apiPrefix.isNotEmpty ? apiPrefix : '/api/v1',
      authData: authData,
      subscribeToken: value['subscribe_token'] is String ? value['subscribe_token'] as String : null,
    );
  }
}

class AppProfile {
  const AppProfile({
    required this.email,
    required this.planName,
    required this.expireAt,
    required this.usedTrafficGb,
    required this.totalTrafficGb,
    required this.resetDay,
  });

  final String email;
  final String planName;
  final DateTime expireAt;
  final double usedTrafficGb;
  final double totalTrafficGb;
  final int resetDay;

  double get remainingTrafficGb => (totalTrafficGb - usedTrafficGb).clamp(0, totalTrafficGb).toDouble();
  double get usageRatio => totalTrafficGb <= 0 ? 0 : (usedTrafficGb / totalTrafficGb).clamp(0, 1).toDouble();
}

class ProxyNode {
  const ProxyNode({
    required this.id,
    required this.name,
    required this.protocol,
    required this.rate,
    required this.isOnline,
    required this.latencyMs,
    this.isFavorite = false,
    this.tags = const [],
  });

  final int id;
  final String name;
  final String protocol;
  final double rate;
  final bool isOnline;
  final int? latencyMs;
  final bool isFavorite;
  final List<String> tags;

  ProxyNode copyWith({
    int? id,
    String? name,
    String? protocol,
    double? rate,
    bool? isOnline,
    int? latencyMs,
    bool? isFavorite,
    List<String>? tags,
  }) {
    return ProxyNode(
      id: id ?? this.id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      rate: rate ?? this.rate,
      isOnline: isOnline ?? this.isOnline,
      latencyMs: latencyMs ?? this.latencyMs,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
    );
  }
}

class RuntimeStats {
  const RuntimeStats({
    required this.uploadSpeed,
    required this.downloadSpeed,
    required this.duration,
  });

  final String uploadSpeed;
  final String downloadSpeed;
  final Duration duration;
}

class CoreDiagnostics {
  const CoreDiagnostics({
    required this.updatedAt,
    required this.runtimeRoot,
    required this.corePath,
    required this.coreExists,
    required this.configPath,
    required this.configExists,
    required this.logPath,
    required this.logExists,
    required this.processRunning,
    required this.localProxyType,
    required this.localProxyListen,
    required this.localProxyPort,
    required this.systemProxyEnabled,
    required this.systemProxyServer,
    required this.configCheckStatus,
    required this.configCheckOutput,
    required this.logTail,
  });

  final DateTime updatedAt;
  final String runtimeRoot;
  final String corePath;
  final bool coreExists;
  final String configPath;
  final bool configExists;
  final String logPath;
  final bool logExists;
  final bool processRunning;
  final String localProxyType;
  final String localProxyListen;
  final int localProxyPort;
  final bool systemProxyEnabled;
  final String? systemProxyServer;
  final String configCheckStatus;
  final String configCheckOutput;
  final List<String> logTail;

  String get localProxyAddress => '$localProxyListen:$localProxyPort';

  String get localProxyDisplay => '$localProxyType://$localProxyAddress';
}

class LogEntry {
  const LogEntry({
    required this.time,
    required this.level,
    required this.message,
  });

  final DateTime time;
  final String level;
  final String message;
}
