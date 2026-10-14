// T-028 QA round 1: edge cases for the 1 MiB response cap (AC7). Bodies are
// built from bytes so the limit is tested at the exact byte.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:api_contract/api_contract.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:board_game_collector/features/game_detail/data/games_remote_data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_http.dart';

const int _limit = 1048576;

/// A handler that serves [bytes] in chunks of [chunkSize], with optional
/// headers, a status, and a reset after [resetAfter] chunks.
FakeHandler bytesBody(
  List<int> bytes, {
  int status = 200,
  int chunkSize = 64 * 1024,
  Map<String, String> headers = const {},
  int? resetAfter,
}) => (options) async {
  final data = Uint8List.fromList(bytes);
  final chunks = <Uint8List>[
    for (var s = 0; s < data.length; s += chunkSize)
      Uint8List.sublistView(
        data,
        s,
        s + chunkSize < data.length ? s + chunkSize : data.length,
      ),
  ];
  Stream<Uint8List> stream() async* {
    var sent = 0;
    for (final chunk in chunks) {
      if (sent == resetAfter) throw const SocketException('reset');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      yield chunk;
      sent++;
    }
    if (sent == resetAfter) throw const SocketException('reset');
  }

  return ResponseBody(
    stream(),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
      for (final e in headers.entries) e.key.toLowerCase(): [e.value],
    },
  );
};

/// A health JSON text of exactly [size] bytes, ASCII filler.
List<int> healthOfSize(int size) {
  const prefix = '{"status":"ok","version":"';
  const suffix = '"}';
  final text = '$prefix${'x' * (size - prefix.length - suffix.length)}$suffix';
  return utf8.encode(text);
}

/// A health JSON of exactly [size] bytes whose version ends with [tail]
/// (multi-byte text), padded with ASCII in front.
List<int> healthWithTail(int size, String tail) {
  const prefix = '{"status":"ok","version":"';
  const suffix = '"}';
  final tailBytes = utf8.encode(tail).length;
  final pad = size - prefix.length - suffix.length - tailBytes;
  final bytes = utf8.encode('$prefix${'x' * pad}$tail$suffix');
  assert(bytes.length == size, 'size mismatch ${bytes.length}');
  return bytes;
}

/// An error envelope padded to [size] bytes.
List<int> errorOfSize(String code, int size) {
  final base = jsonEncode({
    'error': {'code': code, 'message': ''},
  });
  final pad = size - utf8.encode(base).length;
  return utf8.encode(
    jsonEncode({
      'error': {'code': code, 'message': 'm' * pad},
    }),
  );
}

Timed<HealthResponse> _get(FakeHttpAdapter adapter) => runFake(
  () => fakeClient(
    adapter,
    random: FixedRandom(0),
  ).get('/v1/games/13', decode: HealthResponse.fromJson),
);

void main() {
  group('exactly at and one byte over the limit', () {
    for (final chunk in [1024, 64 * 1024, _limit, 7777]) {
      test('exactly 1 MiB decodes (chunks of $chunk, no Content-Length)', () {
        final adapter = FakeHttpAdapter([
          bytesBody(healthOfSize(_limit), chunkSize: chunk),
        ]);
        final t = _get(adapter);
        expect(t.result.isOk, isTrue, reason: '${t.result}');
        expect(adapter.requests, hasLength(1));
      });
      test('1 MiB + 1 byte is unexpected (chunks of $chunk)', () {
        final adapter = FakeHttpAdapter([
          bytesBody(healthOfSize(_limit + 1), chunkSize: chunk),
          bytesBody(healthOfSize(100)),
        ]);
        final t = _get(adapter);
        expect(t.result.failureOrNull, const UnexpectedFailure());
        expect(adapter.requests, hasLength(1), reason: 'never retried');
      });
    }

    test('1 MiB - 1 byte decodes', () {
      final adapter = FakeHttpAdapter([bytesBody(healthOfSize(_limit - 1))]);
      expect(_get(adapter).result.isOk, isTrue);
    });
  });

  group('Content-Length headers', () {
    test('absent, small body', () {
      final adapter = FakeHttpAdapter([bytesBody(healthOfSize(200))]);
      expect(_get(adapter).result.isOk, isTrue);
    });

    test('lying low (100) with an exactly 1 MiB body decodes', () {
      final adapter = FakeHttpAdapter([
        bytesBody(healthOfSize(_limit), headers: {'Content-Length': '100'}),
      ]);
      expect(_get(adapter).result.isOk, isTrue);
    });

    test('lying low (100) with a 1 MiB + 1 body is unexpected, once', () {
      final adapter = FakeHttpAdapter([
        bytesBody(healthOfSize(_limit + 1), headers: {'Content-Length': '100'}),
      ]);
      final t = _get(adapter);
      expect(t.result.failureOrNull, const UnexpectedFailure());
      expect(adapter.requests, hasLength(1));
    });

    test('lying high (over the limit) with a small body is refused, once', () {
      final adapter = FakeHttpAdapter([
        bytesBody(
          healthOfSize(200),
          headers: {'Content-Length': '${_limit + 1}'},
        ),
      ]);
      final t = _get(adapter);
      expect(t.result.failureOrNull, const UnexpectedFailure());
      expect(adapter.requests, hasLength(1));
    });

    test(
      'Content-Length exactly at the limit with that many bytes decodes',
      () {
        final adapter = FakeHttpAdapter([
          bytesBody(
            healthOfSize(_limit),
            headers: {'Content-Length': '$_limit'},
          ),
        ]);
        expect(_get(adapter).result.isOk, isTrue);
      },
    );

    for (final value in ['abc', '-1', '', ' ', '1,2', '1e9', '0x10']) {
      test('unusable Content-Length "$value" with a small body decodes', () {
        final adapter = FakeHttpAdapter([
          bytesBody(healthOfSize(200), headers: {'Content-Length': value}),
        ]);
        final t = _get(adapter);
        expect(t.result.isOk, isTrue, reason: '${t.result}');
      });
      test('unusable Content-Length "$value" with an oversized body is '
          'still capped', () {
        final adapter = FakeHttpAdapter([
          bytesBody(
            healthOfSize(_limit + 5000),
            headers: {'Content-Length': value},
          ),
        ]);
        final t = _get(adapter);
        expect(t.result.failureOrNull, const UnexpectedFailure());
        expect(adapter.requests, hasLength(1));
      });
    }

    test('a huge Content-Length that overflows int is refused without a '
        'throw', () {
      final adapter = FakeHttpAdapter([
        bytesBody(healthOfSize(200), headers: {'Content-Length': '9' * 40}),
      ]);
      final t = _get(adapter);
      // An unreadable (overflowing) length is ignored and the bytes are
      // counted instead, so a small body still decodes.
      expect(t.result.isOk, isTrue, reason: '${t.result}');
      expect(adapter.requests, hasLength(1));
    });
  });

  group('error statuses over the cap', () {
    final cases = <int, String>{
      400: 'invalid_barcode',
      404: 'not_found',
      429: 'rate_limited',
      500: 'internal_error',
      503: 'upstream_unavailable',
    };
    for (final MapEntry(key: status, value: code) in cases.entries) {
      test('$status body over the cap is unexpected and not retried', () {
        final adapter = FakeHttpAdapter([
          bytesBody(
            errorOfSize(code, _limit + 1),
            status: status,
            headers: {'Retry-After': '1'},
          ),
          bytesBody(healthOfSize(100)),
        ]);
        final t = _get(adapter);
        expect(t.result.failureOrNull, const UnexpectedFailure());
        expect(adapter.requests, hasLength(1));
      });
    }

    test('a 404 body just under the cap still maps to not found', () {
      final adapter = FakeHttpAdapter([
        bytesBody(errorOfSize('not_found', _limit), status: 404),
      ]);
      expect(_get(adapter).result.failureOrNull, const NotFoundFailure());
    });

    test('a 400 body at the cap still maps its error code', () {
      final adapter = FakeHttpAdapter([
        bytesBody(errorOfSize('invalid_bgg_id', _limit), status: 400),
      ]);
      expect(
        _get(adapter).result.failureOrNull,
        const InvalidInputFailure(InvalidInputCode.invalidBggId),
      );
    });

    test('the data source also returns unexpected for an oversized 200', () {
      final adapter = FakeHttpAdapter([
        bytesBody(utf8.encode('[${'1,' * 600000}1]')),
      ]);
      final t = runFake(
        () =>
            GamesRemoteDataSource(fakeClient(adapter, random: FixedRandom(0)))
                .searchGames('catan'),
      );
      expect(t.result.failureOrNull, const UnexpectedFailure());
      expect(adapter.requests, hasLength(1));
    });
  });

  group('multi-byte UTF-8 at the boundary', () {
    test('a 4-byte character ending exactly at the limit decodes', () {
      final adapter = FakeHttpAdapter([
        bytesBody(healthWithTail(_limit, '🎲'), chunkSize: _limit - 2),
      ]);
      final t = _get(adapter);
      expect(t.result.isOk, isTrue, reason: '${t.result}');
      expect(t.result.valueOrNull!.version.endsWith('🎲'), isTrue);
    });

    test('a 4-byte character crossing the limit is unexpected', () {
      // Total = limit + 2 bytes: the emoji starts before the limit and ends
      // after it.
      final bytes = healthWithTail(_limit + 2, '🎲');
      final adapter = FakeHttpAdapter([bytesBody(bytes, chunkSize: 4096)]);
      final t = _get(adapter);
      expect(t.result.failureOrNull, const UnexpectedFailure());
      expect(adapter.requests, hasLength(1));
    });

    test('bytes are counted, not characters: 400k 3-byte characters (1.2 MB) '
        'are over the cap', () {
      final text = '{"status":"ok","version":"${'世' * 400000}"}';
      expect(text.length, lessThan(_limit));
      final adapter = FakeHttpAdapter([bytesBody(utf8.encode(text))]);
      final t = _get(adapter);
      expect(t.result.failureOrNull, const UnexpectedFailure());
    });

    test('349,000 3-byte characters (under 1 MiB in bytes) decode', () {
      final text = '{"status":"ok","version":"${'世' * 349000}"}';
      expect(utf8.encode(text).length, lessThan(_limit));
      final adapter = FakeHttpAdapter([bytesBody(utf8.encode(text))]);
      final t = _get(adapter);
      expect(t.result.valueOrNull?.version.length, 349000);
    });

    test('a character split across chunks at every byte offset decodes', () {
      final bytes = utf8.encode('{"status":"ok","version":"a世🎲é"}');
      for (var chunk = 1; chunk <= 5; chunk++) {
        final adapter = FakeHttpAdapter([bytesBody(bytes, chunkSize: chunk)]);
        expect(
          _get(adapter).result.valueOrNull?.version,
          'a世🎲é',
          reason: 'chunk $chunk',
        );
      }
    });

    test('invalid UTF-8 bytes do not throw', () {
      final bytes = <int>[
        ...utf8.encode('{"status":"ok","version":"'),
        0xff,
        0xfe,
        0xc3,
        ...utf8.encode('"}'),
      ];
      final adapter = FakeHttpAdapter([bytesBody(bytes)]);
      final t = _get(adapter);
      // Replaced by U+FFFD, or unexpected; either way no throw.
      expect(
        t.result.isOk || t.result.failureOrNull is UnexpectedFailure,
        isTrue,
      );
    });
  });

  group('resets mid-body', () {
    test('a reset after most of the body is no connection and is retried', () {
      final adapter = FakeHttpAdapter([
        bytesBody(healthOfSize(_limit), resetAfter: 15),
        bytesBody(healthOfSize(300)),
      ]);
      final t = _get(adapter);
      expect(t.result.isOk, isTrue, reason: '${t.result}');
      expect(adapter.requests, hasLength(2));
    });

    test('a reset right before the end of the body is retried', () {
      final bytes = healthOfSize(200 * 1024);
      final adapter = FakeHttpAdapter([
        bytesBody(bytes, resetAfter: 3),
        bytesBody(healthOfSize(300)),
      ]);
      final t = _get(adapter);
      expect(t.result.isOk, isTrue);
      expect(adapter.requests, hasLength(2));
    });

    test('a reset in a 503 body still ends as no connection after retries', () {
      final adapter = FakeHttpAdapter([
        bytesBody(healthOfSize(300000), status: 503, resetAfter: 2),
      ]);
      final t = _get(adapter);
      expect(t.result.failureOrNull, const NoConnectionFailure());
      expect(adapter.requests, hasLength(4));
    });

    test('an oversized body then a reset on retry: the oversize wins first '
        'and nothing is retried', () {
      final adapter = FakeHttpAdapter([
        bytesBody(healthOfSize(_limit + 10)),
        bytesBody(healthOfSize(300), resetAfter: 0),
      ]);
      final t = _get(adapter);
      expect(t.result.failureOrNull, const UnexpectedFailure());
      expect(adapter.requests, hasLength(1));
    });
  });
}
