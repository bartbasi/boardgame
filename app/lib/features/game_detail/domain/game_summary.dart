import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_summary.freezed.dart';

/// One game in a list: a title search result or a barcode lookup candidate.
///
/// Shared by the scanner, game detail, and collection features. A value
/// that BGG does not give is null, never 0 or an empty string.
@freezed
abstract class GameSummary with _$GameSummary {
  /// Creates a game summary.
  const factory GameSummary({
    /// The game's BoardGameGeek id, at least 1.
    required int bggId,

    /// The game's primary name, as BGG lists it.
    required String name,

    /// The year the game was first published, or null when unknown. May
    /// be negative (a year before the common era).
    int? yearPublished,

    /// The game's BoardGameGeek page, as the backend sent it. The app never
    /// builds BGG URLs itself.
    required String bggUrl,
  }) = _GameSummary;
}
