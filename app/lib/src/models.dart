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
    if (baseUrl is! String ||
        baseUrl.isEmpty ||
        authData is! String ||
        authData.isEmpty) {
      return null;
    }
    return ApiSession(
      baseUrl: baseUrl,
      apiPrefix:
          apiPrefix is String && apiPrefix.isNotEmpty ? apiPrefix : '/api/v1',
      authData: authData,
      subscribeToken: value['subscribe_token'] is String
          ? value['subscribe_token'] as String
          : null,
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
    this.uuid,
    this.avatarUrl,
    this.deviceLimit,
    this.speedLimit,
    this.nextResetAt,
    this.planId = 0,
    this.upgradeTargetPlanIds = const [],
  });

  final String email;
  final String planName;
  final DateTime expireAt;
  final double usedTrafficGb;
  final double totalTrafficGb;
  final int resetDay;
  final String? uuid;
  final String? avatarUrl;
  final int? deviceLimit;
  final double? speedLimit;
  final DateTime? nextResetAt;
  final int planId;
  final List<int> upgradeTargetPlanIds;

  double get remainingTrafficGb =>
      (totalTrafficGb - usedTrafficGb).clamp(0, totalTrafficGb).toDouble();
  double get usageRatio => totalTrafficGb <= 0
      ? 0
      : (usedTrafficGb / totalTrafficGb).clamp(0, 1).toDouble();
  bool get hasActiveSubscription =>
      (planId > 0 || planName.trim().isNotEmpty && planName != '未订阅') &&
      (expireAt.year >= 2099 || expireAt.isAfter(DateTime.now()));
}

class StorePlan {
  const StorePlan({
    required this.id,
    required this.name,
    required this.content,
    required this.prices,
    required this.transferEnable,
    required this.speedLimit,
    required this.deviceLimit,
    required this.sell,
    required this.renew,
    required this.sort,
    this.tags = const [],
  });

  final int id;
  final String name;
  final String content;
  final Map<String, int> prices;
  final double transferEnable;
  final double? speedLimit;
  final int? deviceLimit;
  final bool sell;
  final bool renew;
  final int sort;
  final List<String> tags;

  List<PlanPeriodOption> get periodOptions {
    return planPeriodDefinitions
        .where((item) => (prices[item.period] ?? 0) > 0)
        .map((item) => item.copyWith(priceCents: prices[item.period] ?? 0))
        .toList();
  }

  bool get hasRecurringOptions {
    return periodOptions
        .any((option) => recurringUpgradePeriodKeys.contains(option.period));
  }

  String get trafficLabel {
    if (transferEnable <= 0) {
      return '0 GB';
    }
    final gb = transferEnable < 10000
        ? transferEnable
        : transferEnable / 1024 / 1024 / 1024;
    if (gb >= 1024) {
      return '${(gb / 1024).toStringAsFixed(1)} TB';
    }
    return '${gb.toStringAsFixed(gb >= 100 ? 0 : 1)} GB';
  }
}

class PlanPeriodOption {
  const PlanPeriodOption({
    required this.period,
    required this.label,
    required this.months,
    required this.priceCents,
  });

  final String period;
  final String label;
  final int months;
  final int priceCents;

  PlanPeriodOption copyWith({int? priceCents}) {
    return PlanPeriodOption(
      period: period,
      label: label,
      months: months,
      priceCents: priceCents ?? this.priceCents,
    );
  }
}

const recurringUpgradePeriodKeys = <String>{
  'month_price',
  'quarter_price',
  'half_year_price',
  'year_price',
  'two_year_price',
  'three_year_price',
};

const planPeriodDefinitions = <PlanPeriodOption>[
  PlanPeriodOption(
      period: 'month_price', label: '月付', months: 1, priceCents: 0),
  PlanPeriodOption(
      period: 'quarter_price', label: '季付', months: 3, priceCents: 0),
  PlanPeriodOption(
      period: 'half_year_price', label: '半年', months: 6, priceCents: 0),
  PlanPeriodOption(
      period: 'year_price', label: '年付', months: 12, priceCents: 0),
  PlanPeriodOption(
      period: 'two_year_price', label: '两年', months: 24, priceCents: 0),
  PlanPeriodOption(
      period: 'three_year_price', label: '三年', months: 36, priceCents: 0),
  PlanPeriodOption(
      period: 'onetime_price', label: '一次性', months: 0, priceCents: 0),
  PlanPeriodOption(
      period: 'reset_price', label: '重置流量', months: 0, priceCents: 0),
];

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.name,
    required this.payment,
  });

  final String id;
  final String name;
  final String payment;
}

class CheckoutResult {
  const CheckoutResult({
    required this.type,
    this.data,
  });

  final int type;
  final Object? data;
}

class StoreOrder {
  const StoreOrder({
    required this.tradeNo,
    required this.period,
    required this.status,
    required this.totalAmountCents,
    required this.createdAt,
    this.id,
    this.planId,
    this.type,
    this.planName,
    this.upgradeSourcePlanName,
    this.upgradeTargetPlanName,
    this.handlingAmountCents,
    this.balanceAmountCents,
    this.discountAmountCents,
    this.upgradeCreditAmountCents,
  });

  final int? id;
  final int? planId;
  final int? type;
  final String? planName;
  final String? upgradeSourcePlanName;
  final String? upgradeTargetPlanName;
  final String tradeNo;
  final String period;
  final int status;
  final int totalAmountCents;
  final int? handlingAmountCents;
  final int? balanceAmountCents;
  final int? discountAmountCents;
  final int? upgradeCreditAmountCents;
  final DateTime? createdAt;

  bool get isPending => status == 0;
  bool get isRecharge =>
      type == 5 || planId == 0 || period == 'deposit' || period == 'recharge';
  bool get isDiscountUpgrade => type == 6;
}

class CheckoutQrPayload {
  const CheckoutQrPayload({
    required this.qrData,
    this.address,
    this.amount,
    this.fiatAmount,
    this.fiat,
    this.currency,
    this.network,
    this.tradeType,
    this.tradeId,
    this.paymentUrl,
    this.expirationTime,
  });

  final String qrData;
  final String? address;
  final String? amount;
  final String? fiatAmount;
  final String? fiat;
  final String? currency;
  final String? network;
  final String? tradeType;
  final String? tradeId;
  final String? paymentUrl;
  final int? expirationTime;
}

class UpgradePreview {
  const UpgradePreview({
    required this.allowUpgrade,
    this.reason,
    this.quoteToken,
    this.payableAmountCents,
    this.targetPriceCents,
    this.upgradeCreditAmountCents,
    this.sourcePlanName,
    this.targetPlanName,
  });

  final bool allowUpgrade;
  final String? reason;
  final String? quoteToken;
  final int? payableAmountCents;
  final int? targetPriceCents;
  final int? upgradeCreditAmountCents;
  final String? sourcePlanName;
  final String? targetPlanName;
}

class PurchaseResult {
  const PurchaseResult({
    required this.message,
    this.tradeNo,
    this.externalUrl,
    this.copyText,
    this.qrPayload,
  });

  final String message;
  final String? tradeNo;
  final String? externalUrl;
  final String? copyText;
  final CheckoutQrPayload? qrPayload;
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
    this.sessionTraffic = '0 MB',
  });

  final String uploadSpeed;
  final String downloadSpeed;
  final Duration duration;
  final String sessionTraffic;

  RuntimeStats copyWith({
    String? uploadSpeed,
    String? downloadSpeed,
    Duration? duration,
    String? sessionTraffic,
  }) {
    return RuntimeStats(
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      duration: duration ?? this.duration,
      sessionTraffic: sessionTraffic ?? this.sessionTraffic,
    );
  }
}

class CoreTrafficSample {
  const CoreTrafficSample({
    required this.uploadBytesPerSecond,
    required this.downloadBytesPerSecond,
    required this.sessionUploadBytes,
    required this.sessionDownloadBytes,
  });

  final int uploadBytesPerSecond;
  final int downloadBytesPerSecond;
  final int sessionUploadBytes;
  final int sessionDownloadBytes;

  int get sessionTotalBytes => sessionUploadBytes + sessionDownloadBytes;
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
    required this.clashApiAddress,
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
  final String? clashApiAddress;
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
