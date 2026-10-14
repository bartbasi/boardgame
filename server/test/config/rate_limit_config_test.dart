import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

const _valid = {'PORT': '8080', 'LOG_LEVEL': 'info'};

ConfigException _failure(Map<String, String> environment) {
  try {
    Config.load(environment);
  } on ConfigException catch (e) {
    return e;
  }
  fail('Config.load did not throw for $environment');
}

void main() {
  group('rate limit config (T-020)', () {
    test('defaults: 60 per minute [ASSUMPTION], 100,000 tracked IPs '
        '[ASSUMPTION], no trusted proxy', () {
      final config = Config.load(_valid);

      expect(config.rateLimitPerMinute, 60);
      expect(config.rateLimitMaxTrackedIps, 100000);
      expect(config.trustedProxies, isEmpty);
    });

    test('empty values fall back to the defaults', () {
      final config = Config.load({
        ..._valid,
        'RATE_LIMIT_PER_MINUTE': ' ',
        'RATE_LIMIT_MAX_TRACKED_IPS': '',
        'TRUSTED_PROXY_ADDRESSES': '',
      });

      expect(config.rateLimitPerMinute, 60);
      expect(config.rateLimitMaxTrackedIps, 100000);
      expect(config.trustedProxies, isEmpty);
    });

    test('reads every value, including IPv6 proxies and spaces', () {
      final config = Config.load({
        ..._valid,
        'RATE_LIMIT_PER_MINUTE': '120',
        'RATE_LIMIT_MAX_TRACKED_IPS': '5000',
        'TRUSTED_PROXY_ADDRESSES': '10.213.7.10, fd00::10',
      });

      expect(config.rateLimitPerMinute, 120);
      expect(config.rateLimitMaxTrackedIps, 5000);
      expect(config.trustedProxies, [
        InternetAddress('10.213.7.10'),
        InternetAddress('fd00::10'),
      ]);
    });

    test('accepts the bounds', () {
      final low = Config.load({
        ..._valid,
        'RATE_LIMIT_PER_MINUTE': '1',
        'RATE_LIMIT_MAX_TRACKED_IPS': '1',
      });
      final high = Config.load({
        ..._valid,
        'RATE_LIMIT_PER_MINUTE': '${Config.maxRateLimitPerMinute}',
        'RATE_LIMIT_MAX_TRACKED_IPS': '${Config.maxRateLimitMaxTrackedIps}',
        'TRUSTED_PROXY_ADDRESSES': List.filled(
          Config.maxTrustedProxies,
          '10.0.0.1',
        ).join(','),
      });

      expect(low.rateLimitPerMinute, 1);
      expect(low.rateLimitMaxTrackedIps, 1);
      expect(high.rateLimitPerMinute, 10000);
      expect(high.rateLimitMaxTrackedIps, 200000);
      expect(high.trustedProxies, hasLength(10));
    });

    for (final value in ['0', '-1', 'abc', '10001', '1.5', '99999999']) {
      test('RATE_LIMIT_PER_MINUTE=$value fails naming the variable, not the '
          'value', () {
        final error = _failure({..._valid, 'RATE_LIMIT_PER_MINUTE': value});

        expect(
          error.problems.single,
          'RATE_LIMIT_PER_MINUTE is invalid; it must be an integer from 1 to '
          '10000 (default 60).',
        );
      });
    }

    for (final value in ['0', 'many', '200001']) {
      test('RATE_LIMIT_MAX_TRACKED_IPS=$value fails naming the variable', () {
        final error = _failure({
          ..._valid,
          'RATE_LIMIT_MAX_TRACKED_IPS': value,
        });

        expect(
          error.problems.single,
          'RATE_LIMIT_MAX_TRACKED_IPS is invalid; it must be an integer from 1 '
          'to 200000 (default 100000).',
        );
      });
    }

    for (final value in [
      'caddy',
      '10.213.7.10,',
      '10.213.7.0/24',
      '10.213.7.300',
      '10.213.7.10:80',
      List.filled(11, '10.0.0.1').join(','),
    ]) {
      test('TRUSTED_PROXY_ADDRESSES=$value fails without echoing it', () {
        final error = _failure({..._valid, 'TRUSTED_PROXY_ADDRESSES': value});

        expect(
          error.problems.single,
          'TRUSTED_PROXY_ADDRESSES is invalid; it must be a comma-separated '
          'list of at most 10 IP addresses (default none).',
        );
        expect(error.message, isNot(contains('10.213.7')));
      });
    }

    test('the trusted proxy list cannot be changed after loading', () {
      final config = Config.load({
        ..._valid,
        'TRUSTED_PROXY_ADDRESSES': '10.213.7.10',
      });

      expect(
        () => config.trustedProxies.add(InternetAddress('10.0.0.9')),
        throwsUnsupportedError,
      );
    });
  });
}
