import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';

import '../../domain/result.dart';
import 'api_config.dart';
import 'failure_mapper.dart';
import 'http_log_interceptor.dart';
import 'retry_policy.dart';

/// Decodes a JSON object body into a value. Usually an api_contract
/// `fromJson`, followed by mapping the DTO to a domain entity.
///
/// Named to avoid a clash with `JsonDecoder` from dart:convert.
typedef JsonObjectDecoder<T> = T Function(Map<String, dynamic> json);

/// The app's only HTTP client. It talks to our backend and nothing else.
///
/// Every method returns a [Result] and never throws: transport errors,
/// error statuses, and bodies that cannot be decoded all become a
/// [Failure]. GET requests are retried following [RetryPolicy]; other
/// methods are sent exactly once.
///
/// Cancellation: pass one [CancelToken] per logical call (for example one
/// per search query). The client listens to it only while that call runs.
final class ApiClient {
  /// Creates a client for [config]. When [config] is an [Err], every call
  /// returns its failure and no request is sent.
  ///
  /// [enableLogging] adds a debug log of method, path, status, and time.
  /// Release builds pass false. Bodies and headers are never logged.
  ///
  /// [newStopwatch] measures each call against [RetryPolicy.totalTimeout].
  /// It defaults to a monotonic [Stopwatch], so changes to the device clock
  /// do not move the deadline; tests pass `clock.stopwatch` for fake time.
  ApiClient({
    required Result<ApiConfig> config,
    required bool enableLogging,
    Dio? dio,
    this.policy = const RetryPolicy(),
    Random? random,
    void Function(String message)? log,
    Stopwatch Function()? newStopwatch,
  }) : _config = config,
       _random = random ?? Random(),
       _newStopwatch = newStopwatch ?? Stopwatch.new,
       _dio = dio ?? Dio() {
    final baseUri = config.valueOrNull?.baseUri;
    _dio.options
      ..baseUrl = baseUri?.toString() ?? ''
      ..connectTimeout = policy.connectTimeout
      ..receiveTimeout = policy.receiveTimeout
      ..responseType = ResponseType.plain
      ..followRedirects = false
      ..validateStatus = _acceptEveryStatus
      ..headers['Accept'] = 'application/json';
    if (enableLogging) {
      _dio.interceptors.add(HttpLogInterceptor(log ?? (_) {}));
    }
  }

  final Result<ApiConfig> _config;
  final Dio _dio;
  final Random _random;
  final Stopwatch Function() _newStopwatch;

  /// The retry and timeout settings.
  final RetryPolicy policy;

  /// The dio instance, for tests that check its settings and interceptors.
  Dio get dio => _dio;

  /// Closes the underlying connections. Calls made afterwards fail.
  void close() => _dio.close(force: true);

  static bool _acceptEveryStatus(int? status) => true;

  /// Sends a GET to [path] (for example `/v1/games/13`) and decodes the
  /// JSON object body with [decode]. Retried on connection errors,
  /// timeouts, 429, 502, 503, and 504.
  Future<Result<T>> get<T>(
    String path, {
    required JsonObjectDecoder<T> decode,
    Map<String, String>? queryParameters,
    CancelToken? cancelToken,
  }) => _send(
    'GET',
    path,
    decode: decode,
    queryParameters: queryParameters,
    cancelToken: cancelToken,
  );

  /// Sends a POST with a JSON [body]. Never retried, so a request that
  /// changes something on the server is not repeated.
  Future<Result<T>> post<T>(
    String path, {
    required JsonObjectDecoder<T> decode,
    Object? body,
    CancelToken? cancelToken,
  }) =>
      _send('POST', path, decode: decode, body: body, cancelToken: cancelToken);

  Future<Result<T>> _send<T>(
    String method,
    String path, {
    required JsonObjectDecoder<T> decode,
    Map<String, String>? queryParameters,
    Object? body,
    CancelToken? cancelToken,
  }) async {
    if (_config case Err(:final failure)) return Err(failure);
    // Only relative paths, so a request can never leave our backend.
    if (!path.startsWith('/') || path.startsWith('//')) {
      return const Err(UnexpectedFailure());
    }
    final scope = _CallScope(policy.totalTimeout, _newStopwatch())
      ..listenTo(cancelToken);
    try {
      final retries = method == 'GET' ? policy.maxRetries : 0;
      for (var attempt = 0; ; attempt++) {
        final outcome = await _attempt(
          method,
          path,
          queryParameters: queryParameters,
          body: body,
          scope: scope,
        );
        final Failure failure;
        Duration? retryAfter;
        switch (outcome) {
          case _Response(:final status, :final text, :final retryAfterHeader):
            if (status >= 200 && status < 300) {
              return _decode(text, decode);
            }
            // Retry-After may be an HTTP date, which needs the wall clock.
            retryAfter = parseRetryAfter(retryAfterHeader, now: clock.now());
            failure = failureForStatus(
              status,
              body: text,
              retryAfter: retryAfter,
            );
          case _Failed(failure: final f):
            failure = f;
        }
        if (attempt >= retries || !isRetryable(failure)) return Err(failure);
        if (retryAfter != null && retryAfter > policy.maxRetryAfter) {
          return Err(failure);
        }
        final wait = retryAfter ?? policy.backoff(attempt + 1, _random);
        if (wait >= scope.remaining) return Err(failure);
        final interrupted = await scope.wait(wait);
        if (interrupted != null) return Err(interrupted);
      }
    } on Object {
      // A last guard: nothing thrown below may reach the caller.
      return const Err(UnexpectedFailure());
    } finally {
      scope.close();
    }
  }

  Result<T> _decode<T>(String? text, JsonObjectDecoder<T> decode) {
    final json = decodeJsonObject(text);
    if (json == null) return const Err(UnexpectedFailure());
    try {
      return Ok(decode(json));
    } on Object {
      // CheckedFromJsonException from api_contract, or a mapping error.
      return const Err(UnexpectedFailure());
    }
  }

  /// One attempt, ended early when the call's deadline passes (timeout) or
  /// the caller cancels.
  Future<_Outcome> _attempt(
    String method,
    String path, {
    required Map<String, String>? queryParameters,
    required Object? body,
    required _CallScope scope,
  }) {
    if (scope.endedWith case final failure?) {
      return Future.value(_Failed(failure));
    }
    if (scope.remaining <= Duration.zero) {
      return Future.value(const _Failed(TimeoutFailure()));
    }
    final result = Completer<_Outcome>();
    final attemptToken = CancelToken();
    scope.onEnd = (failure) {
      if (!result.isCompleted) result.complete(_Failed(failure));
      attemptToken.cancel();
    };
    unawaited(
      _dio
          .request<String>(
            path,
            data: body,
            queryParameters: queryParameters,
            options: Options(method: method),
            cancelToken: attemptToken,
          )
          .then(
            (response) {
              if (result.isCompleted) return;
              result.complete(
                _Response(
                  status: response.statusCode ?? 0,
                  text: response.data,
                  retryAfterHeader: response.headers.value('retry-after'),
                ),
              );
            },
            onError: (Object error) {
              if (!result.isCompleted) {
                result.complete(_Failed(failureForError(error)));
              }
            },
          ),
    );
    return result.future.whenComplete(() => scope.onEnd = null);
  }
}

/// The state of one call: a monotonic stopwatch and one deadline timer for
/// the whole call, and the caller's cancel token. Attempts and waits listen
/// through [onEnd], which is cleared after each one, and [close] detaches
/// the call from the caller's token so nothing outlives the call.
final class _CallScope {
  _CallScope(this._total, this._stopwatch) {
    _stopwatch.start();
    _deadline = Timer(_total, () => _end(const TimeoutFailure()));
  }

  final Duration _total;
  final Stopwatch _stopwatch;
  late final Timer _deadline;
  _TokenLink? _link;

  /// Set once the call ends early: [TimeoutFailure] or [CancelledFailure].
  Failure? endedWith;

  /// Called once if the call ends early while an attempt or wait runs.
  void Function(Failure failure)? onEnd;

  /// Time left before the call's deadline.
  Duration get remaining => _total - _stopwatch.elapsed;

  void listenTo(CancelToken? token) {
    if (token == null) return;
    if (token.isCancelled) {
      _end(const CancelledFailure());
      return;
    }
    final link = _link = _TokenLink(this);
    // A Future listener cannot be removed; the link is cut in [close], so
    // a long-lived token keeps only the empty link, not this call.
    unawaited(
      token.whenCancel.then((_) => link.scope?._end(const CancelledFailure())),
    );
  }

  void _end(Failure failure) {
    if (endedWith != null) return;
    endedWith = failure;
    onEnd?.call(failure);
  }

  /// Waits [duration]. Returns the failure if the call ended meanwhile.
  Future<Failure?> wait(Duration duration) {
    if (endedWith case final failure?) return Future.value(failure);
    final done = Completer<Failure?>();
    final timer = Timer(duration, () {
      if (!done.isCompleted) done.complete(null);
    });
    onEnd = (failure) {
      timer.cancel();
      if (!done.isCompleted) done.complete(failure);
    };
    return done.future.whenComplete(() => onEnd = null);
  }

  void close() {
    _deadline.cancel();
    _stopwatch.stop();
    _link?.scope = null;
    _link = null;
    onEnd = null;
  }
}

final class _TokenLink {
  _TokenLink(this.scope);

  _CallScope? scope;
}

sealed class _Outcome {
  const _Outcome();
}

final class _Response extends _Outcome {
  const _Response({
    required this.status,
    required this.text,
    required this.retryAfterHeader,
  });

  final int status;
  final String? text;
  final String? retryAfterHeader;
}

final class _Failed extends _Outcome {
  const _Failed(this.failure);

  final Failure failure;
}
