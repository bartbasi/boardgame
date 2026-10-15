import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

/// T-084 round 3 (QA T-084-R2-B1, orchestrator decision): over a real
/// socket, a notification body that is not fully read (too slow, or too
/// large) ends with the connection closed promptly and no response at all;
/// a complete body still gets its 204.
const _deadline = Duration(milliseconds: 500);

/// How long after the deadline a close may still count as prompt (slow CI
/// machines, Windows socket teardown).
const _margin = Duration(milliseconds: 1500);

void main() {
  late HttpServer server;
  late LogCapture logs;

  setUp(() async {
    logs = LogCapture();
    final ebay = Router(notFoundHandler: (_) => notFoundResponse());
    addEbayAccountDeletionRoutes(
      Routes(ebay, mountPath: ebayMountPath),
      const EbayAccountDeletionConfig(
        verificationToken: 'fake-token-fake-token-fake-token-fake-token',
        endpointUrl:
            'https://api.example.com/ebay/marketplace-account-deletion',
      ),
      readTimeout: _deadline,
    );
    final root = Router(notFoundHandler: (_) => notFoundResponse())
      ..mount(ebayMountPath, ebay.call);
    server = await bindAndServe(
      root.call,
      InternetAddress.loopbackIPv4,
      0,
      logs.logger(),
    );
  });
  tearDown(() => server.close(force: true));

  /// Sends [head] (and then one byte every [trickleEvery], if given) and
  /// returns what came back and how long until the server closed the
  /// connection, or null after 10 s.
  Future<(String, Duration?)> exchange(
    List<int> head, {
    Duration? trickleEvery,
  }) async {
    final stopwatch = Stopwatch()..start();
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      server.port,
    );
    socket.add(head);
    await socket.flush();
    Timer? trickle;
    if (trickleEvery != null) {
      trickle = Timer.periodic(trickleEvery, (_) {
        try {
          socket.add([0x20]);
        } on Object {
          // The server closed the connection; the close is what we wait for.
        }
      });
    }
    final received = <int>[];
    final closed = Completer<Duration?>();
    socket.listen(
      received.addAll,
      onDone: () {
        if (!closed.isCompleted) closed.complete(stopwatch.elapsed);
      },
      onError: (Object _) {
        // A reset counts as closed.
        if (!closed.isCompleted) closed.complete(stopwatch.elapsed);
      },
      cancelOnError: true,
    );
    final at = await closed.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
    trickle?.cancel();
    socket.destroy();
    return (latin1.decode(received), at);
  }

  List<int> head(String headers) => utf8.encode(
    'POST $ebayAccountDeletionPath HTTP/1.1\r\nHost: 127.0.0.1\r\n'
    '$headers\r\n',
  );

  test('a stalled body: the connection closes at the deadline with no '
      'response', () async {
    final (received, closedAt) = await exchange([
      ...head('Content-Length: 100\r\n'),
      ...utf8.encode('{'),
    ]);
    expect(closedAt, isNotNull, reason: 'the connection must close');
    expect(closedAt!, greaterThanOrEqualTo(_deadline - _tolerance));
    expect(closedAt, lessThan(_deadline + _margin));
    expect(received, isEmpty);
  });

  test('a trickling body (gaps far below the deadline): the connection '
      'closes by the overall deadline with no response', () async {
    final (received, closedAt) = await exchange(
      head('Content-Length: 60000\r\n'),
      trickleEvery: _deadline ~/ 5,
    );
    expect(closedAt, isNotNull);
    expect(closedAt!, lessThan(_deadline + _margin));
    expect(received, isEmpty);
  });

  test('a declared Content-Length over 64 KiB with one byte sent: the '
      'connection closes at once with no response (dart:io would otherwise '
      'wait for the whole declared body)', () async {
    final (received, closedAt) = await exchange([
      ...head('Content-Length: ${maxNotificationBytes + 1}\r\n'),
      ...utf8.encode('{'),
    ]);
    expect(closedAt, isNotNull);
    expect(closedAt!, lessThan(_deadline));
    expect(received, isEmpty);
  });

  test('a chunked body passing 64 KiB, then silence: the connection closes '
      'at once with no response', () async {
    final size = maxNotificationBytes + 10;
    final (received, closedAt) = await exchange([
      ...head('Transfer-Encoding: chunked\r\n'),
      ...utf8.encode('${size.toRadixString(16)}\r\n'),
      ...List<int>.filled(size, 0x78),
      ...utf8.encode('\r\n'),
    ]);
    expect(closedAt, isNotNull);
    expect(closedAt!, lessThan(_deadline));
    expect(received, isEmpty);
  });

  test('a complete notification still gets 204', () async {
    final (received, closedAt) = await exchange([
      ...head('Content-Length: 2\r\nConnection: close\r\n'),
      ...utf8.encode('{}'),
    ]);
    expect(received, startsWith('HTTP/1.1 204'));
    expect(closedAt, isNotNull);
  });
}

/// Timer slack: a close a few milliseconds before the nominal deadline is
/// still the deadline firing.
const _tolerance = Duration(milliseconds: 50);
