import 'dart:convert';
import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:boardgame_server/boardgame_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

/// Connection info as shelf_io puts it into the request context.
class _Connection implements HttpConnectionInfo {
  _Connection(String address) : remoteAddress = InternetAddress(address);

  @override
  final InternetAddress remoteAddress;

  @override
  int get remotePort => 50000;

  @override
  int get localPort => 8080;
}

/// A fake monotonic clock.
class _Clock {
  Duration now = Duration.zero;

  Duration call() => now;
}

const _caddy = '10.213.7.10';

/// The app with the rate limiter as its first /v1 guard, a fake clock, and
/// captured logs.
class _LimitedApp {
  _LimitedApp({int limit = 60, List<String> trusted = const [_caddy]}) {
    limiter = RateLimiter(limit: limit, now: clock.call);
    handler = buildApp(
      version: 'v',
      logger: logs.logger(),
      databaseHealth: DatabaseHealth.alwaysUp(),
      v1Middleware: [
        rateLimit(
          limiter,
          ClientAddressResolver(
            trustedProxies: [for (final t in trusted) InternetAddress(t)],
          ),
        ),
      ],
      addTestRoutes: (v1) =>
          v1.get('/games/<bggId>', (_) => jsonResponse(200, {'ok': true})),
    );
  }

  final clock = _Clock();
  final logs = LogCapture();
  late final RateLimiter limiter;
  late final Handler handler;

  Future<Response> get(
    String path, {
    String? peer,
    String? forwardedFor,
  }) async => handler(
    Request(
      'GET',
      Uri.parse('http://localhost$path'),
      headers: {'x-forwarded-for': ?forwardedFor},
      context: {if (peer != null) connectionInfoContextKey: _Connection(peer)},
    ),
  );
}

Future<void> _expectRateLimited(Response response) async {
  expect(response.statusCode, 429);
  expect(response.mimeType, 'application/json');
  final retryAfter = response.headers['retry-after'];
  expect(retryAfter, matches(RegExp(r'^[1-9][0-9]*$')));
  final envelope = ErrorEnvelope.fromJson(await jsonObjectOf(response));
  expect(envelope.error.code, ErrorCode.rateLimited);
}

void main() {
  group('per-IP limit on /v1 (T-020)', () {
    test(
      'AC1: of 70 requests from one IP within 10 s, 60 succeed and 10 get '
      '429 rate_limited with a whole-second Retry-After of at least 1',
      () async {
        final app = _LimitedApp();
        final statuses = <int>[];
        for (var i = 0; i < 70; i++) {
          app.clock.now = Duration(milliseconds: i * 140); // last at 9.66 s
          final response = await app.get('/v1/games/13', peer: '198.51.100.7');
          statuses.add(response.statusCode);
          if (response.statusCode == 429) {
            await _expectRateLimited(response);
            // The window started at 0 and lasts 60 s.
            final left = rateLimitWindow - app.clock.now;
            expect(
              int.parse(response.headers['retry-after']!),
              retryAfterSeconds(left),
            );
          }
        }

        expect(statuses.where((s) => s == 200), hasLength(60));
        expect(statuses.where((s) => s == 429), hasLength(10));
        expect(statuses.take(60), everyElement(200));
      },
    );

    test('AC1: an unmatched /v1 path counts too, and a refused request never '
        'reaches routing', () async {
      final app = _LimitedApp(limit: 1);

      expect((await app.get('/v1/nope', peer: '198.51.100.7')).statusCode, 404);
      await _expectRateLimited(
        await app.get('/v1/games/13', peer: '198.51.100.7'),
      );

      final line = app.logs.withMessage('request').last;
      expect(line['status'], 429);
      expect(line['route'], unmatchedRoute);
    });

    test('AC2: while IP A is limited, IP B still succeeds', () async {
      final app = _LimitedApp(limit: 2);
      for (var i = 0; i < 2; i++) {
        await app.get('/v1/games/13', peer: '198.51.100.1');
      }
      await _expectRateLimited(
        await app.get('/v1/games/13', peer: '198.51.100.1'),
      );

      final b = await app.get('/v1/games/13', peer: '198.51.100.2');

      expect(b.statusCode, 200);
      await _expectRateLimited(
        await app.get('/v1/games/13', peer: '198.51.100.1'),
      );
    });

    test('AC3 end to end: after a full minute, A succeeds again', () async {
      final app = _LimitedApp(limit: 1);
      await app.get('/v1/games/13', peer: '198.51.100.1');
      await _expectRateLimited(
        await app.get('/v1/games/13', peer: '198.51.100.1'),
      );

      app.clock.now = rateLimitWindow;

      expect(
        (await app.get('/v1/games/13', peer: '198.51.100.1')).statusCode,
        200,
      );
    });

    test('AC5: /health is never limited and adds no entry', () async {
      final app = _LimitedApp(limit: 1);
      for (var i = 0; i < 20; i++) {
        final response = await app.get('/health', peer: '198.51.100.1');
        expect(response.statusCode, 200);
      }
      expect(app.limiter.trackedCount, 0);

      // The same IP still has its full /v1 allowance.
      expect(
        (await app.get('/v1/games/13', peer: '198.51.100.1')).statusCode,
        200,
      );
    });

    test('AC5: paths outside /v1 are not limited', () async {
      final app = _LimitedApp(limit: 1);
      for (var i = 0; i < 5; i++) {
        expect((await app.get('/nope', peer: '198.51.100.1')).statusCode, 404);
      }
      expect(app.limiter.trackedCount, 0);
    });
  });

  group('client IP behind Caddy (T-020 AC4)', () {
    test('from the trusted proxy, the last X-Forwarded-For entry (the one '
        'Caddy added) is the client, and forged entries before it are '
        'ignored', () async {
      final app = _LimitedApp(limit: 1);

      final first = await app.get(
        '/v1/games/13',
        peer: _caddy,
        forwardedFor: '6.6.6.6, 203.0.113.7',
      );
      final forged = await app.get(
        '/v1/games/13',
        peer: _caddy,
        forwardedFor: '7.7.7.7, 203.0.113.7',
      );
      final other = await app.get(
        '/v1/games/13',
        peer: _caddy,
        forwardedFor: '203.0.113.8',
      );

      expect(first.statusCode, 200);
      await _expectRateLimited(forged);
      expect(other.statusCode, 200, reason: 'a different client behind Caddy');
    });

    test(
      'from an untrusted peer, X-Forwarded-For is ignored and the socket '
      'address is used, so a spoofed header cannot dodge the limit',
      () async {
        final app = _LimitedApp(limit: 1);

        final first = await app.get(
          '/v1/games/13',
          peer: '198.51.100.9',
          forwardedFor: '203.0.113.1',
        );
        final spoofed = await app.get(
          '/v1/games/13',
          peer: '198.51.100.9',
          forwardedFor: '203.0.113.2',
        );

        expect(first.statusCode, 200);
        await _expectRateLimited(spoofed);
      },
    );

    test('an untrusted peer cannot spend another client\'s allowance by '
        'naming it in X-Forwarded-For', () async {
      final app = _LimitedApp(limit: 1);

      await app.get(
        '/v1/games/13',
        peer: '198.51.100.9',
        forwardedFor: '203.0.113.7',
      );
      final victim = await app.get(
        '/v1/games/13',
        peer: _caddy,
        forwardedFor: '203.0.113.7',
      );

      expect(victim.statusCode, 200);
    });

    test('with no trusted proxy configured, even Caddy\'s address is just a '
        'peer', () async {
      final app = _LimitedApp(limit: 1, trusted: const []);

      await app.get('/v1/games/13', peer: _caddy, forwardedFor: '203.0.113.1');
      await _expectRateLimited(
        await app.get(
          '/v1/games/13',
          peer: _caddy,
          forwardedFor: '203.0.113.2',
        ),
      );
    });

    final resolver = ClientAddressResolver(
      trustedProxies: [InternetAddress(_caddy), InternetAddress('fd00::10')],
    );
    String key({String? peer, String? forwardedFor}) => resolver.clientKey(
      Request(
        'GET',
        Uri.parse('http://localhost/v1/x'),
        headers: {'x-forwarded-for': ?forwardedFor},
        context: {
          if (peer != null) connectionInfoContextKey: _Connection(peer),
        },
      ),
    );

    test('a trusted peer without a usable X-Forwarded-For is limited by its '
        'own address', () {
      expect(key(peer: _caddy), _caddy);
      expect(key(peer: _caddy, forwardedFor: 'unknown'), _caddy);
      expect(key(peer: _caddy, forwardedFor: '203.0.113.1, '), _caddy);
      expect(key(peer: _caddy, forwardedFor: '203.0.113.1:443'), _caddy);
    });

    test('repeated header lines, joined by shelf with a comma, use the last '
        'entry of the last line', () {
      expect(
        key(peer: _caddy, forwardedFor: '1.1.1.1,2.2.2.2,203.0.113.5'),
        '203.0.113.5',
      );
    });

    test('IPv6 and IPv4-mapped forms are canonical, so one client is one '
        'key', () {
      expect(
        key(peer: 'fd00::10', forwardedFor: '2001:DB8::1'),
        key(peer: _caddy, forwardedFor: '2001:db8:0:0::1'),
      );
      expect(key(peer: '::ffff:198.51.100.3'), '198.51.100.3');
      expect(
        key(peer: '::ffff:10.213.7.10', forwardedFor: '203.0.113.9'),
        '203.0.113.9',
        reason: 'the mapped form of a trusted address is trusted',
      );
      expect(
        canonicalAddress(InternetAddress('2001:db8::1')),
        '2001:db8:0:0:0:0:0:1',
      );
    });

    test('a request without connection info shares the unknown key', () {
      expect(key(forwardedFor: '203.0.113.1'), unknownClientKey);
    });
  });

  group('privacy (T-020 AC6)', () {
    test('no log line holds a client or forwarded IP, for allowed, refused, '
        'and failing requests, and the limiter holds nothing after the '
        'window', () async {
      final app = _LimitedApp(limit: 2);
      const ips = ['198.51.100.23', '203.0.113.45', '2001:db8::77'];
      for (var i = 0; i < 4; i++) {
        await app.get('/v1/games/13', peer: ips[0]);
        await app.get('/v1/nope', peer: _caddy, forwardedFor: ips[1]);
        await app.get('/v1/games/13', peer: ips[2]);
      }
      expect(app.logs.withMessage('request'), hasLength(12));
      expect(
        app.logs.withMessage('request').where((r) => r['status'] == 429),
        hasLength(6),
      );

      for (final line in app.logs.lines) {
        for (final ip in [...ips, _caddy, '2001:db8:0:0:0:0:0:77']) {
          expect(line, isNot(contains(ip)));
        }
        expect(line.toLowerCase(), isNot(contains('forwarded')));
      }

      expect(app.limiter.trackedCount, 3);
      app.clock.now = rateLimitWindow;
      app.limiter.removeExpired();
      expect(app.limiter.trackedCount, 0);
    });
  });

  group('Retry-After (T-020 AC1)', () {
    test('is whole seconds rounded up, at least 1', () {
      expect(retryAfterSeconds(Duration.zero), 1);
      expect(retryAfterSeconds(const Duration(microseconds: 1)), 1);
      expect(retryAfterSeconds(const Duration(seconds: 1)), 1);
      expect(retryAfterSeconds(const Duration(milliseconds: 1001)), 2);
      expect(retryAfterSeconds(const Duration(seconds: 60)), 60);
    });

    test('the 429 response carries the envelope and the header', () async {
      final response = rateLimitedResponse(const Duration(milliseconds: 1500));

      expect(response.headers['retry-after'], '2');
      final body = jsonDecode(await response.readAsString()) as Map;
      expect((body['error'] as Map)['code'], 'rate_limited');
    });
  });

  group('over real sockets through bindAndServe (T-020 AC4)', () {
    Future<(HttpServer, RateLimiter)> serve(List<String> trusted) async {
      final limiter = RateLimiter(limit: 1);
      final logs = LogCapture();
      final handler = buildApp(
        version: 'v',
        logger: logs.logger(),
        databaseHealth: DatabaseHealth.alwaysUp(),
        v1Middleware: [
          rateLimit(
            limiter,
            ClientAddressResolver(
              trustedProxies: [for (final t in trusted) InternetAddress(t)],
            ),
          ),
        ],
        addTestRoutes: (v1) =>
            v1.get('/ok', (_) => jsonResponse(200, {'ok': true})),
      );
      final server = await bindAndServe(
        handler,
        InternetAddress.loopbackIPv4,
        0,
        logs.logger(),
      );
      addTearDown(() => server.close(force: true));
      return (server, limiter);
    }

    Future<int> get(int port, String forwardedFor) async {
      final client = HttpClient();
      try {
        final request = await client.get('127.0.0.1', port, '/v1/ok');
        request.headers.set('x-forwarded-for', forwardedFor);
        final response = await request.close();
        await response.drain<void>();
        return response.statusCode;
      } finally {
        client.close(force: true);
      }
    }

    test('shelf_io provides the peer address: a trusted loopback peer is '
        'limited per forwarded client', () async {
      final (server, limiter) = await serve(['127.0.0.1']);

      expect(await get(server.port, '203.0.113.1'), 200);
      expect(await get(server.port, '203.0.113.1'), 429);
      expect(await get(server.port, '203.0.113.2'), 200);
      expect(limiter.trackedCount, 2);
    });

    test('an untrusted loopback peer is limited by its socket address, '
        'whatever X-Forwarded-For says', () async {
      final (server, limiter) = await serve(const []);

      expect(await get(server.port, '203.0.113.1'), 200);
      expect(await get(server.port, '203.0.113.2'), 429);
      expect(limiter.trackedCount, 1);
    });
  });
}
