import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/domain/failure.dart';
import 'game_details.dart';

part 'game_details_snapshot.freezed.dart';

/// Whether game data was just loaded from the backend or comes from the
/// device's cache because the backend could not be reached.
enum DataFreshness {
  /// Loaded from the backend just now.
  fresh,

  /// The cached copy, shown because loading failed (offline, timeout, or
  /// the service is down). Screens show a "Last updated" label for it.
  stale,
}

/// Game details as the games repository returns them (T-029): the details,
/// whether they are fresh, and when this device fetched them.
@freezed
abstract class GameDetailsSnapshot with _$GameDetailsSnapshot {
  const GameDetailsSnapshot._();

  /// Creates a snapshot.
  const factory GameDetailsSnapshot({
    /// The game's details.
    required GameDetails details,

    /// Fresh from the backend, or the stale cached copy.
    required DataFreshness freshness,

    /// When this device received the details from the backend (UTC): now
    /// for a fresh load, the time it was cached for a stale copy. The
    /// backend's own fetch time from BGG is [GameDetails.fetchedAt].
    required DateTime fetchedAt,

    /// Why the refresh failed when this is the stale cached copy, so the
    /// screen can say the right thing (offline, the service is down, or
    /// BoardGameGeek no longer lists the game for [NotFoundFailure]); null
    /// for a fresh load (T-029 review R2-S1).
    Failure? refreshFailure,
  }) = _GameDetailsSnapshot;

  /// True for the cached copy shown when loading failed.
  bool get isStale => freshness == DataFreshness.stale;
}
