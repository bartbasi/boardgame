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
typedef JsonDecoder<T> = T Function(Map<String, dynamic> json);

/// The app's only HTTP client. It talks to our backend and nothing else.
///
/// Every method returns a [Result] and never throws: transport errors,
/// error statuses, and bodies that cannot be decoded all become a
/// [Failure]. GET requests are retried following [RetryPolicy]; other
/// methods are sent exactly once.
final class ApiClient {
  /// Creates a client for [config]. When [config] is an [Err], every call
  /// returns its failure and no request is sent.
  ///
  /// [enableLogging] adds a debug log of method, path, status, and time.
  /// Release builds pass false. Bodies and headers are never logged.
  ApiClient({
    required Result<ApiConfig> config,
    required bool enableLogging,
    Dio? dio,
    this.policy = const RetryPolicy(),
    Random? random,
    void Function(String message)? log,
  }) : _config = config,
       _random = random ?? Random(),
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
    required JsonDecoder<T> decode,
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
    required JsonDecoder<T> decode,
    Object? body,
    CancelToken? cancelToken,
  }) =>
      _send('POST', path, decode: decode, body: body, cancelToken: cancelToken);

  Future<Result<T>> _send<T>(
    String method,
    String path, {
    required JsonDecoder<T> decode,
    Map<String, String>? queryParameters,
    Object? body,
    CancelToken? cancelToken,
  }) async {
    if (_config case Err(:final failure)) return Err(failure);
    // Only relative paths, so a request can never leave our backend.
    if (!path.startsWith('/') || path.startsWith('//')) {
      return const Err(UnexpectedFailure());
    }
    try {
      final deadline = clock.now().add(policy.totalTimeout);
      final retries = method == 'GET' ? policy.maxRetries : 0;
      for (var attempt = 0; ; attempt++) {
        final outcome = await _attempt(
          method,
          path,
          queryParameters: queryParameters,
          body: body,
          deadline: deadline,
          cancelToken: cancelToken,
        );
        final Failure failure;
        Duration? retryAfter;
        switch (outcome) {
          case _Response(:final status, :final text, :final retryAfterHeader):
            if (status >= 200 && status < 300) {
              return _decode(text, decode);
            }
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
        if (!clock.now().add(wait).isBefore(deadline)) return Err(failure);
        final cancelled = await _wait(wait, cancelToken);
        if (cancelled) return const Err(CancelledFailure());
      }
    } on Object {
      // A last guard: nothing thrown below may reach the caller.
      return const Err(UnexpectedFailure());
    }
  }

  Result<T> _decode<T>(String? text, JsonDecoder<T> decode) {
    final json = decodeJsonObject(text);
    if (json == null) return const Err(UnexpectedFailure());
    try {
      return Ok(decode(json));
    } on Object {
      // CheckedFromJsonException from api_contract, or a mapping error.
      return const Err(UnexpectedFailure());
    }
  }

  /// One attempt, ended early when [deadline] passes (timeout) or the
  /// caller cancels.
  Future<_Outcome> _attempt(
    String method,
    String path, {
    required Map<String, String>? queryParameters,
    required Object? body,
    required DateTime deadline,
    required CancelToken? cancelToken,
  }) {
    final remaining = deadline.difference(clock.now());
    if (remaining <= Duration.zero) {
      return Future.value(const _Failed(TimeoutFailure()));
    }
    final result = Completer<_Outcome>();
    void finish(_Outcome outcome) {
      if (!result.isCompleted) result.complete(outcome);
    }

    final attemptToken = CancelToken();
    final timer = Timer(remaining, () {
      finish(const _Failed(TimeoutFailure()));
      attemptToken.cancel();
    });
    if (cancelToken != null) {
      if (cancelToken.isCancelled) {
        timer.cancel();
        return Future.value(const _Failed(CancelledFailure()));
      }
      unawaited(
        cancelToken.whenCancel.then((_) {
          finish(const _Failed(CancelledFailure()));
          attemptToken.cancel();
        }),
      );
    }
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
            (response) => finish(
              _Response(
                status: response.statusCode ?? 0,
                text: response.data,
                retryAfterHeader: response.headers.value('retry-after'),
              ),
            ),
            onError: (Object error) => finish(_Failed(failureForError(error))),
          ),
    );
    return result.future.whenComplete(timer.cancel);
  }

  /// Waits [duration]; returns true if the caller cancelled meanwhile.
  Future<bool> _wait(Duration duration, CancelToken? cancelToken) {
    if (cancelToken == null) {
      return Future<bool>.delayed(duration, () => false);
    }
    if (cancelToken.isCancelled) return Future.value(true);
    final done = Completer<bool>();
    final timer = Timer(duration, () {
      if (!done.isCompleted) done.complete(false);
    });
    unawaited(
      cancelToken.whenCancel.then((_) {
        timer.cancel();
        if (!done.isCompleted) done.complete(true);
      }),
    );
    return done.future;
  }
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
