// T-028 review R1-S1: repeated headers are read safely, and anything thrown
// while the client handles a response or its body ends the attempt at once
// with UnexpectedFailure, instead of an uncaught error and a 20 s timeout.
// Every test runs in fake time with jitter fixed at 0.
import 'dart:typed_data';

import 'package:api_contract/api_contract.dart';
import 'package:board_game_collector/core/data/network/api_client.dart';
import 'package:board_game_collector/core/data/network/retry_policy.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http.dart';

final String _healthOk = contractFixture('health/ok.json');

/// Answers [status] with [body] and headers that may repeat a name, which
/// `respond` cannot express.
FakeHandler _respondMulti(
  int status,
  Map<String, List<String>> headers, {
  String body = '{}',
}) =>
    (options) async => ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        ...headers,
      },
    );

/// A response body whose stream cannot be read, standing in for any error
/// raised inside the client's response callback.
class _BrokenBody extends ResponseBody {
  _BrokenBody(ResponseBody original)
    : super(
        const Stream.empty(),
        original.statusCode,
        headers: original.headers,
      );

  @override
  Stream<Uint8List> get stream => throw StateError('broken body');
}

/// Replaces each response body with a [_BrokenBody].
class _BreakBody extends Interceptor {
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    response.data = _BrokenBody(response.data as ResponseBody);
    handler.next(response);
  }
}

Timed<HealthResponse> _get(
  FakeHttpAdapter adapter, {
  Interceptor? interceptor,
}) => runFake(() {
  final client = fakeClient(adapter, random: FixedRandom(0));
  if (interceptor != null) client.dio.interceptors.add(interceptor);
  return client.get('/health', decode: HealthResponse.fromJson);
});

void main() {
  group('R1-S1: repeated headers', () {
    test('two Retry-After values on a 429: the first readable one is '
        'honored', () {
      final adapter = FakeHttpAdapter([
        _respondMulti(429, {
          'retry-after': ['2', '5'],
        }),
        respond(200, body: _healthOk),
      ]);
      final t = _get(adapter);
      expect(t.result.isOk, isTrue, reason: '${t.result}');
      expect(adapter.requests, hasLength(2));
      expect(adapter.gaps, [const Duration(seconds: 2)]);
      expect(t.elapsed, const Duration(seconds: 2));
    });

    test('two Retry-After values on a 503: an unreadable first one is '
        'skipped', () {
      final adapter = FakeHttpAdapter([
        _respondMulti(503, {
          'retry-after': ['soon', '3'],
        }),
        respond(200, body: _healthOk),
      ]);
      final t = _get(adapter);
      expect(t.result.isOk, isTrue, reason: '${t.result}');
      expect(adapter.gaps, [const Duration(seconds: 3)]);
    });

    test('a 429 that keeps repeating Retry-After carries the first value', () {
      final adapter = FakeHttpAdapter([
        _respondMulti(429, {
          'retry-after': ['1', '9'],
        }),
      ]);
      final t = _get(adapter);
      expect(
        t.result,
        const Err<HealthResponse>(
          RateLimitedFailure(retryAfter: Duration(seconds: 1)),
        ),
      );
      expect(adapter.requests, hasLength(4));
      expect(t.elapsed, const Duration(seconds: 3));
    });

    test('two Content-Length values: one over the limit refuses the body', () {
      final adapter = FakeHttpAdapter([
        _respondMulti(200, {
          Headers.contentLengthHeader: [
            '100',
            '${ApiClient.defaultMaxResponseBytes + 1}',
          ],
        }, body: _healthOk),
      ]);
      final t = _get(adapter);
      expect(t.result, const Err<HealthResponse>(UnexpectedFailure()));
      expect(adapter.requests, hasLength(1));
      expect(t.elapsed, Duration.zero);
    });

    test('two small Content-Length values: the body is read and counted', () {
      final adapter = FakeHttpAdapter([
        _respondMulti(200, {
          Headers.contentLengthHeader: ['10', '20'],
        }, body: _healthOk),
      ]);
      final t = _get(adapter);
      expect(t.result.valueOrNull?.status, 'ok');
    });
  });

  group('R1-S1: an error inside a callback ends the attempt at once', () {
    for (final status in [200, 503]) {
      test('a body that throws on a $status: unexpected, not a timeout', () {
        final adapter = FakeHttpAdapter([
          respond(status, body: _healthOk),
          respond(200, body: _healthOk),
        ]);
        // An uncaught async error would fail this test through its zone.
        final t = _get(adapter, interceptor: _BreakBody());
        expect(t.result, const Err<HealthResponse>(UnexpectedFailure()));
        expect(adapter.requests, hasLength(1), reason: 'not retried');
        expect(t.elapsed, Duration.zero, reason: 'no 20 s timeout');
      });
    }
  });

  group('declaredContentLength', () {
    test('reads one value', () {
      expect(declaredContentLength(['42']), 42);
      expect(declaredContentLength([' 42 ']), 42);
    });

    test('uses the largest readable value', () {
      expect(declaredContentLength(['10', 'abc', '30', '20']), 30);
    });

    test('is null when no value can be read', () {
      expect(declaredContentLength(null), isNull);
      expect(declaredContentLength(const []), isNull);
      expect(declaredContentLength(['abc', '', '1,2']), isNull);
    });
  });

  group('firstRetryAfter', () {
    final now = DateTime.utc(2026, 10, 14, 12);

    test('reads the first readable value', () {
      expect(firstRetryAfter(['7', '1'], now: now), const Duration(seconds: 7));
      expect(
        firstRetryAfter(['x', '', '4'], now: now),
        const Duration(seconds: 4),
      );
    });

    test('reads an HTTP date', () {
      expect(
        firstRetryAfter(['Wed, 14 Oct 2026 12:00:05 GMT'], now: now),
        const Duration(seconds: 5),
      );
    });

    test('is null when no value can be read', () {
      expect(firstRetryAfter(null, now: now), isNull);
      expect(firstRetryAfter(const [], now: now), isNull);
      expect(firstRetryAfter(['soon', '1.5'], now: now), isNull);
    });
  });
}
