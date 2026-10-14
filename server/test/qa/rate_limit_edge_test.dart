import 'dart:convert';
import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:boardgame_server/boardgame_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

/// QA round 1 for T-020: edge cases for the limiter, the client address rule,
/// the middleware, and config parsing. Pure Dart, no database.

class _Connection implements HttpConnectionInfo {
  _Connection(String address) : remoteAddress = InternetAddress(address);
  @override
  final InternetAddress remoteAddress;
  @override
  int get remotePort => 50000;
  @override
  int get localPort => 8080;
}

class _Clock {
  Duration now = Duration.zero;
  Duration call() => now;
}

const _caddy = '10.213.7.10';

int _key(String address) => addressKey(InternetAddress(address));

class _App {
  _App({
    int limit = 60,
    int maxTracked = 100000,
    List<String> trusted = const [_caddy],
    List<Middleware> extraGuards = const [],
  }) {
    limiter = RateLimiter(
      limit: limit,
      maxTracked: maxTracked,
      now: clock.call,
      onFull: logRateLimiterFull(logs.logger(), maxTracked),
    );
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
        ...extraGuards,
      ],
      addTestRoutes: (v1) {
        v1.get('/games/<bggId>', (_) => jsonResponse(200, {'ok': true}));
        v1.add('POST', '/things', (_) => jsonResponse(200, {'ok': true}));
      },
    );
  }

  final clock = _Clock();
  final logs = LogCapture();
  late final RateLimiter limiter;
  late final Handler handler;

  Future<Response> send(
    String method,
    String path, {
    String? peer,
    Map<String, Object>? headers,
  }) async => handler(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: headers,
      context: {if (peer != null) connectionInfoContextKey: _Connection(peer)},
    ),
  );

  Future<int> status(String path, {String? peer, String? xff}) async =>
      (await send(
        'GET',
        path,
        peer: peer,
        headers: {'x-forwarded-for': ?xff},
      )).statusCode;
}

void main() {
  group('RateLimiter windows', () {
    test('exactly the limit is allowed, one more is refused', () {
      for (final limit in [1, 2, 60, 10000]) {
        final clock = _Clock();
        final limiter = RateLimiter(limit: limit, now: clock.call);
        for (var i = 0; i < limit; i++) {
          expect(limiter.hit(1), isNull, reason: 'hit $i of $limit');
        }
        expect(limiter.hit(1), isNotNull);
        expect(limiter.hit(1), isNotNull);
      }
    });

    test('the window starts at the first request and ends exactly one '
        'minute later, to the microsecond', () {
      final clock = _Clock()..now = const Duration(seconds: 10);
      final limiter = RateLimiter(limit: 1, now: clock.call);
      expect(limiter.hit(7), isNull);
      clock.now = const Duration(seconds: 70) - const Duration(microseconds: 1);
      expect(limiter.hit(7), const Duration(microseconds: 1));
      clock.now = const Duration(seconds: 70);
      expect(limiter.hit(7), isNull, reason: 'new window at the boundary');
      expect(limiter.hit(7), isNotNull);
    });

    test('refused requests do not extend the window', () {
      final clock = _Clock();
      final limiter = RateLimiter(limit: 2, now: clock.call);
      limiter.hit(1);
      limiter.hit(1);
      for (var s = 1; s < 60; s++) {
        clock.now = Duration(seconds: s);
        expect(limiter.hit(1), isNotNull);
      }
      clock.now = const Duration(seconds: 60);
      expect(limiter.hit(1), isNull);
    });

    test('a new window gets a full allowance again', () {
      final clock = _Clock();
      final limiter = RateLimiter(limit: 3, now: clock.call);
      for (var round = 0; round < 4; round++) {
        clock.now = Duration(minutes: round);
        for (var i = 0; i < 3; i++) {
          expect(limiter.hit(9), isNull, reason: 'round $round hit $i');
        }
        expect(limiter.hit(9), isNotNull);
      }
    });

    test('the wait shrinks as the window runs down', () {
      final clock = _Clock();
      final limiter = RateLimiter(limit: 1, now: clock.call);
      limiter.hit(5);
      clock.now = const Duration(seconds: 20);
      expect(limiter.hit(5), const Duration(seconds: 40));
      clock.now = const Duration(seconds: 59);
      expect(limiter.hit(5), const Duration(seconds: 1));
    });

    test('keys have separate windows that start at different times', () {
      final clock = _Clock();
      final limiter = RateLimiter(limit: 1, now: clock.call);
      limiter.hit(1);
      clock.now = const Duration(seconds: 30);
      limiter.hit(2);
      clock.now = const Duration(seconds: 60);
      expect(limiter.hit(1), isNull);
      expect(limiter.hit(2), isNotNull);
      expect(limiter.trackedCount, 2);
    });

    test('everything expires and trackedCount returns to 0', () {
      final clock = _Clock();
      final limiter = RateLimiter(limit: 5, now: clock.call);
      for (var k = 0; k < 1000; k++) {
        limiter.hit(k);
      }
      expect(limiter.trackedCount, 1000);
      clock.now = rateLimitWindow;
      limiter.removeExpired();
      expect(limiter.trackedCount, 0);
    });

    test('a long uptime does not break the packed counters', () {
      // 10 years on the monotonic clock.
      final clock = _Clock()..now = const Duration(days: 3650);
      final limiter = RateLimiter(limit: 10000, now: clock.call);
      for (var i = 0; i < 10000; i++) {
        expect(limiter.hit(3), isNull);
      }
      expect(limiter.hit(3), isNotNull);
      clock.now += rateLimitWindow;
      expect(limiter.hit(3), isNull);
    });

    test('a custom short window works', () {
      final clock = _Clock();
      final limiter = RateLimiter(
        limit: 1,
        window: const Duration(seconds: 2),
        now: clock.call,
      );
      limiter.hit(1);
      expect(limiter.hit(1), const Duration(seconds: 2));
      clock.now = const Duration(seconds: 2);
      expect(limiter.hit(1), isNull);
    });

    test('negative, zero, and extreme key values are ordinary keys', () {
      final limiter = RateLimiter(limit: 1, now: _Clock().call);
      for (final k in [0, -1, 1, -(1 << 63), (1 << 63) - 1]) {
        expect(limiter.hit(k), isNull, reason: '$k');
        expect(limiter.hit(k), isNotNull, reason: '$k');
      }
    });

    test('construction rejects bad settings', () {
      expect(() => RateLimiter(limit: 0), throwsArgumentError);
      expect(() => RateLimiter(limit: -1), throwsArgumentError);
      expect(
        () => RateLimiter(limit: maxRateLimitPerWindow + 1),
        throwsArgumentError,
      );
      expect(() => RateLimiter(maxTracked: 0), throwsArgumentError);
      expect(() => RateLimiter(window: Duration.zero), throwsArgumentError);
      expect(
        () => RateLimiter(window: const Duration(seconds: -1)),
        throwsArgumentError,
      );
      expect(RateLimiter(limit: maxRateLimitPerWindow), isNotNull);
    });
  });

  group('table full', () {
    test('maxTracked 1: a new key evicts the old one, which starts fresh', () {
      final limiter = RateLimiter(limit: 1, maxTracked: 1, now: _Clock().call);
      expect(limiter.hit(1), isNull);
      expect(limiter.hit(1), isNotNull);
      expect(limiter.hit(2), isNull);
      expect(limiter.trackedCount, 1);
      expect(limiter.hit(1), isNull, reason: 'evicted, so fresh again');
    });

    test('eviction takes the oldest window first, not the busiest key', () {
      final clock = _Clock();
      final limiter = RateLimiter(limit: 5, maxTracked: 3, now: clock.call);
      limiter.hit(1);
      clock.now = const Duration(seconds: 1);
      limiter.hit(2);
      limiter.hit(2);
      limiter.hit(2);
      clock.now = const Duration(seconds: 2);
      limiter.hit(3);
      clock.now = const Duration(seconds: 3);
      limiter.hit(4); // evicts 1
      expect(limiter.trackedCount, 3);
      // Key 2 still has three counted hits: two more allowed, then refused.
      expect(limiter.hit(2), isNull);
      expect(limiter.hit(2), isNull);
      expect(limiter.hit(2), isNotNull);
    });

    test('expired entries are removed before anything is evicted', () {
      final clock = _Clock();
      var full = 0;
      final limiter = RateLimiter(
        limit: 1,
        maxTracked: 2,
        now: clock.call,
        onFull: () => full++,
      );
      limiter.hit(1);
      limiter.hit(2);
      clock.now = rateLimitWindow;
      limiter.hit(3);
      limiter.hit(4);
      expect(full, 0);
      expect(limiter.trackedCount, 2);
    });

    test('onFull fires once per minute, then again after the minute', () {
      final clock = _Clock();
      var full = 0;
      final limiter = RateLimiter(
        limit: 1,
        maxTracked: 1,
        now: clock.call,
        onFull: () => full++,
      );
      for (var k = 0; k < 500; k++) {
        limiter.hit(k);
      }
      expect(full, 1);
      clock.now = const Duration(seconds: 59, milliseconds: 999);
      for (var k = 500; k < 600; k++) {
        limiter.hit(k);
      }
      expect(full, 1);
      clock.now = const Duration(seconds: 61);
      for (var k = 600; k < 700; k++) {
        limiter.hit(k);
      }
      expect(full, 2);
    });

    test('the warning line carries maxTracked and no address or key', () async {
      final app = _App(limit: 1, maxTracked: 2);
      await app.status('/v1/games/1', peer: '203.0.113.1');
      await app.status('/v1/games/1', peer: '203.0.113.2');
      await app.status('/v1/games/1', peer: '203.0.113.3');
      final warnings = app.logs.withMessage(
        'rate limiter full, evicting oldest entries',
      );
      expect(warnings, hasLength(1));
      expect(warnings.single['level'], 'warning');
      expect(warnings.single['maxTracked'], 2);
      final text = jsonEncode(warnings.single);
      expect(text, isNot(contains('203.0.113')));
      expect(text, isNot(contains('${_key('203.0.113.1')}')));
      expect(text, isNot(contains('${_key('203.0.113.3')}')));
    });

    test('a flood of distinct addresses never exceeds the cap', () {
      final limiter = RateLimiter(limit: 1, maxTracked: 50, now: _Clock().call);
      for (var k = 0; k < 5000; k++) {
        limiter.hit(k * 7919);
        expect(limiter.trackedCount, lessThanOrEqualTo(50));
      }
    });
  });

  group('Retry-After', () {
    test('whole seconds, rounded up, never below 1', () {
      expect(retryAfterSeconds(Duration.zero), 1);
      expect(retryAfterSeconds(const Duration(microseconds: -5)), 1);
      expect(retryAfterSeconds(const Duration(seconds: -100)), 1);
      expect(retryAfterSeconds(const Duration(microseconds: 1)), 1);
      expect(retryAfterSeconds(const Duration(milliseconds: 999)), 1);
      expect(retryAfterSeconds(const Duration(seconds: 1)), 1);
      expect(retryAfterSeconds(const Duration(seconds: 1, microseconds: 1)), 2);
      expect(retryAfterSeconds(const Duration(milliseconds: 1001)), 2);
      expect(
        retryAfterSeconds(const Duration(seconds: 59, milliseconds: 999)),
        60,
      );
      expect(retryAfterSeconds(const Duration(minutes: 1)), 60);
    });

    test('the header on a real refusal matches the time left', () async {
      final app = _App(limit: 1);
      await app.status('/v1/games/1', peer: '198.51.100.1');
      app.clock.now = const Duration(seconds: 12, milliseconds: 400);
      final r = await app.send('GET', '/v1/games/1', peer: '198.51.100.1');
      expect(r.statusCode, 429);
      // 47.6 s left, rounded up.
      expect(r.headers['retry-after'], '48');
      app.clock.now = const Duration(seconds: 59, milliseconds: 999);
      final last = await app.send('GET', '/v1/games/1', peer: '198.51.100.1');
      expect(last.headers['retry-after'], '1');
    });
  });

  group('429 response', () {
    test(
      'is exactly the rate_limited envelope with JSON and no leaks',
      () async {
        final app = _App(limit: 1);
        await app.status('/v1/games/1', peer: '198.51.100.1');
        final r = await app.send('GET', '/v1/games/1', peer: '198.51.100.1');
        expect(r.statusCode, 429);
        expect(r.mimeType, 'application/json');
        final body = await jsonObjectOf(r);
        expect(body.keys, ['error']);
        final envelope = ErrorEnvelope.fromJson(body);
        expect(envelope.error.code, ErrorCode.rateLimited);
        expect(envelope.error.message, isNotEmpty);
        final text = jsonEncode(body);
        expect(text, isNot(contains('198.51.100')));
        expect(r.headers['retry-after'], matches(RegExp(r'^[0-9]+$')));
        expect(
          r.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('set-cookie')),
        );
      },
    );

    test('every method counts, and refusal beats routing', () async {
      final app = _App(limit: 3);
      expect(
        (await app.send('POST', '/v1/things', peer: '198.51.100.1')).statusCode,
        200,
      );
      expect(
        (await app.send(
          'DELETE',
          '/v1/things',
          peer: '198.51.100.1',
        )).statusCode,
        isNot(429),
      );
      expect(
        (await app.send('OPTIONS', '/v1/x', peer: '198.51.100.1')).statusCode,
        isNot(429),
      );
      for (final m in ['GET', 'POST', 'HEAD', 'PUT']) {
        expect(
          (await app.send(m, '/v1/anything', peer: '198.51.100.1')).statusCode,
          429,
          reason: m,
        );
      }
    });

    test('the 429 request is still logged once, with status 429', () async {
      final app = _App(limit: 1);
      await app.status('/v1/games/1', peer: '198.51.100.1');
      await app.status('/v1/games/1', peer: '198.51.100.1');
      final requests = app.logs.records
          .where((r) => r['status'] == 429)
          .toList();
      expect(requests, hasLength(1));
    });
  });

  group('what is limited', () {
    test('/health and everything outside /v1 are never limited', () async {
      final app = _App(limit: 1);
      for (var i = 0; i < 20; i++) {
        expect(await app.status('/health', peer: '198.51.100.1'), 200);
      }
      expect(app.limiter.trackedCount, 0);
      for (final path in [
        '/',
        '/healthz',
        '/v10/x',
        '/v1x',
        '/other',
        '/V1/x',
      ]) {
        for (var i = 0; i < 5; i++) {
          expect(
            await app.status(path, peer: '198.51.100.1'),
            404,
            reason: path,
          );
        }
      }
      expect(app.limiter.trackedCount, 0);
    });

    test('/v1 itself, with and without a trailing slash, is limited', () async {
      final app = _App(limit: 1);
      expect(await app.status('/v1/', peer: '198.51.100.1'), isNot(429));
      expect(await app.status('/v1', peer: '198.51.100.1'), 429);
    });

    test('a query string and path variants do not change the client', () async {
      final app = _App(limit: 2);
      expect(await app.status('/v1/games/1?a=1', peer: '198.51.100.1'), 200);
      expect(await app.status('/v1/games/2?a=2', peer: '198.51.100.1'), 200);
      expect(await app.status('/v1/games/3', peer: '198.51.100.1'), 429);
    });

    test('the limiter is the first /v1 guard: a refused request never '
        'reaches the next guard', () async {
      var reached = 0;
      Middleware counting() =>
          (inner) => (request) {
            reached++;
            return inner(request);
          };
      final app = _App(limit: 2, extraGuards: [counting()]);
      for (var i = 0; i < 5; i++) {
        await app.status('/v1/games/1', peer: '198.51.100.1');
      }
      expect(reached, 2);
    });

    test('a throwing later guard still counts against the limit', () async {
      Middleware throwing() =>
          (inner) =>
              (request) => throw StateError('guard failed');
      final app = _App(limit: 2, extraGuards: [throwing()]);
      expect(await app.status('/v1/games/1', peer: '198.51.100.1'), 500);
      expect(await app.status('/v1/games/1', peer: '198.51.100.1'), 500);
      expect(await app.status('/v1/games/1', peer: '198.51.100.1'), 429);
    });
  });

  group('address keys', () {
    test('IPv4: each full address is its own client', () {
      expect(_key('192.0.2.1'), isNot(_key('192.0.2.2')));
      expect(_key('192.0.2.1'), _key('192.0.2.1'));
      expect(_key('0.0.0.0'), 0);
      expect(_key('255.255.255.255'), 0xffffffff);
    });

    test('IPv4-mapped IPv6 is the same client as the IPv4 address', () {
      expect(_key('::ffff:192.0.2.1'), _key('192.0.2.1'));
      expect(_key('::FFFF:c000:201'), _key('192.0.2.1'));
      expect(_key('::ffff:0:0'), _key('0.0.0.0'));
    });

    test('IPv4-translated and other near-mapped forms are NOT mapped', () {
      expect(_key('::ffff:0:192.0.2.1'), isNot(_key('192.0.2.1')));
      expect(_key('64:ff9b::192.0.2.1'), isNot(_key('192.0.2.1')));
    });

    test('IPv6 uppercase, compressed, and expanded forms are one client', () {
      final forms = [
        '2001:db8::1',
        '2001:DB8::1',
        '2001:0db8:0000:0000:0000:0000:0000:0001',
        '2001:db8:0:0:0:0:0:1',
      ];
      expect({for (final f in forms) _key(f)}, hasLength(1));
    });

    test('addresses in one /64 share a key, other /64s do not', () {
      final base = _key('2001:db8:1:2::1');
      expect(_key('2001:db8:1:2:ffff:ffff:ffff:ffff'), base);
      expect(_key('2001:db8:1:2::'), base);
      expect(_key('2001:db8:1:3::1'), isNot(base));
      expect(_key('2001:db8:1:2:8000::'), base);
      expect(_key('2001:db8:1:1:ffff:ffff:ffff:ffff'), isNot(base));
      // Lowest bit of the 64-bit prefix.
      expect(_key('2001:db8:1:2::1'), isNot(_key('2001:db8:1:3::1')));
    });

    test('a zone id does not change the key', () {
      final withZone = InternetAddress.tryParse('fe80::1%eth0');
      final plain = InternetAddress('fe80::1');
      if (withZone == null) {
        markTestSkipped('this Dart runtime does not parse zone ids');
        return;
      }
      expect(addressKey(withZone), addressKey(plain));
      expect(canonicalAddress(withZone), canonicalAddress(plain));
    });

    test('canonical text agrees across spellings', () {
      expect(
        canonicalAddress(InternetAddress('::ffff:10.213.7.10')),
        canonicalAddress(InternetAddress('10.213.7.10')),
      );
      expect(
        canonicalAddress(InternetAddress('2001:DB8::1')),
        canonicalAddress(InternetAddress('2001:0db8:0:0:0:0:0:1')),
      );
    });

    test('an IPv6 /64 prefix never equals the shared "unknown" key', () {
      expect(_key('ffff:ffff:ffff:ffff::1'), unknownClientKey);
      // Documented: that prefix is multicast space, so it never occurs as a
      // real source; the collision is harmless but pinned here.
    });

    test(
      'IPv6 loopback and IPv4 0.0.0.0 collide only in a harmless corner',
      () {
        // ::1 is prefix 0000:0000:0000:0000, which maps to key 0, the same key
        // as IPv4 0.0.0.0. Neither is a valid remote client address.
        expect(_key('::1'), _key('0.0.0.0'));
      },
    );
  });

  group('X-Forwarded-For from a trusted proxy', () {
    Future<(int, int)> twoClients(
      String peer,
      String first,
      String second,
    ) async {
      final app = _App(limit: 1);
      final a = await app.status('/v1/games/1', peer: peer, xff: first);
      final b = await app.status('/v1/games/1', peer: peer, xff: second);
      return (a, b);
    }

    test('only the LAST entry identifies the client', () async {
      final app = _App(limit: 1);
      // The first request from real client 203.0.113.5 forging a leftmost
      // entry; Caddy appends the real address last.
      expect(
        await app.status(
          '/v1/games/1',
          peer: _caddy,
          xff: '9.9.9.9, 8.8.8.8, 203.0.113.5',
        ),
        200,
      );
      // Same real client, a different forged prefix: still the same client.
      expect(
        await app.status(
          '/v1/games/1',
          peer: _caddy,
          xff: '1.1.1.1, 203.0.113.5',
        ),
        429,
      );
      // A different real client with the same forged prefix is a new client.
      expect(
        await app.status(
          '/v1/games/1',
          peer: _caddy,
          xff: '9.9.9.9, 8.8.8.8, 203.0.113.6',
        ),
        200,
      );
    });

    test('spaces and tabs around the entry are ignored', () async {
      final app = _App(limit: 1);
      expect(
        await app.status('/v1/games/1', peer: _caddy, xff: '203.0.113.5'),
        200,
      );
      for (final xff in [
        ' 203.0.113.5',
        '203.0.113.5 ',
        '   203.0.113.5   ',
        '1.1.1.1 ,\t203.0.113.5\t',
        '1.1.1.1,203.0.113.5',
      ]) {
        expect(
          await app.status('/v1/games/1', peer: _caddy, xff: xff),
          429,
          reason: xff,
        );
      }
    });

    test('empty, garbage, or port-bearing entries fall back to the peer '
        '(which is limited as one client: fails safe)', () async {
      for (final bad in [
        '',
        ' ',
        ',',
        'unknown',
        'garbage',
        '1.2.3',
        '256.1.1.1',
        '1.2.3.4:5678',
        '[2001:db8::1]',
        '[2001:db8::1]:443',
        '1.2.3.4, ',
        '1.2.3.4,',
        '-',
        'null',
        '1.2.3.4;5.6.7.8',
        "1.2.3.4'--",
        '\u0000',
        '1.2.3.4/32',
        '0x7f.1',
        '2001:db8::1::2',
      ]) {
        final (a, b) = await twoClients(_caddy, bad, 'also-$bad');
        expect(a, 200, reason: 'first with "$bad"');
        expect(b, 429, reason: 'second shares the proxy bucket: "$bad"');
      }
    });

    test('a request with no header is limited by the proxy address', () async {
      final app = _App(limit: 1);
      expect(await app.status('/v1/games/1', peer: _caddy), 200);
      expect(await app.status('/v1/games/1', peer: _caddy), 429);
      // Another proxy-bucket user with a real header is unaffected.
      expect(
        await app.status('/v1/games/1', peer: _caddy, xff: '203.0.113.9'),
        200,
      );
    });

    test('IPv6 entries: compressed, upper case, and /64 grouping', () async {
      final app = _App(limit: 1);
      expect(
        await app.status('/v1/games/1', peer: _caddy, xff: '2001:db8:1:2::1'),
        200,
      );
      expect(
        await app.status('/v1/games/1', peer: _caddy, xff: '2001:DB8:1:2::99'),
        429,
      );
      expect(
        await app.status(
          '/v1/games/1',
          peer: _caddy,
          xff: '2001:0db8:0001:0002:aaaa:bbbb:cccc:dddd',
        ),
        429,
      );
      expect(
        await app.status('/v1/games/1', peer: _caddy, xff: '2001:db8:1:3::1'),
        200,
      );
    });

    test('an IPv4-mapped entry is the same client as the IPv4 entry', () async {
      final app = _App(limit: 1);
      expect(
        await app.status('/v1/games/1', peer: _caddy, xff: '203.0.113.5'),
        200,
      );
      expect(
        await app.status(
          '/v1/games/1',
          peer: _caddy,
          xff: '::ffff:203.0.113.5',
        ),
        429,
      );
    });

    test(
      'repeated header lines are joined: the last line, last entry wins',
      () async {
        final app = _App(limit: 1);
        Future<int> send(List<String> lines) async => (await app.handler(
          Request(
            'GET',
            Uri.parse('http://localhost/v1/games/1'),
            headers: {'x-forwarded-for': lines},
            context: {connectionInfoContextKey: _Connection(_caddy)},
          ),
        )).statusCode;
        expect(await send(['9.9.9.9', '203.0.113.5']), 200);
        expect(await send(['1.1.1.1', '2.2.2.2', '203.0.113.5']), 429);
        expect(await send(['203.0.113.5', '203.0.113.6']), 200);
      },
    );

    test('header name in any case', () async {
      final app = _App(limit: 1);
      for (final name in [
        'X-Forwarded-For',
        'x-forwarded-for',
        'X-FORWARDED-FOR',
      ]) {
        final r = await app.send(
          'GET',
          '/v1/games/1',
          peer: _caddy,
          headers: {name: '203.0.113.5'},
        );
        expect(
          r.statusCode,
          name == 'X-Forwarded-For' ? 200 : 429,
          reason: name,
        );
      }
    });

    test('other forwarding headers are ignored', () async {
      final app = _App(limit: 1);
      for (final h in [
        'X-Real-IP',
        'Forwarded',
        'X-Client-IP',
        'True-Client-IP',
        'CF-Connecting-IP',
        'X-Forwarded-Host',
      ]) {
        final r = await app.send(
          'GET',
          '/v1/games/1',
          peer: _caddy,
          headers: {h: '203.0.113.${h.length}'},
        );
        expect(r.statusCode, h == 'X-Real-IP' ? 200 : 429, reason: h);
      }
    });

    test(
      'a very long header is handled quickly and uses the last entry',
      () async {
        final app = _App(limit: 1);
        final long = '${List.filled(40000, '9.9.9.9').join(', ')}, 203.0.113.5';
        final watch = Stopwatch()..start();
        expect(await app.status('/v1/games/1', peer: _caddy, xff: long), 200);
        expect(
          await app.status('/v1/games/1', peer: _caddy, xff: '203.0.113.5'),
          429,
        );
        expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
        // Garbage that is one huge token: falls back to the peer.
        final huge = 'a' * 1000000;
        expect(await app.status('/v1/games/1', peer: _caddy, xff: huge), 200);
      },
    );

    test(
      'the proxy forwarding its own address makes the client the proxy',
      () async {
        final app = _App(limit: 1);
        expect(await app.status('/v1/games/1', peer: _caddy), 200);
        expect(await app.status('/v1/games/1', peer: _caddy, xff: _caddy), 429);
      },
    );
  });

  group('X-Forwarded-For from an untrusted peer', () {
    test(
      'is ignored whatever it says; the socket address is the client',
      () async {
        final app = _App(limit: 1);
        expect(
          await app.status('/v1/games/1', peer: '198.51.100.1', xff: '1.1.1.1'),
          200,
        );
        expect(
          await app.status('/v1/games/1', peer: '198.51.100.1', xff: '2.2.2.2'),
          429,
          reason: 'changing the header does not reset the limit',
        );
        // Spoofing the proxy address or a victim does not spend their quota.
        expect(
          await app.status('/v1/games/1', peer: '198.51.100.1', xff: _caddy),
          429,
        );
        expect(
          await app.status(
            '/v1/games/1',
            peer: '198.51.100.2',
            xff: '198.51.100.1',
          ),
          200,
        );
      },
    );

    test(
      'a neighbour of the proxy address is not trusted (exact match)',
      () async {
        for (final peer in [
          '10.213.7.11',
          '10.213.7.9',
          '10.213.7.100',
          '10.213.8.10',
        ]) {
          final app = _App(limit: 1);
          expect(
            await app.status('/v1/games/1', peer: peer, xff: '1.1.1.1'),
            200,
          );
          expect(
            await app.status('/v1/games/1', peer: peer, xff: '2.2.2.2'),
            429,
            reason: peer,
          );
        }
      },
    );

    test('with no trusted proxies configured, nobody is trusted', () async {
      final app = _App(limit: 1, trusted: const []);
      expect(
        await app.status('/v1/games/1', peer: _caddy, xff: '1.1.1.1'),
        200,
      );
      expect(
        await app.status('/v1/games/1', peer: _caddy, xff: '2.2.2.2'),
        429,
      );
    });

    test(
      'an IPv6 proxy matches in any spelling, and its IPv4-mapped form',
      () async {
        final app = _App(
          limit: 1,
          trusted: const ['2001:db8::10', '::ffff:10.0.0.5'],
        );
        Future<int> via(String peer, String xff) =>
            app.status('/v1/games/1', peer: peer, xff: xff);
        expect(await via('2001:DB8:0:0:0:0:0:10', '1.1.1.1'), 200);
        expect(
          await via('2001:db8::10', '2.2.2.2'),
          200,
          reason: 'trusted: new client',
        );
        expect(await via('2001:db8::10', '2.2.2.2'), 429);
        // Different address in the same /64 is not the proxy.
        expect(await via('2001:db8::11', '3.3.3.3'), 200);
        expect(await via('2001:db8::11', '4.4.4.4'), 429);
        // Mapped form equals IPv4 10.0.0.5 and is trusted.
        expect(await via('10.0.0.5', '5.5.5.5'), 200);
        expect(await via('10.0.0.5', '6.6.6.6'), 200);
      },
    );

    test('a request with no connection info shares one bucket', () async {
      final app = _App(limit: 2);
      expect(await app.status('/v1/games/1'), 200);
      expect(await app.status('/v1/games/1', xff: '1.1.1.1'), 200);
      expect(await app.status('/v1/games/1', xff: '2.2.2.2'), 429);
    });
  });

  group('no client address in any log line', () {
    test(
      'allowed, refused, spoofed, malformed, and failing requests',
      () async {
        final app = _App(limit: 1, maxTracked: 3);
        const marks = [
          '203.0.113.77',
          '198.51.100.88',
          '2001:db8:77:88',
          '6.6.6.6',
        ];
        final peers = ['198.51.100.88', _caddy, '2001:db8:77:88::5'];
        final headers = [
          '203.0.113.77',
          '6.6.6.6, 203.0.113.77',
          '203.0.113.77:443',
          '[2001:db8:77:88::1]',
          'junk 203.0.113.77',
        ];
        for (final peer in peers) {
          for (final xff in headers) {
            for (var i = 0; i < 3; i++) {
              await app.status('/v1/games/1', peer: peer, xff: xff);
              await app.status('/v1/nope', peer: peer, xff: xff);
            }
          }
        }
        await app.status('/health', peer: '198.51.100.88', xff: '203.0.113.77');
        await app.status('/other', peer: '198.51.100.88', xff: '203.0.113.77');
        app.clock.now = const Duration(minutes: 5);
        app.limiter.removeExpired();
        expect(app.logs.lines, isNotEmpty);
        final all = app.logs.lines.join('\n');
        for (final m in marks) {
          expect(all, isNot(contains(m)));
        }
        for (final a in ['203.0.113.77', '198.51.100.88', '6.6.6.6']) {
          expect(all, isNot(contains('${_key(a)}')), reason: 'raw key of $a');
        }
        expect(all.toLowerCase(), isNot(contains('forwarded')));
      },
    );
  });
}
