import 'package:freezed_annotation/freezed_annotation.dart';

import 'game_summary.dart';

part 'game_search_results.freezed.dart';

/// The answer to a title search. No results is an empty [games] list, not a
/// failure.
@freezed
abstract class GameSearchResults with _$GameSearchResults {
  /// Creates search results.
  const factory GameSearchResults({
    /// The query as the backend normalized it (for example trimmed), which
    /// may differ from the text the user typed.
    required String query,

    /// The results in the backend's ranking order, exact name matches first.
    required List<GameSummary> games,
  }) = _GameSearchResults;
}
