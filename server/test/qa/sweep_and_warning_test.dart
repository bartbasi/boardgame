import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

/// QA round 2 for T-020: the periodic sweep, the unusable X-Forwarded-For
/// warning, and the Compose ip_range. Pure Dart, no database.

class _Clock {
  Duration now = Duration.zero;
  Duration call() => now;
}

class _Conn implements HttpConnectionInfo {
  _Conn(String a) : remoteAddress = InternetAddress(a);
  @override
  final InternetAddress remoteAddress;
  @override
  int get remotePort => 1;
  @override
  int get localPort => 2;
}

class _FakeTimer implements Timer {
  _FakeTimer(this.interval, this._callback);
  final Duration interval;
  final void Function(Timer) _callback;
  bool active = true;
  int cancels = 0;
  int ticks = 0;

  void fire() {
    if (!active) return;
    ticks++;
    _callback(this);
  }

  @override
  void cancel() {
    cancels++;
    active = false;
  }

  @override
  bool get isActive => active;

  @override
  int get tick => ticks;
}

Request _req(String peer, {String? xff}) => Request(
  'GET',
  Uri.parse('http://localhost/v1/x'),
  headers: {'x-forwarded-for': ?xff},
  context: {connectionInfoContextKey: _Conn(peer)},
);

void main() {
  group('sweep with fake timers', () {
    late _Clock clock;
    late RateLimiter limiter;
    final timers = <_FakeTimer>[];

    Timer factory(Duration i, void Function(Timer) cb) {
      final t = _FakeTimer(i, cb);
      timers.add(t);
      return t;
    }

    setUp(() {
      timers.clear();
      clock = _Clock();
      limiter = RateLimiter(limit: 5, now: clock.call);
    });

    test('the default interval is 10 s and one start makes one timer', () {
      startRateLimitSweep(limiter, periodic: factory);
      expect(timers, hasLength(1));
      expect(timers.single.interval, const Duration(seconds: 10));
      expect(rateLimitSweepInterval, const Duration(seconds: 10));
    });

    test('a custom interval is used', () {
      startRateLimitSweep(
        limiter,
        interval: const Duration(seconds: 3),
        periodic: factory,
      );
      expect(timers.single.interval, const Duration(seconds: 3));
    });

    test('starting makes no change until the timer ticks', () {
      limiter.hit(1);
      startRateLimitSweep(limiter, periodic: factory);
      clock.now = const Duration(minutes: 5);
      expect(limiter.trackedCount, 1, reason: 'no traffic, no tick yet');
      timers.single.fire();
      expect(limiter.trackedCount, 0);
    });

    test('entries are cleared with no traffic, exactly at the window end '
        'and not before', () {
      for (var k = 0; k < 100; k++) {
        limiter.hit(k);
      }
      startRateLimitSweep(limiter, periodic: factory);
      final t = timers.single;
      clock.now = rateLimitWindow - const Duration(microseconds: 1);
      t.fire();
      expect(limiter.trackedCount, 100);
      clock.now = rateLimitWindow;
      t.fire();
      expect(limiter.trackedCount, 0);
    });

    test('staggered windows are cleared in order across ticks', () {
      startRateLimitSweep(limiter, periodic: factory);
      final t = timers.single;
      limiter.hit(1);
      clock.now = const Duration(seconds: 20);
      limiter.hit(2);
      clock.now = const Duration(seconds: 40);
      limiter.hit(3);
      clock.now = const Duration(seconds: 60);
      t.fire();
      expect(limiter.trackedCount, 2);
      clock.now = const Duration(seconds: 80);
      t.fire();
      expect(limiter.trackedCount, 1);
      clock.now = const Duration(seconds: 100);
      t.fire();
      expect(limiter.trackedCount, 0);
    });

    test('a sweep does not touch live entries or their counts', () {
      startRateLimitSweep(limiter, periodic: factory);
      for (var i = 0; i < 5; i++) {
        limiter.hit(1);
      }
      clock.now = const Duration(seconds: 30);
      for (var i = 0; i < 10; i++) {
        timers.single.fire();
      }
      expect(limiter.trackedCount, 1);
      expect(limiter.hit(1), isNotNull, reason: 'still at its limit');
    });

    test('a cancelled timer sweeps nothing more', () {
      limiter.hit(1);
      startRateLimitSweep(limiter, periodic: factory).cancel();
      clock.now = const Duration(minutes: 5);
      timers.single.fire();
      expect(limiter.trackedCount, 1);
      expect(timers.single.cancels, 1);
    });

    test('two sweeps on one limiter are harmless (idempotent)', () {
      for (var k = 0; k < 10; k++) {
        limiter.hit(k);
      }
      startRateLimitSweep(limiter, periodic: factory);
      startRateLimitSweep(limiter, periodic: factory);
      clock.now = rateLimitWindow;
      for (final t in timers) {
        t.fire();
      }
      expect(limiter.trackedCount, 0);
    });

    test('a sweep after the table was evicted to the cap stays consistent', () {
      final small = RateLimiter(limit: 1, maxTracked: 3, now: clock.call);
      startRateLimitSweep(small, periodic: factory);
      for (var k = 0; k < 10; k++) {
        small.hit(k);
      }
      timers.single.fire();
      expect(small.trackedCount, 3);
      clock.now = rateLimitWindow;
      timers.single.fire();
      expect(small.trackedCount, 0);
      expect(small.hit(1), isNull);
    });

    test('the real Timer.periodic default empties an idle limiter and stops '
        'when cancelled', () async {
      final fast = RateLimiter(
        limit: 1,
        window: const Duration(milliseconds: 30),
      );
      fast.hit(1);
      fast.hit(2);
      final timer = startRateLimitSweep(
        fast,
        interval: const Duration(milliseconds: 20),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(fast.trackedCount, 0);
      timer.cancel();
      expect(timer.isActive, isFalse);
    });
  });

  group('unusable X-Forwarded-For warning', () {
    const caddy = '10.213.7.10';
    late _Clock clock;
    late int warnings;
    late ClientAddressResolver resolver;

    setUp(() {
      clock = _Clock();
      warnings = 0;
      resolver = ClientAddressResolver(
        trustedProxies: [InternetAddress(caddy)],
        onUnusableForwarded: () => warnings++,
        now: clock.call,
      );
    });

    test('a missing header warns once, then not again within a minute', () {
      for (var i = 0; i < 1000; i++) {
        resolver.clientKey(_req(caddy));
      }
      expect(warnings, 1);
    });

    test('the boundary is exactly one minute', () {
      resolver.clientKey(_req(caddy));
      clock.now = const Duration(seconds: 59, milliseconds: 999);
      resolver.clientKey(_req(caddy));
      expect(warnings, 1);
      clock.now = const Duration(minutes: 1);
      resolver.clientKey(_req(caddy));
      expect(warnings, 2);
      resolver.clientKey(_req(caddy));
      expect(warnings, 2);
      clock.now = const Duration(minutes: 2);
      resolver.clientKey(_req(caddy));
      expect(warnings, 3);
    });

    test('different kinds of unusable entry share one rate limit', () {
      for (final xff in [
        null,
        '',
        'unknown',
        '1.2.3.4:80',
        '[::1]',
        '1.2.3.4,',
        'x' * 10000,
      ]) {
        resolver.clientKey(_req(caddy, xff: xff));
      }
      expect(warnings, 1);
    });

    test('usable entries never warn', () {
      for (var i = 0; i < 50; i++) {
        resolver.clientKey(_req(caddy, xff: '203.0.113.$i'));
        resolver.clientKey(_req(caddy, xff: '9.9.9.9, 2001:db8::$i'));
        clock.now += const Duration(minutes: 2);
      }
      expect(warnings, 0);
    });

    test('untrusted peers never warn, whatever they send', () {
      for (final xff in [null, '', 'garbage']) {
        resolver.clientKey(_req('198.51.100.1', xff: xff));
      }
      expect(warnings, 0);
    });

    test('a request with no connection info never warns', () {
      resolver.clientKey(Request('GET', Uri.parse('http://localhost/v1/x')));
      expect(warnings, 0);
    });

    test('the fallback key is still the proxy address', () {
      expect(
        resolver.clientKey(_req(caddy, xff: 'junk')),
        addressKey(InternetAddress(caddy)),
      );
    });

    test('a custom warnEvery is honoured', () {
      var n = 0;
      final r = ClientAddressResolver(
        trustedProxies: [InternetAddress(caddy)],
        onUnusableForwarded: () => n++,
        warnEvery: const Duration(seconds: 5),
        now: clock.call,
      );
      r.clientKey(_req(caddy));
      clock.now = const Duration(seconds: 5);
      r.clientKey(_req(caddy));
      expect(n, 2);
    });

    test('no callback: nothing is called and nothing throws', () {
      final r = ClientAddressResolver(
        trustedProxies: [InternetAddress(caddy)],
        now: clock.call,
      );
      expect(() => r.clientKey(_req(caddy)), returnsNormally);
    });

    test('the log line: warning level, only ts, level and msg, no value', () {
      final logs = LogCapture();
      final r = ClientAddressResolver(
        trustedProxies: [InternetAddress(caddy)],
        onUnusableForwarded: logUnusableForwarded(logs.logger()),
        now: clock.call,
      );
      const marker = '203.0.113.250:9999-MARK';
      r.clientKey(_req(caddy, xff: marker));
      final record = logs.records.single;
      expect(record['level'], 'warning');
      expect(record.keys.toSet(), {'ts', 'level', 'msg'});
      final text = jsonEncode(record);
      expect(text, isNot(contains('MARK')));
      expect(text, isNot(contains('203.0.113')));
      expect(text, isNot(contains(caddy)));
      expect(record['msg'], contains('trusted proxy'));
    });

    test('through the middleware the warning appears once for a burst and '
        'the requests are still limited by the proxy bucket', () async {
      final logs = LogCapture();
      final limiter = RateLimiter(limit: 3, now: clock.call);
      final res = ClientAddressResolver(
        trustedProxies: [InternetAddress(caddy)],
        onUnusableForwarded: logUnusableForwarded(logs.logger()),
        now: clock.call,
      );
      final handler = const Pipeline()
          .addMiddleware(rateLimit(limiter, res))
          .addHandler((_) => Response.ok('x'));
      final codes = [
        for (var i = 0; i < 6; i++) (await handler(_req(caddy))).statusCode,
      ];
      expect(codes, [200, 200, 200, 429, 429, 429]);
      expect(logs.records, hasLength(1));
    });
  });

  group('Compose ip_range', () {
    final compose = File('../deploy/docker-compose.yml');

    int ipValue(String a) =>
        InternetAddress(a).rawAddress.fold(0, (v, b) => (v << 8) | b);

    test('the dynamic range is inside the subnet, aligned, and excludes '
        'Caddy, the gateway, and the broadcast-low half', () {
      if (!compose.existsSync()) {
        markTestSkipped('deploy/docker-compose.yml is not in this checkout');
        return;
      }
      final text = compose.readAsStringSync();
      final subnet = RegExp(
        r'^\s+- subnet:\s*(\S+)\s*$',
        multiLine: true,
      ).firstMatch(text)![1]!.split('/');
      final range = RegExp(
        r'^\s+ip_range:\s*(\S+)\s*$',
        multiLine: true,
      ).allMatches(text).toList();
      final caddy = RegExp(
        r'^\s+ipv4_address:\s*(\S+)\s*$',
        multiLine: true,
      ).firstMatch(text)![1]!;
      expect(range, hasLength(1));
      final r = range.single[1]!.split('/');

      final subnetBits = int.parse(subnet[1]);
      final rangeBits = int.parse(r[1]);
      expect(rangeBits, greaterThan(subnetBits), reason: 'strictly smaller');
      expect(rangeBits, lessThanOrEqualTo(30));

      final sMask = (0xffffffff << (32 - subnetBits)) & 0xffffffff;
      final rMask = (0xffffffff << (32 - rangeBits)) & 0xffffffff;
      final sNet = ipValue(subnet[0]);
      final rNet = ipValue(r[0]);
      expect(sNet & sMask, sNet, reason: 'subnet base aligned');
      expect(rNet & rMask, rNet, reason: 'range base aligned');
      expect(rNet & sMask, sNet, reason: 'range inside subnet');

      final rEnd = rNet | (~rMask & 0xffffffff);
      final c = ipValue(caddy);
      expect(c >= rNet && c <= rEnd, isFalse, reason: 'Caddy outside range');
      expect(c & sMask, sNet, reason: 'Caddy inside subnet');
      final gateway = sNet + 1;
      expect(gateway >= rNet && gateway <= rEnd, isFalse);
      // The pinned address is the first half, the range the second half.
      expect(ipValue('10.213.7.10') < rNet, isTrue);
      expect(r.join('/'), '10.213.7.128/25');
    });

    test('the ip_range sits under the web network, not the db network', () {
      if (!compose.existsSync()) {
        markTestSkipped('deploy/docker-compose.yml is not in this checkout');
        return;
      }
      final text = compose.readAsStringSync();
      final web = text.indexOf('\n  web:');
      final db = text.indexOf('\n  db:', web);
      final range = RegExp(
        r'^ +ip_range:',
        multiLine: true,
      ).firstMatch(text)!.start;
      expect(web, greaterThan(0));
      expect(range, greaterThan(web));
      expect(db < 0 || range < db, isTrue, reason: 'before the db network');
    });
  });
}
