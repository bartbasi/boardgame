import 'package:drift/drift.dart';

import '../../domain/result.dart';
import 'app_database.dart';

/// Cached details of one game, as stored on the device.
final class CachedGameDetails {
  const CachedGameDetails({
    required this.bggId,
    required this.detailsJson,
    required this.fetchedAt,
    required this.lastViewedAt,
  });

  final int bggId;

  /// The backend's game details JSON, exactly as it was saved.
  final String detailsJson;

  /// When the details were fetched (UTC).
  final DateTime fetchedAt;

  /// When the user last opened the game (UTC), or null if never.
  final DateTime? lastViewedAt;
}

/// A barcode confirmed to belong to a game.
final class ConfirmedMatch {
  const ConfirmedMatch({
    required this.gtin13,
    required this.bggId,
    required this.confirmedAt,
  });

  /// The 13-digit key (`Barcode.gtin13`).
  final String gtin13;
  final int bggId;

  /// When the match was confirmed (UTC).
  final DateTime confirmedAt;
}

/// The on-device store of cached game details and confirmed barcode matches
/// (T-027).
///
/// Callers use BGG ids, as in the api_contract; the database's internal game
/// id never leaves this class. Every method returns a [Result] and never
/// throws: database errors become [StorageFailure] (AC6).
///
/// At most [maxCachedDetails] games keep their details [ASSUMPTION: 500].
/// Saving more evicts the details of the least recently viewed games (a game
/// never viewed counts from its fetch time). A game that a confirmed match
/// points to keeps its row and BGG id, so the barcode still resolves; other
/// evicted games are deleted. M3 will exempt games in the collection.
class LocalGameStore {
  LocalGameStore(
    this._db, {
    this.maxCachedDetails = defaultMaxCachedDetails,
    this.log,
  });

  /// The default cap on games with cached details [ASSUMPTION].
  static const int defaultMaxCachedDetails = 500;

  final AppDatabase _db;

  /// How many games may keep cached details.
  final int maxCachedDetails;

  /// Receives one line per failed operation (debug builds only). The line
  /// names the operation and the error type, never stored data.
  final void Function(String message)? log;

  /// Saves the details of [bggId], fetched at [fetchedAt]. Saving the same
  /// game again updates its row in place, so its internal id and any
  /// barcode match pointing to it stay valid (AC8). [viewedAt], when given,
  /// also records a view.
  Future<Result<void>> saveDetails({
    required int bggId,
    required String detailsJson,
    required DateTime fetchedAt,
    DateTime? viewedAt,
  }) => _guard('saveDetails', () {
    return _db.transaction(() async {
      final games = _db.games;
      await games.insertOne(
        GamesCompanion.insert(
          bggId: Value(bggId),
          detailsJson: Value(detailsJson),
          fetchedAt: Value(fetchedAt.toUtc()),
          lastViewedAt: Value(viewedAt?.toUtc()),
        ),
        onConflict: DoUpdate(
          (_) => GamesCompanion(
            detailsJson: Value(detailsJson),
            fetchedAt: Value(fetchedAt.toUtc()),
            lastViewedAt: viewedAt == null
                ? const Value.absent()
                : Value(viewedAt.toUtc()),
          ),
          target: [games.bggId],
        ),
      );
      await _evictDetails();
    });
  });

  /// The cached details of [bggId], or null when none are stored.
  Future<Result<CachedGameDetails?>> readDetails(int bggId) =>
      _guard('readDetails', () async {
        final row = await (_db.select(
          _db.games,
        )..where((g) => g.bggId.equals(bggId))).getSingleOrNull();
        final details = row?.detailsJson;
        final fetchedAt = row?.fetchedAt;
        if (row == null || details == null || fetchedAt == null) return null;
        return CachedGameDetails(
          bggId: bggId,
          detailsJson: details,
          fetchedAt: fetchedAt,
          lastViewedAt: row.lastViewedAt,
        );
      });

  /// Records that the user opened [bggId] at [viewedAt]. Does nothing when
  /// the game is not stored.
  Future<Result<void>> markViewed(int bggId, DateTime viewedAt) =>
      _guard('markViewed', () async {
        await (_db.update(_db.games)..where((g) => g.bggId.equals(bggId)))
            .write(GamesCompanion(lastViewedAt: Value(viewedAt.toUtc())));
      });

  /// Stores that [gtin13] belongs to [bggId], replacing any earlier match
  /// for that code (AC2). The game gets a row without details if it has
  /// none yet.
  Future<Result<void>> saveConfirmedMatch({
    required String gtin13,
    required int bggId,
    required DateTime confirmedAt,
  }) => _guard('saveConfirmedMatch', () {
    return _db.transaction(() async {
      final games = _db.games;
      await games.insertOne(
        GamesCompanion.insert(bggId: Value(bggId)),
        mode: InsertMode.insertOrIgnore,
      );
      final gameId =
          await (_db.selectOnly(games)
                ..addColumns([games.id])
                ..where(games.bggId.equals(bggId)))
              .map((row) => row.read(games.id)!)
              .getSingle();
      await _db.barcodeMatches.insertOnConflictUpdate(
        BarcodeMatchesCompanion.insert(
          gtin13: gtin13,
          gameId: gameId,
          confirmedAt: confirmedAt.toUtc(),
        ),
      );
      await _deleteUnusedGames();
    });
  });

  /// The confirmed match for [gtin13], or null when there is none.
  Future<Result<ConfirmedMatch?>> readConfirmedMatch(String gtin13) =>
      _guard('readConfirmedMatch', () async {
        final matches = _db.barcodeMatches;
        final games = _db.games;
        final row = await (_db.select(matches).join([
          innerJoin(games, games.id.equalsExp(matches.gameId)),
        ])..where(matches.gtin13.equals(gtin13))).getSingleOrNull();
        if (row == null) return null;
        final bggId = row.readTable(games).bggId;
        // A game from a source other than BGG has no BGG id to return.
        if (bggId == null) return null;
        return ConfirmedMatch(
          gtin13: gtin13,
          bggId: bggId,
          confirmedAt: row.readTable(matches).confirmedAt,
        );
      });

  /// Clears the details of the least recently viewed games beyond
  /// [maxCachedDetails], then deletes games nothing points to.
  Future<void> _evictDetails() async {
    final games = _db.games;
    final hasDetails = games.detailsJson.isNotNull();
    final count = countAll(filter: hasDetails);
    final cached = await (_db.selectOnly(
      games,
    )..addColumns([count])).map((row) => row.read(count)!).getSingle();
    final excess = cached - maxCachedDetails;
    if (excess <= 0) return;

    final recency = coalesce<int>([games.lastViewedAt, games.fetchedAt]);
    final oldest = _db.selectOnly(games)
      ..addColumns([games.id])
      ..where(hasDetails)
      ..orderBy([OrderingTerm.asc(recency), OrderingTerm.asc(games.id)])
      ..limit(excess);
    final ids = await oldest.map((row) => row.read(games.id)!).get();

    await (_db.update(games)..where((g) => g.id.isIn(ids))).write(
      const GamesCompanion(detailsJson: Value(null), fetchedAt: Value(null)),
    );
    await _deleteUnusedGames();
  }

  /// Deletes games that have no cached details and no barcode match.
  Future<void> _deleteUnusedGames() async {
    final matches = _db.barcodeMatches;
    await (_db.delete(_db.games)..where(
          (g) =>
              g.detailsJson.isNull() &
              notExistsQuery(
                _db.select(matches)..where((m) => m.gameId.equalsExp(g.id)),
              ),
        ))
        .go();
  }

  /// Runs [body] and turns any error into [StorageFailure], so nothing
  /// thrown by SQLite or drift reaches the caller.
  Future<Result<T>> _guard<T>(
    String operation,
    Future<T> Function() body,
  ) async {
    try {
      return Result.ok(await body());
    } on Object catch (error) {
      // Only the error type: messages can quote stored data.
      log?.call('LocalGameStore.$operation failed: ${error.runtimeType}');
      return Result.err(const StorageFailure());
    }
  }
}
