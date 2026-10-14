import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_details.freezed.dart';

/// Everything the game detail screen shows about one game.
///
/// A value that BGG does not give is null (or an empty list), never 0 or an
/// empty string.
@freezed
abstract class GameDetails with _$GameDetails {
  /// Creates game details.
  const factory GameDetails({
    /// The game's BoardGameGeek id, at least 1.
    required int bggId,

    /// The game's primary name, as BGG lists it.
    required String name,

    /// The year the game was first published, or null when unknown.
    int? yearPublished,

    /// The smallest player count, or null when unknown.
    int? minPlayers,

    /// The largest player count, or null when unknown.
    int? maxPlayers,

    /// The shortest play time in minutes, or null when unknown.
    int? minPlayTimeMinutes,

    /// The longest play time in minutes, or null when unknown.
    int? maxPlayTimeMinutes,

    /// Designer names in BGG's order; empty when BGG lists none.
    required List<String> designers,

    /// Publisher names in BGG's order; empty when BGG lists none.
    required List<String> publishers,

    /// The description as plain text with `\n` line breaks, or null.
    String? description,

    /// The game's BoardGameGeek page, as the backend sent it.
    required String bggUrl,

    /// When the backend fetched this data from BGG, in UTC. Used for the
    /// "Last updated" label and cache freshness.
    required DateTime fetchedAt,
  }) = _GameDetails;
}
