import 'package:clock/clock.dart';

import '../../../core/data/database/game_stores.dart';
import '../../../core/domain/result.dart';
import '../../scanner/domain/barcode.dart';
import '../domain/barcode_lookup.dart';
import '../domain/game_details.dart';
import '../domain/game_details_snapshot.dart';
import '../domain/game_lookup_result.dart';
import '../domain/game_search_results.dart';
import '../domain/game_summary.dart';
import '../domain/games_repository.dart';
import 'game_details_codec.dart';
import 'games_remote_data_source.dart';

/// Whether [failure] of a details load should show the cached copy instead
/// (T-029 AC5).
///
/// Today every failure serves the copy: a game the user viewed that cannot
/// be refreshed shows its cached data with a "Last updated" label rather
/// than an error screen (PRD 8.2; orchestrator decisions in T-029 rounds 2
/// and 3), whether the backend is unreachable, refused the call, answered
/// 404, or broke the contract. The snapshot carries the failure as
/// `refreshFailure`, so the screen can say why. With no usable copy the
/// failure is returned.
///
/// It is kept as an exhaustive switch with no catch-all, although every
/// case is true, so that adding a new [Failure] type breaks the build here
/// and forces a decision about it.
bool servesCachedCopy(Failure failure) => switch (failure) {
  NoConnectionFailure() ||
  TimeoutFailure() ||
  ServiceUnavailableFailure() ||
  RateLimitedFailure() ||
  NotFoundFailure() ||
  InvalidInputFailure() ||
  InvalidBarcodeFailure() ||
  AccessDeniedFailure() ||
  CancelledFailure() ||
  ConfigurationFailure() ||
  StorageFailure() ||
  UnexpectedFailure() => true,
};

/// Whether [lookup] may be stored as the confirmed match for [barcode]
/// (T-029 AC2, AC10): only a `matched` answer with exactly one game for the
/// very code that was looked up. `candidates`, `none`, `unavailable`, and
/// `unknown` never are (docs/decisions.md 2026-10-15, T-028).
bool isStorableMatch(BarcodeLookup lookup, Barcode barcode) =>
    lookup.status == BarcodeLookupStatus.matched &&
    lookup.gtin13 == barcode.gtin13 &&
    lookup.games.length == 1;

/// The games repository (T-029): backend game data through
/// [GamesRemoteDataSource], confirmed barcode matches through
/// [BarcodeMatchStore], and downloaded details through [GameDetailsCache].
///
/// Device storage problems never fail a call that the backend can answer:
/// a cache that cannot be read or written only loses the offline copy.
class GamesRepositoryImpl implements GamesRepository {
  /// Creates the repository. [log] receives one line per problem it
  /// swallows (debug builds only); lines name the operation and an error
  /// type, never stored data.
  GamesRepositoryImpl({
    required this._remote,
    required this._detailsCache,
    required this._matchStore,
    this.log,
  });

  final GamesRemoteDataSource _remote;
  final GameDetailsCache _detailsCache;
  final BarcodeMatchStore _matchStore;

  /// Receives one line per swallowed problem.
  final void Function(String message)? log;

  @override
  Future<Result<GameLookupResult>> lookupBarcode(Barcode barcode) async {
    final stored = await _matchStore.readConfirmedMatch(barcode.gtin13);
    switch (stored) {
      case Ok(value: final match?):
        return Ok(
          GameLookupResult.confirmedOnDevice(
            gtin13: match.gtin13,
            bggId: match.bggId,
            confirmedAt: match.confirmedAt,
            game: await _cachedSummary(match.bggId),
          ),
        );
      case Ok():
        break;
      case Err(:final failure):
        // The backend can still answer; the stored match is only a shortcut.
        _report('readConfirmedMatch', failure);
    }
    // When the read failed, a match may be stored that the user chose
    // (confirmMatch), so a backend match must not overwrite it (T-029
    // review R1-S1): the answer is shown but not saved.
    final mayStore = stored.isOk;

    final remote = await _remote.lookupBarcode(barcode);
    // The data source already refuses an answer for another code (T-028
    // D2); checked again here because a wrong match must never be stored or
    // shown as this barcode's game.
    if (remote case Ok(value: final lookup)
        when lookup.gtin13 != barcode.gtin13) {
      _report('lookupBarcode', const UnexpectedFailure());
      return const Err(UnexpectedFailure());
    }
    if (remote case Ok(value: final lookup)
        when isStorableMatch(lookup, barcode)) {
      if (!mayStore) {
        log?.call(
          'GamesRepository.saveConfirmedMatch skipped: stored match unknown',
        );
        return remote.map(GameLookupResult.fromBackend);
      }
      final saved = await _matchStore.saveConfirmedMatch(
        gtin13: barcode.gtin13,
        bggId: lookup.games.single.bggId,
        confirmedAt: clock.now().toUtc(),
      );
      // The user still gets the match; it is just not remembered.
      if (saved case Err(:final failure)) {
        _report('saveConfirmedMatch', failure);
      }
    }
    return remote.map(GameLookupResult.fromBackend);
  }

  @override
  Future<Result<void>> confirmMatch(Barcode barcode, int bggId) async {
    if (bggId < 1) {
      return const Err(InvalidInputFailure(InvalidInputCode.invalidBggId));
    }
    return _matchStore.saveConfirmedMatch(
      gtin13: barcode.gtin13,
      bggId: bggId,
      confirmedAt: clock.now().toUtc(),
    );
  }

  @override
  Future<Result<GameDetailsSnapshot>> getGame(int bggId) async {
    var remote = await _remote.fetchGame(bggId);
    // Checked again, as in lookupBarcode: details of another game must
    // never be cached under this id (T-028 D2). Like any failed refresh, it
    // then falls back to the cached copy.
    if (remote case Ok(value: final details) when details.bggId != bggId) {
      _report('getGame', const UnexpectedFailure());
      remote = const Err<GameDetails>(UnexpectedFailure());
    }
    switch (remote) {
      case Ok(value: final details):
        final now = clock.now().toUtc();
        await _save(details, now);
        return Ok(
          GameDetailsSnapshot(
            details: details,
            freshness: DataFreshness.fresh,
            fetchedAt: now,
          ),
        );
      case Err(:final failure):
        final copy = servesCachedCopy(failure)
            ? await _cachedSnapshot(bggId, failure)
            : null;
        return copy ?? Err(failure);
    }
  }

  @override
  Future<Result<GameSearchResults>> searchGames(String query) =>
      _remote.searchGames(query);

  /// Caches [details] as fetched and viewed at [now].
  /// Encoding cannot throw: the entity holds only strings, numbers, lists
  /// of strings, and a DateTime, which the contract's toJson writes as is.
  Future<void> _save(GameDetails details, DateTime now) async {
    final saved = await _detailsCache.saveDetails(
      bggId: details.bggId,
      detailsJson: encodeCachedDetails(details),
      fetchedAt: now,
      viewedAt: now,
    );
    if (saved case Err(:final failure)) _report('saveDetails', failure);
  }

  /// The cached copy of [bggId] as a stale snapshot, recording the view,
  /// or null when there is no usable copy.
  Future<Ok<GameDetailsSnapshot>?> _cachedSnapshot(
    int bggId,
    Failure refreshFailure,
  ) async {
    final copy = await _readCached(bggId);
    if (copy == null) return null;
    final (details, fetchedAt) = copy;
    final viewed = await _detailsCache.markViewed(bggId, clock.now().toUtc());
    if (viewed case Err(:final failure)) _report('markViewed', failure);
    return Ok(
      GameDetailsSnapshot(
        details: details,
        freshness: DataFreshness.stale,
        fetchedAt: fetchedAt,
        refreshFailure: refreshFailure,
      ),
    );
  }

  /// The name, year, and link of [bggId] from its cached details, or null.
  Future<GameSummary?> _cachedSummary(int bggId) async {
    final copy = await _readCached(bggId);
    if (copy == null) return null;
    final (details, _) = copy;
    return GameSummary(
      bggId: details.bggId,
      name: details.name,
      yearPublished: details.yearPublished,
      bggUrl: details.bggUrl,
    );
  }

  /// The cached details of [bggId] and when they were fetched, or null when
  /// none are cached, the cache cannot be read, or the copy is unusable
  /// (not valid game detail JSON, or for another game).
  Future<(GameDetails, DateTime)?> _readCached(int bggId) async {
    final read = await _detailsCache.readDetails(bggId);
    switch (read) {
      case Err(:final failure):
        _report('readDetails', failure);
        return null;
      case Ok(value: null):
        return null;
      case Ok(value: final copy?):
        final GameDetails details;
        try {
          details = decodeCachedDetails(copy.detailsJson);
        } on Object catch (error) {
          log?.call(
            'GamesRepository.decodeDetails failed: ${error.runtimeType}',
          );
          return null;
        }
        if (details.bggId != bggId) {
          log?.call('GamesRepository.decodeDetails failed: wrong game');
          return null;
        }
        return (details, copy.fetchedAt);
    }
  }

  void _report(String operation, Failure failure) =>
      log?.call('GamesRepository.$operation failed: ${failure.runtimeType}');
}
