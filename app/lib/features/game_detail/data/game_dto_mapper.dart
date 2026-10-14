// Maps api_contract DTOs to domain entities. Only the data layer sees the
// DTOs (T-028 AC5); everything above it gets the entities.
import 'package:api_contract/api_contract.dart' as api;

import '../domain/barcode_lookup.dart';
import '../domain/game_details.dart';
import '../domain/game_search_results.dart';
import '../domain/game_summary.dart';

/// The only host a BGG page link may point to (decisions.md 2026-10-14,
/// T-018: `https://boardgamegeek.com/boardgame/{bggId}`, without www).
const String bggHost = 'boardgamegeek.com';

/// Returns [url] if it is an absolute https URL on [bggHost] with no user
/// info and the default port, and throws [FormatException] otherwise (the
/// API client turns that into UnexpectedFailure). The path is not checked:
/// the backend owns the format and may change it without a contract change
/// (api_contract README). The app opens this link outside the app, so it
/// must never point anywhere else (T-028 review R1-S2).
String checkedBggUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !uri.isScheme('https') ||
      uri.host != bggHost ||
      uri.userInfo.isNotEmpty ||
      uri.port != 443) {
    throw const FormatException('bggUrl must be an https link to BGG');
  }
  return url;
}

/// Maps a game summary DTO. Null stays null (the contract never sends 0 or
/// an empty string for a missing value).
GameSummary gameSummaryFromDto(api.GameSummary dto) => GameSummary(
  bggId: dto.bggId,
  name: dto.name,
  yearPublished: dto.yearPublished,
  bggUrl: checkedBggUrl(dto.bggUrl),
);

/// Maps a game detail DTO. `fetchedAt` stays in UTC.
GameDetails gameDetailsFromDto(api.GameDetailResponse dto) => GameDetails(
  bggId: dto.bggId,
  name: dto.name,
  yearPublished: dto.yearPublished,
  minPlayers: dto.minPlayers,
  maxPlayers: dto.maxPlayers,
  minPlayTimeMinutes: dto.minPlayTimeMinutes,
  maxPlayTimeMinutes: dto.maxPlayTimeMinutes,
  designers: dto.designers,
  publishers: dto.publishers,
  description: dto.description,
  bggUrl: checkedBggUrl(dto.bggUrl),
  fetchedAt: dto.fetchedAt.toUtc(),
);

/// Maps a search response DTO.
GameSearchResults searchResultsFromDto(api.SearchResponse dto) =>
    GameSearchResults(
      query: dto.query,
      games: [for (final game in dto.games) gameSummaryFromDto(game)],
    );

/// Maps a lookup response DTO.
BarcodeLookup barcodeLookupFromDto(api.LookupResponse dto) => BarcodeLookup(
  gtin13: dto.code,
  status: lookupStatusFromDto(dto.status),
  games: [for (final game in dto.games) gameSummaryFromDto(game)],
);

/// Maps a lookup status. An exhaustive switch with no catch-all on purpose
/// (docs/decisions.md 2026-10-13): a status added to the contract breaks
/// this build until the app handles it.
BarcodeLookupStatus lookupStatusFromDto(api.LookupStatus status) =>
    switch (status) {
      api.LookupStatus.matched => BarcodeLookupStatus.matched,
      api.LookupStatus.candidates => BarcodeLookupStatus.candidates,
      api.LookupStatus.none => BarcodeLookupStatus.none,
      api.LookupStatus.unavailable => BarcodeLookupStatus.unavailable,
      api.LookupStatus.unknown => BarcodeLookupStatus.unknown,
    };
