import 'dart:async';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';

/// Entry point. All logic lives in [runMain] so tests can drive it.
///
/// No arguments: serve HTTP. `--healthcheck`: call /health on the running
/// server and exit 0 or 1 (the Compose health check, T-010).
Future<void> main(List<String> args) async {
  final code = await runMain(
    args,
    environment: Platform.environment,
    shutdownSignals: _shutdownSignals,
    stdoutLine: stdout.writeln,
    stderrLine: stderr.writeln,
  );
  await Future.wait([stdout.flush(), stderr.flush()]);
  exit(code);
}

/// SIGTERM (docker stop) and SIGINT (Ctrl+C). Windows cannot watch SIGTERM.
Stream<ProcessSignal> _shutdownSignals() {
  final controller = StreamController<ProcessSignal>();
  ProcessSignal.sigint.watch().listen(controller.add);
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen(controller.add);
  }
  return controller.stream;
}
