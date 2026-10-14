import 'package:api_contract/api_contract.dart' as api;
import 'package:dio/dio.dart' show CancelToken;

import '../../../core/data/network/api_client.dart';
import '../../../core/domain/result.dart';
import '../../scanner/domain/barcode.dart';
import '../domain/barcode_lookup.dart';
import '../domain/game_details.dart';
import '../domain/game_search_results.dart';
import 'game_dto_mapper.dart';

/// The backend's game endpoints: barcode lookup, title search, and game
/// details (T-028). The one remote source of game data, shared by the
/// scanner, game detail, and collection features.
///
/// Every method returns a [Result] and never throws. Transport errors,
/// error statuses, and bodies that break the contract become a [Failure]
/// in [ApiClient]; this class adds the paths and the DTO to entity mapping.
class GamesRemoteDataSource {
  /// Creates a data source that sends requests through [client].
  const GamesRemoteDataSource(this._client);

  final ApiClient _client;

  /// Looks up [barcode] with `GET /v1/lookup/barcode/{gtin13}`.
  ///
  /// The code is always sent in its 13-digit form. An answer for a
  /// different code than the one asked for breaks the contract and gives
  /// [UnexpectedFailure], so a wrong match is never stored.
  Future<Result<BarcodeLookup>> lookupBarcode(
    Barcode barcode, {
    CancelToken? cancelToken,
  }) async {
    final result = await _client.get(
      '/v1/lookup/barcode/${barcode.gtin13}',
      decode: (json) => barcodeLookupFromDto(api.LookupResponse.fromJson(json)),
      cancelToken: cancelToken,
    );
    return result.flatMap(
      (lookup) => lookup.gtin13 == barcode.gtin13
          ? Ok(lookup)
          : const Err(UnexpectedFailure()),
    );
  }

  /// Searches titles with `GET /v1/games/search?q=`.
  ///
  /// [query] is sent exactly as given (URL encoded); the backend trims and
  /// validates it, and answers an unusable query with
  /// [InvalidInputCode.invalidQuery].
  Future<Result<GameSearchResults>> searchGames(
    String query, {
    CancelToken? cancelToken,
  }) => _client.get(
    '/v1/games/search',
    queryParameters: {'q': query},
    decode: (json) => searchResultsFromDto(api.SearchResponse.fromJson(json)),
    cancelToken: cancelToken,
  );

  /// Loads one game with `GET /v1/games/{bggId}`.
  ///
  /// A [bggId] below 1 gives [InvalidInputCode.invalidBggId] without a
  /// request, as the backend would. Details for a different game than the
  /// one asked for give [UnexpectedFailure].
  Future<Result<GameDetails>> fetchGame(
    int bggId, {
    CancelToken? cancelToken,
  }) async {
    if (bggId < 1) {
      return const Err(InvalidInputFailure(InvalidInputCode.invalidBggId));
    }
    final result = await _client.get(
      '/v1/games/$bggId',
      decode: (json) =>
          gameDetailsFromDto(api.GameDetailResponse.fromJson(json)),
      cancelToken: cancelToken,
    );
    return result.flatMap(
      (details) =>
          details.bggId == bggId ? Ok(details) : const Err(UnexpectedFailure()),
    );
  }
}
