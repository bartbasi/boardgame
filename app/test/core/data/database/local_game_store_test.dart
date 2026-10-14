import 'package:board_game_collector/core/data/database/app_database.dart';
import 'package:board_game_collector/core/data/database/local_game_store.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

final DateTime _t0 = DateTime.utc(2026, 10, 13, 12);

DateTime _at(int minutes) => _t0.add(Duration(minutes: minutes));

String _json(int bggId) => '{"bggId":$bggId,"name":"Game $bggId"}';

/// The value of an [Ok], failing the test on an [Err].
T _ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected Ok, got $failure'),
};

void main() {
  late AppDatabase db;
  late LocalGameStore store;

  setUp(() {
    db = inMemoryDatabase();
    store = LocalGameStore(db);
  });
  tearDown(() => db.close());

  Future<int> gameCount() async => (await db.select(db.games).get()).length;

  Future<int?> internalId(int bggId) async => (await (db.select(
    db.games,
  )..where((g) => g.bggId.equals(bggId))).getSingleOrNull())?.id;

  group('confirmed matches', () {
    test('a saved match reads back with its BGG id and time', () async {
      _ok(
        await store.saveConfirmedMatch(
          gtin13: '0036000291452',
          bggId: 13,
          confirmedAt: _at(0),
        ),
      );
      final match = _ok(await store.readConfirmedMatch('0036000291452'));
      expect(match, isNotNull);
      expect(match!.gtin13, '0036000291452');
      expect(match.bggId, 13);
      expect(match.confirmedAt, _at(0));
      expect(match.confirmedAt.isUtc, isTrue);
    });

    test('an unknown code reads as null', () async {
      expect(_ok(await store.readConfirmedMatch('0036000291452')), isNull);
    });

    test('a new match for the same code replaces the old one (AC2)', () async {
      _ok(
        await store.saveConfirmedMatch(
          gtin13: '0036000291452',
          bggId: 13,
          confirmedAt: _at(0),
        ),
      );
      _ok(
        await store.saveConfirmedMatch(
          gtin13: '0036000291452',
          bggId: 822,
          confirmedAt: _at(5),
        ),
      );
      final match = _ok(await store.readConfirmedMatch('0036000291452'));
      expect(match!.bggId, 822);
      expect(match.confirmedAt, _at(5));
      expect(await db.select(db.barcodeMatches).get(), hasLength(1));
      // Game 13 had no details and nothing points to it any more.
      expect(await internalId(13), isNull);
    });

    test('replacing a match keeps the old game when it has details', () async {
      _ok(
        await store.saveDetails(
          bggId: 13,
          detailsJson: _json(13),
          fetchedAt: _t0,
        ),
      );
      _ok(
        await store.saveConfirmedMatch(
          gtin13: '0036000291452',
          bggId: 13,
          confirmedAt: _at(0),
        ),
      );
      _ok(
        await store.saveConfirmedMatch(
          gtin13: '0036000291452',
          bggId: 822,
          confirmedAt: _at(1),
        ),
      );
      expect(_ok(await store.readDetails(13))!.detailsJson, _json(13));
    });

    test('a match to a game with cached details reuses its row', () async {
      _ok(
        await store.saveDetails(
          bggId: 13,
          detailsJson: _json(13),
          fetchedAt: _t0,
        ),
      );
      final id = await internalId(13);
      _ok(
        await store.saveConfirmedMatch(
          gtin13: '0036000291452',
          bggId: 13,
          confirmedAt: _at(1),
        ),
      );
      expect(await internalId(13), id);
      expect(await gameCount(), 1);
      final row = await db.select(db.barcodeMatches).getSingle();
      expect(row.gameId, id);
    });

    test('two codes can point to the same game', () async {
      for (final code in ['0036000291452', '4006381333931']) {
        _ok(
          await store.saveConfirmedMatch(
            gtin13: code,
            bggId: 13,
            confirmedAt: _at(0),
          ),
        );
      }
      expect(await gameCount(), 1);
      expect(_ok(await store.readConfirmedMatch('4006381333931'))!.bggId, 13);
    });

    test('a match to a game without a BGG id reads as null', () async {
      final gameId = await db.into(db.games).insert(GamesCompanion.insert());
      await db
          .into(db.barcodeMatches)
          .insert(
            BarcodeMatchesCompanion.insert(
              gtin13: '0036000291452',
              gameId: gameId,
              confirmedAt: _t0,
            ),
          );
      expect(_ok(await store.readConfirmedMatch('0036000291452')), isNull);
    });

    test('times in another zone are stored as the same instant', () async {
      final local = DateTime(2026, 10, 13, 8);
      _ok(
        await store.saveConfirmedMatch(
          gtin13: '0036000291452',
          bggId: 13,
          confirmedAt: local,
        ),
      );
      final match = _ok(await store.readConfirmedMatch('0036000291452'));
      expect(match!.confirmedAt, local.toUtc());
    });
  });

  group('cached details', () {
    test('saved details read back', () async {
      _ok(
        await store.saveDetails(
          bggId: 13,
          detailsJson: _json(13),
          fetchedAt: _at(0),
          viewedAt: _at(1),
        ),
      );
      final cached = _ok(await store.readDetails(13))!;
      expect(cached.bggId, 13);
      expect(cached.detailsJson, _json(13));
      expect(cached.fetchedAt, _at(0));
      expect(cached.lastViewedAt, _at(1));
    });

    test('an unknown game reads as null', () async {
      expect(_ok(await store.readDetails(13)), isNull);
    });

    test('a game known only from a barcode match has no details', () async {
      _ok(
        await store.saveConfirmedMatch(
          gtin13: '0036000291452',
          bggId: 13,
          confirmedAt: _at(0),
        ),
      );
      expect(_ok(await store.readDetails(13)), isNull);
    });

    test('saving twice keeps one row and its internal id (AC8)', () async {
      _ok(
        await store.saveDetails(
          bggId: 13,
          detailsJson: _json(13),
          fetchedAt: _t0,
        ),
      );
      final id = await internalId(13);
      _ok(
        await store.saveConfirmedMatch(
          gtin13: '0036000291452',
          bggId: 13,
          confirmedAt: _at(1),
        ),
      );
      _ok(
        await store.saveDetails(
          bggId: 13,
          detailsJson: '{"bggId":13,"name":"Catan"}',
          fetchedAt: _at(2),
        ),
      );

      expect(await gameCount(), 1);
      expect(await internalId(13), id);
      expect(
        _ok(await store.readDetails(13))!.detailsJson,
        '{"bggId":13,"name":"Catan"}',
      );
      expect(_ok(await store.readConfirmedMatch('0036000291452'))!.bggId, 13);
    });

    test('saving again without a view keeps the last view time', () async {
      _ok(
        await store.saveDetails(
          bggId: 13,
          detailsJson: _json(13),
          fetchedAt: _at(0),
          viewedAt: _at(1),
        ),
      );
      _ok(
        await store.saveDetails(
          bggId: 13,
          detailsJson: _json(13),
          fetchedAt: _at(2),
        ),
      );
      final cached = _ok(await store.readDetails(13))!;
      expect(cached.fetchedAt, _at(2));
      expect(cached.lastViewedAt, _at(1));
    });

    test('markViewed records the view time', () async {
      _ok(
        await store.saveDetails(
          bggId: 13,
          detailsJson: _json(13),
          fetchedAt: _t0,
        ),
      );
      _ok(await store.markViewed(13, _at(9)));
      expect(_ok(await store.readDetails(13))!.lastViewedAt, _at(9));
    });

    test('markViewed on an unknown game changes nothing', () async {
      _ok(await store.markViewed(13, _at(9)));
      expect(await gameCount(), 0);
    });
  });

  group('eviction (AC3)', () {
    /// Saves games 1..[count], each fetched and viewed one minute after the
    /// previous, so game 1 is the least recently viewed.
    Future<void> saveGames(LocalGameStore target, int count) async {
      for (var bggId = 1; bggId <= count; bggId++) {
        _ok(
          await target.saveDetails(
            bggId: bggId,
            detailsJson: _json(bggId),
            fetchedAt: _at(bggId),
            viewedAt: _at(bggId),
          ),
        );
      }
    }

    Future<int> detailsCount() async => (await (db.select(
      db.games,
    )..where((g) => g.detailsJson.isNotNull())).get()).length;

    test('the default cap is 500', () {
      expect(store.maxCachedDetails, 500);
      expect(LocalGameStore.defaultMaxCachedDetails, 500);
    });

    test(
      '501 games: the least recently viewed is evicted, 500 remain',
      () async {
        await saveGames(store, 500);
        expect(await detailsCount(), 500);
        // Game 1 was viewed first; viewing game 2 again makes it recent, so a
        // pure fetch-time order would pick the wrong game.
        _ok(await store.markViewed(2, _at(10000)));

        _ok(
          await store.saveDetails(
            bggId: 501,
            detailsJson: _json(501),
            fetchedAt: _at(501),
            viewedAt: _at(501),
          ),
        );

        expect(await detailsCount(), 500);
        expect(_ok(await store.readDetails(1)), isNull);
        expect(_ok(await store.readDetails(2)), isNotNull);
        expect(_ok(await store.readDetails(501)), isNotNull);
        // Nothing points to game 1, so its row is gone too.
        expect(await internalId(1), isNull);
        expect(await gameCount(), 500);
      },
    );

    test(
      'an evicted game a match points to keeps its row and BGG id',
      () async {
        await saveGames(store, 1);
        final id = await internalId(1);
        _ok(
          await store.saveConfirmedMatch(
            gtin13: '0036000291452',
            bggId: 1,
            confirmedAt: _at(0),
          ),
        );
        for (var bggId = 2; bggId <= 501; bggId++) {
          _ok(
            await store.saveDetails(
              bggId: bggId,
              detailsJson: _json(bggId),
              fetchedAt: _at(bggId),
              viewedAt: _at(bggId),
            ),
          );
        }

        expect(await detailsCount(), 500);
        expect(_ok(await store.readDetails(1)), isNull);
        expect(await internalId(1), id);
        expect(await gameCount(), 501);
        final match = _ok(await store.readConfirmedMatch('0036000291452'));
        expect(match!.bggId, 1);
      },
    );

    test('games never viewed count from their fetch time', () async {
      final small = LocalGameStore(db, maxCachedDetails: 2);
      _ok(
        await small.saveDetails(
          bggId: 1,
          detailsJson: _json(1),
          fetchedAt: _at(5),
          viewedAt: _at(5),
        ),
      );
      // Fetched before game 1 was viewed, never viewed itself.
      _ok(
        await small.saveDetails(
          bggId: 2,
          detailsJson: _json(2),
          fetchedAt: _at(1),
        ),
      );
      _ok(
        await small.saveDetails(
          bggId: 3,
          detailsJson: _json(3),
          fetchedAt: _at(6),
          viewedAt: _at(6),
        ),
      );
      expect(_ok(await small.readDetails(2)), isNull);
      expect(_ok(await small.readDetails(1)), isNotNull);
      expect(_ok(await small.readDetails(3)), isNotNull);
    });

    test('ties go to the game stored first', () async {
      final small = LocalGameStore(db, maxCachedDetails: 1);
      _ok(
        await small.saveDetails(
          bggId: 7,
          detailsJson: _json(7),
          fetchedAt: _t0,
        ),
      );
      _ok(
        await small.saveDetails(
          bggId: 3,
          detailsJson: _json(3),
          fetchedAt: _t0,
        ),
      );
      expect(_ok(await small.readDetails(7)), isNull);
      expect(_ok(await small.readDetails(3)), isNotNull);
    });

    test(
      'the game just saved is kept even with the oldest fetch time',
      () async {
        final small = LocalGameStore(db, maxCachedDetails: 1);
        _ok(
          await small.saveDetails(
            bggId: 7,
            detailsJson: _json(7),
            fetchedAt: _at(10),
            viewedAt: _at(10),
          ),
        );
        // Details fetched earlier (for example a slow response) and never
        // viewed: by recency alone it would be evicted the moment it is saved.
        _ok(
          await small.saveDetails(
            bggId: 3,
            detailsJson: _json(3),
            fetchedAt: _at(1),
          ),
        );
        expect(_ok(await small.readDetails(3)), isNotNull);
        expect(_ok(await small.readDetails(7)), isNull);
      },
    );

    test('a cap below 1 is rejected', () {
      expect(
        () => LocalGameStore(db, maxCachedDetails: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rows without details do not count toward the cap', () async {
      final small = LocalGameStore(db, maxCachedDetails: 1);
      for (var bggId = 10; bggId < 13; bggId++) {
        _ok(
          await small.saveConfirmedMatch(
            gtin13: '00000000000$bggId',
            bggId: bggId,
            confirmedAt: _t0,
          ),
        );
      }
      _ok(
        await small.saveDetails(
          bggId: 1,
          detailsJson: _json(1),
          fetchedAt: _t0,
        ),
      );
      expect(_ok(await small.readDetails(1)), isNotNull);
      expect(await gameCount(), 4);
    });
  });
}
