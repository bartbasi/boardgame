import 'package:freezed_annotation/freezed_annotation.dart';

import 'barcode_lookup.dart';
import 'game_summary.dart';

part 'game_lookup_result.freezed.dart';

/// What the games repository answers for a barcode (T-029): a match this
/// device already knows, or the backend's answer.
@freezed
sealed class GameLookupResult with _$GameLookupResult {
  const GameLookupResult._();

  /// The barcode has a confirmed match on this device, so no request was
  /// sent (T-029 AC1). This is a match: open the game's detail.
  const factory GameLookupResult.confirmedOnDevice({
    /// The barcode as a 13-digit key (`Barcode.gtin13`).
    required String gtin13,

    /// The game the barcode was confirmed to belong to.
    required int bggId,

    /// When the match was confirmed (UTC).
    required DateTime confirmedAt,

    /// The game's name, year, and BGG link from the details cached on the
    /// device, or null when no details are cached (for example after the
    /// cache dropped them). The bggId is enough to open the detail.
    GameSummary? game,
  }) = ConfirmedOnDevice;

  /// The backend's answer, for a barcode with no confirmed match on this
  /// device. A `matched` answer has been stored as the confirmed match.
  const factory GameLookupResult.fromBackend(BarcodeLookup lookup) =
      FromBackend;

  /// The barcode as a 13-digit key.
  String get barcode => switch (this) {
    ConfirmedOnDevice(:final gtin13) => gtin13,
    FromBackend(:final lookup) => lookup.gtin13,
  };

  /// The game this barcode belongs to when it is a match (stored on the
  /// device, or `matched` by the backend), or null when the user still has
  /// to choose (`candidates`, `unknown`) or nothing was found (`none`,
  /// `unavailable`).
  int? get matchedBggId => switch (this) {
    ConfirmedOnDevice(:final bggId) => bggId,
    FromBackend(:final lookup)
        when lookup.status == BarcodeLookupStatus.matched &&
            lookup.games.length == 1 =>
      lookup.games.single.bggId,
    FromBackend() => null,
  };
}
