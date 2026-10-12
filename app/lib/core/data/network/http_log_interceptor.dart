import 'package:clock/clock.dart';
import 'package:dio/dio.dart';

/// Logs one line per request: method, path, status or error type, and time
/// taken. Never logs bodies, headers, or query strings, which can hold
/// what the user searched for.
///
/// The API client adds it only when logging is enabled, which is never in
/// release builds (T-013 AC12).
final class HttpLogInterceptor extends Interceptor {
  /// Creates an interceptor that writes lines with [log].
  HttpLogInterceptor(this.log);

  /// Where lines go, usually `debugPrint`.
  final void Function(String message) log;

  static const String _startKey = 'httpLogStart';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = clock.now();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    log(
      '${_describe(response.requestOptions)} -> ${response.statusCode}'
      '${_elapsed(response.requestOptions)}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    log(
      '${_describe(err.requestOptions)} -> ${err.type.name}'
      '${_elapsed(err.requestOptions)}',
    );
    handler.next(err);
  }

  static String _describe(RequestOptions options) =>
      'HTTP ${options.method} ${options.uri.path}';

  static String _elapsed(RequestOptions options) {
    final start = options.extra[_startKey];
    if (start is! DateTime) return '';
    return ' (${clock.now().difference(start).inMilliseconds} ms)';
  }
}
