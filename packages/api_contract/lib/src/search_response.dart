import 'package:freezed_annotation/freezed_annotation.dart';

import 'game_summary.dart';

part 'search_response.freezed.dart';
part 'search_response.g.dart';

/// The body of `GET /v1/games/search?q=`.
///
/// No results is a 200 with an empty [games] list, not a 404.
///
/// JSON shape:
///
/// ```json
/// {
///   "query": "catan",
///   "games": [
///     {"bggId": 13, "name": "Catan", "yearPublished": 1995,
///      "bggUrl": "https://boardgamegeek.com/boardgame/13"}
///   ]
/// }
/// ```
@freezed
abstract class SearchResponse with _$SearchResponse {
  /// Creates a search response.
  const factory SearchResponse({
    /// The query as the server normalized it before searching (for example
    /// trimmed). The exact rules belong to the search endpoint (T-023), so
    /// it may differ from the text the client sent.
    required String query,

    /// The results in the server's ranking order: exact name matches first.
    required List<GameSummary> games,
  }) = _SearchResponse;

  /// Decodes a search response.
  ///
  /// Throws [CheckedFromJsonException] if a required field is missing,
  /// null, or of the wrong type, including any invalid game in [games].
  /// Unknown fields are ignored.
  factory SearchResponse.fromJson(Map<String, dynamic> json) =>
      _$SearchResponseFromJson(json);
}
