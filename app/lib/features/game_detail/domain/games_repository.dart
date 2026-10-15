import '../../../core/domain/result.dart';
import '../../scanner/domain/barcode.dart';
import 'game_details_snapshot.dart';
import 'game_lookup_result.dart';
import 'game_search_results.dart';

/// Game data for the scanner, title search, game detail, and collection
/// features: backend answers plus what this device remembers (T-029).
///
/// Every method returns a [Result] and never throws.
abstract interface class GamesRepository {
  /// Finds the game for [barcode].
  ///
  /// A confirmed match stored on the device answers at once, with no
  /// request. Otherwise the backend is asked; a `matched` answer for this
  /// barcode is stored as the confirmed match, and no other status changes
  /// what is stored. When the stored match could not be read, a `matched`
  /// answer is returned but not stored, so a match the user chose is never
  /// overwritten. A failure of the backend lookup is returned as is.
  Future<Result<GameLookupResult>> lookupBarcode(Barcode barcode);

  /// Stores that [barcode] belongs to [bggId], replacing any earlier match
  /// for it (the user picked a candidate, a search result, or a correction).
  Future<Result<void>> confirmMatch(Barcode barcode, int bggId);

  /// Loads the details of [bggId] and records that the user viewed it.
  ///
  /// A successful load is cached and returned as [DataFreshness.fresh].
  /// When the load fails for any reason and a usable copy is cached, that
  /// copy is returned as [DataFreshness.stale] instead (PRD 8.2); with no
  /// usable copy, the failure is returned.
  Future<Result<GameDetailsSnapshot>> getGame(int bggId);

  /// Searches game titles. Results are never cached on the device, and a
  /// failure is returned unchanged.
  Future<Result<GameSearchResults>> searchGames(String query);
}
