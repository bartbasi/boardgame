import 'package:freezed_annotation/freezed_annotation.dart';

part 'health_response.freezed.dart';
part 'health_response.g.dart';

/// The body of GET /health.
///
/// JSON shape:
///
/// ```json
/// {"status": "ok", "version": "0.1.0+abc1234"}
/// ```
@freezed
abstract class HealthResponse with _$HealthResponse {
  /// Creates a health response.
  const factory HealthResponse({
    /// Overall status, for example `ok`.
    required String status,

    /// The server build version.
    required String version,
  }) = _HealthResponse;

  /// Decodes a health response.
  ///
  /// Throws [CheckedFromJsonException] if a required field is missing,
  /// null, or of the wrong type. Unknown fields are ignored.
  factory HealthResponse.fromJson(Map<String, dynamic> json) =>
      _$HealthResponseFromJson(json);
}
