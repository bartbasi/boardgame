import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters.dart';
import 'game_summary.dart';

part 'lookup_response.freezed.dart';
part 'lookup_response.g.dart';

/// The outcome of a barcode lookup, in [LookupResponse.status].
///
/// On the wire each value is snake_case. A status this version of the
/// contract does not know decodes to [unknown], so the server can add one
/// within /v1 without breaking older apps.
@JsonEnum(fieldRename: FieldRename.snake, alwaysCreate: true)
enum LookupStatus {
  /// The barcode maps to exactly one game; `games` holds that game.
  matched,

  /// The barcode may be one of several games; `games` holds at least one
  /// candidate, in the server's ranking order.
  candidates,

  /// The barcode source knows no game for this code; `games` is empty.
  none,

  /// The barcode source failed or timed out; `games` is empty. The answer
  /// is still a 200, so the app can offer title search.
  unavailable,

  /// Any status this version of the contract does not recognize. The server
  /// never sends it.
  unknown;

  /// The value used on the wire, for example `matched`.
  String get wireName => _$LookupStatusEnumMap[this]!;
}

/// The body of `GET /v1/lookup/barcode/{code}`.
///
/// JSON shape:
///
/// ```json
/// {
///   "code": "0036000291452",
///   "status": "matched",
///   "games": [
///     {"bggId": 13, "name": "Catan", "yearPublished": 1995,
///      "thumbnailUrl": null, "bggUrl": "https://boardgamegeek.com/boardgame/13"}
///   ]
/// }
/// ```
@freezed
abstract class LookupResponse with _$LookupResponse {
  /// Creates a lookup response.
  const factory LookupResponse({
    /// The barcode as the server normalized it: a GTIN-13 string of 13
    /// digits (a 12-digit UPC-A gets a leading zero).
    @Gtin13Converter() required String code,

    /// The outcome. An unrecognized value becomes [LookupStatus.unknown].
    @JsonKey(unknownEnumValue: LookupStatus.unknown)
    required LookupStatus status,

    /// The matched game or the candidates; see [LookupStatus] for how many
    /// each status carries.
    required List<GameSummary> games,
  }) = _LookupResponse;

  /// Decodes a lookup response.
  ///
  /// Throws [CheckedFromJsonException] if a required field is missing,
  /// null, or of the wrong type; if `code` is not 13 digits; or if the
  /// number of games does not fit the status: exactly one for `matched`,
  /// at least one for `candidates`, none for `none` and `unavailable`. An
  /// unknown status accepts any number. Unknown fields are ignored.
  factory LookupResponse.fromJson(Map<String, dynamic> json) =>
      _checkGames(json, _$LookupResponseFromJson(json));
}

/// Returns [response] if its number of games fits its status, and throws
/// [CheckedFromJsonException] with key `games` otherwise.
LookupResponse _checkGames(Map<String, dynamic> json, LookupResponse response) {
  final count = response.games.length;
  final String? problem = switch (response.status) {
    LookupStatus.matched when count != 1 =>
      'status matched needs exactly one game, got $count',
    LookupStatus.candidates when count == 0 =>
      'status candidates needs at least one game',
    LookupStatus.none || LookupStatus.unavailable when count != 0 =>
      'status ${response.status.wireName} needs an empty games list, '
          'got $count',
    _ => null,
  };
  if (problem == null) return response;
  throw CheckedFromJsonException(json, 'games', 'LookupResponse', problem);
}
