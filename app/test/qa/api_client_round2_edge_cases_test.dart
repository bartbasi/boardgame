// T-028 QA round 2: repeated and odd Retry-After and Content-Length headers,
// and callbacks that throw at different points of the response. Fake time
// is used, and its zone reports any uncaught async error as a test failure,
// so "no uncaught error" is checked by every runFake call. One real-time
// test also uses runZonedGuarded.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:api_contract/api_contract.dart';
import 'package:board_game_collector/core/data/network/api_client.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_http.dart';

final String _healthOk = contractFixture('health/ok.json');

/// Answers [status] with [body]; header names may repeat (several lines)
/// and keep the case given here.
FakeHandler _multi(
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

Timed<HealthResponse> _get(
  FakeHttpAdapter adapter, {
  Interceptor? interceptor,
}) => runFake(() {
  final client = fakeClient(adapter, random: FixedRandom(0));
  if (interceptor != null) client.dio.interceptors.add(interceptor);
  return client.get('/health', decode: HealthResponse.fromJson);
});

/// Headers that throw when [throwOn] is read (or, once [armed] is true,
/// when [armedName] is read).
class _ThrowingHeaders extends Headers {
  _ThrowingHeaders(Headers original, this.throwOn)
    : super.fromMap(original.map);

  final String throwOn;

  @override
  List<String>? operator [](String name) {
    if (name.toLowerCase() == throwOn) throw StateError('header $name');
    return super[name];
  }
}

class _HeaderBreaker extends Interceptor {
  _HeaderBreaker(this.name);

  final String name;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    handler.next(
      _ArmedResponse(
        response,
        headers: _ThrowingHeaders(response.headers, name),
      ),
    );
  }
}

/// A response whose requestOptions throw once [armed] (the client reads it
/// only in its body-stream onError callback).
bool _armed = false;

class _ArmedResponse extends Response<ResponseBody> {
  _ArmedResponse(Response<dynamic> from, {Headers? headers})
    : _options = from.requestOptions,
      super(
        data: from.data as ResponseBody,
        requestOptions: from.requestOptions,
        statusCode: from.statusCode,
        headers: headers ?? from.headers,
      );

  RequestOptions _options;

  @override
  RequestOptions get requestOptions {
    if (_armed) throw StateError('requestOptions');
    return _options;
  }

  @override
  set requestOptions(RequestOptions value) => _options = value;
}

class _ArmResponse extends Interceptor {
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    handler.next(_ArmedResponse(response));
  }
}

/// [count] chunks of the health text, then (when [failAtEnd]) a reset that
/// first arms [_ArmedResponse].
FakeHandler _chunked(int count, {bool failAtEnd = false}) => (options) async {
  final bytes = Uint8List.fromList(_healthOk.codeUnits);
  final size = (bytes.length / count).ceil();
  Stream<Uint8List> stream() async* {
    for (var s = 0; s < bytes.length; s += size) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      yield Uint8List.sublistView(
        bytes,
        s,
        s + size < bytes.length ? s + size : bytes.length,
      );
    }
    if (failAtEnd) {
      _armed = true;
      throw const SocketException('reset');
    }
  }

  return ResponseBody(
    stream(),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
};

void main() {
  tearDown(() => _armed = false);

  group('Retry-After on a 429 (3 attempts of waiting, 4 requests)', () {
    // Each case: the header lines, then the wait expected before request 2
    // (null means the policy's own backoff, not a Retry-After).
    Duration? waitFor(Map<String, List<String>> headers) {
      final adapter = FakeHttpAdapter([
        _multi(429, headers),
        respond(200, body: _healthOk),
      ]);
      final t = _get(adapter);
      expect(t.result.isOk, isTrue, reason: '${t.result}');
      expect(adapter.requests, hasLength(2));
      return adapter.gaps.single;
    }

    test('mixed lines: invalid, negative, empty, then a valid number', () {
      expect(
        waitFor({
          'retry-after': ['abc', '-5', '', ' ', '4', '9'],
        }),
        const Duration(seconds: 4),
      );
    });

    test('a valid number first wins over a later HTTP date', () {
      final later = HttpDate.format(fakeStart.add(const Duration(seconds: 9)));
      expect(
        waitFor({
          'retry-after': ['3', later],
        }),
        const Duration(seconds: 3),
      );
    });

    test('invalid first, then an HTTP date in the future', () {
      final date = HttpDate.format(fakeStart.add(const Duration(seconds: 6)));
      expect(
        waitFor({
          'retry-after': ['-1', 'tomorrow', date],
        }),
        const Duration(seconds: 6),
      );
    });

    test('an HTTP date in the past waits no time beyond the policy', () {
      final past = HttpDate.format(
        fakeStart.subtract(const Duration(hours: 1)),
      );
      final gap = waitFor({
        'retry-after': [past],
      });
      // Zero wait from the header; the policy may add its own backoff.
      expect(gap, lessThan(const Duration(seconds: 5)));
    });

    test('a negative first and a valid second line: the second is used', () {
      expect(
        waitFor({
          'retry-after': ['-1', '2'],
        }),
        const Duration(seconds: 2),
      );
    });

    test('header name case: Retry-After, RETRY-AFTER, retry-after', () {
      for (final name in ['Retry-After', 'RETRY-AFTER', 'retry-after']) {
        expect(
          waitFor({
            name: ['3'],
          }),
          const Duration(seconds: 3),
          reason: name,
        );
      }
    });

    test('header name with surrounding spaces is still read', () {
      expect(
        waitFor({
          ' Retry-After ': ['3'],
        }),
        const Duration(seconds: 3),
      );
    });

    test('values joined in one line ("2, 5") are not read as a number', () {
      // Not a number and not an HTTP date: treated as absent, so the
      // client falls back to its own backoff instead of crashing.
      final adapter = FakeHttpAdapter([
        _multi(429, {
          'retry-after': ['2, 5'],
        }),
      ]);
      final t = _get(adapter);
      expect(t.result.failureOrNull, isA<RateLimitedFailure>());
      expect(
        (t.result.failureOrNull! as RateLimitedFailure).retryAfter,
        isNull,
      );
      expect(adapter.requests, hasLength(4));
    });

    test('an HTTP date joined with a number in one line is absent', () {
      final date = HttpDate.format(fakeStart.add(const Duration(seconds: 5)));
      final adapter = FakeHttpAdapter([
        _multi(429, {
          'retry-after': ['$date, 7'],
        }),
      ]);
      final t = _get(adapter);
      expect(
        (t.result.failureOrNull! as RateLimitedFailure).retryAfter,
        isNull,
      );
    });

    test('many lines of garbage: no crash, backoff only', () {
      final adapter = FakeHttpAdapter([
        _multi(429, {'retry-after': List.filled(500, 'zz')}),
      ]);
      final t = _get(adapter);
      expect(t.result.failureOrNull, isA<RateLimitedFailure>());
      expect(adapter.requests, hasLength(4));
    });

    test('503 with a negative then a valid line', () {
      final adapter = FakeHttpAdapter([
        _multi(503, {
          'retry-after': ['-3', '2'],
        }),
        respond(200, body: _healthOk),
      ]);
      final t = _get(adapter);
      expect(t.result.isOk, isTrue);
      expect(adapter.gaps, [const Duration(seconds: 2)]);
    });

    test(
      'a wait over the deadline is reported with its value, one request',
      () {
        final adapter = FakeHttpAdapter([
          _multi(429, {
            'retry-after': ['x', '60', '1'],
          }),
        ]);
        final t = _get(adapter);
        expect(
          t.result,
          const Err<HealthResponse>(
            RateLimitedFailure(retryAfter: Duration(seconds: 60)),
          ),
        );
        expect(adapter.requests, hasLength(1));
      },
    );
  });

  group('Content-Length lines', () {
    const over = '${ApiClient.defaultMaxResponseBytes + 1}';

    test('conflicting values: small, over: refused, one request', () {
      final adapter = FakeHttpAdapter([
        _multi(200, {
          Headers.contentLengthHeader: ['5', over],
        }, body: _healthOk),
        respond(200, body: _healthOk),
      ]);
      final t = _get(adapter);
      expect(t.result.failureOrNull, const UnexpectedFailure());
      expect(adapter.requests, hasLength(1));
    });

    test('conflicting values: over first, small second: refused', () {
      final adapter = FakeHttpAdapter([
        _multi(200, {
          Headers.contentLengthHeader: [over, '5'],
        }, body: _healthOk),
      ]);
      expect(_get(adapter).result.failureOrNull, const UnexpectedFailure());
    });

    test('garbage line plus an over-limit line: refused', () {
      final adapter = FakeHttpAdapter([
        _multi(200, {
          Headers.contentLengthHeader: ['abc', '-1', over],
        }, body: _healthOk),
      ]);
      expect(_get(adapter).result.failureOrNull, const UnexpectedFailure());
    });

    test('exactly the limit on one line and small on another: read', () {
      final adapter = FakeHttpAdapter([
        _multi(200, {
          Headers.contentLengthHeader: [
            '${ApiClient.defaultMaxResponseBytes}',
            '5',
          ],
        }, body: _healthOk),
      ]);
      expect(_get(adapter).result.isOk, isTrue);
    });

    test('comma-joined "5, 2000000" is unreadable, so bytes are counted', () {
      final adapter = FakeHttpAdapter([
        _multi(200, {
          Headers.contentLengthHeader: ['5, 2000000'],
        }, body: _healthOk),
      ]);
      expect(_get(adapter).result.isOk, isTrue);
    });

    test('name case: CONTENT-LENGTH over the limit is refused', () {
      final adapter = FakeHttpAdapter([
        _multi(200, {
          'CONTENT-LENGTH': [over],
        }, body: _healthOk),
      ]);
      expect(_get(adapter).result.failureOrNull, const UnexpectedFailure());
    });

    test('a refused oversize on an error status is not retried', () {
      final adapter = FakeHttpAdapter([
        _multi(503, {
          Headers.contentLengthHeader: ['1', over],
          'retry-after': ['1'],
        }),
        respond(200, body: _healthOk),
      ]);
      final t = _get(adapter);
      expect(t.result.failureOrNull, const UnexpectedFailure());
      expect(adapter.requests, hasLength(1));
    });

    test('a false small line next to the real body still hits the cap', () {
      final adapter = FakeHttpAdapter([
        _multi(200, {
          Headers.contentLengthHeader: ['1', '2'],
        }, body: _healthOk),
      ]);
      expect(_get(adapter).result.isOk, isTrue);
    });
  });

  group('a callback throws', () {
    void expectEndedAtOnce(Timed<HealthResponse> t, FakeHttpAdapter a) {
      expect(t.result, const Err<HealthResponse>(UnexpectedFailure()));
      expect(a.requests, hasLength(1), reason: 'not retried');
      expect(t.elapsed, lessThan(const Duration(seconds: 1)));
    }

    test('in the response callback (Content-Length read throws)', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: _healthOk),
        respond(200, body: _healthOk),
      ]);
      expectEndedAtOnce(
        _get(adapter, interceptor: _HeaderBreaker('content-length')),
        adapter,
      );
    });

    for (final chunks in [1, 2, 7]) {
      test('in onDone after $chunks chunk(s) (Retry-After read throws)', () {
        final adapter = FakeHttpAdapter([
          _chunked(chunks),
          respond(200, body: _healthOk),
        ]);
        expectEndedAtOnce(
          _get(adapter, interceptor: _HeaderBreaker('retry-after')),
          adapter,
        );
      });
    }

    for (final chunks in [1, 4]) {
      test('in onError after $chunks chunk(s) (a reset, then the callback '
          'throws)', () {
        final adapter = FakeHttpAdapter([
          _chunked(chunks, failAtEnd: true),
          respond(200, body: _healthOk),
        ]);
        expectEndedAtOnce(_get(adapter, interceptor: _ArmResponse()), adapter);
      });
    }

    test('on a 503 (retryable status) it is still not retried', () {
      final adapter = FakeHttpAdapter([
        respond(503, body: _healthOk),
        respond(200, body: _healthOk),
      ]);
      expectEndedAtOnce(
        _get(adapter, interceptor: _HeaderBreaker('retry-after')),
        adapter,
      );
    });

    test('a call after a failed one works (client state is clean)', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: _healthOk),
        respond(200, body: _healthOk),
      ]);
      final t = runFake(() async {
        final client = fakeClient(adapter, random: FixedRandom(0));
        final breaker = _HeaderBreaker('retry-after');
        client.dio.interceptors.add(breaker);
        final first = await client.get(
          '/health',
          decode: HealthResponse.fromJson,
        );
        expect(first.failureOrNull, const UnexpectedFailure());
        client.dio.interceptors.remove(breaker);
        return client.get('/health', decode: HealthResponse.fromJson);
      });
      expect(t.result.isOk, isTrue, reason: '${t.result}');
      expect(adapter.requests, hasLength(2));
    });

    test('real time: no uncaught async error escapes', () async {
      final errors = <Object>[];
      final adapter = FakeHttpAdapter([respond(200, body: _healthOk)]);
      final result = await runZonedGuarded(() async {
        final client = fakeClient(adapter, random: FixedRandom(0));
        client.dio.interceptors.add(_HeaderBreaker('retry-after'));
        final r = await client.get('/health', decode: HealthResponse.fromJson);
        // Let any stray async error surface.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return r;
      }, (error, stack) => errors.add(error));
      expect(result?.failureOrNull, const UnexpectedFailure());
      expect(errors, isEmpty);
    });
  });
}
