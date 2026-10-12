import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';

const _jsonHeaders = {'content-type': 'application/json'};

/// A JSON response with [status] and [body] (already JSON-encodable).
Response jsonResponse(int status, Object body) =>
    Response(status, body: jsonEncode(body), headers: _jsonHeaders);

/// An error response with the api_contract error envelope.
///
/// [message] is fixed, human-readable text written by us. Never pass
/// exception text, stack traces, or upstream response bodies.
///
/// Throws [ArgumentError] for [ErrorCode.unknown]: that value exists only so
/// clients can decode codes added after their release, and the server must
/// never send it. Inside a handler the throw becomes a 500 `internal_error`.
Response errorResponse(int status, ErrorCode code, String message) {
  if (code == ErrorCode.unknown) {
    throw ArgumentError.value(
      code,
      'code',
      'ErrorCode.unknown is client-side only',
    );
  }
  return jsonResponse(
    status,
    ErrorEnvelope(
      error: ApiError(code: code, message: message),
    ).toJson(),
  );
}

/// 404 for a route or resource that does not exist.
Response notFoundResponse() =>
    errorResponse(404, ErrorCode.notFound, 'Not found.');

/// 500 for an unexpected error. Never includes exception details.
Response internalErrorResponse() => errorResponse(
  500,
  ErrorCode.internalError,
  'Something went wrong on our side. Please try again later.',
);
