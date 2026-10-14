// T-013 QA round 1: edge cases beyond the developer's tests. Timing tests run
// in fake time through runFake.
import 'dart:convert';
import 'dart:math';

import 'package:api_contract/api_contract.dart';
import 'package:board_game_collector/core/data/network/api_config.dart';
import 'package:board_game_collector/core/data/network/failure_mapper.dart';
import 'package:board_game_collector/core/data/network/retry_policy.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_http.dart';

final String _healthOk = contractFixture('health/ok.json');

HealthResponse _decode(Map<String, dynamic> json) =>
    HealthResponse.fromJson(json);

Timed<HealthResponse> _get(
  FakeHttpAdapter adapter, {
  RetryPolicy policy = const RetryPolicy(),
  CancelToken? cancelToken,
  String baseUrl = testBaseUrl,
  String path = '/health',
  Map<String, String>? query,
  Random? random,
}) => runFake(
  () =>
      fakeClient(adapter, baseUrl: baseUrl, policy: policy, random: random).get(
        path,
        decode: _decode,
        cancelToken: cancelToken,
        queryParameters: query,
      ),
);

Duration _s(int s) => Duration(seconds: s);

void main() {
  final now = DateTime.utc(2026, 10, 12, 12);

  group('parseRetryAfter edge cases', () {
    test('negative seconds are unreadable', () {
      expect(parseRetryAfter('-5', now: now), isNull);
    });
    test('zero is zero', () {
      expect(parseRetryAfter('0', now: now), Duration.zero);
      expect(parseRetryAfter('000', now: now), Duration.zero);
    });
    test('a decimal is unreadable', () {
      expect(parseRetryAfter('1.5', now: now), isNull);
    });
    test('a 40-digit number is clamped, never throws', () {
      final value = parseRetryAfter('9' * 40, now: now);
      expect(value, isNotNull);
      expect(value! > const Duration(seconds: 30), isTrue);
    });
    test('surrounding spaces are tolerated', () {
      expect(parseRetryAfter('  7 ', now: now), _s(7));
    });
    test('malformed dates are unreadable', () {
      for (final v in ['tomorrow', 'Wed, 12 Oct 2026', '١٢٣', '1e3', '+5']) {
        expect(parseRetryAfter(v, now: now), isNull, reason: v);
      }
    });
    test('an HTTP date far in the future is huge, not null', () {
      final v = parseRetryAfter('Fri, 31 Dec 9999 23:59:59 GMT', now: now);
      expect(v, isNotNull);
      expect(v! > _s(30), isTrue);
    });
    test('asctime dates parse', () {
      expect(parseRetryAfter('Mon Oct 12 12:00:10 2026', now: now), _s(10));
    });
  });

  group('429 on GET', () {
    test('without Retry-After is retried with backoff, then fails', () {
      final adapter = FakeHttpAdapter([respond(429)]);
      final t = _get(adapter);
      expect(adapter.requests, hasLength(4));
      expect(t.result.failureOrNull, const RateLimitedFailure());
    });
    test('with Retry-After: 1 is retried after at least 1 s', () {
      final adapter = FakeHttpAdapter([
        respond(429, headers: {'Retry-After': '1'}),
        respond(200, body: _healthOk),
      ]);
      final t = _get(adapter);
      expect(t.result.isOk, isTrue);
      expect(adapter.gaps.single, greaterThanOrEqualTo(_s(1)));
    });
    test('with a past HTTP date retries at once', () {
      final adapter = FakeHttpAdapter([
        respond(429, headers: {'Retry-After': 'Mon, 01 Jan 2024 00:00:00 GMT'}),
        respond(200, body: _healthOk),
      ]);
      _get(adapter);
      expect(adapter.gaps.single, Duration.zero);
    });
    test('with a negative Retry-After falls back to jittered backoff', () {
      final adapter = FakeHttpAdapter([
        respond(429, headers: {'Retry-After': '-1'}),
        respond(200, body: _healthOk),
      ]);
      _get(adapter, random: FixedRandom(0.5));
      expect(adapter.gaps.single, const Duration(milliseconds: 250));
    });
    test('with a huge Retry-After is not retried and carries the wait', () {
      final adapter = FakeHttpAdapter([
        respond(429, headers: {'Retry-After': '99999999999999999999'}),
      ]);
      final t = _get(adapter);
      expect(adapter.requests, hasLength(1));
      final f = t.result.failureOrNull;
      expect(f, isA<RateLimitedFailure>());
      expect((f! as RateLimitedFailure).retryAfter! > _s(30), isTrue);
    });
    test('with a Retry-After of 20 s ends at once (would pass deadline)', () {
      final adapter = FakeHttpAdapter([
        respond(429, headers: {'Retry-After': '20'}),
      ]);
      final t = _get(adapter);
      expect(adapter.requests, hasLength(1));
      expect(t.elapsed, Duration.zero);
    });
    test('POST 429 is sent once and carries Retry-After', () {
      final adapter = FakeHttpAdapter([
        respond(429, headers: {'Retry-After': '4'}),
      ]);
      final t = runFake(
        () => fakeClient(adapter).post('/v1/x', decode: _decode, body: {}),
      );
      expect(adapter.requests, hasLength(1));
      expect(t.result.failureOrNull, RateLimitedFailure(retryAfter: _s(4)));
    });
  });

  group('jitter bounds at every attempt', () {
    test('each real retry wait is in [0, ceiling) for many seeds', () {
      const ceilings = [500, 1000, 2000];
      for (var seed = 0; seed < 40; seed++) {
        final adapter = FakeHttpAdapter([respond(503)]);
        _get(adapter, random: Random(seed));
        expect(adapter.gaps, hasLength(3));
        for (var i = 0; i < 3; i++) {
          expect(adapter.gaps[i], greaterThanOrEqualTo(Duration.zero));
          expect(
            adapter.gaps[i],
            lessThan(Duration(milliseconds: ceilings[i])),
            reason: 'seed $seed retry ${i + 1}',
          );
        }
      }
    });
    test('the maximum random value (just under 1) stays under the cap', () {
      const policy = RetryPolicy();
      final r = FixedRandom(0.9999999999999999);
      for (var n = 1; n <= 6; n++) {
        expect(policy.backoff(n, r), lessThan(policy.maxBackoff));
      }
    });
    test('the 8 s cap holds for larger retry counts', () {
      const policy = RetryPolicy(maxRetries: 10);
      final r = FixedRandom(0.99999);
      for (var n = 5; n <= 40; n++) {
        final d = policy.backoff(n, r);
        expect(d.isNegative, isFalse, reason: 'retry $n');
        expect(d, lessThanOrEqualTo(policy.maxBackoff), reason: 'retry $n');
      }
    });
    test('backoff stays sane for absurd retry numbers', () {
      // Tightened by flutter-developer in T-013 round 2 (review R1-S1): the
      // old bounds also accepted 0, which is what an overflowing ceiling
      // gave. Half of the 8 s cap is exactly 4 s for every retry from 6 up.
      const policy = RetryPolicy();
      final r = FixedRandom(0.5);
      for (final n in [
        6,
        7,
        10,
        45,
        46,
        47,
        62,
        63,
        64,
        65,
        100,
        1000,
        1 << 30,
      ]) {
        final d = policy.backoff(n, r);
        expect(d, const Duration(seconds: 4), reason: 'retry $n');
      }
    });
  });

  group('cancellation', () {
    test('cancelling mid-retry wait stops further requests', () {
      final adapter = FakeHttpAdapter([respond(503)]);
      final t = runFake(() {
        final token = CancelToken();
        final f = fakeClient(
          adapter,
          random: FixedRandom(0.99),
        ).get('/health', decode: _decode, cancelToken: token);
        Future<void>.delayed(const Duration(milliseconds: 100), token.cancel);
        return f;
      });
      expect(t.result.failureOrNull, const CancelledFailure());
      expect(adapter.requests, hasLength(1));
    });
    test('cancelling twice is harmless', () {
      final adapter = FakeHttpAdapter([hang()]);
      final t = runFake(() {
        final token = CancelToken();
        final f = fakeClient(adapter)
            .get('/health', decode: _decode, cancelToken: token);
        Future<void>.delayed(const Duration(seconds: 1), () {
          token.cancel();
          token.cancel('again');
        });
        return f;
      });
      expect(t.result.failureOrNull, const CancelledFailure());
      expect(t.elapsed, _s(1));
    });
    test('cancelling after the call finished changes nothing', () {
      final token = CancelToken();
      final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
      final t = _get(adapter, cancelToken: token);
      token.cancel();
      expect(t.result.isOk, isTrue);
    });
    test('a shared token cancels a POST too', () {
      final token = CancelToken()..cancel();
      final adapter = FakeHttpAdapter([respond(200)]);
      final t = runFake(
        () =>
            fakeClient(adapter)
                .post('/v1/x', decode: _decode, cancelToken: token),
      );
      expect(t.result.failureOrNull, const CancelledFailure());
      expect(adapter.requests, isEmpty);
    });
  });

  group('the 20 s deadline', () {
    test('a response at 19.99 s is accepted', () {
      final adapter = FakeHttpAdapter([
        respond(
          200,
          body: _healthOk,
          delay: const Duration(milliseconds: 19990),
        ),
      ]);
      // Per attempt receive timeout is a dio feature; the fake adapter does
      // not enforce it, so only the 20 s budget applies here.
      final t = _get(adapter);
      expect(t.result.isOk, isTrue);
    });
    test('a response at 20.01 s is a timeout', () {
      final adapter = FakeHttpAdapter([
        respond(
          200,
          body: _healthOk,
          delay: const Duration(milliseconds: 20010),
        ),
      ]);
      final t = _get(adapter);
      expect(t.result.failureOrNull, const TimeoutFailure());
      expect(t.elapsed, _s(20));
    });
    test('a response at exactly 20 s gives one clean outcome', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: _healthOk, delay: _s(20)),
      ]);
      final t = _get(adapter);
      // Either outcome is acceptable, but it must be a Result, not a throw,
      // and must not exceed the budget.
      expect(t.elapsed, lessThanOrEqualTo(_s(20)));
      expect(t.result.isOk || t.result.failureOrNull is TimeoutFailure, isTrue);
    });
    test('503 at 19.9 s does not start a retry past the deadline', () {
      final adapter = FakeHttpAdapter([
        respond(503, delay: const Duration(milliseconds: 19900)),
      ]);
      final t = _get(adapter, random: FixedRandom(0.5));
      expect(adapter.requests, hasLength(1));
      expect(t.elapsed, lessThanOrEqualTo(_s(20)));
    });
  });

  group('base URLs', () {
    test('many trailing slashes are removed', () {
      final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
      _get(adapter, baseUrl: 'https://api.example.test///');
      expect(
        adapter.requests.single.uri.toString(),
        'https://api.example.test/health',
      );
    });
    test('a path prefix with a trailing slash joins once', () {
      final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
      _get(adapter, baseUrl: 'https://api.example.test/api/v1/');
      expect(
        adapter.requests.single.uri.toString(),
        'https://api.example.test/api/v1/health',
      );
    });
    test('a base URL with a query or fragment is refused', () {
      for (final raw in [
        'https://api.example.test/?a=1',
        'https://api.example.test?',
        'https://api.example.test#x',
        'https://user:pw@api.example.test',
      ]) {
        final r = ApiConfig.parse(raw, allowInsecureHttp: false);
        expect(r.failureOrNull, isA<ConfigurationFailure>(), reason: raw);
      }
    });
    test('uppercase scheme and host are accepted', () {
      final r = ApiConfig.parse(
        'HTTPS://API.Example.TEST/',
        allowInsecureHttp: false,
      );
      expect(r.isOk, isTrue);
    });
    test('uppercase HTTP is still refused in release', () {
      final r = ApiConfig.parse(
        'HTTP://api.example.test',
        allowInsecureHttp: false,
      );
      expect(r.failureOrNull, isA<ConfigurationFailure>());
    });
    test('other schemes are refused', () {
      for (final raw in [
        'ftp://api.example.test',
        'file:///etc/passwd',
        'javascript:alert(1)',
        'https://',
        '//api.example.test',
        'api.example.test',
      ]) {
        expect(
          ApiConfig.parse(raw, allowInsecureHttp: true).failureOrNull,
          isA<ConfigurationFailure>(),
          reason: raw,
        );
      }
    });
    test('a path with a backslash or CR/LF cannot change host', () {
      final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
      _get(adapter, path: r'/\evil.test/x');
      for (final r in adapter.requests) {
        expect(r.uri.host, 'api.example.test');
      }
    });
    test('query values with unicode and reserved characters are encoded', () {
      final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
      _get(adapter, query: {'q': 'Café & Ünïcode #1 ?x=y 世界'});
      final uri = adapter.requests.single.uri;
      expect(uri.host, 'api.example.test');
      expect(uri.queryParameters['q'], 'Café & Ünïcode #1 ?x=y 世界');
      expect(uri.hasFragment, isFalse);
    });
  });

  group('bodies', () {
    // T-028 AC7 replaced the T-013 rule "a 5 MB body decodes": bodies over
    // 1 MiB are the unexpected failure after one request, never retried.
    test('a 5 MB valid JSON object body is the unexpected failure, once', () {
      final big = jsonEncode({
        'status': 'ok',
        'version': 'x' * (5 * 1024 * 1024),
      });
      final adapter = FakeHttpAdapter([
        respond(200, body: big),
        respond(200, body: big),
      ]);
      final t = _get(adapter);
      expect(t.result.failureOrNull, const UnexpectedFailure());
      expect(adapter.requests, hasLength(1));
    });
    test('unicode values survive', () {
      final body = jsonEncode({'status': 'ok', 'version': 'Café 世界 🎲'});
      final adapter = FakeHttpAdapter([respond(200, body: body)]);
      final t = _get(adapter);
      expect(t.result.valueOrNull?.version, 'Café 世界 🎲');
    });
    test('a huge non-JSON error body maps by status', () {
      final adapter = FakeHttpAdapter([
        respond(500, body: '<html>${'a' * 2000000}</html>'),
      ]);
      final t = _get(adapter);
      expect(t.result.failureOrNull, const UnexpectedFailure());
      expect(adapter.requests, hasLength(1));
    });
    test('a 200 with an empty body is unexpected', () {
      final adapter = FakeHttpAdapter([respond(200, body: '')]);
      expect(_get(adapter).result.failureOrNull, const UnexpectedFailure());
    });
    test('a 204 is unexpected, not a crash', () {
      final adapter = FakeHttpAdapter([respond(204, body: '')]);
      expect(_get(adapter).result.failureOrNull, const UnexpectedFailure());
    });
    test('a 3xx is unexpected and not followed', () {
      final adapter = FakeHttpAdapter([
        respond(302, headers: {'Location': 'https://evil.test/'}),
      ]);
      final t = _get(adapter);
      expect(t.result.failureOrNull, const UnexpectedFailure());
      expect(adapter.requests, hasLength(1));
    });
  });

  group('failure mapper over every ErrorCode', () {
    for (final code in ErrorCode.values) {
      test('400 with ${code.name} maps without throwing', () {
        final body = jsonEncode({
          'error': {'code': code.wireName, 'message': 'm'},
        });
        final f = failureForStatus(400, body: body);
        expect(f, isA<InvalidInputFailure>());
        final expected = switch (code) {
          ErrorCode.invalidBarcode => InvalidInputCode.invalidBarcode,
          ErrorCode.invalidQuery => InvalidInputCode.invalidQuery,
          ErrorCode.invalidBggId => InvalidInputCode.invalidBggId,
          _ => InvalidInputCode.unknown,
        };
        expect((f as InvalidInputFailure).code, expected);
      });
    }
    test('an unknown code string maps to unknown', () {
      final body = jsonEncode({
        'error': {'code': 'brand_new_code', 'message': 'm'},
      });
      expect(
        (failureForStatus(422, body: body) as InvalidInputFailure).code,
        InvalidInputCode.unknown,
      );
    });
    test('a 404 with a 400-type code in the body is still NotFound', () {
      final body = jsonEncode({
        'error': {'code': 'invalid_barcode', 'message': 'm'},
      });
      expect(failureForStatus(404, body: body), const NotFoundFailure());
    });
    test('status codes outside the table are unexpected', () {
      for (final s in [100, 199, 300, 304, 405, 409, 418, 451, 500, 501, 599]) {
        expect(failureForStatus(s), const UnexpectedFailure(), reason: '$s');
      }
    });
    test('every DioExceptionType maps and never throws', () {
      for (final type in DioExceptionType.values) {
        final f = failureForError(
          DioException(
            requestOptions: RequestOptions(path: '/'),
            type: type,
          ),
        );
        expect(f, isA<Failure>(), reason: type.name);
      }
    });
    test('non-Dio errors are unexpected', () {
      expect(failureForError(StateError('x')), const UnexpectedFailure());
      expect(failureForError('str'), const UnexpectedFailure());
    });
  });

  group('debug log never leaks request details', () {
    const secret = 'zq7secret';
    test('query string passed as a parameter is not logged', () {
      final lines = <String>[];
      final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
      final client = fakeClient(adapter, enableLogging: true, log: lines.add);
      runFake(
        () => client.get(
          '/v1/search',
          decode: _decode,
          queryParameters: {'q': secret},
        ),
      );
      expect(lines.join(), isNot(contains(secret)));
      expect(lines, isNotEmpty);
    });
    test('a query string embedded in the path is not logged', () {
      final lines = <String>[];
      final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
      final client = fakeClient(adapter, enableLogging: true, log: lines.add);
      runFake(
        () => client.get('/v1/search?q=$secret#$secret', decode: _decode),
      );
      expect(lines.join(), isNot(contains(secret)));
      expect(lines.join(), isNot(contains('?')));
    });
    test('errors and retries log no body, header, or query', () {
      final lines = <String>[];
      final adapter = FakeHttpAdapter([
        respond(503, body: secret, headers: {'X-Token': secret}),
      ]);
      final client = fakeClient(adapter, enableLogging: true, log: lines.add);
      runFake(
        () => client.get(
          '/v1/lookup',
          decode: _decode,
          queryParameters: {'barcode': secret},
        ),
      );
      expect(lines, hasLength(4));
      expect(lines.join('\n'), isNot(contains(secret)));
    });
    test('a failed connection logs only the error type', () {
      final lines = <String>[];
      final adapter = FakeHttpAdapter([
        failWith(DioExceptionType.connectionError, error: secret),
      ]);
      final client = fakeClient(adapter, enableLogging: true, log: lines.add);
      runFake(() => client.get('/health', decode: _decode));
      expect(lines.join(), isNot(contains(secret)));
    });
    test('post body is not logged', () {
      final lines = <String>[];
      final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
      final client = fakeClient(adapter, enableLogging: true, log: lines.add);
      runFake(() => client.post('/v1/x', decode: _decode, body: {'a': secret}));
      expect(lines.join(), isNot(contains(secret)));
    });
  });
}
