import '../../domain/result.dart';

/// The on-device cache of downloaded game details.
///
/// The games repository (T-029) reads and writes details only through this
/// interface, never through `LocalGameStore` directly, so T-102 can move
/// the cache to its own database file by changing what
/// `gameDetailsCacheProvider` returns (docs/decisions.md 2026-10-14, PRD
/// Q39). Everything in it can be downloaded again: a missing copy is never
/// an error.
abstract interface class GameDetailsCache {
  /// Saves the details JSON of [bggId], fetched at [fetchedAt]. [viewedAt],
  /// when given, also records a view.
  Future<Result<void>> saveDetails({
    required int bggId,
    required String detailsJson,
    required DateTime fetchedAt,
    DateTime? viewedAt,
  });

  /// The cached details of [bggId], or null when none are stored.
  Future<Result<CachedGameDetails?>> readDetails(int bggId);

  /// Records that the user opened [bggId] at [viewedAt].
  Future<Result<void>> markViewed(int bggId, DateTime viewedAt);
}

/// The on-device store of confirmed barcode matches. User data: it stays in
/// the main database file when T-102 moves the details cache out.
abstract interface class BarcodeMatchStore {
  /// Stores that [gtin13] belongs to [bggId], replacing any earlier match
  /// for that code.
  Future<Result<void>> saveConfirmedMatch({
    required String gtin13,
    required int bggId,
    required DateTime confirmedAt,
  });

  /// The confirmed match for [gtin13], or null when there is none.
  Future<Result<ConfirmedMatch?>> readConfirmedMatch(String gtin13);
}

/// Cached details of one game, as stored on the device. The value types
/// live here, not in local_game_store.dart, so another store (T-102) does
/// not depend on that file (T-029 R1-G1); local_game_store.dart re-exports
/// them.
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
