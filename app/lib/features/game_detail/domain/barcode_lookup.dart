import 'package:freezed_annotation/freezed_annotation.dart';

import 'game_summary.dart';

part 'barcode_lookup.freezed.dart';

/// The outcome of a barcode lookup.
enum BarcodeLookupStatus {
  /// The barcode maps to exactly one game, the only entry in
  /// [BarcodeLookup.games].
  matched,

  /// The barcode may be one of several games; [BarcodeLookup.games] holds
  /// at least one candidate, best first.
  candidates,

  /// No game is known for this barcode; [BarcodeLookup.games] is empty.
  none,

  /// The barcode source failed or timed out; [BarcodeLookup.games] is
  /// empty. Title search still works.
  unavailable,

  /// A status added to the backend after this app version. It may carry
  /// any number of games; treat it as not confirmed, like [candidates] when
  /// there are games and like [none] when there are none.
  unknown,
}

/// The answer to a barcode lookup.
@freezed
abstract class BarcodeLookup with _$BarcodeLookup {
  /// Creates a lookup answer.
  const factory BarcodeLookup({
    /// The barcode as a 13-digit key (`Barcode.gtin13`). Always the code
    /// that was looked up.
    required String gtin13,

    /// The outcome.
    required BarcodeLookupStatus status,

    /// The matched game or the candidates, in the backend's ranking order.
    required List<GameSummary> games,
  }) = _BarcodeLookup;
}
