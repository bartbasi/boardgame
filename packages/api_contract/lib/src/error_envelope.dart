import 'package:freezed_annotation/freezed_annotation.dart';

import 'error_code.dart';

part 'error_envelope.freezed.dart';
part 'error_envelope.g.dart';

/// The body of every error response from the backend.
///
/// JSON shape:
///
/// ```json
/// {"error": {"code": "invalid_barcode", "message": "Barcode check digit is wrong."}}
/// ```
@freezed
abstract class ErrorEnvelope with _$ErrorEnvelope {
  /// Creates an error envelope around [error].
  const factory ErrorEnvelope({required ApiError error}) = _ErrorEnvelope;

  /// Decodes an error envelope.
  ///
  /// Throws [CheckedFromJsonException] if a required field is missing,
  /// null, or of the wrong type. Unknown fields are ignored.
  factory ErrorEnvelope.fromJson(Map<String, dynamic> json) =>
      _$ErrorEnvelopeFromJson(json);
}

/// One error: a machine-readable [code] and a human-readable [message].
@freezed
abstract class ApiError with _$ApiError {
  /// Creates an error with [code] and [message].
  const factory ApiError({
    @JsonKey(unknownEnumValue: ErrorCode.unknown) required ErrorCode code,
    required String message,
  }) = _ApiError;

  /// Decodes an error.
  ///
  /// Throws [CheckedFromJsonException] if a required field is missing,
  /// null, or of the wrong type. An unrecognized code becomes
  /// [ErrorCode.unknown].
  factory ApiError.fromJson(Map<String, dynamic> json) =>
      _$ApiErrorFromJson(json);
}
