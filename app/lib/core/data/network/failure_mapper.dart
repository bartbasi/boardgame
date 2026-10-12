import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:api_contract/api_contract.dart';
import 'package:dio/dio.dart';

import '../../domain/result.dart';

/// Decodes [body] as JSON and returns it only if it is a JSON object.
///
/// Returns null for invalid JSON (for example an HTML error page from a
/// proxy), for JSON that is not an object (`[]`, `"ok"`, `42`, `null`), and
/// for a null body. Never throws (docs/decisions.md 2026-10-12, T-007:
/// callers check that a body is a JSON object before decoding).
Map<String, dynamic>? decodeJsonObject(String? body) {
  if (body == null) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return null;
  }
  return decoded is Map<String, dynamic> ? decoded : null;
}

/// Maps an HTTP status outside 2xx to a [Failure].
///
/// The status decides the failure type. The body is read only for the
/// error code of an [InvalidInputFailure]; a body that is not a valid error
/// envelope gives [InvalidInputCode.unknown].
Failure failureForStatus(int status, {String? body, Duration? retryAfter}) {
  return switch (status) {
    400 || 422 => InvalidInputFailure(_inputCode(body)),
    401 || 403 => const AccessDeniedFailure(),
    404 || 410 => const NotFoundFailure(),
    408 => const TimeoutFailure(),
    429 => RateLimitedFailure(retryAfter: retryAfter),
    502 || 503 || 504 => const ServiceUnavailableFailure(),
    _ => const UnexpectedFailure(),
  };
}

InvalidInputCode _inputCode(String? body) {
  final json = decodeJsonObject(body);
  if (json == null) return InvalidInputCode.unknown;
  final ErrorEnvelope envelope;
  try {
    envelope = ErrorEnvelope.fromJson(json);
  } on Object {
    // CheckedFromJsonException, or anything else a decoder can throw.
    return InvalidInputCode.unknown;
  }
  return switch (envelope.error.code) {
    ErrorCode.invalidBarcode => InvalidInputCode.invalidBarcode,
    ErrorCode.invalidQuery => InvalidInputCode.invalidQuery,
    ErrorCode.invalidBggId => InvalidInputCode.invalidBggId,
    ErrorCode.notFound ||
    ErrorCode.rateLimited ||
    ErrorCode.upstreamUnavailable ||
    ErrorCode.internalError ||
    ErrorCode.unknown => InvalidInputCode.unknown,
  };
}

/// Maps an error raised while sending a request to a [Failure].
///
/// A [DioException.badResponse] is mapped by its status. Anything that is
/// not a [DioException] becomes [UnexpectedFailure].
Failure failureForError(Object error) {
  if (error is! DioException) return const UnexpectedFailure();
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const TimeoutFailure(),
    DioExceptionType.connectionError => const NoConnectionFailure(),
    DioExceptionType.cancel => const CancelledFailure(),
    DioExceptionType.badResponse => switch (error.response) {
      final Response<Object?> response? when response.statusCode != null =>
        failureForStatus(
          response.statusCode!,
          body: response.data is String ? response.data as String : null,
        ),
      _ => const UnexpectedFailure(),
    },
    DioExceptionType.unknown =>
      error.error is SocketException
          ? const NoConnectionFailure()
          : const UnexpectedFailure(),
    DioExceptionType.badCertificate ||
    DioExceptionType.transformTimeout => const UnexpectedFailure(),
  };
}

/// Whether a failure from a GET is worth another attempt.
bool isRetryable(Failure failure) => switch (failure) {
  NoConnectionFailure() ||
  TimeoutFailure() ||
  RateLimitedFailure() ||
  ServiceUnavailableFailure() => true,
  NotFoundFailure() ||
  InvalidInputFailure() ||
  AccessDeniedFailure() ||
  CancelledFailure() ||
  ConfigurationFailure() ||
  UnexpectedFailure() => false,
};
