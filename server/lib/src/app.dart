import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'http/middleware.dart';
import 'http/responses.dart';
import 'http/routes.dart';
import 'logging/logger.dart';

/// Builds the whole HTTP handler: middleware, /health, and the /v1 routes.
///
/// Order, outermost first:
/// 1. request log (one line per request, including 401, 429, and 500),
/// 2. error boundary (any throw, including from the /v1 guards, becomes a
///    500 envelope and never reaches shelf_io's stderr printer),
/// 3. root router: /health, and /v1 mounted behind [v1Middleware].
///
/// [v1Middleware] runs for every request under /v1, matched or not (an
/// unknown /v1 path reaches the /v1 not-found handler through it). Per-IP
/// rate limiting (T-020) and attestation (T-066) go here, in that order.
///
/// [version] is the build version reported by /health.
///
/// [addTestRoutes] lets tests register extra /v1 routes (for example one that
/// throws) so they run through the real pipeline. Production code never
/// passes it.
Handler buildApp({
  required String version,
  required Logger logger,
  List<Middleware> v1Middleware = const [],
  void Function(Routes v1)? addTestRoutes,
}) {
  final v1Router = Router(notFoundHandler: (_) => notFoundResponse());
  final v1 = Routes(v1Router, mountPath: '/v1');
  addTestRoutes?.call(v1);

  var v1Pipeline = const Pipeline();
  for (final middleware in v1Middleware) {
    v1Pipeline = v1Pipeline.addMiddleware(middleware);
  }

  final root = Router(notFoundHandler: (_) => notFoundResponse())
    ..mount('/v1', v1Pipeline.addHandler(v1Router.call));

  // /health stays outside /v1 so Compose and Caddy health checks can use it
  // without attestation.
  Routes(root).get(
    '/health',
    (_) => jsonResponse(
      200,
      HealthResponse(status: 'ok', version: version).toJson(),
    ),
  );

  return const Pipeline()
      .addMiddleware(requestLog(logger))
      .addMiddleware(errorBoundary(logger))
      .addHandler(root.call);
}
