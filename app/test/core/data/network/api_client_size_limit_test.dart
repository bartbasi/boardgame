// T-028 AC7: the API client caps response bodies at 1 MiB (T-013 review
// R1-G4). Every test runs in fake time with the fake HTTP adapter.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:api_contract/api_contract.dart';
import 'package:board_game_collector/core/data/network/api_client.dart';
import 'package:board_game_collector/core/data/network/api_config.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http.dart';

const int _limit = ApiClient.defaultMaxResponseBytes;

/// The time between two chunks of a [_ChunkedBody], like packets arriving
/// from a network. dio reads ahead into its own buffer, so a body that
/// arrived all at once would be buffered before the client could stop it.
const Duration _packetGap = Duration(milliseconds: 1);

/// A response body sent in chunks, recording how far it was read.
class _ChunkedBody {
  _ChunkedBody(this.chunks, {this.hangAfter, this.errorAfter});

  /// The chunks, in order.
  final List<Uint8List> chunks;

  /// When set, the body stops sending after this many chunks and never
  /// ends (a stalled connection).
  final int? hangAfter;

  /// When set, the body fails with a [SocketException] after this many
  /// chunks (a reset connection).
  final int? errorAfter;

  /// How many chunks were handed to the client.
  int sent = 0;

  /// Whether the client cancelled its subscription to the body.
  bool cancelled = false;

  /// Whether the client closed the response (dio calls this on cancel).
  bool closed = false;

  Stream<Uint8List> stream() {
    late final StreamController<Uint8List> controller;
    Timer? next;
    late final void Function() schedule;
    void pump() {
      if (sent == hangAfter) return;
      if (sent == errorAfter) {
        controller.addError(const SocketException('Connection reset'));
        unawaited(controller.close());
        return;
      }
      if (sent == chunks.length) {
        unawaited(controller.close());
        return;
      }
      controller.add(chunks[sent++]);
      schedule();
    }

    schedule = () => next = Timer(_packetGap, pump);

    controller = StreamController<Uint8List>(
      onListen: schedule,
      onPause: () => next?.cancel(),
      onResume: schedule,
      onCancel: () {
        cancelled = true;
        next?.cancel();
      },
    );
    return controller.stream;
  }

  /// Answers with this body, [status], and [headers].
  FakeHandler handler(int status, {Map<String, String> headers = const {}}) =>
      (options) async => ResponseBody(
        stream(),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
          for (final entry in headers.entries)
            entry.key.toLowerCase(): [entry.value],
        },
        onClose: () => closed = true,
      );
}

/// A health JSON object of exactly [size] bytes in UTF-8.
String _jsonOfSize(int size) {
  const prefix = '{"status":"ok","version":"';
  const suffix = '"}';
  final body = '$prefix${'x' * (size - prefix.length - suffix.length)}$suffix';
  assert(utf8.encode(body).length == size, 'size mismatch');
  return body;
}

/// [text] split into chunks of [chunkSize] bytes.
List<Uint8List> _split(String text, {int chunkSize = 64 * 1024}) {
  final bytes = utf8.encode(text);
  return [
    for (var start = 0; start < bytes.length; start += chunkSize)
      Uint8List.sublistView(
        bytes,
        start,
        start + chunkSize < bytes.length ? start + chunkSize : bytes.length,
      ),
  ];
}

/// [count] chunks of 64 KiB of the letter a.
List<Uint8List> _filler(int count) => [
  for (var i = 0; i < count; i++) Uint8List(64 * 1024)..fillRange(0, 65536, 97),
];

/// GETs a health body through [adapter]. The jitter is fixed at 0, so the
/// first retry starts at once and the elapsed times are exact.
Timed<HealthResponse> _get(FakeHttpAdapter adapter, {CancelToken? token}) =>
    runFake(
      () => fakeClient(adapter, random: FixedRandom(0)).get(
        '/v1/games/13',
        decode: HealthResponse.fromJson,
        cancelToken: token,
      ),
    );

void main() {
  test('the limit is 1 MiB [ASSUMPTION: 1 MB]', () {
    expect(_limit, 1048576);
    final client = fakeClient(FakeHttpAdapter([respond(200)]));
    expect(client.maxResponseBytes, _limit);
    expect(client.dio.options.responseType, ResponseType.stream);
  });

  group('AC7: bodies within the limit decode', () {
    test('a 900 KB body decodes', () {
      final body = _jsonOfSize(900 * 1024);
      final adapter = FakeHttpAdapter([respond(200, body: body)]);
      final t = _get(adapter);
      expect(t.result.valueOrNull?.status, 'ok');
      expect(t.result.valueOrNull?.version.length, 900 * 1024 - 28);
      expect(adapter.requests, hasLength(1));
    });

    test('a 900 KB body in 64 KiB chunks with its Content-Length decodes', () {
      final text = _jsonOfSize(900 * 1024);
      final body = _ChunkedBody(_split(text));
      final adapter = FakeHttpAdapter([
        body.handler(200, headers: {'Content-Length': '${900 * 1024}'}),
      ]);
      final t = _get(adapter);
      expect(t.result.valueOrNull?.version.length, 900 * 1024 - 28);
      expect(body.sent, body.chunks.length);
    });

    test('a body of exactly the limit decodes', () {
      final body = _ChunkedBody(_split(_jsonOfSize(_limit)));
      final adapter = FakeHttpAdapter([
        body.handler(200, headers: {'Content-Length': '$_limit'}),
      ]);
      final t = _get(adapter);
      expect(t.result.isOk, isTrue, reason: '${t.result}');
    });

    test('multi-byte characters split across chunks decode', () {
      final text = jsonEncode({'status': 'ok', 'version': 'Café 世界 🎲'});
      final body = _ChunkedBody(_split(text, chunkSize: 1));
      final t = _get(FakeHttpAdapter([body.handler(200)]));
      expect(t.result.valueOrNull?.version, 'Café 世界 🎲');
    });
  });

  group('AC7: bodies over the limit give the unexpected failure', () {
    test('one byte over the limit, without Content-Length', () {
      final body = _ChunkedBody(_split(_jsonOfSize(_limit + 1)));
      final adapter = FakeHttpAdapter([body.handler(200)]);
      final t = _get(adapter);
      expect(t.result, const Err<HealthResponse>(UnexpectedFailure()));
      expect(adapter.requests, hasLength(1));
      // The 17th chunk holds the extra byte: reading stops there.
      expect(body.sent, 17);
      expect(body.cancelled, isTrue);
      expect(body.closed, isTrue);
    });

    test('a 10 MB stream with a false small Content-Length stops at the '
        'limit', () {
      final body = _ChunkedBody(_filler(160));
      final adapter = FakeHttpAdapter([
        body.handler(200, headers: {'Content-Length': '100'}),
      ]);
      final t = _get(adapter);
      expect(t.result, const Err<HealthResponse>(UnexpectedFailure()));
      expect(adapter.requests, hasLength(1), reason: 'not retried');
      // 16 chunks fill the limit; the 17th passes it. Nothing more is read.
      expect(body.sent, 17);
      expect(body.cancelled, isTrue);
      expect(body.closed, isTrue);
    });

    test('a Content-Length over the limit is refused before reading', () {
      final body = _ChunkedBody(_filler(32));
      final adapter = FakeHttpAdapter([
        body.handler(200, headers: {'Content-Length': '${2 * _limit}'}),
      ]);
      final t = _get(adapter);
      expect(t.result, const Err<HealthResponse>(UnexpectedFailure()));
      expect(adapter.requests, hasLength(1), reason: 'not retried');
      expect(body.sent, 0);
      expect(body.cancelled, isTrue);
      expect(body.closed, isTrue);
    });

    test('a Content-Length of one byte over the limit is refused', () {
      final body = _ChunkedBody(_filler(1));
      final adapter = FakeHttpAdapter([
        body.handler(200, headers: {'Content-Length': '${_limit + 1}'}),
      ]);
      final t = _get(adapter);
      expect(t.result, const Err<HealthResponse>(UnexpectedFailure()));
      expect(body.closed, isTrue);
    });

    test('an oversized 503 body is not retried', () {
      final body = _ChunkedBody(_filler(20));
      final adapter = FakeHttpAdapter([
        body.handler(503, headers: {'Retry-After': '1'}),
        respond(200, body: contractFixture('health/ok.json')),
      ]);
      final t = _get(adapter);
      expect(t.result, const Err<HealthResponse>(UnexpectedFailure()));
      expect(adapter.requests, hasLength(1));
      // Only the 17 chunks (1 ms apart) were read; no Retry-After wait.
      expect(t.elapsed, const Duration(milliseconds: 17));
    });

    test('a smaller client limit applies to the same rules', () {
      final adapter = FakeHttpAdapter([
        respond(200, body: contractFixture('health/ok.json')),
      ]);
      final client = ApiClient(
        config: ApiConfig.parse(testBaseUrl, allowInsecureHttp: false),
        enableLogging: false,
        dio: Dio()..httpClientAdapter = adapter,
        maxResponseBytes: 10,
        newStopwatch: clock.stopwatch,
      );
      final t = runFake(
        () => client.get('/health', decode: HealthResponse.fromJson),
      );
      expect(t.result, const Err<HealthResponse>(UnexpectedFailure()));
    });
  });

  group('errors while the body streams', () {
    test('a reset connection mid-body is no connection, and is retried', () {
      final body = _ChunkedBody(_filler(4), errorAfter: 2);
      final adapter = FakeHttpAdapter([
        body.handler(200),
        respond(200, body: contractFixture('health/ok.json')),
      ]);
      final t = _get(adapter);
      expect(t.result.isOk, isTrue, reason: '${t.result}');
      expect(adapter.requests, hasLength(2));
    });

    test('a reset connection on every attempt gives no connection', () {
      final adapter = FakeHttpAdapter([
        (options) =>
            _ChunkedBody(_filler(4), errorAfter: 1).handler(200)(options),
      ]);
      final t = _get(adapter);
      expect(t.result, const Err<HealthResponse>(NoConnectionFailure()));
      expect(adapter.requests, hasLength(4));
    });

    test('a body that stalls hits the 15 s receive timeout, then retries', () {
      final body = _ChunkedBody(_filler(4), hangAfter: 1);
      final adapter = FakeHttpAdapter([
        body.handler(200),
        respond(200, body: contractFixture('health/ok.json')),
      ]);
      final t = _get(adapter);
      expect(t.result.isOk, isTrue, reason: '${t.result}');
      expect(adapter.requests, hasLength(2));
      expect(body.closed, isTrue);
      // The receive timer restarts at the first chunk (1 ms), then the
      // retry starts at once (jitter 0).
      expect(t.elapsed, const Duration(seconds: 15, milliseconds: 1));
    });

    test('cancelling while the body streams ends the call', () {
      final body = _ChunkedBody(_filler(4), hangAfter: 1);
      final adapter = FakeHttpAdapter([body.handler(200)]);
      final t = runFake(() {
        final token = CancelToken();
        Timer(const Duration(seconds: 1), token.cancel);
        return fakeClient(
          adapter,
        ).get('/health', decode: HealthResponse.fromJson, cancelToken: token);
      });
      expect(t.result, const Err<HealthResponse>(CancelledFailure()));
      expect(t.elapsed, const Duration(seconds: 1));
      expect(body.cancelled, isTrue);
      expect(body.closed, isTrue);
    });
  });
}
