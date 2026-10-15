import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

/// QA round 2 for T-084: one overall body deadline (408), the 64 KiB cap
/// (413), their ordering, and the 300 per minute limit. Real short timers
/// (the handler uses dart:async Timer), so each test uses deadlines of a few
/// hundred milliseconds.

const _config = EbayAccountDeletionConfig(
  verificationToken: 'tok_ABC-123_tok_ABC-123_tok_ABC-123_',
  endpointUrl: 'https://api.example.com/ebay/marketplace-account-deletion',
);

Handler _handler(Duration deadline) {
  final router = Router(notFoundHandler: (_) => notFoundResponse());
  addEbayAccountDeletionRoutes(
    Routes(router, mountPath: ebayMountPath),
    _config,
    readTimeout: deadline,
  );
  return router.call;
}

Future<Response> _post(Handler h, Stream<List<int>> body, {int? length}) =>
    Future(
      () => h(
        Request(
          'POST',
          Uri.parse('http://localhost$ebayAccountDeletionRoute'),
          body: body,
          headers: {'content-length': ?(length == null ? null : '$length')},
        ),
      ),
    );

/// A body that emits [chunk] every [every], [count] times (forever when
/// null), and reports how many chunks it emitted and whether it was
/// cancelled.
class _Trickle {
  _Trickle(this.every, {this.count, this.chunk = const [0x41], this.first});
  final Duration every;
  final int? count;
  final List<int> chunk;
  final List<int>? first;
  int emitted = 0;
  bool cancelled = false;
  bool done = false;

  Stream<List<int>> get stream {
    late StreamController<List<int>> c;
    Timer? t;
    c = StreamController<List<int>>(
      onListen: () {
        if (first != null) c.add(first!);
        t = Timer.periodic(every, (_) {
          emitted++;
          c.add(chunk);
          if (count != null && emitted >= count!) {
            t?.cancel();
            done = true;
            c.close();
          }
        });
      },
      onCancel: () {
        cancelled = true;
        t?.cancel();
      },
    );
    return c.stream;
  }
}

void main() {
  const deadline = Duration(milliseconds: 400);

  group('overall body deadline', () {
    test('a trickle of one byte per interval gets 408 at the overall '
        'deadline, and reading stops', () async {
      final trickle = _Trickle(const Duration(milliseconds: 50));
      final watch = Stopwatch()..start();
      final r = await _post(_handler(deadline), trickle.stream);
      final took = watch.elapsed;
      expect(r.statusCode, 408);
      expect(
        took,
        greaterThanOrEqualTo(deadline - const Duration(milliseconds: 40)),
      );
      expect(took, lessThan(deadline * 4));
      expect(
        ((jsonDecode(await r.readAsString()) as Map)['error'] as Map)['code'],
        'request_timeout',
      );
      expect(trickle.cancelled, isTrue);
      final seen = trickle.emitted;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(trickle.emitted, seen, reason: 'nothing more is produced');
    });

    test('every gap shorter than the deadline still hits 408 (a per-chunk '
        'timeout would never fire)', () async {
      final trickle = _Trickle(const Duration(milliseconds: 100));
      final r = await _post(
        _handler(const Duration(milliseconds: 350)),
        trickle.stream,
      );
      expect(r.statusCode, 408);
      expect(trickle.cancelled, isTrue);
      // Roughly deadline / interval chunks were consumed, not hundreds.
      expect(trickle.emitted, lessThan(10));
    });

    test('a body that arrives well inside the deadline is acknowledged and '
        'the deadline timer never fires afterwards', () async {
      final trickle = _Trickle(const Duration(milliseconds: 30), count: 5);
      final r = await _post(
        _handler(const Duration(milliseconds: 600)),
        trickle.stream,
      );
      expect(r.statusCode, 204);
      expect(trickle.done, isTrue);
      // Waiting past the deadline changes nothing (no late 408, no error).
      await Future<void>.delayed(const Duration(milliseconds: 700));
    });

    test('a body arriving just inside the deadline is acknowledged', () async {
      // 6 chunks, 100 ms apart: done at about 600 ms, deadline 900 ms.
      final trickle = _Trickle(const Duration(milliseconds: 100), count: 6);
      final r = await _post(
        _handler(const Duration(milliseconds: 900)),
        trickle.stream,
      );
      expect(r.statusCode, 204);
    });

    test('a body that would finish only after the deadline gets 408', () async {
      final trickle = _Trickle(const Duration(milliseconds: 100), count: 12);
      final r = await _post(
        _handler(const Duration(milliseconds: 500)),
        trickle.stream,
      );
      expect(r.statusCode, 408);
      expect(trickle.done, isFalse);
    });

    test(
      'an empty body and an immediately finished body are 204 at once',
      () async {
        final watch = Stopwatch()..start();
        expect(
          (await _post(_handler(deadline), const Stream.empty())).statusCode,
          204,
        );
        expect(
          (await _post(
            _handler(deadline),
            Stream.value(utf8.encode('{}')),
          )).statusCode,
          204,
        );
        expect(watch.elapsed, lessThan(const Duration(milliseconds: 300)));
      },
    );

    test('a stream that never emits and never ends gets 408', () async {
      final never = StreamController<List<int>>();
      addTearDown(() {
        never.close();
      });
      final r = await _post(
        _handler(const Duration(milliseconds: 250)),
        never.stream,
      );
      expect(r.statusCode, 408);
    });

    test('twenty trickling requests at once all get 408 at about one '
        'deadline, not one after another', () async {
      final h = _handler(deadline);
      final watch = Stopwatch()..start();
      final trickles = [
        for (var i = 0; i < 20; i++) _Trickle(const Duration(milliseconds: 60)),
      ];
      final responses = await Future.wait([
        for (final t in trickles) _post(h, t.stream),
      ]);
      expect({for (final r in responses) r.statusCode}, {408});
      expect(watch.elapsed, lessThan(deadline * 3));
      expect(trickles.every((t) => t.cancelled), isTrue);
    });

    test('the 408 body is only the error envelope', () async {
      final never = StreamController<List<int>>();
      addTearDown(() {
        never.close();
      });
      final r = await _post(
        _handler(const Duration(milliseconds: 100)),
        never.stream,
      );
      final body = jsonDecode(await r.readAsString()) as Map;
      expect(body.keys, ['error']);
      expect((body['error'] as Map).keys.toSet(), {'code', 'message'});
    });
  });

  group('408 versus 413', () {
    test('more than 64 KiB in the first chunk is 413 at once, never a '
        'late 408', () async {
      final trickle = _Trickle(
        const Duration(milliseconds: 50),
        first: List.filled(maxNotificationBytes + 1, 0x41),
      );
      final watch = Stopwatch()..start();
      final r = await _post(
        _handler(const Duration(seconds: 2)),
        trickle.stream,
      );
      expect(r.statusCode, 413);
      expect(watch.elapsed, lessThan(const Duration(milliseconds: 500)));
      expect(trickle.cancelled, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });

    test(
      'crossing 64 KiB while trickling, before the deadline, is 413',
      () async {
        final trickle = _Trickle(
          const Duration(milliseconds: 30),
          chunk: List.filled(8 * 1024, 0x41),
        );
        final r = await _post(
          _handler(const Duration(seconds: 3)),
          trickle.stream,
        );
        expect(r.statusCode, 413);
        expect(trickle.cancelled, isTrue);
        expect(trickle.emitted, lessThanOrEqualTo(9));
      },
    );

    test(
      'a slow body that stays under 64 KiB until the deadline is 408',
      () async {
        final trickle = _Trickle(
          const Duration(milliseconds: 100),
          first: List.filled(40 * 1024, 0x41),
        );
        final r = await _post(
          _handler(const Duration(milliseconds: 450)),
          trickle.stream,
        );
        expect(r.statusCode, 408);
      },
    );

    test('a big chunk that would arrive after the deadline never counts: '
        '408', () async {
      final late = StreamController<List<int>>();
      addTearDown(() {
        if (!late.isClosed) late.close();
      });
      Timer(const Duration(milliseconds: 600), () {
        if (!late.isClosed && late.hasListener) {
          late.add(List.filled(maxNotificationBytes + 10, 0x41));
        }
      });
      final r = await _post(
        _handler(const Duration(milliseconds: 250)),
        late.stream,
      );
      expect(r.statusCode, 408);
    });

    test(
      'a declared length over the cap is 413 without waiting or reading',
      () async {
        final never = StreamController<List<int>>();
        addTearDown(() {
          never.close();
        });
        final watch = Stopwatch()..start();
        final r = await _post(
          _handler(const Duration(seconds: 5)),
          never.stream,
          length: maxNotificationBytes + 1,
        );
        expect(r.statusCode, 413);
        expect(watch.elapsed, lessThan(const Duration(milliseconds: 300)));
        expect(never.hasListener, isFalse, reason: 'body never read');
      },
    );

    test('a declared length at the cap and a slow body is 408', () async {
      final trickle = _Trickle(const Duration(milliseconds: 80));
      final r = await _post(
        _handler(const Duration(milliseconds: 300)),
        trickle.stream,
        length: maxNotificationBytes,
      );
      expect(r.statusCode, 408);
    });

    test('exactly 64 KiB in one fast chunk is 204', () async {
      final r = await _post(
        _handler(deadline),
        Stream.value(List.filled(maxNotificationBytes, 0x41)),
      );
      expect(r.statusCode, 204);
    });
  });

  group('a failing body stream', () {
    test('an error before the deadline is not acknowledged and the deadline '
        'timer does not fire afterwards', () async {
      final c = StreamController<List<int>>();
      Object? thrown;
      final f = _post(_handler(const Duration(milliseconds: 300)), c.stream)
          .then<Object?>(
            (r) => r.statusCode,
            onError: (Object e) {
              thrown = e;
              return null;
            },
          );
      c.add([1, 2, 3]);
      c.addError(const SocketException('reset'));
      final result = await f;
      expect(result, isNull);
      expect(thrown, isA<SocketException>());
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await c.close();
    });
  });

  group('over a real socket with a short deadline', () {
    late HttpServer server;

    setUp(() async {
      server = await bindAndServe(
        _handler(const Duration(milliseconds: 500)),
        InternetAddress.loopbackIPv4,
        0,
        LogCapture().logger(),
      );
      addTearDown(() => server.close(force: true));
    });

    test(
      'headers promise 100 bytes, one byte every 100 ms: the connection is '
      'closed within the deadline plus a margin and nothing 2xx is sent',
      () async {
        final socket = await Socket.connect('127.0.0.1', server.port);
        final output = StringBuffer();
        final closed = Completer<void>();
        socket.listen(
          (d) => output.write(utf8.decode(d, allowMalformed: true)),
          onDone: closed.complete,
          onError: (_) {
            if (!closed.isCompleted) closed.complete();
          },
        );
        socket.write(
          'POST $ebayAccountDeletionRoute HTTP/1.1\r\nHost: x\r\n'
          'Content-Length: 100\r\n\r\n',
        );
        final watch = Stopwatch()..start();
        for (var i = 0; i < 30 && !closed.isCompleted; i++) {
          try {
            socket.write('A');
            await socket.flush();
          } on Object {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        await closed.future.timeout(const Duration(seconds: 5));
        expect(watch.elapsed, lessThan(const Duration(seconds: 4)));
        expect(output.toString(), isNot(contains('HTTP/1.1 2')));
      },
    );

    // T-084-R2-B1 (minor): the 408 is documented but never reaches a real
    // client. dart:io destroys the connection when the body subscription is
    // cancelled, so the client sees a reset. Left failing on purpose.
    test(
      'T-084-R2-B1: the stalled-body 408 is delivered over the wire',
      () async {
        final socket = await Socket.connect('127.0.0.1', server.port);
        final output = StringBuffer();
        final closed = Completer<void>();
        socket.listen(
          (d) => output.write(utf8.decode(d, allowMalformed: true)),
          onDone: closed.complete,
          onError: (_) {
            if (!closed.isCompleted) closed.complete();
          },
        );
        socket.write(
          'POST $ebayAccountDeletionRoute HTTP/1.1\r\nHost: x\r\n'
          'Content-Length: 100\r\n\r\n',
        );
        socket.write('A');
        await socket.flush();
        await closed.future.timeout(const Duration(seconds: 5));
        expect(output.toString(), startsWith('HTTP/1.1 408'));
        socket.destroy();
        await socket.close().catchError((Object _) {});
      },
    );

    test('a fast, complete body on the same server is 204', () async {
      final client = HttpClient()..findProxy = (_) => 'DIRECT';
      addTearDown(() => client.close(force: true));
      final req = await client.post(
        '127.0.0.1',
        server.port,
        ebayAccountDeletionRoute,
      );
      req.write('{"a":1}');
      final res = await req.close();
      expect(res.statusCode, 204);
      await res.drain<void>();
    });
  });

  group('300 requests a minute', () {
    test('the 300th request passes, the 301st is 429', () async {
      expect(ebayRateLimitPerMinute, 300);
      var now = Duration.zero;
      final limiter = RateLimiter(
        limit: ebayRateLimitPerMinute,
        now: () => now,
      );
      final h = buildApp(
        version: 'v',
        logger: LogCapture().logger(),
        databaseHealth: DatabaseHealth.alwaysUp(),
        ebayAccountDeletion: _config,
        ebayMiddleware: [rateLimit(limiter, ClientAddressResolver())],
      );
      Future<int> hit() async => (await h(
        Request(
          'GET',
          Uri.parse(
            'http://localhost$ebayAccountDeletionPath?challenge_code=a',
          ),
          context: {connectionInfoContextKey: _Conn('203.0.113.7')},
        ),
      )).statusCode;
      for (var i = 1; i <= 299; i++) {
        expect(await hit(), 200, reason: 'request $i');
      }
      expect(await hit(), 200, reason: 'the 300th');
      now = const Duration(seconds: 10);
      final r = await h(
        Request(
          'GET',
          Uri.parse(
            'http://localhost$ebayAccountDeletionPath?challenge_code=a',
          ),
          context: {connectionInfoContextKey: _Conn('203.0.113.7')},
        ),
      );
      expect(r.statusCode, 429, reason: 'the 301st');
      expect(r.headers['retry-after'], '50');
      now = const Duration(seconds: 59, milliseconds: 999);
      expect(await hit(), 429);
      now = const Duration(minutes: 1);
      expect(await hit(), 200, reason: 'a new window');
    });

    test('the /v1 limiter keeps its own, much lower default', () {
      expect(defaultRateLimitPerWindow, 60);
      expect(ebayRateLimitPerMinute, greaterThan(defaultRateLimitPerWindow));
    });
  });
}

class _Conn implements HttpConnectionInfo {
  _Conn(String a) : remoteAddress = InternetAddress(a);
  @override
  final InternetAddress remoteAddress;
  @override
  int get remotePort => 1;
  @override
  int get localPort => 2;
}
