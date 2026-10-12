import 'package:json_annotation/json_annotation.dart';

part 'error_code.g.dart';

/// Machine-readable error codes returned by the backend in [ApiError.code].
///
/// On the wire each value is snake_case, for example `invalid_barcode`.
/// A code this version of the contract does not know decodes to [unknown],
/// so the server can add codes within /v1 without breaking older apps.
@JsonEnum(fieldRename: FieldRename.snake, alwaysCreate: true)
enum ErrorCode {
  /// The barcode is not a valid UPC-A, EAN-13, or EAN-8 code.
  invalidBarcode,

  /// The search query is empty, too short, or too long.
  invalidQuery,

  /// The BGG id is not a positive integer.
  invalidBggId,

  /// The route or the requested resource does not exist.
  notFound,

  /// The caller sent too many requests; see the Retry-After header.
  rateLimited,

  /// An upstream service (BGG, eBay, GameUPC) failed or timed out.
  upstreamUnavailable,

  /// An unexpected server error. The body never contains exception details.
  internalError,

  /// Any code this version of the contract does not recognize.
  unknown;

  /// The value used on the wire, for example `invalid_barcode`.
  String get wireName => _$ErrorCodeEnumMap[this]!;
}
