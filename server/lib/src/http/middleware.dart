import 'package:shelf/shelf.dart';

import '../logging/logger.dart';
import 'responses.dart';
import 'routes.dart';

/// Route value logged for requests that matched no route. The raw path is
/// never logged, because it is client-controlled.
const unmatchedRoute = '<unmatched>';

/// Method value logged for any method outside [_knownMethods]. dart:io
/// accepts any HTTP token as a method, so the raw value is client-controlled.
const otherMethod = '<other>';

const _knownMethods = {
  'GET',
  'HEAD',
  'POST',
  'PUT',
  'PATCH',
  'DELETE',
  'OPTIONS',
};

/// [method] if it is a standard method, otherwise [otherMethod].
String loggableMethod(String method) =>
    _knownMethods.contains(method) ? method : otherMethod;

/// Writes one `request` log line with only safe fields.
void logRequest(
  Logger logger, {
  required String method,
  required String? route,
  required int status,
  required Duration elapsed,
}) {
  logger.log(status >= 500 ? LogLevel.error : LogLevel.info, 'request', {
    'method': loggableMethod(method),
    'route': route ?? unmatchedRoute,
    'status': status,
    'durationMs': elapsed.inMicroseconds / 1000,
  });
}

/// Writes exactly one log line per request: method, route template, status,
/// and duration in milliseconds.
///
/// Privacy: the line never holds the client IP, any header (including
/// User-Agent and X-Forwarded-For), the raw path, the query string, the body,
/// or a non-standard method name. Status 500 and above is logged at error
/// level, the rest at info.
Middleware requestLog(Logger logger) => (Handler inner) {
  return (Request request) async {
    final (tracked, slot) = RouteSlot.attach(request);
    final stopwatch = Stopwatch()..start();
    final response = await inner(tracked);
    logRequest(
      logger,
      method: request.method,
      route: slot.template,
      status: response.statusCode,
      elapsed: stopwatch.elapsed,
    );
    return response;
  };
};

/// Turns any uncaught error into a 500 `internal_error` envelope.
///
/// The error type, a redacted description, and the stack trace go to the log
/// at error level, together with the route template; the response body never
/// contains them.
///
/// HijackException is caught too: the server never hijacks connections, and
/// letting it through would make shelf_io print the raw URL to stderr.
Middleware errorBoundary(Logger logger) => (Handler inner) {
  return (Request request) async {
    try {
      return await inner(request);
    } catch (error, stackTrace) {
      logger.error(
        'unhandled error',
        error: error,
        stackTrace: stackTrace,
        fields: {
          'method': loggableMethod(request.method),
          'route': RouteSlot.of(request)?.template ?? unmatchedRoute,
        },
      );
      return internalErrorResponse();
    }
  };
};
