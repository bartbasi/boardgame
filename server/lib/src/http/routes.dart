import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const _routeSlotKey = 'boardgame_server.route';

/// Holds the route template of the matched route, for the request log.
///
/// The request log middleware puts one slot into the request context before
/// routing; [Routes] fills it in when a route matches. A request that matches
/// no route leaves [template] null.
class RouteSlot {
  /// The matched template, for example `/v1/games/{bggId}`.
  String? template;

  /// Returns [request] with a fresh slot attached, and the slot.
  static (Request, RouteSlot) attach(Request request) {
    final slot = RouteSlot();
    return (request.change(context: {_routeSlotKey: slot}), slot);
  }

  /// The slot attached to [request], if any.
  static RouteSlot? of(Request request) {
    final slot = request.context[_routeSlotKey];
    return slot is RouteSlot ? slot : null;
  }
}

/// Registers routes on a shelf_router [Router] and records each route's
/// template for logging.
///
/// Handlers take only the [Request]; read path parameters with
/// `request.params['name']` (shelf_router's extension).
class Routes {
  /// Creates a registrar for [_router], which is mounted at [mountPath]
  /// (for example `/v1`; empty for the root router).
  Routes(this._router, {this.mountPath = ''});

  final Router _router;

  /// Where the router is mounted, for example `/v1`. Routes are registered
  /// relative to it; the logged template includes it.
  final String mountPath;

  static final _param = RegExp(r'<([A-Za-z_][A-Za-z0-9_]*)(\|[^>]*)?>');

  /// Converts a shelf_router path such as `/games/<bggId|[0-9]+>` into the
  /// log template `/games/{bggId}`.
  static String templateOf(String path) =>
      path.replaceAllMapped(_param, (m) => '{${m[1]}}');

  /// Adds a GET route. shelf_router also answers HEAD for it.
  void get(String path, Handler handler) => add('GET', path, handler);

  /// Adds a route for [verb].
  void add(String verb, String path, Handler handler) {
    final template = templateOf('$mountPath$path');
    _router.add(verb, path, (Request request) {
      RouteSlot.of(request)?.template = template;
      return handler(request);
    });
  }
}
