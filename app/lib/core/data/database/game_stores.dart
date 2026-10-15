import '../../domain/result.dart';
import 'local_game_store.dart';

/// The on-device cache of downloaded game details.
///
/// The games repository (T-029) reads and writes details only through this
/// interface, never through [LocalGameStore] directly, so T-102 can move
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
