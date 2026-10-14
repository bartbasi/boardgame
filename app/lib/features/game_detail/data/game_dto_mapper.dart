// Maps api_contract DTOs to domain entities. Only the data layer sees the
// DTOs (T-028 AC5); everything above it gets the entities.
import 'package:api_contract/api_contract.dart' as api;

import '../domain/barcode_lookup.dart';
import '../domain/game_details.dart';
import '../domain/game_search_results.dart';
import '../domain/game_summary.dart';

/// Maps a game summary DTO. Null stays null (the contract never sends 0 or
/// an empty string for a missing value).
GameSummary gameSummaryFromDto(api.GameSummary dto) => GameSummary(
  bggId: dto.bggId,
  name: dto.name,
  yearPublished: dto.yearPublished,
  bggUrl: dto.bggUrl,
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
  bggUrl: dto.bggUrl,
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
