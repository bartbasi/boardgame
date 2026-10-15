// Fakes for the games repository's collaborators (T-029): a remote data
// source that records calls and answers from queued results, a store spy
// that records which store methods ran, and entity fixtures read from the
// recorded api_contract JSON.
import 'dart:convert';

import 'package:api_contract/api_contract.dart' as api;
import 'package:board_game_collector/core/data/database/game_stores.dart';
import 'package:board_game_collector/core/data/database/local_game_store.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:board_game_collector/features/game_detail/data/game_dto_mapper.dart';
import 'package:board_game_collector/features/game_detail/data/games_remote_data_source.dart';
import 'package:board_game_collector/features/game_detail/domain/barcode_lookup.dart';
import 'package:board_game_collector/features/game_detail/domain/game_details.dart';
import 'package:board_game_collector/features/game_detail/domain/game_search_results.dart';
import 'package:board_game_collector/features/scanner/domain/barcode.dart';
import 'package:dio/dio.dart' show CancelToken;

import 'fake_http.dart';

Map<String, dynamic> _json(String fixture) =>
    jsonDecode(contractFixture(fixture)) as Map<String, dynamic>;

/// A lookup answer from an api_contract fixture, for example
/// `lookup/matched.json`.
BarcodeLookup lookupFixture(String fixture) =>
    barcodeLookupFromDto(api.LookupResponse.fromJson(_json(fixture)));

/// Game details from an api_contract fixture, for example
/// `game_detail/full.json` (Catan, bggId 13).
GameDetails detailsFixture(String fixture) =>
    gameDetailsFromDto(api.GameDetailResponse.fromJson(_json(fixture)));

/// Search results from an api_contract fixture, for example
/// `search/results.json`.
GameSearchResults searchFixture(String fixture) =>
    searchResultsFromDto(api.SearchResponse.fromJson(_json(fixture)));

/// A valid barcode; fails the test for an invalid one.
Barcode barcodeOf(String code) => Barcode.parse(code).valueOrNull!;

/// A remote data source that records every call and answers with the
/// result set for that endpoint. It sends no HTTP requests.
class FakeGamesRemote implements GamesRemoteDataSource {
  /// The answer to every lookup.
  Result<BarcodeLookup> lookupResult = const Err(UnexpectedFailure());

  /// The answer to every details load.
  Result<GameDetails> fetchResult = const Err(UnexpectedFailure());

  /// The answer to every search.
  Result<GameSearchResults> searchResult = const Err(UnexpectedFailure());

  /// The barcodes looked up, in order.
  final List<Barcode> lookups = [];

  /// The game ids loaded, in order.
  final List<int> fetches = [];

  /// The search queries, in order.
  final List<String> searches = [];

  /// Every call to any endpoint.
  int get calls => lookups.length + fetches.length + searches.length;

  @override
  Future<Result<BarcodeLookup>> lookupBarcode(
    Barcode barcode, {
    CancelToken? cancelToken,
  }) async {
    lookups.add(barcode);
    return lookupResult;
  }

  @override
  Future<Result<GameDetails>> fetchGame(
    int bggId, {
    CancelToken? cancelToken,
  }) async {
    fetches.add(bggId);
    return fetchResult;
  }

  @override
  Future<Result<GameSearchResults>> searchGames(
    String query, {
    CancelToken? cancelToken,
  }) async {
    searches.add(query);
    return searchResult;
  }
}

/// Wraps a store and records the name of every method called on it.
class StoreSpy implements GameDetailsCache, BarcodeMatchStore {
  StoreSpy(this._store);

  final LocalGameStore _store;

  /// The names of the methods called, in order.
  final List<String> calls = [];

  /// When true, the next [readConfirmedMatch] fails with [StorageFailure]
  /// (and resets this flag) without touching the store.
  bool failNextMatchRead = false;

  /// When true, every [saveConfirmedMatch] fails with [StorageFailure]
  /// without touching the store.
  bool failMatchSaves = false;

  @override
  Future<Result<void>> saveDetails({
    required int bggId,
    required String detailsJson,
    required DateTime fetchedAt,
    DateTime? viewedAt,
  }) {
    calls.add('saveDetails');
    return _store.saveDetails(
      bggId: bggId,
      detailsJson: detailsJson,
      fetchedAt: fetchedAt,
      viewedAt: viewedAt,
    );
  }

  @override
  Future<Result<CachedGameDetails?>> readDetails(int bggId) {
    calls.add('readDetails');
    return _store.readDetails(bggId);
  }

  @override
  Future<Result<void>> markViewed(int bggId, DateTime viewedAt) {
    calls.add('markViewed');
    return _store.markViewed(bggId, viewedAt);
  }

  @override
  Future<Result<void>> saveConfirmedMatch({
    required String gtin13,
    required int bggId,
    required DateTime confirmedAt,
  }) {
    calls.add('saveConfirmedMatch');
    if (failMatchSaves) return Future.value(const Err(StorageFailure()));
    return _store.saveConfirmedMatch(
      gtin13: gtin13,
      bggId: bggId,
      confirmedAt: confirmedAt,
    );
  }

  @override
  Future<Result<ConfirmedMatch?>> readConfirmedMatch(String gtin13) {
    calls.add('readConfirmedMatch');
    if (failNextMatchRead) {
      failNextMatchRead = false;
      return Future.value(const Err(StorageFailure()));
    }
    return _store.readConfirmedMatch(gtin13);
  }
}
