import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keli_client/src/models.dart';
import 'package:keli_client/src/services/keli_api.dart';

void main() {
  test('login and app bootstrap follow the keliboard client contract',
      () async {
    final server = await ContractServer.start();
    String? bootstrapAuthorization;

    server.route('POST', '/api/v1/passport/auth/login', (request) {
      expect(request.jsonBody, <String, Object?>{
        'email': 'user@example.com',
        'password': 'password',
      });
      return <String, Object?>{
        'status': 'success',
        'data': <String, Object?>{
          'token': 'subscribe-token',
          'auth_data': 'Bearer access-token',
          'is_admin': false,
          'is_staff': false,
        },
      };
    });
    server.route('GET', '/api/v1/app/bootstrap', (request) {
      bootstrapAuthorization = request.header(HttpHeaders.authorizationHeader);
      return <String, Object?>{
        'status': 'success',
        'data': <String, Object?>{
          'app': <String, Object?>{'name': 'Keli'},
          'user': <String, Object?>{
            'email': 'user@example.com',
            'plan_id': 1,
            'balance': 1234,
            'device_limit': 3,
            'speed_limit': 100,
            'avatar_url': 'https://example.com/avatar.png',
          },
          'subscribe': <String, Object?>{
            'plan_id': 1,
            'expired_at': 4102444800,
            'u': 1073741824,
            'd': 2147483648,
            'transfer_enable': 10737418240,
            'reset_day': 5,
            'plan': <String, Object?>{
              'id': 1,
              'name': 'Pro',
              'upgrade_to_plan_ids': <int>[2, 3],
            },
          },
          'servers': <Object?>[
            <String, Object?>{
              'id': 51,
              'type': 'hysteria',
              'version': 2,
              'name': 'HY2 Tokyo',
              'rate': 1.5,
              'tags': <String>['jp', 'streaming'],
              'is_online': 1,
              'cache_key': 'node:51',
              'last_check_at': 1777550400,
            },
          ],
        },
      };
    });

    try {
      final api = RealKeliApi();
      final login = await api.login(
        baseUrl: server.baseUrl,
        apiPrefix: 'api/v1',
        email: ' user@example.com ',
        password: 'password',
      );
      expect(login.session.baseUrl, server.baseUrl);
      expect(login.session.apiPrefix, '/api/v1');
      expect(login.session.authData, 'Bearer access-token');
      expect(login.session.subscribeToken, 'subscribe-token');

      final bootstrap = await api.bootstrap();
      expect(bootstrapAuthorization, 'Bearer access-token');
      expect(bootstrap.profile.email, 'user@example.com');
      expect(bootstrap.profile.planName, 'Pro');
      expect(bootstrap.profile.planId, 1);
      expect(bootstrap.profile.accountBalanceCents, 1234);
      expect(bootstrap.profile.deviceLimit, 3);
      expect(bootstrap.profile.speedLimit, 100);
      expect(bootstrap.profile.resetDay, 5);
      expect(bootstrap.profile.upgradeTargetPlanIds, <int>[2, 3]);
      expect(bootstrap.profile.usedTrafficGb, 3);
      expect(bootstrap.profile.totalTrafficGb, 10);
      expect(bootstrap.nodes.single.id, 51);
      expect(bootstrap.nodes.single.protocol, 'Hysteria2');
      expect(bootstrap.nodes.single.isOnline, isTrue);
      expect(bootstrap.nodes.single.tags, <String>['jp', 'streaming']);
    } finally {
      await server.close();
    }
  });

  test('bootstrap falls back to legacy user and server endpoints', () async {
    final server = await ContractServer.start();

    server.route('GET', '/api/v1/app/bootstrap', (_) {
      return const ContractReply(
        statusCode: 404,
        body: <String, Object?>{
          'status': 'fail',
          'message': 'not found',
        },
      );
    });
    server.route('GET', '/api/v1/user/info', (_) {
      return <String, Object?>{
        'status': 'success',
        'data': <String, Object?>{
          'email': 'legacy@example.com',
          'plan_id': 7,
          'expired_at': 4102444800,
        },
      };
    });
    server.route('GET', '/api/v1/user/getSubscribe', (_) {
      return <String, Object?>{
        'status': 'success',
        'data': <String, Object?>{
          'plan_id': 7,
          'u': 0,
          'd': 0,
          'transfer_enable': 5368709120,
          'plan': <String, Object?>{'id': 7, 'name': 'Legacy Pro'},
        },
      };
    });
    server.route('GET', '/api/v1/user/server/fetch', (_) {
      return <String, Object?>{
        'status': 'success',
        'data': <String, Object?>{
          'hysteria': <Object?>[
            <String, Object?>{
              'id': 8,
              'version': 2,
              'name': 'Legacy HY2',
              'rate': '2',
              'tags': 'legacy,hy2',
              'is_online': true,
            },
          ],
        },
      };
    });

    try {
      final api = RealKeliApi(
        session: ApiSession(
          baseUrl: server.baseUrl,
          apiPrefix: '/api/v1',
          authData: 'Bearer legacy',
        ),
      );

      final payload = await api.bootstrap();
      expect(payload.profile.email, 'legacy@example.com');
      expect(payload.profile.planName, 'Legacy Pro');
      expect(payload.profile.planId, 7);
      expect(payload.profile.totalTrafficGb, 5);
      expect(payload.nodes.single.id, 8);
      expect(payload.nodes.single.protocol, 'Hysteria2');
      expect(payload.nodes.single.tags, <String>['legacy', 'hy2']);
    } finally {
      await server.close();
    }
  });

  test('store, order, payment and sing-box config endpoints parse correctly',
      () async {
    final server = await ContractServer.start();
    ContractRequest? saveOrderRequest;
    ContractRequest? rechargeRequest;
    ContractRequest? couponRequest;
    ContractRequest? checkoutRequest;
    ContractRequest? configRequest;
    ContractRequest? batchConfigRequest;

    server.route('GET', '/api/v1/user/plan/fetch', (_) {
      return <String, Object?>{
        'status': 'success',
        'data': <Object?>[
          <String, Object?>{
            'id': 2,
            'name': 'Hidden',
            'sell': 0,
            'month_price': 100,
          },
          <String, Object?>{
            'id': 3,
            'name': 'Annual',
            'sort': 20,
            'prices': <String, Object?>{'yearly': 9900},
            'transfer_enable': 107374182400,
            'tags': 'annual,hot',
          },
          <String, Object?>{
            'id': 1,
            'name': 'Monthly',
            'sort': 10,
            'month_price': 1200,
            'transfer_enable': 50,
            'speed_limit': 200,
            'device_limit': 5,
            'renew': true,
          },
        ],
      };
    });
    server.route('GET', '/api/v1/user/order/getPaymentMethod', (_) {
      return <String, Object?>{
        'status': 'success',
        'data': <Object?>[
          <String, Object?>{
            'id': 9,
            'name': 'Stripe',
            'payment': 'stripe',
            'handling_fee_fixed': 50,
            'handling_fee_percent': '2.5',
          },
        ],
      };
    });
    server.route('GET', '/api/v1/user/order/fetch', (_) {
      return <String, Object?>{
        'status': 'success',
        'data': <Object?>[
          <String, Object?>{
            'id': 10,
            'plan_id': 1,
            'type': 6,
            'period': 'month_price',
            'trade_no': 'K202605010001',
            'status': 0,
            'total_amount': 1200,
            'handling_amount': 80,
            'bonus_amount': 200,
            'upgrade_credit_amount': 300,
            'created_at': 1777550400,
            'plan': <String, Object?>{'name': 'Monthly'},
            'upgrade_pricing_snapshot': <String, Object?>{
              'source_plan': <String, Object?>{'name': 'Basic'},
              'target_plan': <String, Object?>{'name': 'Monthly'},
            },
          },
        ],
      };
    });
    server.route('POST', '/api/v1/user/order/save', (request) {
      saveOrderRequest = request;
      return <String, Object?>{
        'status': 'success',
        'data': 'K202605010002',
      };
    });
    server.route('POST', '/api/v1/user/order/recharge', (request) {
      rechargeRequest = request;
      return <String, Object?>{
        'status': 'success',
        'data': 'R202605010001',
      };
    });
    server.route('POST', '/api/v1/user/coupon/check', (request) {
      couponRequest = request;
      return <String, Object?>{
        'status': 'success',
        'data': <String, Object?>{
          'type': 2,
          'value': 20,
        },
      };
    });
    server.route('POST', '/api/v1/user/order/upgrade/preview', (_) {
      return <String, Object?>{
        'status': 'success',
        'data': <String, Object?>{
          'allow_upgrade': true,
          'quote_token': 'quote-token',
          'payable_amount': 900,
          'source_plan': <String, Object?>{'name': 'Basic'},
          'target_plan': <String, Object?>{'name': 'Pro'},
          'pricing_detail': <String, Object?>{
            'target_price': 1200,
            'upgrade_credit_amount': 300,
          },
        },
      };
    });
    server.route('POST', '/api/v1/user/order/upgrade/confirm', (_) {
      return <String, Object?>{
        'status': 'success',
        'data': <String, Object?>{'trade_no': 'U202605010001'},
      };
    });
    server.route('POST', '/api/v1/user/order/checkout', (request) {
      checkoutRequest = request;
      return <String, Object?>{
        'type': 1,
        'data': 'https://pay.example/checkout',
      };
    });
    server.route('GET', '/api/v1/user/order/check', (_) {
      return <String, Object?>{'status': 'success', 'data': 3};
    });
    server.route('POST', '/api/v1/user/order/cancel', (_) {
      return <String, Object?>{'status': 'success', 'data': true};
    });
    server.route('GET', '/api/v1/app/config', (request) {
      if (request.query['server_id'] == null) {
        batchConfigRequest = request;
      } else {
        configRequest = request;
      }
      return <String, Object?>{
        'status': 'success',
        'data': <String, Object?>{
          'log': <String, Object?>{},
          'dns': <String, Object?>{},
          'inbounds': <Object?>[],
          'outbounds': <Object?>[
            <String, Object?>{'type': 'direct', 'tag': 'direct'},
          ],
          'route': <String, Object?>{},
        },
      };
    });

    try {
      final api = RealKeliApi(
        session: ApiSession(
          baseUrl: server.baseUrl,
          apiPrefix: '/api/v1',
          authData: 'Bearer access-token',
        ),
      );

      final plans = await api.fetchPlans();
      expect(plans.map((plan) => plan.id), <int>[1, 3]);
      expect(plans.first.prices['month_price'], 1200);
      expect(plans.last.prices['year_price'], 9900);
      expect(plans.last.tags, <String>['annual', 'hot']);

      final payments = await api.fetchPaymentMethods();
      expect(payments.single.id, '9');
      expect(payments.single.payment, 'stripe');
      expect(payments.single.handlingFeeFixedCents, 50);
      expect(payments.single.handlingFeePercent, 2.5);

      final orders = await api.fetchOrders();
      expect(orders.single.tradeNo, 'K202605010001');
      expect(orders.single.isPending, isTrue);
      expect(orders.single.isDiscountUpgrade, isTrue);
      expect(orders.single.handlingAmountCents, 80);
      expect(orders.single.bonusAmountCents, 200);
      expect(orders.single.upgradeSourcePlanName, 'Basic');
      expect(orders.single.upgradeTargetPlanName, 'Monthly');

      final coupon = await api.checkCoupon(
        code: 'SAVE20',
        planId: 1,
        period: 'month_price',
      );
      expect(coupon.type, 2);
      expect(coupon.value, 20);
      expect(couponRequest?.jsonBody, <String, Object?>{
        'code': 'SAVE20',
        'plan_id': 1,
        'period': 'month_price',
      });

      final tradeNo = await api.createOrder(
        planId: 1,
        period: 'month_price',
        couponCode: 'SAVE20',
      );
      expect(tradeNo, 'K202605010002');
      expect(saveOrderRequest?.jsonBody, <String, Object?>{
        'plan_id': 1,
        'period': 'month_price',
        'coupon_code': 'SAVE20',
      });

      final rechargeTradeNo =
          await api.createRechargeOrder(amountCents: 2550);
      expect(rechargeTradeNo, 'R202605010001');
      expect(rechargeRequest?.jsonBody, <String, Object?>{'amount': '25.50'});

      final preview = await api.previewUpgrade(
        targetPlanId: 3,
        period: 'year_price',
      );
      expect(preview.allowUpgrade, isTrue);
      expect(preview.quoteToken, 'quote-token');
      expect(preview.payableAmountCents, 900);
      expect(preview.targetPriceCents, 1200);
      expect(preview.upgradeCreditAmountCents, 300);
      expect(preview.sourcePlanName, 'Basic');
      expect(preview.targetPlanName, 'Pro');

      expect(
        await api.confirmUpgrade(quoteToken: 'quote-token'),
        'U202605010001',
      );

      final checkout = await api.checkoutOrder(
        tradeNo: 'K202605010002',
        method: '9',
      );
      expect(checkout.type, 1);
      expect(checkout.data, 'https://pay.example/checkout');
      expect(checkoutRequest?.jsonBody, <String, Object?>{
        'trade_no': 'K202605010002',
        'method': '9',
      });

      expect(await api.checkOrder(tradeNo: 'K202605010002'), 3);
      await api.cancelOrder(tradeNo: 'K202605010002');

      final config = await api.fetchSingBoxConfig(
        serverId: 51,
        platform: 'windows',
        coreVersion: '1.13.11',
      );
      expect(config['outbounds'], isA<List>());
      expect(configRequest?.query['core'], 'sing-box');
      expect(configRequest?.query['platform'], 'windows');
      expect(configRequest?.query['server_id'], '51');
      expect(configRequest?.query['core_version'], '1.13.11');

      await api.fetchSingBoxBatchConfig(platform: 'android');
      expect(batchConfigRequest?.query['core'], 'sing-box');
      expect(batchConfigRequest?.query['platform'], 'android');
      expect(batchConfigRequest?.query.containsKey('server_id'), isFalse);
    } finally {
      await server.close();
    }
  });

  test('announcements page through visible popup notices', () async {
    final server = await ContractServer.start();
    final seenPages = <String>[];

    server.route('GET', '/api/v1/user/notice/fetch', (request) {
      seenPages.add(request.query['current'] ?? '');
      final page = request.query['current'];
      final notices = page == '1'
          ? <Object?>[
              <String, Object?>{
                'id': 1,
                'title': 'Hidden',
                'content': 'ignored',
                'show': 0,
              },
              <String, Object?>{
                'id': 2,
                'title': 'Maintenance',
                'content': '<p>Tonight</p>',
                'created_at': 1777550400,
                'show': 1,
                'tags': <String>['popup'],
              },
            ]
          : <Object?>[
              <String, Object?>{
                'id': 3,
                'title': 'Upgrade',
                'content': 'Done',
                'created_at': 1777550500,
                'popup': true,
              },
            ];
      return <String, Object?>{
        'status': 'success',
        'data': notices,
        'total': 2,
      };
    });

    try {
      final api = RealKeliApi(
        session: ApiSession(
          baseUrl: server.baseUrl,
          apiPrefix: '/api/v1',
          authData: 'Bearer access-token',
        ),
      );

      final announcements = await api.fetchAnnouncements(maxItems: 2);
      expect(seenPages, <String>['1', '2']);
      expect(announcements.map((item) => item.title), <String>[
        'Upgrade',
        'Maintenance',
      ]);
      expect(announcements.first.shouldAutoPopup, isTrue);
      expect(announcements.last.shouldAutoPopup, isTrue);
    } finally {
      await server.close();
    }
  });
}

typedef ContractHandler = FutureOr<Object?> Function(ContractRequest request);

class ContractServer {
  ContractServer._(this._server) {
    _subscription = _server.listen(_handleRequest);
  }

  final HttpServer _server;
  late final StreamSubscription<HttpRequest> _subscription;
  final Map<String, ContractHandler> _routes = <String, ContractHandler>{};

  static Future<ContractServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return ContractServer._(server);
  }

  String get baseUrl => 'http://${_server.address.address}:${_server.port}';

  void route(String method, String path, ContractHandler handler) {
    _routes['${method.toUpperCase()} $path'] = handler;
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final contractRequest = await ContractRequest.from(request);
    final key = '${contractRequest.method} ${contractRequest.path}';
    final handler = _routes[key];
    if (handler == null) {
      await _sendJson(
        request,
        const ContractReply(
          statusCode: 404,
          body: <String, Object?>{
            'status': 'fail',
            'message': 'route not found',
          },
        ),
      );
      return;
    }

    try {
      final rawReply = await handler(contractRequest);
      final reply = rawReply is ContractReply
          ? rawReply
          : ContractReply(body: rawReply ?? <String, Object?>{});
      await _sendJson(request, reply);
    } catch (error, stackTrace) {
      await _sendJson(
        request,
        ContractReply(
          statusCode: 500,
          body: <String, Object?>{
            'status': 'fail',
            'message': '$error\n$stackTrace',
          },
        ),
      );
    }
  }

  Future<void> _sendJson(HttpRequest request, ContractReply reply) async {
    request.response
      ..statusCode = reply.statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(reply.body));
    await request.response.close();
  }
}

class ContractRequest {
  const ContractRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.headers,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, String> query;
  final HttpHeaders headers;
  final String body;

  static Future<ContractRequest> from(HttpRequest request) async {
    return ContractRequest(
      method: request.method.toUpperCase(),
      path: request.uri.path,
      query: request.uri.queryParameters,
      headers: request.headers,
      body: await utf8.decoder.bind(request).join(),
    );
  }

  Object? get jsonBody {
    if (body.trim().isEmpty) {
      return null;
    }
    return jsonDecode(body);
  }

  String? header(String name) => headers.value(name);
}

class ContractReply {
  const ContractReply({
    this.statusCode = 200,
    required this.body,
  });

  final int statusCode;
  final Object? body;
}
