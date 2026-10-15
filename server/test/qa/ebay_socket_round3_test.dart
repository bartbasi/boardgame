import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

/// QA round 3 for T-084 (orchestrator decision on T-084-R2-B1): over a real
/// socket, a body that is not fully read ends with the connection closed
/// promptly and no response bytes; a complete body is acknowledged with 204.
/// Pure Dart, no database.

const _deadline = Duration(milliseconds: 500);
const _margin = Duration(milliseconds: 1500);
const _cap = maxNotificationBytes;

class _Result {
  _Result(this.received, this.closedAfter);
  final String received;
  final Duration? closedAfter;
  bool get closed => closedAfter != null;
}

void main() {
  late HttpServer server;
  late LogCapture serverLogs;

  setUp(() async {
    serverLogs = LogCapture();
    final ebay = Router(notFoundHandler: (_) => notFoundResponse());
    addEbayAccountDeletionRoutes(
      Routes(ebay, mountPath: ebayMountPath),
      const EbayAccountDeletionConfig(
        verificationToken: 'tok_ABC-123_tok_ABC-123_tok_ABC-123_',
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
      serverLogs.logger(),
    );
  });
  tearDown(() => server.close(force: true));

  List<int> head(String headers, {String method = 'POST'}) => utf8.encode(
    '$method $ebayAccountDeletionPath HTTP/1.1\r\nHost: 127.0.0.1\r\n'
    '$headers\r\n',
  );

  /// Sends [parts] one after another ([gap] apart) and waits for the server
  /// to close the connection or for 10 s. When [stopAfterClose] the sender
  /// stops as soon as the connection is closed.
  Future<_Result> exchange(
    List<List<int>> parts, {
    Duration gap = Duration.zero,
    int? port,
  }) async {
    final watch = Stopwatch()..start();
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      port ?? server.port,
    );
    final received = <int>[];
    final closed = Completer<Duration>();
    socket.listen(
      received.addAll,
      onDone: () {
        if (!closed.isCompleted) closed.complete(watch.elapsed);
      },
      onError: (Object _) {
        if (!closed.isCompleted) closed.complete(watch.elapsed);
      },
      cancelOnError: true,
    );
    () async {
      for (final p in parts) {
        if (closed.isCompleted) break;
        try {
          socket.add(p);
          await socket.flush();
        } on Object {
          break;
        }
        if (gap > Duration.zero) await Future<void>.delayed(gap);
      }
    }();
    Duration? at;
    try {
      at = await closed.future.timeout(const Duration(seconds: 6));
    } on TimeoutException {
      at = null;
    }
    socket.destroy();
    return _Result(latin1.decode(received), at);
  }

  void expectPromptClose(_Result r, {Duration? within}) {
    expect(r.closed, isTrue, reason: 'the connection must be closed');
    expect(r.received, isEmpty, reason: 'no response bytes');
    expect(r.closedAfter!, lessThan(within ?? _deadline + _margin));
  }

  group('declared Content-Length over the cap', () {
    test('with 0 body bytes sent: closed at once, no response', () async {
      final r = await exchange([head('Content-Length: ${_cap + 1}\r\n')]);
      expectPromptClose(r, within: _deadline);
    });

    test('with a partial body: closed at once, no response', () async {
      for (final sent in [1, 100, 30000, _cap, _cap + 1]) {
        final r = await exchange([
          head('Content-Length: ${_cap + 1000}\r\n'),
          List.filled(sent, 0x78),
        ]);
        expectPromptClose(r, within: _deadline);
      }
    });

    test(
      'with the full declared body: still closed, no 413 on the wire',
      () async {
        final r = await exchange([
          head('Content-Length: ${_cap + 1}\r\n'),
          List.filled(_cap + 1, 0x78),
        ]);
        expectPromptClose(r, within: _deadline);
      },
    );

    test('absurd declared lengths close at once', () async {
      for (final length in ['99999999999', '2147483648', '4294967296']) {
        final r = await exchange([head('Content-Length: $length\r\n')]);
        expect(r.received, isEmpty, reason: length);
        expect(r.closed, isTrue, reason: length);
        expect(r.closedAfter!, lessThan(_deadline + _margin), reason: length);
      }
    });

    test('cap + 1 closes at once, exactly the cap does not (it waits for '
        'its body)', () async {
      final over = await exchange([head('Content-Length: ${_cap + 1}\r\n')]);
      expectPromptClose(over, within: _deadline);
      // At the cap and silent: closed only at the deadline.
      final atCap = await exchange([head('Content-Length: $_cap\r\n')]);
      expect(atCap.received, isEmpty);
      expect(atCap.closed, isTrue);
      expect(
        atCap.closedAfter!,
        greaterThanOrEqualTo(_deadline - const Duration(milliseconds: 80)),
      );
    });

    test('exactly the cap, fully sent, is 204', () async {
      final r = await exchange([
        head('Content-Length: $_cap\r\nConnection: close\r\n'),
        List.filled(_cap, 0x78),
      ]);
      expect(r.received, startsWith('HTTP/1.1 204'));
    });
  });

  group('chunked bodies', () {
    List<int> chunk(int size) => [
      ...utf8.encode('${size.toRadixString(16)}\r\n'),
      ...List.filled(size, 0x78),
      ...utf8.encode('\r\n'),
    ];

    test('one chunk over the cap, then silence: closed at once', () async {
      final r = await exchange([
        head('Transfer-Encoding: chunked\r\n'),
        chunk(_cap + 1),
      ]);
      expectPromptClose(r, within: _deadline);
    });

    test('many small chunks crossing the cap: closed, no response', () async {
      final r = await exchange([
        head('Transfer-Encoding: chunked\r\n'),
        for (var i = 0; i < 20; i++) chunk(8192),
      ]);
      expectPromptClose(r, within: _deadline + _margin);
    });

    test(
      'chunks summing to exactly the cap and a final zero chunk: 204',
      () async {
        final r = await exchange([
          head('Transfer-Encoding: chunked\r\nConnection: close\r\n'),
          for (var i = 0; i < 8; i++) chunk(8192),
          utf8.encode('0\r\n\r\n'),
        ]);
        expect(r.received, startsWith('HTTP/1.1 204'));
      },
    );

    test('one byte over the cap in chunks with a final zero chunk: closed '
        'without a response', () async {
      final r = await exchange([
        head('Transfer-Encoding: chunked\r\n'),
        for (var i = 0; i < 8; i++) chunk(8192),
        chunk(1),
        utf8.encode('0\r\n\r\n'),
      ]);
      expect(r.received, isEmpty);
      expect(r.closed, isTrue);
    });

    test('a chunked body that never ends is closed at the deadline', () async {
      final r = await exchange([
        head('Transfer-Encoding: chunked\r\n'),
        chunk(10),
      ]);
      expect(r.received, isEmpty);
      expect(r.closed, isTrue);
      expect(r.closedAfter!, lessThan(_deadline + _margin));
    });

    test('a malformed chunk header closes without a 2xx', () async {
      final r = await exchange([
        head('Transfer-Encoding: chunked\r\n'),
        utf8.encode('ZZZ\r\nhello\r\n0\r\n\r\n'),
      ]);
      expect(r.received, isNot(contains('HTTP/1.1 2')));
    });
  });

  group('stalled and slow bodies', () {
    test('headers only with a small declared length: closed at the deadline, '
        'no response', () async {
      final r = await exchange([head('Content-Length: 100\r\n')]);
      expect(r.received, isEmpty);
      expect(r.closed, isTrue);
      expect(
        r.closedAfter!,
        greaterThanOrEqualTo(_deadline - const Duration(milliseconds: 80)),
      );
      expect(r.closedAfter!, lessThan(_deadline + _margin));
    });

    test('one byte every 100 ms: closed by the overall deadline', () async {
      final r = await exchange([
        head('Content-Length: 1000\r\n'),
        for (var i = 0; i < 100; i++) [0x78],
      ], gap: const Duration(milliseconds: 100));
      expectPromptClose(r);
    });

    test('T-084-R2-B1 (agreed behavior): the stalled-body close is prompt '
        'and carries no response bytes', () async {
      final r = await exchange([
        head('Content-Length: 100\r\n'),
        [0x41],
      ]);
      expectPromptClose(r);
    });
  });

  group('a complete notification is still acknowledged', () {
    test('204 with Content-Length and an empty body', () async {
      final r = await exchange([
        head('Content-Length: 0\r\nConnection: close\r\n'),
      ]);
      expect(r.received, startsWith('HTTP/1.1 204'));
    });

    test('204 for a JSON body', () async {
      const body = '{"notification":{"data":{"username":"MARKER-u"}}}';
      final r = await exchange([
        head('Content-Length: ${body.length}\r\nConnection: close\r\n'),
        utf8.encode(body),
      ]);
      expect(r.received, startsWith('HTTP/1.1 204'));
      expect(r.received, isNot(contains('MARKER-u')));
    });

    test(
      'keep-alive: two notifications on one connection both get 204',
      () async {
        final socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          server.port,
        );
        final received = StringBuffer();
        socket.listen((d) => received.write(latin1.decode(d)));
        for (var i = 0; i < 2; i++) {
          socket.add(head('Content-Length: 2\r\n'));
          socket.add(utf8.encode('{}'));
          await socket.flush();
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
        socket.destroy();
        expect('HTTP/1.1 204'.allMatches(received.toString()), hasLength(2));
      },
    );

    test(
      'a complete notification after a rejected connection still works',
      () async {
        final bad = await exchange([head('Content-Length: ${_cap + 1}\r\n')]);
        expect(bad.received, isEmpty);
        final good = await exchange([
          head('Content-Length: 2\r\nConnection: close\r\n'),
          utf8.encode('{}'),
        ]);
        expect(good.received, startsWith('HTTP/1.1 204'));
      },
    );

    test('the challenge GET works on the same server', () async {
      final r = await exchange([
        utf8.encode(
          'GET $ebayAccountDeletionPath?challenge_code=abc HTTP/1.1\r\n'
          'Host: x\r\nConnection: close\r\n\r\n',
        ),
      ]);
      expect(r.received, startsWith('HTTP/1.1 200'));
      expect(r.received, contains('challengeResponse'));
    });
  });

  group('many connections at once', () {
    test('sixty mixed bad connections all close promptly with no response, '
        'and a good request afterwards is 204', () async {
      final watch = Stopwatch()..start();
      final kinds = <Future<_Result>>[];
      for (var i = 0; i < 60; i++) {
        switch (i % 4) {
          case 0:
            kinds.add(exchange([head('Content-Length: ${_cap + 1}\r\n')]));
          case 1:
            kinds.add(exchange([head('Content-Length: 100\r\n')]));
          case 2:
            kinds.add(
              exchange([
                head('Transfer-Encoding: chunked\r\n'),
                [
                  ...utf8.encode('${(_cap + 5).toRadixString(16)}\r\n'),
                  ...List.filled(_cap + 5, 0x78),
                ],
              ]),
            );
          default:
            kinds.add(
              exchange([
                head('Content-Length: 500\r\n'),
                for (var j = 0; j < 30; j++) [0x78],
              ], gap: const Duration(milliseconds: 80)),
            );
        }
      }
      final results = await Future.wait(kinds);
      for (final r in results) {
        expect(r.received, isEmpty);
        expect(r.closed, isTrue);
        expect(r.closedAfter!, lessThan(_deadline + _margin * 2));
      }
      // All of them in about one deadline, not one after another.
      expect(watch.elapsed, lessThan(_deadline + _margin * 3));
      final good = await exchange([
        head('Content-Length: 2\r\nConnection: close\r\n'),
        utf8.encode('{}'),
      ]);
      expect(good.received, startsWith('HTTP/1.1 204'));
    });

    test('pipelined: an oversize request followed by a good one in the same '
        'write gets no response at all', () async {
      final r = await exchange([
        [
          ...head('Content-Length: ${_cap + 1}\r\n'),
          ...head('Content-Length: 2\r\n'),
          ...utf8.encode('{}'),
        ],
      ]);
      expect(r.received, isNot(contains('HTTP/1.1 2')));
      expect(r.closed, isTrue);
    });
  });

  group('logging', () {
    test('the server logs nothing for rejected bodies (no body bytes, no '
        'markers)', () async {
      const marker = 'SECRETMARK-body-77';
      await exchange([
        head('Content-Length: ${_cap + 1}\r\n'),
        utf8.encode(marker),
      ]);
      await exchange([head('Content-Length: 100\r\n'), utf8.encode(marker)]);
      await exchange([
        head('Transfer-Encoding: chunked\r\n'),
        utf8.encode('${(_cap + 1).toRadixString(16)}\r\n$marker'),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(serverLogs.lines.join(), isNot(contains(marker)));
      expect(serverLogs.lines.join(), isNot(contains('challenge')));
    });
  });

  group('through the full app: only the standard request line', () {
    late HttpServer app;
    late LogCapture appLogs;

    setUp(() async {
      appLogs = LogCapture();
      app = await bindAndServe(
        buildApp(
          version: 'v',
          logger: appLogs.logger(),
          databaseHealth: DatabaseHealth.alwaysUp(),
          ebayAccountDeletion: const EbayAccountDeletionConfig(
            verificationToken: 'tok_ABC-123_tok_ABC-123_tok_ABC-123_',
            endpointUrl:
                'https://api.example.com/ebay/marketplace-account-deletion',
          ),
        ),
        InternetAddress.loopbackIPv4,
        0,
        appLogs.logger(),
      );
    });
    tearDown(() => app.close(force: true));

    test('rejected and accepted bodies log at most one request record each, '
        'with no body content', () async {
      const marker = 'SECRETMARK-app-body';
      // A declared over-cap body is closed at once.
      final bad = await exchange([
        head('Content-Length: ${_cap + 1}\r\n'),
        utf8.encode(marker),
      ], port: app.port);
      expect(bad.received, isEmpty);
      // A complete body.
      final good = await exchange([
        head('Content-Length: ${marker.length}\r\nConnection: close\r\n'),
        utf8.encode(marker),
      ], port: app.port);
      expect(good.received, startsWith('HTTP/1.1 204'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(appLogs.lines.join(), isNot(contains(marker)));
      final records = appLogs.records;
      expect(records.length, lessThanOrEqualTo(2));
      for (final r in records) {
        expect(r['msg'], isNot(contains('body')));
        expect(
          r.keys.toSet().difference({
            'ts',
            'level',
            'msg',
            'method',
            'route',
            'status',
            'durationMs',
            'errorType',
            'error',
          }),
          isEmpty,
          reason: 'unexpected keys in $r',
        );
      }
      final statuses = records.map((r) => r['status']).toList();
      expect(statuses, contains(204));
    });
  });
}
