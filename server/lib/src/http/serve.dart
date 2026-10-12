import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../logging/logger.dart';
import 'middleware.dart';
import 'responses.dart';

/// How long an idle keep-alive connection stays open (T-008 review R1-G2).
/// Caddy's upstream keep-alive (T-010) must be shorter, so Caddy never reuses
/// a connection this server is about to close.
const serverIdleTimeout = Duration(seconds: 65);

/// Binds an [HttpServer] and serves [handler] on it, without letting shelf_io
/// print anything.
///
/// Why not `shelf_io.serve`: shelf_io (1.4.2) writes plain text to stderr,
/// including the raw URL and query string, when it cannot build a shelf
/// `Request` (dart:io builds `requestedUri` from the client's Host,
/// X-Forwarded-Host, and X-Forwarded-Proto headers, and a value such as
/// `[` makes it throw), when a handler throws, and for stray async errors in
/// its own error zone. Here:
/// - the URL is checked first; a request that fails gets our 404 envelope and
///   one `request` log line with no raw values, and never reaches shelf_io;
/// - [handler] must already catch every error (the app's error boundary);
/// - stray async errors go to [logger] through our own guarded zone.
Future<HttpServer> bindAndServe(
  Handler handler,
  Object address,
  int port,
  Logger logger,
) async {
  final server = await HttpServer.bind(address, port)
    ..idleTimeout = serverIdleTimeout;
  runZonedGuarded(
    () => server.listen((request) => _serveOne(request, handler, logger)),
    (error, stackTrace) => logger.error(
      'uncaught async error',
      error: error,
      stackTrace: stackTrace,
    ),
  );
  return server;
}

Future<void> _serveOne(
  HttpRequest request,
  Handler handler,
  Logger logger,
) async {
  final stopwatch = Stopwatch()..start();
  if (!_canBuildShelfRequest(request)) {
    await _rejectUnparseable(request);
    logRequest(
      logger,
      method: request.method,
      route: null,
      status: HttpStatus.notFound,
      elapsed: stopwatch.elapsed,
    );
    return;
  }
  await shelf_io.handleRequest(request, handler, poweredByHeader: null);
}

/// Runs the same checks shelf_io's request conversion would fail on: the
/// requested URI (Uri.parse of client headers), the shelf `Request`
/// constructor's argument checks, and the connection info.
bool _canBuildShelfRequest(HttpRequest request) {
  try {
    if (request.connectionInfo == null) return false;
    Request(request.method, request.requestedUri);
    return true;
  } catch (_) {
    // Deliberately not logged: the error text contains the raw URL.
    return false;
  }
}

/// Answers a request whose URL cannot be built with the 404 `not_found`
/// envelope. A `bad_request` code would be an api_contract addition (open
/// question in docs/handoffs/T-008.md).
Future<void> _rejectUnparseable(HttpRequest request) async {
  final body = utf8.encode(await notFoundResponse().readAsString());
  final response = request.response
    ..statusCode = HttpStatus.notFound
    ..headers.contentType = ContentType.json
    ..contentLength = body.length
    ..add(body);
  await response.close();
}
