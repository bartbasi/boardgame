// T-029 QA round 2: a failed match read, every refresh failure serving the
// copy, and the stricter layer checker.
import 'package:board_game_collector/core/data/database/app_database.dart';
import 'package:board_game_collector/core/data/database/local_game_store.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:board_game_collector/features/game_detail/data/game_details_codec.dart';
import 'package:board_game_collector/features/game_detail/data/games_repository_impl.dart';
import 'package:board_game_collector/features/game_detail/domain/barcode_lookup.dart';
import 'package:board_game_collector/features/game_detail/domain/game_details.dart';
import 'package:board_game_collector/features/game_detail/domain/game_lookup_result.dart';
import 'package:board_game_collector/features/game_detail/domain/game_summary.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_games.dart';
import '../helpers/test_database.dart';

final DateTime _now = DateTime.utc(2026, 10, 15, 8);
final DateTime _earlier = DateTime.utc(2026, 10, 10, 9, 30, 15);

const String _upc = '036000291452';
const String _key = '0036000291452';

BarcodeLookup _lookup(
  BarcodeLookupStatus status, {
  List<int> ids = const [13],
}) => BarcodeLookup(
  gtin13: _key,
  status: status,
  games: [
    for (final id in ids)
      GameSummary(
        bggId: id,
        name: 'Game $id',
        yearPublished: 2000,
        bggUrl: 'https://boardgamegeek.com/boardgame/$id',
      ),
  ],
);

/// A store spy whose match reads can be made to fail for every call.
class _ReadsFail extends StoreSpy {
  _ReadsFail(super.store);

  bool failReads = false;

  @override
  Future<Result<ConfirmedMatch?>> readConfirmedMatch(String gtin13) {
    if (failReads) {
      calls.add('readConfirmedMatch');
      return Future.value(const Err(StorageFailure()));
    }
    return super.readConfirmedMatch(gtin13);
  }
}

void main() {
  late AppDatabase db;
  late LocalGameStore store;
  late FakeGamesRemote remote;
  late List<String> logs;
  late _ReadsFail flaky;
  late GamesRepositoryImpl repo;
  late GameDetails catan;

  setUp(() {
    db = inMemoryDatabase();
    store = LocalGameStore(db);
    remote = FakeGamesRemote();
    logs = [];
    flaky = _ReadsFail(store);
    repo = GamesRepositoryImpl(
      remote: remote,
      detailsCache: flaky,
      matchStore: flaky,
      log: logs.add,
    );
    catan = detailsFixture('game_detail/full.json');
  });

  tearDown(() => db.close());

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle())
          .read<int>('c');

  Future<ConfirmedMatch?> match() async =>
      (await store.readConfirmedMatch(_key)).valueOrNull;

  Future<void> cache({DateTime? fetchedAt, String? json, int? id}) async {
    final saved = await store.saveDetails(
      bggId: id ?? catan.bggId,
      detailsJson: json ?? encodeCachedDetails(catan),
      fetchedAt: fetchedAt ?? _earlier,
    );
    expect(saved.isOk, isTrue);
  }

  group('a failed match read means the match is unknown', () {
    test('read fails, nothing stored: shown but never saved', () async {
      flaky.failReads = true;
      remote.lookupResult = Ok(_lookup(BarcodeLookupStatus.matched));
      final r = await repo.lookupBarcode(barcodeOf(_upc));
      expect(r.valueOrNull, isA<FromBackend>());
      expect(r.valueOrNull?.matchedBggId, 13);
      expect(flaky.calls, isNot(contains('saveConfirmedMatch')));
      expect(await count('barcode_matches'), 0);
      expect(
        logs,
        contains(
          'GamesRepository.saveConfirmedMatch skipped: stored match unknown',
        ),
      );
    });

    test('read fails, user chose 822: 822 survives a backend match', () async {
      await store.saveConfirmedMatch(
        gtin13: _key,
        bggId: 822,
        confirmedAt: _earlier,
      );
      flaky.failReads = true;
      remote.lookupResult = Ok(_lookup(BarcodeLookupStatus.matched));
      final r = await repo.lookupBarcode(barcodeOf(_upc));
      expect(r.valueOrNull?.matchedBggId, 13, reason: 'shown, not saved');
      final m = await match();
      expect(m?.bggId, 822);
      expect(m?.confirmedAt, _earlier);
    });

    test('concurrent lookups with failing reads and a confirm in the middle '
        'end with the confirmed game', () async {
      flaky.failReads = true;
      remote.lookupResult = Ok(_lookup(BarcodeLookupStatus.matched));
      final futures = <Future<Object>>[
        for (var i = 0; i < 2; i++) repo.lookupBarcode(barcodeOf(_upc)),
        repo.confirmMatch(barcodeOf(_upc), 822),
        for (var i = 0; i < 3; i++) repo.lookupBarcode(barcodeOf(_upc)),
      ];
      await Future.wait(futures);
      expect(
        flaky.calls.where((c) => c == 'saveConfirmedMatch'),
        hasLength(1),
        reason: 'only the confirm writes',
      );
      expect((await match())?.bggId, 822);
    });

    test('the read recovers: the next lookup saves, the one after answers '
        'from the device', () async {
      flaky.failReads = true;
      remote.lookupResult = Ok(_lookup(BarcodeLookupStatus.matched));
      await repo.lookupBarcode(barcodeOf(_upc));
      flaky.failReads = false;
      await repo.lookupBarcode(barcodeOf(_upc));
      expect(remote.lookups, hasLength(2));
      expect((await match())?.bggId, 13);
      await repo.lookupBarcode(barcodeOf(_upc));
      expect(remote.lookups, hasLength(2), reason: 'now stored');
    });

    test(
      'read fails and the answer is not storable: no skip is logged',
      () async {
        flaky.failReads = true;
        remote.lookupResult = Ok(
          _lookup(BarcodeLookupStatus.candidates, ids: [13, 14]),
        );
        await repo.lookupBarcode(barcodeOf(_upc));
        expect(logs.where((l) => l.contains('skipped')), isEmpty);
      },
    );

    test('confirmMatch still writes while reads fail', () async {
      flaky.failReads = true;
      final r = await repo.confirmMatch(barcodeOf(_upc), 822);
      expect(r.isOk, isTrue);
      expect((await match())?.bggId, 822);
    });

    test('hideNextMatch lets a matched answer replace (the harness sees a '
        'write)', () async {
      await store.saveConfirmedMatch(
        gtin13: _key,
        bggId: 822,
        confirmedAt: _earlier,
      );
      flaky.hideNextMatch = true;
      remote.lookupResult = Ok(_lookup(BarcodeLookupStatus.matched));
      await withClock(
        Clock.fixed(_now),
        () => repo.lookupBarcode(barcodeOf(_upc)),
      );
      final m = await match();
      expect(m?.bggId, 13);
      expect(m?.confirmedAt, _now);
    });
  });

  group('every refresh failure serves a usable copy', () {
    test('404 serves the stale copy with its stored fetch time', () async {
      await cache();
      remote.fetchResult = const Err(NotFoundFailure());
      final r = await withClock(Clock.fixed(_now), () => repo.getGame(13));
      final snap = r.valueOrNull!;
      expect(snap.isStale, isTrue);
      expect(snap.fetchedAt, _earlier);
      expect(snap.details, catan);
      expect((await store.readDetails(13)).valueOrNull?.lastViewedAt, _now);
    });

    test('404 without a copy is still 404', () async {
      remote.fetchResult = const Err(NotFoundFailure());
      expect((await repo.getGame(13)).failureOrNull, const NotFoundFailure());
    });

    test(
      'a copy is served again and again, never refreshed by a failure',
      () async {
        await cache();
        remote.fetchResult = const Err(UnexpectedFailure());
        for (var i = 0; i < 3; i++) {
          expect((await repo.getGame(13)).valueOrNull?.fetchedAt, _earlier);
        }
        expect((await store.readDetails(13)).valueOrNull?.fetchedAt, _earlier);
      },
    );

    test('details of another game fall back to the copy and are never '
        'saved', () async {
      await cache();
      remote.fetchResult = Ok(catan.copyWith(bggId: 14, name: 'Impostor'));
      final r = await repo.getGame(13);
      expect(r.valueOrNull?.isStale, isTrue);
      expect(r.valueOrNull?.details.name, 'Catan');
      expect(await count('games'), 1);
      expect((await store.readDetails(14)).valueOrNull, isNull);
      expect(
        decodeCachedDetails(
          (await store.readDetails(13)).valueOrNull!.detailsJson,
        ).name,
        'Catan',
      );
      expect(
        logs,
        contains('GamesRepository.getGame failed: UnexpectedFailure'),
      );
    });

    test(
      'details of another game without a copy is the unexpected failure',
      () async {
        remote.fetchResult = Ok(catan.copyWith(bggId: 14));
        expect(
          (await repo.getGame(13)).failureOrNull,
          const UnexpectedFailure(),
        );
        expect(await count('games'), 0);
      },
    );

    test(
      'a copy filed for another game plus a failure returns the failure',
      () async {
        await cache(id: 99);
        remote.fetchResult = const Err(NotFoundFailure());
        expect((await repo.getGame(99)).failureOrNull, const NotFoundFailure());
      },
    );

    test('a broken copy plus 404 returns 404', () async {
      await cache(json: 'garbage');
      remote.fetchResult = const Err(NotFoundFailure());
      expect((await repo.getGame(13)).failureOrNull, const NotFoundFailure());
    });

    test('concurrent failing loads of one game all get the copy', () async {
      await cache();
      remote.fetchResult = const Err(NotFoundFailure());
      final rs = await Future.wait([
        for (var i = 0; i < 5; i++) repo.getGame(13),
      ]);
      expect(rs.every((r) => r.valueOrNull?.isStale ?? false), isTrue);
    });

    test('a lookup is not affected: not found on a lookup is still not '
        'found, with a stored copy around', () async {
      await cache();
      remote.lookupResult = const Err(NotFoundFailure());
      final r = await repo.lookupBarcode(barcodeOf(_upc));
      expect(r.failureOrNull, const NotFoundFailure());
    });
  });
}
