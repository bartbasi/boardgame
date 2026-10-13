// Runs bin/server.dart as a real child process. Slower than the other tests
// (the VM compiles the server on start), so it has its own timeout.
@Timeout(Duration(minutes: 2))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

import '../support/harness.dart';
import '../support/database.dart';

/// Starts `dart bin/server.dart` (same process id, so signals reach the
/// server) with [environment] on top of the parent environment.
Future<Process> _startServer(Map<String, String> environment) => Process.start(
  Platform.resolvedExecutable,
  ['bin/server.dart'],
  environment: environment,
);

void main() {
  group('bin/server.dart --healthcheck (T-010 AC12)', () {
    Future<ProcessResult> healthcheck(int port) => Process.run(
      Platform.resolvedExecutable,
      ['bin/server.dart', '--healthcheck'],
      environment: {'PORT': '$port', 'LOG_LEVEL': 'info'},
    );

    test('exits 0 with no output when /health answers 200', () async {
      final signals = StreamController<ProcessSignal>();
      final listening = Completer<HttpServer>();
      final serverExit = runServer(
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
      final port = (await listening.future).port;

      final result = await healthcheck(port);

      signals.add(ProcessSignal.sigterm);
      await serverExit;
      expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
      expect((result.stdout as String).trim(), isEmpty);
      expect((result.stderr as String).trim(), isEmpty);
    });

    test('exits 1 with one JSON line when nothing listens', () async {
      final result = await healthcheck(await freePort());

      expect(result.exitCode, 1);
      expect((result.stdout as String).trim(), isEmpty);
      final record =
          jsonDecode((result.stderr as String).trim()) as Map<String, dynamic>;
      expect(record['msg'], 'healthcheck failed');
      expect(record['reason'], 'connection failed');
    });

    test('an unknown argument exits 64', () async {
      final result = await Process.run(Platform.resolvedExecutable, [
        'bin/server.dart',
        '--bogus',
      ]);

      expect(result.exitCode, usageErrorExitCode);
      expect((result.stderr as String), isNot(contains('--bogus')));
    });
  });

  test('missing PORT: the process exits non-zero before listening and prints '
      'one line naming the variable, not values (T-008 AC4)', () async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      ['bin/server.dart'],
      // Empty values count as missing, which also hides any PORT or
      // LOG_LEVEL the parent shell might have set.
      environment: {'PORT': '', 'LOG_LEVEL': 'loud'},
    );

    expect(result.exitCode, configErrorExitCode);
    expect((result.stdout as String).trim(), isEmpty);
    final lines = const LineSplitter().convert(
      (result.stderr as String).trim(),
    );
    expect(lines, hasLength(1));
    final record = jsonDecode(lines.single) as Map<String, dynamic>;
    expect(record['level'], 'error');
    expect(record['msg'], contains('PORT is missing'));
    expect(record['msg'], contains('LOG_LEVEL is invalid'));
    expect(record['msg'], isNot(contains('loud')));
  });

  test(
    'SIGTERM: the process stops listening and exits 0 (T-008 AC9)',
    () async {
      final port = await freePort();
      final process = await _startServer(
        withTestDatabase({'PORT': '$port', 'LOG_LEVEL': 'info'}),
      );
      final stdoutLines = <String>[];
      final started = Completer<void>();
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            stdoutLines.add(line);
            if (line.contains('"server started"') && !started.isCompleted) {
              started.complete();
            }
          });
      final stderrText = StringBuffer();
      process.stderr.transform(utf8.decoder).listen(stderrText.write);
      addTearDown(() => process.kill(ProcessSignal.sigkill));

      await started.future.timeout(const Duration(seconds: 60));
      final client = HttpClient();
      final response = await (await client.get(
        '127.0.0.1',
        port,
        '/health',
      )).close();
      await response.drain<void>();
      client.close(force: true);
      expect(response.statusCode, 200);

      expect(process.kill(ProcessSignal.sigterm), isTrue);

      final code = await process.exitCode.timeout(const Duration(seconds: 15));
      expect(code, 0, reason: 'stderr: $stderrText');
      expect(
        stdoutLines.where((l) => l.contains('"shutdown complete"')),
        hasLength(1),
      );
      await expectLater(
        Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: const Duration(seconds: 5),
        ),
        throwsA(isA<SocketException>()),
      );
    },
    testOn: 'linux || mac-os',
  );
}
