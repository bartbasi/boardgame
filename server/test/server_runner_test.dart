import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// Drives [runServer] in-process on the loopback interface.
class _Run {
  _Run({
    Map<String, String>? environment,
    this.grace = const Duration(seconds: 10),
    this.addTestRoutes,
  }) : environment = environment ?? const {};

  final Map<String, String> environment;
  final Duration grace;
  final void Function(Routes v1)? addTestRoutes;

  final signals = StreamController<ProcessSignal>();
  final out = LogCapture();
  final err = LogCapture();
  final listening = Completer<HttpServer>();
  late final Future<int> exitCode;

  void start() {
    exitCode = runServer(
      environment: environment,
      shutdownSignals: signals.stream,
      stdoutLine: out.call,
      stderrLine: err.call,
      version: '9.9.9+run',
      shutdownGrace: grace,
      address: InternetAddress.loopbackIPv4,
      clock: () => fixedNow,
      onListening: listening.complete,
      addTestRoutes: addTestRoutes,
    );
  }

  Future<int> get port async => (await listening.future).port;
}

Future<Map<String, String>> _env() async => {
  'PORT': '${await freePort()}',
  'LOG_LEVEL': 'info',
};

void main() {
  group('startup with bad config (T-008 AC4, AC5)', () {
    test('a missing PORT exits with code 78 before listening and prints one '
        'line naming it', () async {
      final run = _Run(environment: {'LOG_LEVEL': 'info'})..start();

      expect(await run.exitCode, configErrorExitCode);
      expect(run.listening.isCompleted, isFalse);
      expect(run.out.lines, isEmpty);
      expect(run.err.lines, hasLength(1));
      final record = run.err.records.single;
      expect(record['level'], 'error');
      expect(record['msg'], contains('PORT is missing'));
    });

    test(
      'PORT=abc and LOG_LEVEL=loud are both named, values not printed',
      () async {
        final run = _Run(environment: {'PORT': 'abc', 'LOG_LEVEL': 'loud'})
          ..start();

        expect(await run.exitCode, configErrorExitCode);
        final line = run.err.lines.single;
        expect(line, contains('PORT is invalid'));
        expect(line, contains('1 to 65535'));
        expect(line, contains('LOG_LEVEL is invalid'));
        expect(line, contains('debug, info, warning, error'));
        expect(line, isNot(contains('abc')));
        expect(line, isNot(contains('loud')));
      },
    );
  });

  group('serving', () {
    test('serves /health over HTTP with JSON and no X-Powered-By', () async {
      final run = _Run(environment: await _env())..start();
      final port = await run.port;

      final client = HttpClient();
      final request = await client.get('127.0.0.1', port, '/health');
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      client.close(force: true);

      expect(response.statusCode, 200);
      expect(response.headers.contentType?.mimeType, 'application/json');
      expect(response.headers.value('x-powered-by'), isNull);
      expect(
        HealthResponse.fromJson(jsonDecode(body) as Map<String, dynamic>),
        const HealthResponse(status: 'ok', version: '9.9.9+run'),
      );
      final started = run.out.withMessage('server started').single;
      expect(started['port'], port);
      expect(started['version'], '9.9.9+run');

      run.signals.add(ProcessSignal.sigterm);
      expect(await run.exitCode, 0);
    });

    test('a port already in use exits with code 1 and logs why', () async {
      final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(blocker.close);
      final run = _Run(
        environment: {'PORT': '${blocker.port}', 'LOG_LEVEL': 'info'},
      )..start();

      expect(await run.exitCode, listenErrorExitCode);
      final record = run.out.withMessage('could not listen').single;
      expect(record['level'], 'error');
      expect(record['port'], blocker.port);
      expect(run.listening.isCompleted, isFalse);
    });
  });

  group('graceful shutdown on SIGTERM (T-008 AC9)', () {
    test('stops accepting connections, lets an in-flight request finish, and '
        'exits 0', () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final run = _Run(
        environment: await _env(),
        addTestRoutes: (v1) => v1.get('/slow', (_) async {
          entered.complete();
          await release.future;
          return jsonResponse(200, {'done': true});
        }),
      )..start();
      final port = await run.port;

      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final inFlight = client
          .get('127.0.0.1', port, '/v1/slow')
          .then((request) => request.close())
          .then((response) async {
            return (response.statusCode, await utf8.decodeStream(response));
          });
      await entered.future;

      run.signals.add(ProcessSignal.sigterm);
      await _eventually(
        () => run.out.withMessage('shutdown started').isNotEmpty,
      );

      await expectLater(
        Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: const Duration(seconds: 5),
        ),
        throwsA(isA<SocketException>()),
        reason: 'new connections must be refused after SIGTERM',
      );

      var exited = false;
      unawaited(run.exitCode.then((_) => exited = true));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(exited, isFalse, reason: 'must wait for the in-flight request');

      release.complete();
      final (status, body) = await inFlight;
      expect(status, 200);
      expect(jsonDecode(body), {'done': true});
      expect(await run.exitCode, 0);
      expect(run.out.withMessage('shutdown complete'), hasLength(1));
      expect(run.out.withMessage('shutdown grace period expired'), isEmpty);
      final started = run.out.withMessage('shutdown started').single;
      expect(started['signal'], 'SIGTERM');
      expect(started['graceMs'], 10000);
    });

    test(
      'closes requests still running after the grace period and exits 0',
      () async {
        final entered = Completer<void>();
        final run = _Run(
          environment: await _env(),
          grace: const Duration(milliseconds: 300),
          addTestRoutes: (v1) => v1.get('/hang', (_) async {
            entered.complete();
            await Completer<void>().future;
            return jsonResponse(200, {});
          }),
        )..start();
        final port = await run.port;

        final client = HttpClient();
        addTearDown(() => client.close(force: true));
        final inFlight = client
            .get('127.0.0.1', port, '/v1/hang')
            .then((request) => request.close())
            .then((response) => response.drain<void>());
        await entered.future;
        final inFlightFails = expectLater(
          inFlight,
          throwsA(isA<HttpException>()),
        );

        final stopwatch = Stopwatch()..start();
        run.signals.add(ProcessSignal.sigterm);

        expect(await run.exitCode, 0);
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
        expect(
          stopwatch.elapsed,
          greaterThanOrEqualTo(const Duration(milliseconds: 300)),
        );
        final warning = run.out
            .withMessage('shutdown grace period expired')
            .single;
        expect(warning['level'], 'warning');
        expect(warning['openConnections'], 1);
        await inFlightFails;
      },
    );

    test('an idle keep-alive connection does not hold up shutdown', () async {
      final run = _Run(environment: await _env())..start();
      final port = await run.port;
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final response = await (await client.get(
        '127.0.0.1',
        port,
        '/health',
      )).close();
      await response.drain<void>();

      final stopwatch = Stopwatch()..start();
      run.signals.add(ProcessSignal.sigint);

      expect(await run.exitCode, 0);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(run.out.withMessage('shutdown grace period expired'), isEmpty);
    });

    test('the default grace period is 10 seconds', () {
      expect(defaultShutdownGrace, const Duration(seconds: 10));
    });
  });
}

Future<void> _eventually(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('condition not met in 5 s');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
