import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'http/middleware.dart';
import 'http/responses.dart';
import 'http/routes.dart';
import 'logging/logger.dart';

/// Builds the whole HTTP handler: middleware, /health, and the /v1 routes.
///
/// [version] is the build version reported by /health.
///
/// [addTestRoutes] lets tests register extra /v1 routes (for example one that
/// throws) so they run through the real pipeline. Production code never
/// passes it.
Handler buildApp({
  required String version,
  required Logger logger,
  void Function(Routes v1)? addTestRoutes,
}) {
  final router = Router(notFoundHandler: (_) => notFoundResponse());

  // /health stays outside /v1 so Compose and Caddy health checks can use it
  // without attestation.
  Routes(router).get(
    '/health',
    (_) => jsonResponse(
      200,
      HealthResponse(status: 'ok', version: version).toJson(),
    ),
  );

  final v1 = Routes(router, prefix: '/v1');
  addTestRoutes?.call(v1);

  return const Pipeline()
      .addMiddleware(requestLog(logger))
      .addMiddleware(errorBoundary(logger))
      .addHandler(router.call);
}
