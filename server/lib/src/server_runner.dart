import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;

import 'app.dart';
import 'config/config.dart';
import 'http/routes.dart';
import 'logging/logger.dart';
import 'version.dart';

/// Exit code for a missing or invalid configuration (sysexits EX_CONFIG).
const configErrorExitCode = 78;

/// Exit code when the server cannot listen, for example the port is in use.
const listenErrorExitCode = 1;

/// How long in-flight requests may run after a shutdown signal
/// [ASSUMPTION: 10 s, T-008 AC9].
const defaultShutdownGrace = Duration(seconds: 10);

/// Loads config, serves HTTP until the first event on [shutdownSignals], then
/// shuts down gracefully. Returns the process exit code.
///
/// Startup fails before listening, with [configErrorExitCode] and one JSON
/// line on [stderrLine] naming every missing or invalid variable (never
/// their values).
///
/// Shutdown stops accepting connections at once, lets in-flight requests
/// finish for up to [shutdownGrace], then closes whatever is left and
/// returns 0.
///
/// [address] defaults to all IPv4 interfaces, as needed inside a container.
/// [onListening] and [addTestRoutes] are test hooks.
Future<int> runServer({
  required Map<String, String> environment,
  required Stream<ProcessSignal> shutdownSignals,
  required void Function(String line) stdoutLine,
  required void Function(String line) stderrLine,
  String version = appVersion,
  Duration shutdownGrace = defaultShutdownGrace,
  Object? address,
  DateTime Function() clock = DateTime.now,
  void Function(HttpServer server)? onListening,
  void Function(Routes v1)? addTestRoutes,
}) async {
  final Config config;
  try {
    config = Config.load(environment);
  } on ConfigException catch (e) {
    Logger(
      minLevel: LogLevel.error,
      sink: stderrLine,
      clock: clock,
    ).error(e.message);
    return configErrorExitCode;
  }

  final logger = Logger(
    minLevel: config.logLevel,
    sink: stdoutLine,
    clock: clock,
  );
  final handler = buildApp(
    version: version,
    logger: logger,
    addTestRoutes: addTestRoutes,
  );

  final HttpServer server;
  try {
    server = await shelf_io.serve(
      handler,
      address ?? InternetAddress.anyIPv4,
      config.port,
      poweredByHeader: null,
    );
  } on SocketException catch (e) {
    logger.error(
      'could not listen',
      fields: {'port': config.port, 'reason': e.osError?.message ?? e.message},
    );
    return listenErrorExitCode;
  }
  logger.info('server started', {'port': server.port, 'version': version});
  onListening?.call(server);

  final signal = await shutdownSignals.first;
  logger.info('shutdown started', {
    'signal': signal.toString(),
    'graceMs': shutdownGrace.inMilliseconds,
  });

  // close() stops listening at once and closes idle keep-alive connections;
  // active connections close after their response is written.
  await server.close();
  final drained = await _waitForConnections(server, shutdownGrace);
  if (!drained) {
    final left = server.connectionsInfo().total;
    logger.warning('shutdown grace period expired', {'openConnections': left});
    await server.close(force: true);
  }
  logger.info('shutdown complete');
  return 0;
}

Future<bool> _waitForConnections(HttpServer server, Duration grace) async {
  final deadline = Stopwatch()..start();
  while (server.connectionsInfo().total > 0) {
    if (deadline.elapsed >= grace) return false;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return true;
}
