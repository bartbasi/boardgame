// T-013: the API client. Every timing test runs in fake time (fake_async
// drives Timer, Future.delayed, and package:clock), with a seeded random.
import 'dart:io';
import 'dart:math';

import 'package:api_contract/api_contract.dart';
import 'package:board_game_collector/core/data/network/api_client.dart';
import 'package:board_game_collector/core/data/network/api_config.dart';
import 'package:board_game_collector/core/data/network/retry_policy.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http.dart';

final String _healthOk = contractFixture('health/ok.json');

HealthResponse _decodeHealth(Map<String, dynamic> json) =>
    HealthResponse.fromJson(json);

Timed<HealthResponse> _getHealth(
  FakeHttpAdapter adapter, {
  RetryPolicy policy = const RetryPolicy(),
  CancelToken? cancelToken,
}) => runFake(
  () => fakeClient(
    adapter,
    policy: policy,
  ).get('/health', decode: _decodeHealth, cancelToken: cancelToken),
);

const RetryPolicy _noRetries = RetryPolicy(maxRetries: 0);

void main() {
  group('AC2: every request goes to the API_BASE_URL', () {
    test('GET joins the path to the base URL', () {
      final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
      final timed = _getHealth(adapter);

      expect(
        timed.result,
        const Ok(HealthResponse(status: 'ok', version: '0.1.0+abc1234')),
      );
      expect(
        adapter.requests.single.uri,
        Uri.parse('https://api.example.test/health'),
      );
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.headers['Accept'], 'application/json');
    });

    test('query parameters are encoded onto the same host', () {
      final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
      runFake(
        () => fakeClient(adapter).get(
          '/v1/search',
          decode: _decodeHealth,
          queryParameters: {'q': 'Catan & friends'},
        ),
      );

      final uri = adapter.requests.single.uri;
      expect(uri.origin, 'https://api.example.test');
      expect(uri.path, '/v1/search');
      expect(uri.queryParameters, {'q': 'Catan & friends'});
    });

    test('a base URL with a path prefix keeps the prefix', () {
      final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
      runFake(
        () => fakeClient(
          adapter,
          baseUrl: 'https://api.example.test:8443/api/',
        ).get('/v1/games/13', decode: _decodeHealth),
      );

      expect(
        adapter.requests.single.uri,
        Uri.parse('https://api.example.test:8443/api/v1/games/13'),
      );
    });

    test('POST goes to the same base URL', () {
      final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
      runFake(
        () =>
            fakeClient(adapter)
                .post('/v1/attest', decode: _decodeHealth, body: {'a': 1}),
      );

      expect(
        adapter.requests.single.uri,
        Uri.parse('https://api.example.test/v1/attest'),
      );
      expect(adapter.requests.single.method, 'POST');
    });

    for (final path in [
      'https://other.example.test/health',
      '//other.example.test/health',
      'http:/other.example.test',
      'health',
      '',
    ]) {
      test('refuses path "$path" that could leave the backend', () {
        final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
        final timed = runFake(
          () => fakeClient(adapter).get(path, decode: _decodeHealth),
        );

        expect(timed.result, const Err<HealthResponse>(UnexpectedFailure()));
        expect(adapter.requests, isEmpty);
      });
    }
  });

  group('AC3: an unusable configuration sends nothing', () {
    for (final (baseUrl, problem) in [
      ('http://api.example.test', ConfigurationProblem.insecureBaseUrl),
      ('', ConfigurationProblem.missingBaseUrl),
      ('not a url', ConfigurationProblem.malformedBaseUrl),
    ]) {
      test('"$baseUrl" in a release config gives $problem', () {
        final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
        final client = fakeClient(adapter, baseUrl: baseUrl);

        final get = runFake(() => client.get('/health', decode: _decodeHealth));
        final post = runFake(() => client.post('/v1/x', decode: _decodeHealth));

        expect(get.result, Err<HealthResponse>(ConfigurationFailure(problem)));
        expect(post.result, Err<HealthResponse>(ConfigurationFailure(problem)));
        expect(adapter.requests, isEmpty);
      });
    }
  });

  group('AC4: 503, 503, then 200', () {
    test('returns the 200 after 3 attempts with jittered waits', () {
      final adapter = FakeHttpAdapter([
        respond(503),
        respond(503),
        respond(200, body: _healthOk),
      ]);
      final timed = _getHealth(adapter);

      expect(timed.result.isOk, isTrue);
      expect(adapter.requests, hasLength(3));
      final gaps = adapter.gaps;
      expect(
        gaps[0],
        allOf(greaterThanOrEqualTo(Duration.zero), lessThanOrEqualTo(_ms(500))),
      );
      expect(
        gaps[1],
        allOf(
          greaterThanOrEqualTo(Duration.zero),
          lessThanOrEqualTo(_ms(1000)),
        ),
      );
    });

    for (final seed in [1, 2, 3, 7, 42, 1234]) {
      test('waits stay in range with seed $seed', () {
        final adapter = FakeHttpAdapter([
          respond(503),
          respond(503),
          respond(200, body: _healthOk),
        ]);
        runFake(
          () => fakeClient(
            adapter,
            random: Random(seed),
          ).get('/health', decode: _decodeHealth),
        );

        expect(adapter.gaps[0], lessThan(_ms(500)));
        expect(adapter.gaps[1], lessThan(_ms(1000)));
      });
    }

    test('the top of the jitter range is just under 500 ms and 1,000 ms', () {
      final adapter = FakeHttpAdapter([
        respond(503),
        respond(503),
        respond(200, body: _healthOk),
      ]);
      runFake(
        () => fakeClient(
          adapter,
          random: FixedRandom(0.999),
        ).get('/health', decode: _decodeHealth),
      );

      expect(adapter.gaps, [_ms(499.5), _ms(999)]);
    });

    test('the bottom of the jitter range retries at once', () {
      final adapter = FakeHttpAdapter([
        respond(503),
        respond(503),
        respond(200, body: _healthOk),
      ]);
      runFake(
        () => fakeClient(
          adapter,
          random: FixedRandom(0),
        ).get('/health', decode: _decodeHealth),
      );

      expect(adapter.gaps, [Duration.zero, Duration.zero]);
    });
  });

  group('AC5: four 503s in a row', () {
    test('give the service unavailable failure after exactly 4 attempts', () {
      final adapter = FakeHttpAdapter([respond(503)]);
      final timed = _getHealth(adapter);

      expect(
        timed.result,
        const Err<HealthResponse>(ServiceUnavailableFailure()),
      );
      expect(adapter.requests, hasLength(4));
      expect(adapter.gaps[2], lessThan(_ms(2000)));
    });

    test('502 and 504 are retried the same way', () {
      final adapter = FakeHttpAdapter([
        respond(502),
        respond(504),
        respond(200, body: _healthOk),
      ]);
      final timed = _getHealth(adapter);

      expect(timed.result.isOk, isTrue);
      expect(adapter.requests, hasLength(3));
    });

    test('an HTML 502 page from a proxy maps by status', () {
      final adapter = FakeHttpAdapter([
        respond(502, body: appFixture('network/proxy_502.html')),
      ]);
      final timed = _getHealth(adapter, policy: _noRetries);

      expect(
        timed.result,
        const Err<HealthResponse>(ServiceUnavailableFailure()),
      );
    });
  });

  group('AC6: Retry-After is honored', () {
    test('429 with Retry-After: 3 waits at least 3 s', () {
      final adapter = FakeHttpAdapter([
        respond(
          429,
          body: contractFixture('error/rate_limited.json'),
          headers: {'Retry-After': '3'},
        ),
        respond(200, body: _healthOk),
      ]);
      final timed = _getHealth(adapter);

      expect(timed.result.isOk, isTrue);
      expect(adapter.gaps.single, greaterThanOrEqualTo(_s(3)));
    });

    test(
      '429 with Retry-After as an HTTP date 5 s ahead waits at least 5 s',
      () {
        final adapter = FakeHttpAdapter([
          respond(
            429,
            headers: {'Retry-After': HttpDate.format(fakeStart.add(_s(5)))},
          ),
          respond(200, body: _healthOk),
        ]);
        final timed = _getHealth(adapter);

        expect(timed.result.isOk, isTrue);
        expect(adapter.gaps.single, greaterThanOrEqualTo(_s(5)));
      },
    );

    test('503 with Retry-After: 2 waits at least 2 s', () {
      final adapter = FakeHttpAdapter([
        respond(503, headers: {'Retry-After': '2'}),
        respond(200, body: _healthOk),
      ]);
      _getHealth(adapter);

      expect(adapter.gaps.single, greaterThanOrEqualTo(_s(2)));
    });

    test('Retry-After: 0 retries at once', () {
      final adapter = FakeHttpAdapter([
        respond(429, headers: {'Retry-After': '0'}),
        respond(200, body: _healthOk),
      ]);
      _getHealth(adapter);

      expect(adapter.gaps.single, Duration.zero);
    });

    test('429 without Retry-After uses backoff and carries no wait', () {
      final adapter = FakeHttpAdapter([respond(429)]);
      final timed = _getHealth(adapter);

      expect(timed.result, const Err<HealthResponse>(RateLimitedFailure()));
      expect(adapter.requests, hasLength(4));
    });

    test('an unreadable Retry-After falls back to backoff', () {
      final adapter = FakeHttpAdapter([
        respond(429, headers: {'Retry-After': 'soon'}),
        respond(200, body: _healthOk),
      ]);
      _getHealth(adapter);

      expect(adapter.gaps.single, lessThan(_ms(500)));
    });

    test('the last 429 carries its Retry-After', () {
      final adapter = FakeHttpAdapter([
        respond(429, headers: {'Retry-After': '1'}),
      ]);
      final timed = _getHealth(adapter);

      expect(
        timed.result,
        Err<HealthResponse>(RateLimitedFailure(retryAfter: _s(1))),
      );
      expect(adapter.requests, hasLength(4));
    });
  });

  group('AC7: Retry-After above the 30 s cap', () {
    test('429 with Retry-After: 120 is not retried and carries 120 s', () {
      final adapter = FakeHttpAdapter([
        respond(429, headers: {'Retry-After': '120'}),
        respond(200, body: _healthOk),
      ]);
      final timed = _getHealth(adapter);

      expect(
        timed.result,
        Err<HealthResponse>(RateLimitedFailure(retryAfter: _s(120))),
      );
      expect(adapter.requests, hasLength(1));
      expect(timed.elapsed, Duration.zero);
    });

    test('Retry-After of exactly 30 s is still honored', () {
      const policy = RetryPolicy(totalTimeout: Duration(minutes: 1));
      final adapter = FakeHttpAdapter([
        respond(429, headers: {'Retry-After': '30'}),
        respond(200, body: _healthOk),
      ]);
      final timed = _getHealth(adapter, policy: policy);

      expect(timed.result.isOk, isTrue);
      expect(adapter.gaps.single, _s(30));
    });

    test('503 with Retry-After: 31 is not retried', () {
      final adapter = FakeHttpAdapter([
        respond(503, headers: {'Retry-After': '31'}),
      ]);
      final timed = _getHealth(adapter);

      expect(
        timed.result,
        const Err<HealthResponse>(ServiceUnavailableFailure()),
      );
      expect(adapter.requests, hasLength(1));
    });
  });

  group('AC8: client errors are not retried', () {
    final cases = <(int, String?, Failure)>[
      (
        400,
        contractFixture('error/invalid_barcode.json'),
        const InvalidInputFailure(InvalidInputCode.invalidBarcode),
      ),
      (
        400,
        contractFixture('error/invalid_query.json'),
        const InvalidInputFailure(InvalidInputCode.invalidQuery),
      ),
      (
        400,
        contractFixture('error/invalid_bgg_id.json'),
        const InvalidInputFailure(InvalidInputCode.invalidBggId),
      ),
      (
        400,
        contractFixture('variants/error_unknown_code.json'),
        const InvalidInputFailure(InvalidInputCode.unknown),
      ),
      (
        400,
        contractFixture('malformed/error_missing_code.json'),
        const InvalidInputFailure(InvalidInputCode.unknown),
      ),
      (401, null, const AccessDeniedFailure()),
      (403, null, const AccessDeniedFailure()),
      (404, contractFixture('error/not_found.json'), const NotFoundFailure()),
    ];
    for (final (status, body, failure) in cases) {
      test('$status gives $failure after one attempt', () {
        final adapter = FakeHttpAdapter([respond(status, body: body ?? '')]);
        final timed = _getHealth(adapter);

        expect(timed.result, Err<HealthResponse>(failure));
        expect(adapter.requests, hasLength(1));
      });
    }
  });

  group('AC9: only GET is retried', () {
    final cases = <(FakeHandler, Failure)>[
      (respond(503), const ServiceUnavailableFailure()),
      (
        respond(429, headers: {'Retry-After': '1'}),
        RateLimitedFailure(retryAfter: _s(1)),
      ),
      (failWith(DioExceptionType.connectionError), const NoConnectionFailure()),
      (failWith(DioExceptionType.receiveTimeout), const TimeoutFailure()),
    ];
    for (final (handler, failure) in cases) {
      test('POST that gets $failure is sent exactly once', () {
        final adapter = FakeHttpAdapter([
          handler,
          respond(200, body: _healthOk),
        ]);
        final timed = runFake(
          () => fakeClient(adapter).post('/v1/attest', decode: _decodeHealth),
        );

        expect(timed.result, Err<HealthResponse>(failure));
        expect(adapter.requests, hasLength(1));
      });
    }

    test('POST success decodes the body', () {
      final adapter = FakeHttpAdapter([respond(201, body: _healthOk)]);
      final timed = runFake(
        () => fakeClient(adapter).post('/v1/attest', decode: _decodeHealth),
      );

      expect(timed.result.isOk, isTrue);
    });
  });

  group('AC10: one call never takes longer than 20 s', () {
    test('the client uses a 10 s connect and 15 s receive timeout', () {
      final client = fakeClient(FakeHttpAdapter([respond(200)]));

      expect(client.dio.options.connectTimeout, _s(10));
      expect(client.dio.options.receiveTimeout, _s(15));
      expect(client.policy.totalTimeout, _s(20));
    });

    test('a request that never answers ends at 20 s with a timeout', () {
      final adapter = FakeHttpAdapter([hang()]);
      final timed = _getHealth(adapter);

      expect(timed.result, const Err<HealthResponse>(TimeoutFailure()));
      expect(timed.elapsed, _s(20));
      expect(adapter.requests, hasLength(1));
      expect(adapter.cancelled.single, isTrue);
    });

    test('receive timeouts plus retries stop at 20 s', () {
      final adapter = FakeHttpAdapter([
        failWith(DioExceptionType.receiveTimeout, delay: _s(15)),
      ]);
      final timed = _getHealth(adapter);

      expect(timed.result, const Err<HealthResponse>(TimeoutFailure()));
      expect(timed.elapsed, lessThanOrEqualTo(_s(20)));
      expect(adapter.requests, hasLength(2));
    });

    test('connect timeouts plus retries stop at 20 s', () {
      // Attempt 1: 0 to 10 s. Wait 250 ms. Attempt 2 starts at 10.25 s and
      // is cut off by the deadline at 20 s.
      final adapter = FakeHttpAdapter([
        failWith(DioExceptionType.connectionTimeout, delay: _s(10)),
      ]);
      final timed = runFake(
        () => fakeClient(
          adapter,
          random: FixedRandom(0.5),
        ).get('/health', decode: _decodeHealth),
      );

      expect(timed.result, const Err<HealthResponse>(TimeoutFailure()));
      expect(timed.elapsed, _s(20));
      expect(adapter.requests, hasLength(2));
      expect(adapter.gaps, [_ms(10250)]);
      expect(adapter.cancelled, [false, true]);
    });

    test('slow 503s stop retrying when the next wait would pass 20 s', () {
      // Waits are 0.9 of 500 ms, 1 s, 2 s. Attempt 3 ends at 19.35 s; the
      // next wait (1.8 s) would pass the deadline, so the call ends there.
      final adapter = FakeHttpAdapter([respond(503, delay: _s(6))]);
      final timed = runFake(
        () => fakeClient(
          adapter,
          random: FixedRandom(0.9),
        ).get('/health', decode: _decodeHealth),
      );

      expect(
        timed.result,
        const Err<HealthResponse>(ServiceUnavailableFailure()),
      );
      expect(adapter.requests, hasLength(3));
      expect(timed.elapsed, _ms(19350));
    });

    test('slow 503s with a short last wait time out at exactly 20 s', () {
      // Waits are 250 ms, 500 ms, 1 s. Attempt 4 starts at 19.75 s and the
      // deadline cuts it off at 20 s.
      final adapter = FakeHttpAdapter([respond(503, delay: _s(6))]);
      final timed = runFake(
        () => fakeClient(
          adapter,
          random: FixedRandom(0.5),
        ).get('/health', decode: _decodeHealth),
      );

      expect(timed.result, const Err<HealthResponse>(TimeoutFailure()));
      expect(adapter.requests, hasLength(4));
      expect(timed.elapsed, _s(20));
      expect(adapter.cancelled.last, isTrue);
    });

    test('the deadline ignores the wall clock (review R1-G1)', () {
      // The wall clock is frozen; only the monotonic stopwatch and timers
      // move. A wall-clock deadline would never shrink and would allow a
      // fourth attempt here.
      final adapter = FakeHttpAdapter([respond(503, delay: _s(6))]);
      final timed = runFake(() {
        final monotonic = clock;
        return withClock(
          Clock.fixed(DateTime.utc(2000)),
          () => fakeClient(
            adapter,
            random: FixedRandom(0.9),
            newStopwatch: monotonic.stopwatch,
          ).get('/health', decode: _decodeHealth),
        );
      });

      expect(
        timed.result,
        const Err<HealthResponse>(ServiceUnavailableFailure()),
      );
      expect(adapter.requests, hasLength(3));
      expect(timed.elapsed, _ms(19350));
    });

    test('the default stopwatch is a real monotonic Stopwatch', () {
      final client = ApiClient(
        config: ApiConfig.parse(testBaseUrl, allowInsecureHttp: false),
        enableLogging: false,
        dio: Dio()..httpClientAdapter = FakeHttpAdapter([hang()]),
        policy: const RetryPolicy(totalTimeout: Duration(milliseconds: 50)),
      );

      return expectLater(
        client.get('/health', decode: _decodeHealth),
        completion(const Err<HealthResponse>(TimeoutFailure())),
      );
    });

    test('a Retry-After that would pass the limit ends the call at once', () {
      final adapter = FakeHttpAdapter([
        respond(429, headers: {'Retry-After': '25'}),
        respond(200, body: _healthOk),
      ]);
      final timed = _getHealth(adapter);

      expect(
        timed.result,
        Err<HealthResponse>(RateLimitedFailure(retryAfter: _s(25))),
      );
      expect(timed.elapsed, Duration.zero);
      expect(adapter.requests, hasLength(1));
    });

    test('a call over the limit before its first attempt times out', () {
      final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
      final timed = _getHealth(
        adapter,
        policy: const RetryPolicy(totalTimeout: Duration.zero),
      );

      expect(timed.result, const Err<HealthResponse>(TimeoutFailure()));
      expect(adapter.requests, isEmpty);
    });
  });

  group('AC11: every transport error becomes a Failure', () {
    final cases = <String, (FakeHandler, Failure)>{
      'connection error': (
        failWith(DioExceptionType.connectionError),
        const NoConnectionFailure(),
      ),
      'connection timeout': (
        failWith(DioExceptionType.connectionTimeout),
        const TimeoutFailure(),
      ),
      'send timeout': (
        failWith(DioExceptionType.sendTimeout),
        const TimeoutFailure(),
      ),
      'receive timeout': (
        failWith(DioExceptionType.receiveTimeout),
        const TimeoutFailure(),
      ),
      'bad certificate': (
        failWith(DioExceptionType.badCertificate),
        const UnexpectedFailure(),
      ),
      'bad response': (
        failWith(DioExceptionType.badResponse),
        const UnexpectedFailure(),
      ),
      'cancel': (failWith(DioExceptionType.cancel), const CancelledFailure()),
      'unknown with a SocketException': (
        failWith(
          DioExceptionType.unknown,
          error: const SocketException('Failed host lookup'),
        ),
        const NoConnectionFailure(),
      ),
      'unknown with another error': (
        failWith(DioExceptionType.unknown, error: StateError('boom')),
        const UnexpectedFailure(),
      ),
      'transform timeout': (
        failWith(DioExceptionType.transformTimeout),
        const UnexpectedFailure(),
      ),
      'a raw exception from the adapter': (
        throwRaw(const FormatException('raw')),
        const UnexpectedFailure(),
      ),
      'a raw error from the adapter': (
        throwRaw(ArgumentError('raw')),
        const UnexpectedFailure(),
      ),
      '200 with invalid JSON': (
        respond(200, body: '{"status": "ok",'),
        const UnexpectedFailure(),
      ),
      '200 with an HTML page': (
        respond(200, body: appFixture('network/proxy_502.html')),
        const UnexpectedFailure(),
      ),
      '200 with an empty body': (
        respond(200, body: ''),
        const UnexpectedFailure(),
      ),
      '200 with a field of the wrong type': (
        respond(200, body: contractFixture('malformed/health_wrong_type.json')),
        const UnexpectedFailure(),
      ),
      '200 with a missing field': (
        respond(
          200,
          body: contractFixture('malformed/health_missing_version.json'),
        ),
        const UnexpectedFailure(),
      ),
      '500 internal error': (
        respond(500, body: contractFixture('error/internal_error.json')),
        const UnexpectedFailure(),
      ),
      '302 redirect': (respond(302), const UnexpectedFailure()),
    };
    for (final MapEntry(key: name, value: (handler, failure))
        in cases.entries) {
      test('$name gives $failure', () {
        final adapter = FakeHttpAdapter([handler]);
        final timed = _getHealth(adapter, policy: _noRetries);

        expect(timed.result, Err<HealthResponse>(failure));
      });
    }

    test('a decoder that throws a TypeError gives the unexpected failure', () {
      final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
      final timed = runFake(
        () =>
            fakeClient(adapter)
                .get<int>('/health', decode: (json) => json['status'] as int),
      );

      expect(timed.result, const Err<int>(UnexpectedFailure()));
    });

    test('retryable transport errors are retried for GET', () {
      final adapter = FakeHttpAdapter([
        failWith(DioExceptionType.connectionError),
        failWith(DioExceptionType.receiveTimeout),
        respond(200, body: _healthOk),
      ]);
      final timed = _getHealth(adapter);

      expect(timed.result.isOk, isTrue);
      expect(adapter.requests, hasLength(3));
    });

    test('a closed client returns a failure instead of throwing', () {
      final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
      final client = fakeClient(adapter)..close();
      final timed = runFake(() => client.get('/health', decode: _decodeHealth));

      expect(timed.result.isErr, isTrue);
    });
  });

  group('AC16: JSON that is not an object is never decoded', () {
    const bodies = ['[]', '"ok"', '42', 'null'];
    final statuses = <int, Failure>{
      200: const UnexpectedFailure(),
      400: const InvalidInputFailure(InvalidInputCode.unknown),
      401: const AccessDeniedFailure(),
      404: const NotFoundFailure(),
      429: const RateLimitedFailure(),
      500: const UnexpectedFailure(),
      503: const ServiceUnavailableFailure(),
    };
    for (final body in bodies) {
      for (final MapEntry(key: status, value: failure) in statuses.entries) {
        test('$status with body $body gives $failure', () {
          var decodeCalls = 0;
          final adapter = FakeHttpAdapter([respond(status, body: body)]);
          final timed = runFake(
            () => fakeClient(adapter, policy: _noRetries).get(
              '/health',
              decode: (json) {
                decodeCalls++;
                return HealthResponse.fromJson(json);
              },
            ),
          );

          expect(timed.result, Err<HealthResponse>(failure));
          expect(decodeCalls, 0);
        });
      }
    }
  });

  group('cancellation by the caller', () {
    test('a token cancelled before the call sends nothing', () {
      final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
      final token = CancelToken()..cancel();
      final timed = _getHealth(adapter, cancelToken: token);

      expect(timed.result, const Err<HealthResponse>(CancelledFailure()));
      expect(adapter.requests, isEmpty);
    });

    test('cancelling during a request ends it', () {
      final adapter = FakeHttpAdapter([hang()]);
      final timed = runFake(() {
        // Created inside fake time, so its completion runs in fake time.
        final token = CancelToken();
        Future<void>.delayed(_s(1), token.cancel);
        return fakeClient(adapter)
            .get('/health', decode: _decodeHealth, cancelToken: token);
      });

      expect(timed.result, const Err<HealthResponse>(CancelledFailure()));
      expect(timed.elapsed, _s(1));
      expect(adapter.cancelled.single, isTrue);
    });

    test('cancelling during a backoff wait ends the call', () {
      final adapter = FakeHttpAdapter([
        respond(503, headers: {'Retry-After': '5'}),
        respond(200, body: _healthOk),
      ]);
      final timed = runFake(() {
        // Created inside fake time, so its completion runs in fake time.
        final token = CancelToken();
        Future<void>.delayed(_s(2), token.cancel);
        return fakeClient(adapter)
            .get('/health', decode: _decodeHealth, cancelToken: token);
      });

      expect(timed.result, const Err<HealthResponse>(CancelledFailure()));
      expect(timed.elapsed, _s(2));
      expect(adapter.requests, hasLength(1));
    });

    test('one token reused across calls only affects calls that run when '
        'it is cancelled (review R1-G2)', () {
      final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
      final timed = runFake(() async {
        final token = CancelToken();
        final client = fakeClient(adapter);
        for (var i = 0; i < 3; i++) {
          final r = await client.get(
            '/health',
            decode: _decodeHealth,
            cancelToken: token,
          );
          expect(r.isOk, isTrue);
        }
        token.cancel();
        return client.get('/health', decode: _decodeHealth, cancelToken: token);
      });

      expect(timed.result, const Err<HealthResponse>(CancelledFailure()));
      expect(adapter.requests, hasLength(3));
    });

    test('a live token does not change a successful call', () {
      final adapter = FakeHttpAdapter([
        respond(503),
        respond(200, body: _healthOk),
      ]);
      final timed = _getHealth(adapter, cancelToken: CancelToken());

      expect(timed.result.isOk, isTrue);
      expect(adapter.requests, hasLength(2));
    });
  });
}

Duration _ms(num milliseconds) =>
    Duration(microseconds: (milliseconds * 1000).round());

Duration _s(int seconds) => Duration(seconds: seconds);
