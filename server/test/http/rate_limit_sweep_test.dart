import 'dart:async';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

/// A fake monotonic clock.
class _Clock {
  Duration now = Duration.zero;

  Duration call() => now;
}

/// A periodic timer that fires only when the test says so.
class _FakeTimer implements Timer {
  _FakeTimer(this.interval, this._callback);

  final Duration interval;
  final void Function(Timer) _callback;
  bool _active = true;
  int _tick = 0;

  void fire() {
    if (!_active) return;
    _tick++;
    _callback(this);
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;
}

class _Connection implements HttpConnectionInfo {
  _Connection(String address) : remoteAddress = InternetAddress(address);

  @override
  final InternetAddress remoteAddress;

  @override
  int get remotePort => 50000;

  @override
  int get localPort => 8080;
}

int _ip(String address) => addressKey(InternetAddress(address));

void main() {
  group('periodic sweep (T-020 AC6, review R1-S2)', () {
    late _Clock clock;
    late RateLimiter limiter;
    late List<_FakeTimer> timers;

    Timer fakePeriodic(Duration interval, void Function(Timer) callback) {
      final timer = _FakeTimer(interval, callback);
      timers.add(timer);
      return timer;
    }

    setUp(() {
      clock = _Clock();
      limiter = RateLimiter(now: clock.call);
      timers = [];
    });

    test('runs every 10 s by default [ASSUMPTION]', () {
      startRateLimitSweep(limiter, periodic: fakePeriodic);

      expect(timers.single.interval, const Duration(seconds: 10));
      expect(rateLimitSweepInterval, const Duration(seconds: 10));
    });

    test('with no traffic, entries are removed by the sweep after their '
        'window, and not before', () {
      startRateLimitSweep(limiter, periodic: fakePeriodic);
      limiter.hit(_ip('198.51.100.1'));
      clock.now = const Duration(seconds: 30);
      limiter.hit(_ip('198.51.100.2'));
      limiter.hit(_ip('2001:db8::1'));

      clock.now = const Duration(seconds: 59);
      timers.single.fire();
      expect(limiter.trackedCount, 3);

      clock.now = const Duration(seconds: 60);
      timers.single.fire();
      expect(limiter.trackedCount, 2);

      clock.now = const Duration(seconds: 90);
      timers.single.fire();
      expect(limiter.trackedCount, 0, reason: 'nothing held after expiry');
    });

    test('a cancelled sweep removes nothing more', () {
      final timer = startRateLimitSweep(limiter, periodic: fakePeriodic);
      limiter.hit(_ip('198.51.100.1'));
      timer.cancel();
      clock.now = rateLimitWindow;

      timers.single.fire();

      expect(timer.isActive, isFalse);
      expect(limiter.trackedCount, 1);
    });

    test(
      'with the real Timer.periodic, an idle limiter empties itself',
      () async {
        final real = RateLimiter(window: const Duration(milliseconds: 1));
        real.hit(1);
        real.hit(2);
        final timer = startRateLimitSweep(
          real,
          interval: const Duration(milliseconds: 5),
        );
        addTearDown(timer.cancel);

        final deadline = DateTime.now().add(const Duration(seconds: 2));
        while (real.trackedCount > 0 && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }

        expect(real.trackedCount, 0);
        timer.cancel();
        expect(timer.isActive, isFalse);
      },
    );
  });

  group('unusable X-Forwarded-For from the trusted proxy (review R1-G2)', () {
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

    int key(String peer, [String? forwardedFor]) => resolver.clientKey(
      Request(
        'GET',
        Uri.parse('http://localhost/v1/x'),
        headers: {'x-forwarded-for': ?forwardedFor},
        context: {connectionInfoContextKey: _Connection(peer)},
      ),
    );

    test('a missing or unparsable entry warns once a minute and falls back '
        'to the proxy address', () {
      expect(key(caddy), _ip(caddy));
      expect(warnings, 1);
      expect(key(caddy, 'unknown'), _ip(caddy));
      expect(key(caddy, '203.0.113.1:443'), _ip(caddy));
      clock.now = const Duration(seconds: 59);
      key(caddy, '');
      expect(warnings, 1, reason: 'at most once per minute');

      clock.now = rateLimitWindow;
      key(caddy, 'garbage');
      expect(warnings, 2);
    });

    test('usable entries and untrusted peers never warn', () {
      expect(key(caddy, '203.0.113.1'), _ip('203.0.113.1'));
      expect(key('198.51.100.9'), _ip('198.51.100.9'));
      expect(key('198.51.100.9', 'garbage'), _ip('198.51.100.9'));

      expect(warnings, 0);
    });

    test('the warning line holds no value and no address', () {
      final logs = LogCapture();
      final logging = ClientAddressResolver(
        trustedProxies: [InternetAddress(caddy)],
        onUnusableForwarded: logUnusableForwarded(logs.logger()),
      );

      logging.clientKey(
        Request(
          'GET',
          Uri.parse('http://localhost/v1/x'),
          headers: {'x-forwarded-for': 'secret-value, 203.0.113.1:99'},
          context: {connectionInfoContextKey: _Connection(caddy)},
        ),
      );

      final record = logs.records.single;
      expect(record['level'], 'warning');
      expect(record['msg'], contains('trusted proxy sent no usable client'));
      expect(record.keys.toSet(), {'ts', 'level', 'msg'});
      expect(logs.lines.single, isNot(contains('secret-value')));
      expect(logs.lines.single, isNot(contains('203.0.113')));
      expect(logs.lines.single, isNot(contains('10.213.7')));
    });

    test('without a callback nothing happens', () {
      final silent = ClientAddressResolver(
        trustedProxies: [InternetAddress(caddy)],
      );

      expect(
        silent.clientKey(
          Request(
            'GET',
            Uri.parse('http://localhost/v1/x'),
            context: {connectionInfoContextKey: _Connection(caddy)},
          ),
        ),
        _ip(caddy),
      );
    });
  });
}
