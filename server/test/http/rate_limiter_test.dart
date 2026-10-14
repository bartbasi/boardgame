import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

/// A fake monotonic clock.
class _Clock {
  Duration now = Duration.zero;

  Duration call() => now;

  void advance(Duration by) => now += by;
}

void main() {
  late _Clock clock;

  setUp(() => clock = _Clock());

  RateLimiter limiter({int limit = 60, int maxTracked = 100000}) =>
      RateLimiter(limit: limit, maxTracked: maxTracked, now: clock.call);

  group('RateLimiter windows (T-020 AC1, AC3)', () {
    test('allows [limit] requests per key in a window, then refuses with the '
        'time left', () {
      final l = limiter(limit: 3);

      expect(l.hit(1), isNull);
      clock.advance(const Duration(seconds: 10));
      expect(l.hit(1), isNull);
      expect(l.hit(1), isNull);
      expect(l.hit(1), const Duration(seconds: 50));
      clock.advance(const Duration(seconds: 20));
      expect(l.hit(1), const Duration(seconds: 30));
    });

    test('AC3: a limited key is allowed again once a full minute has passed '
        'on the fake clock, and not a microsecond earlier', () {
      final l = limiter(limit: 2);
      l.hit(1);
      l.hit(1);
      expect(l.hit(1), isNotNull);

      clock.advance(rateLimitWindow - const Duration(microseconds: 1));
      expect(l.hit(1), const Duration(microseconds: 1));

      clock.advance(const Duration(microseconds: 1));
      expect(l.hit(1), isNull);
      expect(l.hit(1), isNull);
      expect(l.hit(1), isNotNull);
    });

    test('keys are counted separately (AC2 at unit level)', () {
      final l = limiter(limit: 1);

      expect(l.hit(1), isNull);
      expect(l.hit(1), isNotNull);
      expect(l.hit(2), isNull);
    });

    test('refused requests do not extend the window', () {
      final l = limiter(limit: 1);
      l.hit(1);
      for (var i = 0; i < 59; i++) {
        clock.advance(const Duration(seconds: 1));
        expect(l.hit(1), isNotNull);
      }
      clock.advance(const Duration(seconds: 1));
      expect(l.hit(1), isNull);
    });

    test('the default clock is a real stopwatch', () {
      final l = RateLimiter(limit: 1);

      expect(l.hit(1), isNull);
      final wait = l.hit(1)!;
      expect(wait, greaterThan(const Duration(seconds: 59)));
      expect(wait, lessThanOrEqualTo(rateLimitWindow));
    });

    test('defaults are 60 per minute and 100,000 keys [ASSUMPTION]', () {
      final l = RateLimiter();

      expect(l.limit, 60);
      expect(l.maxTracked, 100000);
      expect(l.window, const Duration(minutes: 1));
      expect(defaultRateLimitPerWindow, 60);
      expect(defaultRateLimitMaxTracked, 100000);
    });

    test('rejects a limit, size, or window below 1', () {
      expect(() => RateLimiter(limit: 0), throwsArgumentError);
      expect(() => RateLimiter(maxTracked: 0), throwsArgumentError);
      expect(() => RateLimiter(window: Duration.zero), throwsArgumentError);
    });
  });

  group('expiry (T-020 AC6)', () {
    test('every entry is removed once its window passes: the tracked count '
        'is 0 after expiry', () {
      final l = limiter(limit: 1);
      l.hit(0xCB007101);
      clock.advance(const Duration(seconds: 30));
      l.hit(0xCB007102);
      l.hit(0xCB007102);
      expect(l.trackedCount, 2);

      clock.advance(const Duration(seconds: 30));
      l.removeExpired();
      expect(l.trackedCount, 1, reason: 'the first window has passed');

      clock.advance(const Duration(seconds: 30));
      l.removeExpired();
      expect(l.trackedCount, 0);
    });

    test('a request for any key also removes expired entries', () {
      final l = limiter();
      for (var i = 0; i < 1000; i++) {
        l.hit(i);
      }
      clock.advance(rateLimitWindow);

      l.hit(-5);

      expect(l.trackedCount, 1);
    });

    test('rate_limiter.dart and rate_limit.dart import no database or file '
        'code and never call the logger with a key', () {
      for (final path in [
        'lib/src/http/rate_limiter.dart',
        'lib/src/http/rate_limit.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('postgres')), reason: path);
        expect(source, isNot(contains('/db/')), reason: path);
        expect(source, isNot(contains('File(')), reason: path);
        expect(source, isNot(contains('print(')), reason: path);
      }
      expect(
        File('lib/src/http/rate_limiter.dart').readAsStringSync(),
        isNot(contains('logger')),
      );
    });
  });

  group('bounded size (T-020 AC7)', () {
    test('200,000 distinct IPs in one minute never track more than the '
        'maximum, and the oldest are evicted first', () {
      var fullCalls = 0;
      final l = RateLimiter(
        limit: 1,
        maxTracked: 100000,
        now: clock.call,
        onFull: () => fullCalls++,
      );
      int ip(int i) => addressKey(
        InternetAddress('10.${i >> 16}.${(i >> 8) & 255}.${i & 255}'),
      );

      var highest = 0;
      for (var i = 0; i < 200000; i++) {
        expect(l.hit(ip(i)), isNull);
        if (l.trackedCount > highest) highest = l.trackedCount;
        if (i % 4 == 0) clock.advance(const Duration(microseconds: 100));
      }
      expect(clock.now, lessThan(rateLimitWindow));

      expect(highest, 100000);
      expect(l.trackedCount, 100000);
      // The newest 100,000 are still tracked: a second request is refused.
      // Check those first, because a fresh hit evicts the oldest entry.
      expect(l.hit(ip(199999)), isNotNull);
      expect(l.hit(ip(100000)), isNotNull);
      // The oldest 100,000 were evicted: they start a new window.
      expect(l.hit(ip(99999)), isNull);
      expect(l.hit(ip(0)), isNull);
      expect(l.trackedCount, 100000);
      expect(fullCalls, 1, reason: 'the full warning fires once per window');
    });

    test('the full warning fires again after a window, with no key in its '
        'log line', () {
      final logs = <String>[];
      final logger = Logger(minLevel: LogLevel.debug, sink: logs.add);
      final l = RateLimiter(
        limit: 1,
        maxTracked: 2,
        now: clock.call,
        onFull: logRateLimiterFull(logger, 2),
      );

      l.hit(addressKey(InternetAddress('198.51.100.1')));
      l.hit(addressKey(InternetAddress('198.51.100.2')));
      l.hit(addressKey(InternetAddress('198.51.100.3')));
      l.hit(addressKey(InternetAddress('198.51.100.4')));
      expect(logs, hasLength(1));
      clock.advance(rateLimitWindow);
      l.hit(addressKey(InternetAddress('198.51.100.5')));
      l.hit(addressKey(InternetAddress('198.51.100.6')));
      expect(logs, hasLength(1), reason: 'expired entries made room');
      l.hit(addressKey(InternetAddress('198.51.100.7')));
      expect(logs, hasLength(2));

      for (final line in logs) {
        expect(line, contains('rate limiter full'));
        expect(line, contains('"maxTracked":2'));
        expect(line, isNot(contains('198.51.100')));
      }
    });
  });
}
