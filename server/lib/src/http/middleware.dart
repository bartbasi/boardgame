import 'package:shelf/shelf.dart';

import '../logging/logger.dart';
import 'responses.dart';
import 'routes.dart';

/// Route value logged for requests that matched no route. The raw path is
/// never logged, because it is client-controlled.
const unmatchedRoute = '<unmatched>';

/// Writes exactly one log line per request: method, route template, status,
/// and duration in milliseconds.
///
/// Privacy: the line never holds the client IP, any header (including
/// User-Agent and X-Forwarded-For), the raw path, the query string, or the
/// body. Status 500 and above is logged at error level, the rest at info.
Middleware requestLog(Logger logger) => (Handler inner) {
  return (Request request) async {
    final (tracked, slot) = RouteSlot.attach(request);
    final stopwatch = Stopwatch()..start();
    final response = await inner(tracked);
    stopwatch.stop();
    final status = response.statusCode;
    logger.log(status >= 500 ? LogLevel.error : LogLevel.info, 'request', {
      'method': request.method,
      'route': slot.template ?? unmatchedRoute,
      'status': status,
      'durationMs': stopwatch.elapsedMicroseconds / 1000,
    });
    return response;
  };
};

/// Turns any uncaught error into a 500 `internal_error` envelope.
///
/// The error and its stack trace go to the log at error level, together with
/// the route template; the response body never contains them.
Middleware errorBoundary(Logger logger) => (Handler inner) {
  return (Request request) async {
    try {
      return await inner(request);
    } on HijackException {
      rethrow;
    } catch (error, stackTrace) {
      logger.error(
        'unhandled error',
        error: error,
        stackTrace: stackTrace,
        fields: {
          'method': request.method,
          'route': RouteSlot.of(request)?.template ?? unmatchedRoute,
        },
      );
      return internalErrorResponse();
    }
  };
};
