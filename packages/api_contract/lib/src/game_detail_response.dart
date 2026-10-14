import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters.dart';

part 'game_detail_response.freezed.dart';
part 'game_detail_response.g.dart';

/// The body of `GET /v1/games/{bggId}`: what the game detail screen shows.
///
/// Every field BGG may leave out is nullable (or an empty list), and the
/// server sends null rather than 0 or an empty string for a missing value.
///
/// JSON shape:
///
/// ```json
/// {
///   "bggId": 13,
///   "name": "Catan",
///   "yearPublished": 1995,
///   "minPlayers": 3,
///   "maxPlayers": 4,
///   "minPlayTimeMinutes": 60,
///   "maxPlayTimeMinutes": 120,
///   "designers": ["Klaus Teuber"],
///   "publishers": ["KOSMOS"],
///   "description": "Plain text.\nSecond paragraph.",
///   "bggUrl": "https://boardgamegeek.com/boardgame/13",
///   "fetchedAt": "2026-10-13T08:15:30.000Z"
/// }
/// ```
@freezed
abstract class GameDetailResponse with _$GameDetailResponse {
  /// Creates a game detail response.
  const factory GameDetailResponse({
    /// The game's BoardGameGeek id, a whole number of at least 1.
    @PositiveIntConverter() required int bggId,

    /// The game's primary name, as BGG lists it.
    required String name,

    /// The year the game was first published, or null. Negative values are
    /// allowed; the server sends null, never 0, for an unknown year.
    @WholeNumberConverter() int? yearPublished,

    /// The smallest player count, at least 1, or null.
    @PositiveIntConverter() int? minPlayers,

    /// The largest player count, at least 1, or null.
    @PositiveIntConverter() int? maxPlayers,

    /// The shortest play time in minutes, at least 1, or null.
    @PositiveIntConverter() int? minPlayTimeMinutes,

    /// The longest play time in minutes, at least 1, or null.
    @PositiveIntConverter() int? maxPlayTimeMinutes,

    /// Designer names in BGG's order. Empty when BGG lists none; a missing
    /// or null value decodes as empty.
    @Default(<String>[]) List<String> designers,

    /// Publisher names in BGG's order. Empty when BGG lists none; a missing
    /// or null value decodes as empty.
    @Default(<String>[]) List<String> publishers,

    /// The description as plain text: line breaks are `\n`, and it holds
    /// no HTML markup or character entities (the server decodes them).
    /// Null when BGG gives no description.
    String? description,

    /// The URL of the game's page on BoardGameGeek, built by the server, for
    /// the "Powered by BGG" link (BGG-41). Clients never build BGG URLs.
    required String bggUrl,

    /// When the server fetched this data from BGG, in UTC. A cached answer
    /// keeps its original time.
    @UtcDateTimeConverter() required DateTime fetchedAt,
  }) = _GameDetailResponse;

  /// Decodes a game detail response.
  ///
  /// Throws [CheckedFromJsonException] if a required field is missing,
  /// null, or of the wrong type; if `bggId`, a player count, or a play time
  /// is not a whole number of at least 1; or if `fetchedAt` is not an
  /// ISO 8601 timestamp in UTC. Unknown fields are ignored.
  factory GameDetailResponse.fromJson(Map<String, dynamic> json) =>
      _$GameDetailResponseFromJson(json);
}
