// T-013 AC4, AC6, AC7: backoff and Retry-After parsing.
import 'dart:io';
import 'dart:math';

import 'package:board_game_collector/core/data/network/retry_policy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http.dart';

void main() {
  group('RetryPolicy defaults', () {
    test('match the T-013 assumption', () {
      const policy = RetryPolicy();
      expect(policy.baseDelay, const Duration(milliseconds: 500));
      expect(policy.factor, 2);
      expect(policy.maxBackoff, const Duration(seconds: 8));
      expect(policy.maxRetries, 3);
      expect(policy.maxRetryAfter, const Duration(seconds: 30));
      expect(policy.connectTimeout, const Duration(seconds: 10));
      expect(policy.receiveTimeout, const Duration(seconds: 15));
      expect(policy.totalTimeout, const Duration(seconds: 20));
    });
  });

  group('backoff (full jitter)', () {
    const policy = RetryPolicy();
    const ceilings = {
      1: Duration(milliseconds: 500),
      2: Duration(seconds: 1),
      3: Duration(seconds: 2),
      4: Duration(seconds: 4),
      5: Duration(seconds: 8),
      6: Duration(seconds: 8),
      10: Duration(seconds: 8),
    };

    for (final MapEntry(key: retry, value: ceiling) in ceilings.entries) {
      test('retry $retry stays in [0, $ceiling)', () {
        final random = Random(retry);
        for (var i = 0; i < 1000; i++) {
          final wait = policy.backoff(retry, random);
          expect(wait, greaterThanOrEqualTo(Duration.zero));
          expect(wait, lessThan(ceiling));
        }
        expect(policy.backoff(retry, FixedRandom(0)), Duration.zero);
        expect(
          policy.backoff(retry, FixedRandom(0.5)),
          Duration(microseconds: ceiling.inMicroseconds ~/ 2),
        );
      });
    }

    test('a seeded random gives the same waits every run', () {
      List<Duration> waits() {
        final random = Random(42);
        return [for (var r = 1; r <= 3; r++) policy.backoff(r, random)];
      }

      expect(waits(), waits());
    });

    test('waits are spread out, not fixed', () {
      final random = Random(7);
      final waits = {for (var i = 0; i < 50; i++) policy.backoff(1, random)};
      expect(waits.length, greaterThan(40));
    });
  });

  group('parseRetryAfter', () {
    final now = DateTime.utc(2026, 10, 12, 12);

    test('delta seconds', () {
      expect(parseRetryAfter('3', now: now), const Duration(seconds: 3));
      expect(parseRetryAfter(' 120 ', now: now), const Duration(seconds: 120));
      expect(parseRetryAfter('0', now: now), Duration.zero);
    });

    test('a huge number is clamped, not ignored', () {
      const max = Duration(seconds: 0x7fffffff);
      expect(parseRetryAfter('3000000000', now: now), max);
      expect(parseRetryAfter('99999999999999999999999', now: now), max);
    });

    test('an HTTP date in the future', () {
      final value = HttpDate.format(now.add(const Duration(seconds: 5)));
      expect(parseRetryAfter(value, now: now), const Duration(seconds: 5));
    });

    test('an HTTP date in the past gives zero', () {
      final value = HttpDate.format(now.subtract(const Duration(minutes: 1)));
      expect(parseRetryAfter(value, now: now), Duration.zero);
    });

    for (final value in [
      null,
      '',
      '  ',
      '-1',
      '1.5',
      'soon',
      'Mon, 99 Foo 2026 12:00:00 GMT',
    ]) {
      test('unreadable value "$value" gives null', () {
        expect(parseRetryAfter(value, now: now), isNull);
      });
    }
  });
}
