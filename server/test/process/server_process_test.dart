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

/// Starts `dart bin/server.dart` (same process id, so signals reach the
/// server) with [environment] on top of the parent environment.
Future<Process> _startServer(Map<String, String> environment) => Process.start(
  Platform.resolvedExecutable,
  ['bin/server.dart'],
  environment: environment,
);

void main() {
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
      final process = await _startServer({
        'PORT': '$port',
        'LOG_LEVEL': 'info',
      });
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
