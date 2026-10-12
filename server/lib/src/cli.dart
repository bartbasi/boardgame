import 'dart:async';
import 'dart:io';

import 'healthcheck.dart';
import 'logging/logger.dart';
import 'server_runner.dart';

/// Command-line flag for the health check mode (T-010 AC12).
const healthcheckFlag = '--healthcheck';

/// Exit code for unknown command-line arguments (sysexits EX_USAGE).
const usageErrorExitCode = 64;

/// What the executable was asked to do.
enum Command {
  /// No arguments: run the HTTP server.
  serve,

  /// `--healthcheck`: call /health on the running server and exit 0 or 1.
  healthcheck,
}

/// Parses the command-line [args]. Returns null for anything that is not
/// exactly no arguments or exactly [healthcheckFlag].
Command? parseCommand(List<String> args) {
  if (args.isEmpty) return Command.serve;
  if (args.length == 1 && args.single == healthcheckFlag) {
    return Command.healthcheck;
  }
  return null;
}

/// Entry point behind bin/server.dart. Returns the process exit code.
///
/// [shutdownSignals] is called only in serve mode, so the health check mode
/// installs no signal handlers. Unknown arguments print one JSON line on
/// [stderrLine] (it never repeats the arguments) and return
/// [usageErrorExitCode].
Future<int> runMain(
  List<String> args, {
  required Map<String, String> environment,
  required Stream<ProcessSignal> Function() shutdownSignals,
  required void Function(String line) stdoutLine,
  required void Function(String line) stderrLine,
  DateTime Function() clock = DateTime.now,
}) async {
  switch (parseCommand(args)) {
    case Command.serve:
      return runServer(
        environment: environment,
        shutdownSignals: shutdownSignals(),
        stdoutLine: stdoutLine,
        stderrLine: stderrLine,
        clock: clock,
      );
    case Command.healthcheck:
      return runHealthcheck(
        environment: environment,
        stderrLine: stderrLine,
        clock: clock,
      );
    case null:
      Logger(minLevel: LogLevel.error, sink: stderrLine, clock: clock).error(
        'Invalid arguments: run with no arguments to serve, or with '
        '$healthcheckFlag to check a running server.',
      );
      return usageErrorExitCode;
  }
}
