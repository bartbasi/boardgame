import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters.dart';

part 'game_summary.freezed.dart';
part 'game_summary.g.dart';

/// One game in a list: a search result or a barcode lookup candidate.
///
/// JSON shape:
///
/// ```json
/// {
///   "bggId": 13,
///   "name": "Catan",
///   "yearPublished": 1995,
///   "bggUrl": "https://boardgamegeek.com/boardgame/13"
/// }
/// ```
///
/// There is no image URL field: no cover images are shown until BGG
/// answers how its images may be used (PRD Q5, BGG-42, docs/decisions.md
/// 2026-10-12). One can be added later as an optional field.
@freezed
abstract class GameSummary with _$GameSummary {
  /// Creates a game summary.
  const factory GameSummary({
    /// The game's BoardGameGeek id, a whole number of at least 1.
    @PositiveIntConverter() required int bggId,

    /// The game's primary name, as BGG lists it.
    required String name,

    /// The year the game was first published, or null when BGG does not
    /// give one. Negative values are allowed, so a year before the common
    /// era can be represented; the server sends null, never 0, for an
    /// unknown year.
    @WholeNumberConverter() int? yearPublished,

    /// The URL of the game's page on BoardGameGeek, built by the server, for
    /// the "Powered by BGG" link (BGG-41). Clients never build BGG URLs.
    required String bggUrl,
  }) = _GameSummary;

  /// Decodes a game summary.
  ///
  /// Throws [CheckedFromJsonException] if a required field is missing,
  /// null, or of the wrong type, or if `bggId` is not a whole number of at
  /// least 1. Unknown fields are ignored.
  factory GameSummary.fromJson(Map<String, dynamic> json) =>
      _$GameSummaryFromJson(json);
}
