import 'dart:async';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

import 'support/harness.dart';
import 'support/database.dart';

/// A bare local HTTP server that answers every request with [handle].
Future<HttpServer> _stubServer(
  FutureOr<void> Function(HttpRequest request) handle,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    try {
      await handle(request);
    } on Object {
      // The client may have gone away (timeout test).
    }
  });
  addTearDown(() => server.close(force: true));
  return server;
}

Map<String, String> _env(int port) => {'PORT': '$port', 'LOG_LEVEL': 'info'};

void main() {
  group('runHealthcheck (T-010 AC12)', () {
    test('exits 0 and prints nothing when the real app answers 200 on '
        '/health', () async {
      final signals = StreamController<ProcessSignal>();
      final listening = Completer<HttpServer>();
      final serverLogs = LogCapture();
      final serverExit = runServer(
        environment: withTestDatabase({
          'PORT': '${await freePort()}',
          'LOG_LEVEL': 'info',
        }),
        shutdownSignals: signals.stream,
        stdoutLine: serverLogs.call,
        stderrLine: serverLogs.call,
        address: InternetAddress.loopbackIPv4,
        onListening: listening.complete,
      );
      final port = (await listening.future).port;
      final err = LogCapture();

      final code = await runHealthcheck(
        environment: _env(port),
        stderrLine: err.call,
      );

      expect(code, healthyExitCode);
      expect(healthyExitCode, 0);
      expect(err.lines, isEmpty);
      final request = serverLogs.withMessage('request').single;
      expect(request['route'], '/health');
      expect(request['status'], 200);

      signals.add(ProcessSignal.sigterm);
      expect(await serverExit, 0);
    });

    test('calls GET /health on 127.0.0.1', () async {
      String? method;
      String? path;
      final server = await _stubServer((request) async {
        method = request.method;
        path = request.uri.toString();
        request.response.statusCode = 200;
        await request.response.close();
      });

      final code = await runHealthcheck(
        environment: _env(server.port),
        stderrLine: (_) {},
      );

      expect(code, healthyExitCode);
      expect(method, 'GET');
      expect(path, '/health');
    });

    test('exits 1 on 503 and logs the status, not the body', () async {
      final server = await _stubServer((request) async {
        request.response.statusCode = 503;
        request.response.write('secret upstream body');
        await request.response.close();
      });
      final err = LogCapture();

      final code = await runHealthcheck(
        environment: _env(server.port),
        stderrLine: err.call,
        clock: () => fixedNow,
      );

      expect(code, unhealthyExitCode);
      expect(unhealthyExitCode, 1);
      final line = err.records.single;
      expect(line['level'], 'error');
      expect(line['msg'], 'healthcheck failed');
      expect(line['reason'], 'unexpected status');
      expect(line['status'], 503);
      expect(line['ts'], fixedNow.toIso8601String());
      expect(err.lines.single, isNot(contains('secret')));
    });

    test('exits 1 on a redirect instead of following it', () async {
      final server = await _stubServer((request) async {
        request.response.statusCode = 302;
        request.response.headers.set('location', '/elsewhere');
        await request.response.close();
      });
      final err = LogCapture();

      final code = await runHealthcheck(
        environment: _env(server.port),
        stderrLine: err.call,
      );

      expect(code, unhealthyExitCode);
      expect(err.records.single['status'], 302);
    });

    test('exits 1 when nothing listens on PORT', () async {
      final err = LogCapture();

      final code = await runHealthcheck(
        environment: _env(await freePort()),
        stderrLine: err.call,
      );

      expect(code, unhealthyExitCode);
      expect(err.records.single['reason'], 'connection failed');
    });

    test('exits 1 when the server does not answer in time', () async {
      final never = Completer<void>();
      addTearDown(never.complete);
      final server = await _stubServer((request) => never.future);
      final err = LogCapture();
      final stopwatch = Stopwatch()..start();

      final code = await runHealthcheck(
        environment: _env(server.port),
        stderrLine: err.call,
        timeout: const Duration(milliseconds: 300),
      );

      expect(code, unhealthyExitCode);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
      final line = err.records.single;
      expect(line['reason'], 'timeout');
      expect(line['timeoutMs'], 300);
    });

    test('exits 1 on a malformed HTTP response', () async {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(socket.close);
      socket.listen((client) async {
        client.write('this is not HTTP\r\n\r\n');
        await client.flush();
        await client.close();
      });
      final err = LogCapture();

      final code = await runHealthcheck(
        environment: _env(socket.port),
        stderrLine: err.call,
      );

      expect(code, unhealthyExitCode);
      expect(err.records.single['reason'], 'invalid response');
    });

    test(
      'exits 1 on an invalid configuration without printing values',
      () async {
        final err = LogCapture();

        final code = await runHealthcheck(
          environment: {'PORT': 'secret-port', 'LOG_LEVEL': 'info'},
          stderrLine: err.call,
        );

        expect(code, unhealthyExitCode);
        expect(err.records.single['reason'], 'invalid configuration');
        expect(err.lines.single, isNot(contains('secret')));
      },
    );

    test('any other error exits 1 with one line naming only its type '
        '(T-010 review R1-G2)', () async {
      final err = LogCapture();

      final code = await runHealthcheck(
        environment: _env(1),
        stderrLine: err.call,
        getStatus: (_, _) async => throw StateError('secret detail'),
      );

      expect(code, unhealthyExitCode);
      final line = err.records.single;
      expect(line['reason'], 'unexpected error');
      expect(line['errorType'], 'StateError');
      expect(err.lines.single, isNot(contains('secret')));
      expect(line.containsKey('stack'), isFalse);
    });

    test('the default timeout stays below the Compose timeout of 5 s', () {
      expect(healthcheckTimeout, const Duration(seconds: 3));
    });
  });

  group('parseCommand and runMain (T-010 AC12)', () {
    test(
      'no arguments serves, --healthcheck checks, anything else is null',
      () {
        expect(parseCommand([]), Command.serve);
        expect(parseCommand(['--healthcheck']), Command.healthcheck);
        expect(parseCommand(['--healthcheck', 'x']), isNull);
        expect(parseCommand(['--health']), isNull);
        expect(parseCommand(['serve']), isNull);
      },
    );

    test(
      'unknown arguments exit 64 with one line that does not echo them',
      () async {
        final out = LogCapture();
        final err = LogCapture();
        var signalsRequested = false;

        final code = await runMain(
          ['--secret-flag'],
          environment: _env(1),
          shutdownSignals: () {
            signalsRequested = true;
            return const Stream.empty();
          },
          stdoutLine: out.call,
          stderrLine: err.call,
        );

        expect(code, usageErrorExitCode);
        expect(usageErrorExitCode, 64);
        expect(out.lines, isEmpty);
        expect(err.records.single['msg'], contains(healthcheckFlag));
        expect(err.lines.single, isNot(contains('secret')));
        expect(signalsRequested, isFalse);
      },
    );

    test(
      '--healthcheck runs the check and installs no signal handlers',
      () async {
        var signalsRequested = false;
        final err = LogCapture();

        final code = await runMain(
          [healthcheckFlag],
          environment: _env(await freePort()),
          shutdownSignals: () {
            signalsRequested = true;
            return const Stream.empty();
          },
          stdoutLine: (_) {},
          stderrLine: err.call,
        );

        expect(code, unhealthyExitCode);
        expect(err.records.single['reason'], 'connection failed');
        expect(signalsRequested, isFalse);
      },
    );

    test('no arguments runs the server until a shutdown signal', () async {
      final signals = StreamController<ProcessSignal>();
      final out = LogCapture();
      final port = await freePort();

      final exit = runMain(
        const [],
        environment: withTestDatabase(_env(port)),
        shutdownSignals: () => signals.stream,
        stdoutLine: out.call,
        stderrLine: out.call,
      );
      for (var i = 0; i < 250; i++) {
        if (out.lines.any((l) => l.contains('"server started"'))) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(
        await runHealthcheck(environment: _env(port), stderrLine: (_) {}),
        healthyExitCode,
      );

      signals.add(ProcessSignal.sigterm);
      expect(await exit, 0);
      expect(out.withMessage('shutdown complete'), hasLength(1));
    });
  });
}
