// How game details are written to and read from the device cache (T-029).
// The cache holds the backend's game detail JSON (api_contract
// GameDetailResponse), so a cached copy is checked by the same decoder and
// mapper as a fresh one.
import 'dart:convert';

import 'package:api_contract/api_contract.dart' as api;

import '../domain/game_details.dart';
import 'game_dto_mapper.dart';

/// Encodes [details] as the backend's game detail JSON.
String encodeCachedDetails(GameDetails details) => jsonEncode(
  api.GameDetailResponse(
    bggId: details.bggId,
    name: details.name,
    yearPublished: details.yearPublished,
    minPlayers: details.minPlayers,
    maxPlayers: details.maxPlayers,
    minPlayTimeMinutes: details.minPlayTimeMinutes,
    maxPlayTimeMinutes: details.maxPlayTimeMinutes,
    designers: details.designers,
    publishers: details.publishers,
    description: details.description,
    bggUrl: details.bggUrl,
    fetchedAt: details.fetchedAt,
  ).toJson(),
);

/// Decodes cached details JSON. Throws (for example [FormatException] or
/// a json_serializable `CheckedFromJsonException`) when the text is not
/// valid game detail JSON or breaks the contract's rules, such as a BGG link
/// to another host; callers treat that as no cached copy.
GameDetails decodeCachedDetails(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('cached details are not a JSON object');
  }
  return gameDetailsFromDto(api.GameDetailResponse.fromJson(decoded));
}
