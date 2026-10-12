import 'dart:async';
import 'dart:io';

import 'config/config.dart';
import 'logging/logger.dart';

/// Exit code when GET /health answered 200.
const healthyExitCode = 0;

/// Exit code for any other outcome: another status, no answer within
/// [healthcheckTimeout], connection refused, or an invalid configuration.
const unhealthyExitCode = 1;

/// How long one health check may take in total, connecting included. Keep it
/// below the Compose health check `timeout` (deploy/docker-compose.yml).
const healthcheckTimeout = Duration(seconds: 3);

/// Calls GET /health on the running server at 127.0.0.1:PORT and returns
/// [healthyExitCode] on 200, [unhealthyExitCode] otherwise (T-010 AC12).
///
/// This is the Compose health check for the scratch image, which has no shell
/// and no curl (docs/decisions.md 2026-10-12). It runs inside the server's
/// container with the same environment, so PORT comes from the same config
/// loader as the server's.
///
/// Prints nothing on success. On failure it writes one JSON line on
/// [stderrLine] with a fixed `reason` (Docker keeps it in the health log);
/// the line never holds the response body, headers, or a config value.
///
/// It connects to 127.0.0.1, not `localhost`, because the server listens on
/// IPv4 only and `localhost` may resolve to ::1 first. It sends no proxy
/// lookups and follows no redirects.
Future<int> runHealthcheck({
  required Map<String, String> environment,
  required void Function(String line) stderrLine,
  Duration timeout = healthcheckTimeout,
  DateTime Function() clock = DateTime.now,
}) async {
  final logger = Logger(
    minLevel: LogLevel.error,
    sink: stderrLine,
    clock: clock,
  );
  void fail(String reason, [Map<String, Object?> fields = const {}]) {
    logger.error('healthcheck failed', fields: {'reason': reason, ...fields});
  }

  final int port;
  try {
    port = Config.load(environment).port;
  } on ConfigException {
    fail('invalid configuration');
    return unhealthyExitCode;
  }

  final client = HttpClient()
    ..connectionTimeout = timeout
    ..findProxy = (_) => 'DIRECT';
  try {
    final status = await _getHealthStatus(client, port).timeout(timeout);
    if (status == HttpStatus.ok) return healthyExitCode;
    fail('unexpected status', {'status': status});
    return unhealthyExitCode;
  } on TimeoutException {
    fail('timeout', {'timeoutMs': timeout.inMilliseconds});
    return unhealthyExitCode;
  } on SocketException {
    fail('connection failed');
    return unhealthyExitCode;
  } on HttpException {
    fail('invalid response');
    return unhealthyExitCode;
  } finally {
    client.close(force: true);
  }
}

Future<int> _getHealthStatus(HttpClient client, int port) async {
  final request = await client.get('127.0.0.1', port, '/health');
  request.followRedirects = false;
  final response = await request.close();
  await response.drain<void>();
  return response.statusCode;
}
