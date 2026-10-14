import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/harness.dart';
import '../support/database.dart';

/// QA edge cases for T-008 (round 1).
void main() {
  group('QA T-008: config edge cases', () {
    Map<String, String> env(String port, [String level = 'info']) => {
      'PORT': port,
      'LOG_LEVEL': level,
    };

    for (final bad in [
      '0',
      '65536',
      '99999',
      '100000',
      '-1',
      '+80',
      '80.0',
      '8 0',
      '0x50',
      '1e3',
      '99999999999999999999',
      '٣٠', // Arabic-Indic digits
      '\u{FF18}\u{FF10}', // full-width digits
    ]) {
      test('PORT=${jsonEncode(bad)} is rejected without echoing it', () {
        try {
          Config.load(env(bad));
          fail('expected ConfigException');
        } on ConfigException catch (e) {
          expect(e.message, contains('PORT is invalid'));
          expect(e.message, isNot(contains(bad)));
        }
      });
    }

    for (final (raw, expected) in [
      ('1', 1),
      ('65535', 65535),
      ('08080', 8080),
      ('  8080  ', 8080),
      ('\t8080\n', 8080),
    ]) {
      test('PORT=${jsonEncode(raw)} is accepted as $expected', () {
        expect(Config.load(env(raw)).port, expected);
      });
    }

    test('whitespace-only values count as missing', () {
      try {
        Config.load(env('   ', '\t\n'));
        fail('expected ConfigException');
      } on ConfigException catch (e) {
        expect(e.problems, hasLength(2));
        expect(e.message, contains('PORT is missing'));
        expect(e.message, contains('LOG_LEVEL is missing'));
      }
    });

    test('LOG_LEVEL is case sensitive and trimmed', () {
      expect(Config.load(env('80', ' warning ')).logLevel, LogLevel.warning);
      expect(
        () => Config.load(env('80', 'INFO')),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => Config.load(env('80', 'info,debug')),
        throwsA(isA<ConfigException>()),
      );
    });

    test('a value holding a newline never reaches the message', () {
      try {
        Config.load(env('80', 'secret-token\nsecond-line'));
        fail('expected ConfigException');
      } on ConfigException catch (e) {
        expect(e.message, isNot(contains('secret-token')));
        expect(e.message, isNot(contains('\n')));
      }
    });

    test('unrelated env variables are ignored and never printed', () {
      try {
        Config.load({'EBAY_SECRET': 'hunter2', 'LOG_LEVEL': 'loud'});
        fail('expected ConfigException');
      } on ConfigException catch (e) {
        expect(e.message, isNot(contains('hunter2')));
        expect(e.message, isNot(contains('EBAY_SECRET')));
      }
    });
  });

  group('QA T-008: HTTP method and path edge cases', () {
    late TestApp app;
    setUp(
      () => app = TestApp(
        addTestRoutes: (v1) {
          v1.get('/games/<bggId|[0-9]+>', (r) => Response.ok('x'));
          v1.get(
            '/boom',
            (r) => throw StateError('line1\nline2 "quoted" \u{1F4A5}'),
          );
        },
      ),
    );

    test('HEAD /health is 200 with no body', () async {
      final r = await app.send('HEAD', '/health');
      expect(r.statusCode, 200);
      expect(r.headers['content-type'], contains('application/json'));
      expect(await r.readAsString(), isEmpty);
    });

    test('OPTIONS /health returns a clean envelope, no leak', () async {
      final r = await app.send('OPTIONS', '/health');
      expect(r.statusCode, anyOf(404, 405));
      final body = await r.readAsString();
      expect(body, isNot(contains('shelf')));
      expect(body, isNot(contains('StateError')));
      expect(jsonDecode(body), isA<Map<String, dynamic>>());
    });

    for (final method in ['PUT', 'DELETE', 'PATCH', 'POST']) {
      test('$method /health is a clean 404 envelope', () async {
        final r = await app.send(method, '/health', body: 'x');
        expect(r.statusCode, 404);
        expect((await jsonObjectOf(r))['error'], isNotNull);
      });
    }

    for (final path in [
      '/health/',
      '/HEALTH',
      '/health%2F',
      '/%00',
      '/v1/a%20b',
      '/v1/games/abc',
      '/v1/games/',
      '/..%2f..%2fetc/passwd',
      '/é\u{1F600}',
      '/${'a' * 20000}',
      '/v1/${'%41' * 5000}',
    ]) {
      test('path of length ${path.length} gives a clean envelope and '
          'one short log line', () async {
        final Response r;
        try {
          r = await app.get(path);
        } on FormatException {
          // Uri.parse rejected it before the app saw it.
          return;
        }
        expect(r.statusCode, anyOf(200, 404));
        if (r.statusCode == 404) {
          final body = await r.readAsString();
          expect(body, isNot(contains('shelf')));
          expect(jsonDecode(body), isA<Map<String, dynamic>>());
        }
        expect(app.logs.withMessage('request'), hasLength(1));
        final line = app.logs.lines.single;
        expect(line, isNot(contains('aaaaaaaa')));
        expect(line, isNot(contains('passwd')));
        expect(line.length, lessThan(400));
      });
    }

    test(
      'route template is logged for a parameter route, not the value',
      () async {
        await app.get('/v1/games/12345');
        final rec = app.logs.withMessage('request').single;
        expect(rec['route'], '/v1/games/{bggId}');
        expect(app.logs.lines.single, isNot(contains('12345')));
      },
    );

    test(
      'an error message with newlines and quotes stays one log line',
      () async {
        final r = await app.get('/v1/boom');
        expect(r.statusCode, 500);
        for (final line in app.logs.lines) {
          expect(line, isNot(contains('\n')));
          expect(line, isNot(contains('\r')));
          jsonDecode(line);
        }
        final err = app.logs.withMessage('unhandled error').single;
        expect(err['level'], 'error');
        expect(err['error'], contains('line1\nline2'));
        expect(app.logs.withMessage('request').single['status'], 500);
      },
    );

    test('a thrown String is a 500 envelope without its text', () async {
      final a = TestApp(
        addTestRoutes: (v1) {
          v1.get('/s', (r) => throw 'plain string secret');
        },
      );
      final r = await a.get('/v1/s');
      expect(r.statusCode, 500);
      expect(await r.readAsString(), isNot(contains('secret')));
    });

    test('100 concurrent requests each log exactly one line', () async {
      final rs = await Future.wait(
        List.generate(100, (i) => app.get(i.isEven ? '/health' : '/nope$i')),
      );
      expect(rs.where((r) => r.statusCode == 200), hasLength(50));
      expect(app.logs.withMessage('request'), hasLength(100));
    });

    test('unicode header values are never logged', () async {
      await app.get(
        '/health',
        headers: {
          'X-Forwarded-For': '203.0.113.9',
          'User-Agent': 'EvilAgent/1',
          'Cookie': 'sid=abc',
        },
      );
      final all = app.logs.lines.join();
      for (final s in ['203.0.113.9', 'EvilAgent', 'sid=abc']) {
        expect(all, isNot(contains(s)));
      }
    });
  });

  group('QA T-008: shutdown and real sockets', () {
    test(
      'several in-flight requests finish; new connections are refused',
      () async {
        final gate = Completer<void>();
        final signals = StreamController<ProcessSignal>();
        final out = LogCapture();
        final listening = Completer<HttpServer>();
        final exit = runServer(
          environment: withTestDatabase({
            'PORT': '${await freePort()}',
            'LOG_LEVEL': 'info',
          }),
          shutdownSignals: signals.stream,
          stdoutLine: out.call,
          stderrLine: (_) {},
          address: InternetAddress.loopbackIPv4,
          onListening: listening.complete,
          addTestRoutes: (v1) {
            v1.get('/slow', (r) async {
              await gate.future;
              return Response.ok('done');
            });
          },
        );
        final port = (await listening.future).port;
        final clients = List.generate(5, (_) => HttpClient());
        final replies = [
          for (final c in clients)
            c
                .getUrl(Uri.parse('http://127.0.0.1:$port/v1/slow'))
                .then((q) => q.close())
                .then(utf8.decodeStream),
        ];
        await Future<void>.delayed(const Duration(milliseconds: 300));
        signals.add(ProcessSignal.sigterm);
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final extra = HttpClient();
        await expectLater(
          extra
              .getUrl(Uri.parse('http://127.0.0.1:$port/health'))
              .then((q) => q.close()),
          throwsA(isA<SocketException>()),
        );
        var exited = false;
        unawaited(exit.then((_) => exited = true));
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(exited, isFalse, reason: 'must wait for in-flight requests');

        gate.complete();
        expect(await Future.wait(replies), everyElement('done'));
        expect(await exit, 0);
        expect(out.withMessage('shutdown complete'), hasLength(1));
        for (final c in [...clients, extra]) {
          c.close(force: true);
        }
      },
    );

    test('a second signal does not break shutdown', () async {
      final signals = StreamController<ProcessSignal>();
      final listening = Completer<HttpServer>();
      final exit = runServer(
        environment: withTestDatabase({
          'PORT': '${await freePort()}',
          'LOG_LEVEL': 'info',
        }),
        shutdownSignals: signals.stream,
        stdoutLine: (_) {},
        stderrLine: (_) {},
        address: InternetAddress.loopbackIPv4,
        onListening: listening.complete,
      );
      await listening.future;
      signals
        ..add(ProcessSignal.sigterm)
        ..add(ProcessSignal.sigint);
      expect(await exit.timeout(const Duration(seconds: 5)), 0);
    });

    test('LOG_LEVEL=error hides request lines', () async {
      final out = LogCapture();
      final signals = StreamController<ProcessSignal>();
      final listening = Completer<HttpServer>();
      final exit = runServer(
        environment: withTestDatabase({
          'PORT': '${await freePort()}',
          'LOG_LEVEL': 'error',
        }),
        shutdownSignals: signals.stream,
        stdoutLine: out.call,
        stderrLine: (_) {},
        address: InternetAddress.loopbackIPv4,
        onListening: listening.complete,
      );
      final port = (await listening.future).port;
      final c = HttpClient();
      final res = await (await c.getUrl(
        Uri.parse('http://127.0.0.1:$port/health'),
      )).close();
      await res.drain<void>();
      c.close();
      signals.add(ProcessSignal.sigterm);
      await exit;
      expect(out.lines, isEmpty);
    });

    test('a port already in use returns exit code 1', () async {
      final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final code = await runServer(
        environment: withTestDatabase({
          'PORT': '${blocker.port}',
          'LOG_LEVEL': 'info',
        }),
        shutdownSignals: const Stream.empty(),
        stdoutLine: (_) {},
        stderrLine: (_) {},
        address: InternetAddress.loopbackIPv4,
      );
      await blocker.close();
      expect(code, listenErrorExitCode);
    });
  });
}
