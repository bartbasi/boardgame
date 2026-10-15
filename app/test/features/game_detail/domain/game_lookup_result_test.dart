// T-029: what the games repository answers for a barcode.
import 'package:board_game_collector/features/game_detail/domain/barcode_lookup.dart';
import 'package:board_game_collector/features/game_detail/domain/game_details.dart';
import 'package:board_game_collector/features/game_detail/domain/game_details_snapshot.dart';
import 'package:board_game_collector/features/game_detail/domain/game_lookup_result.dart';
import 'package:board_game_collector/features/game_detail/domain/game_summary.dart';
import 'package:flutter_test/flutter_test.dart';

const GameSummary _catan = GameSummary(
  bggId: 13,
  name: 'Catan',
  bggUrl: 'https://boardgamegeek.com/boardgame/13',
);

const GameSummary _carcassonne = GameSummary(
  bggId: 822,
  name: 'Carcassonne',
  bggUrl: 'https://boardgamegeek.com/boardgame/822',
);

GameLookupResult _backend(BarcodeLookupStatus status, List<GameSummary> g) =>
    GameLookupResult.fromBackend(
      BarcodeLookup(gtin13: '0036000291452', status: status, games: g),
    );

void main() {
  group('GameLookupResult', () {
    test('a match on the device is a match, with or without a summary', () {
      final bare = GameLookupResult.confirmedOnDevice(
        gtin13: '0036000291452',
        bggId: 13,
        confirmedAt: DateTime.utc(2026, 10, 11),
      );
      expect(bare.barcode, '0036000291452');
      expect(bare.matchedBggId, 13);
      expect((bare as ConfirmedOnDevice).game, isNull);
      expect(
        bare.copyWith(game: _catan),
        GameLookupResult.confirmedOnDevice(
          gtin13: '0036000291452',
          bggId: 13,
          confirmedAt: DateTime.utc(2026, 10, 11),
          game: _catan,
        ),
      );
    });

    test('a backend answer is a match only when matched with one game', () {
      final cases = <GameLookupResult, int?>{
        _backend(BarcodeLookupStatus.matched, [_catan]): 13,
        _backend(BarcodeLookupStatus.matched, [_catan, _carcassonne]): null,
        _backend(BarcodeLookupStatus.matched, []): null,
        _backend(BarcodeLookupStatus.candidates, [_catan, _carcassonne]): null,
        _backend(BarcodeLookupStatus.candidates, [_catan]): null,
        _backend(BarcodeLookupStatus.none, []): null,
        _backend(BarcodeLookupStatus.unavailable, []): null,
        _backend(BarcodeLookupStatus.unknown, [_catan]): null,
        _backend(BarcodeLookupStatus.unknown, []): null,
      };
      for (final MapEntry(key: result, value: bggId) in cases.entries) {
        expect(result.matchedBggId, bggId, reason: '$result');
        expect(result.barcode, '0036000291452');
      }
    });
  });

  group('GameDetailsSnapshot', () {
    final details = GameDetails(
      bggId: 13,
      name: 'Catan',
      designers: const [],
      publishers: const [],
      bggUrl: 'https://boardgamegeek.com/boardgame/13',
      fetchedAt: DateTime.utc(2026, 10, 13),
    );

    test('isStale follows the freshness', () {
      final fresh = GameDetailsSnapshot(
        details: details,
        freshness: DataFreshness.fresh,
        fetchedAt: DateTime.utc(2026, 10, 14),
      );
      expect(fresh.isStale, isFalse);
      expect(fresh.copyWith(freshness: DataFreshness.stale).isStale, isTrue);
    });
  });
}
