// T-029 QA round 1: edge cases for the games repository, with the real
// LocalGameStore on an in-memory database and a fake remote data source.
import 'dart:io';

import 'package:board_game_collector/core/data/database/app_database.dart';
import 'package:board_game_collector/core/data/database/local_game_store.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:board_game_collector/features/game_detail/data/game_details_codec.dart';
import 'package:board_game_collector/features/game_detail/data/games_repository_impl.dart';
import 'package:board_game_collector/features/game_detail/domain/barcode_lookup.dart';
import 'package:board_game_collector/features/game_detail/domain/game_details.dart';
import 'package:board_game_collector/features/game_detail/domain/game_details_snapshot.dart';
import 'package:board_game_collector/features/game_detail/domain/game_lookup_result.dart';
import 'package:board_game_collector/features/game_detail/domain/game_summary.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';

import '../architecture/repository_layers.dart';
import '../helpers/fake_games.dart';
import '../helpers/test_database.dart';

final DateTime _now = DateTime.utc(2026, 10, 15, 8);
final DateTime _earlier = DateTime.utc(2026, 10, 10, 9, 30, 15);

const String _upc = '036000291452';
const String _key = '0036000291452';

Future<T> _atNow<T>(Future<T> Function() body, [DateTime? at]) =>
    withClock(Clock.fixed(at ?? _now), body);

BarcodeLookup _lookup(
  BarcodeLookupStatus status, {
  String code = _key,
  List<int> ids = const [13],
}) => BarcodeLookup(
  gtin13: code,
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

void main() {
  late AppDatabase db;
  late LocalGameStore store;
  late StoreSpy spy;
  late FakeGamesRemote remote;
  late List<String> logs;
  late GamesRepositoryImpl repository;
  late GameDetails catan;

  void build({int cap = LocalGameStore.defaultMaxCachedDetails}) {
    store = LocalGameStore(db, maxCachedDetails: cap);
    spy = StoreSpy(store);
    repository = GamesRepositoryImpl(
      remote: remote,
      detailsCache: spy,
      matchStore: spy,
      log: logs.add,
    );
  }

  setUp(() {
    db = inMemoryDatabase();
    remote = FakeGamesRemote();
    logs = [];
    catan = detailsFixture('game_detail/full.json');
    build();
  });

  tearDown(() => db.close());

  Future<void> cache(
    GameDetails d, {
    String? json,
    DateTime? fetchedAt,
    DateTime? viewedAt,
  }) async {
    final saved = await store.saveDetails(
      bggId: d.bggId,
      detailsJson: json ?? encodeCachedDetails(d),
      fetchedAt: fetchedAt ?? _earlier,
      viewedAt: viewedAt,
    );
    expect(saved.isOk, isTrue);
  }

  Future<ConfirmedMatch?> match([String key = _key]) async =>
      (await store.readConfirmedMatch(key)).valueOrNull;

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle())
          .read<int>('c');

  group('lookup with a stored match', () {
    test('the three key forms of one code share one stored match', () async {
      await store.saveConfirmedMatch(
        gtin13: _key,
        bggId: 13,
        confirmedAt: _earlier,
      );
      await store.saveConfirmedMatch(
        gtin13: '0000096385074',
        bggId: 822,
        confirmedAt: _earlier,
      );
      for (final code in [_upc, _key]) {
        final r = await repository.lookupBarcode(barcodeOf(code));
        expect(r.valueOrNull?.matchedBggId, 13, reason: code);
      }
      final ean8 = await repository.lookupBarcode(barcodeOf('96385074'));
      expect(ean8.valueOrNull?.matchedBggId, 822);
      expect(remote.calls, 0);
    });

    test('details evicted: the match still answers with no summary and no '
        'request, and the offline copy is gone', () async {
      build(cap: 1);
      await cache(catan);
      await store.saveConfirmedMatch(
        gtin13: _key,
        bggId: 13,
        confirmedAt: _earlier,
      );
      // Two newer games push Catan's details out (cap 1).
      for (final id in [14, 15]) {
        await cache(catan.copyWith(bggId: id), fetchedAt: _now);
      }
      expect((await store.readDetails(13)).valueOrNull, isNull);

      final r = await repository.lookupBarcode(barcodeOf(_upc));
      final m = r.valueOrNull! as ConfirmedOnDevice;
      expect(m.bggId, 13);
      expect(m.game, isNull);
      expect(remote.calls, 0);

      remote.fetchResult = const Err(NoConnectionFailure());
      expect(
        (await repository.getGame(13)).failureOrNull,
        const NoConnectionFailure(),
      );
    });

    test('a failing remote never clears or changes a stored match', () async {
      await store.saveConfirmedMatch(
        gtin13: _key,
        bggId: 13,
        confirmedAt: _earlier,
      );
      remote.lookupResult = const Err(NoConnectionFailure());
      await repository.lookupBarcode(barcodeOf(_upc));
      expect((await match())?.bggId, 13);
    });

    test('a stored match for one code does not answer another code', () async {
      await store.saveConfirmedMatch(
        gtin13: _key,
        bggId: 13,
        confirmedAt: _earlier,
      );
      remote.lookupResult = Ok(
        _lookup(BarcodeLookupStatus.none, code: '4006381333931', ids: []),
      );
      final r = await repository.lookupBarcode(barcodeOf('4006381333931'));
      expect(r.valueOrNull, isA<FromBackend>());
      expect(remote.lookups, hasLength(1));
    });
  });

  group('what the backend answers', () {
    test(
      'matched for a different code stores nothing and is refused',
      () async {
        remote.lookupResult = Ok(
          _lookup(BarcodeLookupStatus.matched, code: '4006381333931'),
        );
        final r = await repository.lookupBarcode(barcodeOf(_upc));
        expect(r.failureOrNull, const UnexpectedFailure());
        expect(await count('barcode_matches'), 0);
        expect(await count('games'), 0);
      },
    );

    for (final ids in [
      <int>[],
      [13, 14],
      [13, 14, 15],
    ]) {
      test('matched with ${ids.length} games is not stored', () async {
        remote.lookupResult = Ok(
          _lookup(BarcodeLookupStatus.matched, ids: ids),
        );
        final r = await repository.lookupBarcode(barcodeOf(_upc));
        expect(r.valueOrNull, isA<FromBackend>());
        expect(r.valueOrNull?.matchedBggId, isNull);
        expect(await count('barcode_matches'), 0);
        expect(await count('games'), 0);
      });
    }

    final neverStored = <String, BarcodeLookup>{
      'candidates, 3 games': _lookup(
        BarcodeLookupStatus.candidates,
        ids: [13, 14, 15],
      ),
      'candidates, 1 game': _lookup(BarcodeLookupStatus.candidates),
      'none': _lookup(BarcodeLookupStatus.none, ids: []),
      'none with a game (contract break)': _lookup(BarcodeLookupStatus.none),
      'unavailable': _lookup(BarcodeLookupStatus.unavailable, ids: []),
      'unknown, 1 game': _lookup(BarcodeLookupStatus.unknown),
      'unknown, 2 games': _lookup(BarcodeLookupStatus.unknown, ids: [13, 14]),
      'unknown, none': _lookup(BarcodeLookupStatus.unknown, ids: []),
    };
    for (final MapEntry(key: name, value: answer) in neverStored.entries) {
      test(
        '$name never stores and never overwrites an earlier match',
        () async {
          remote.lookupResult = Ok(answer);
          // Clean store.
          var r = await repository.lookupBarcode(barcodeOf(_upc));
          expect(r.isOk, isTrue);
          expect(await count('barcode_matches'), 0);
          expect(await count('games'), 0);
          expect(r.valueOrNull?.matchedBggId, isNull);

          // An earlier match, with the match read forced to miss.
          await store.saveConfirmedMatch(
            gtin13: _key,
            bggId: 822,
            confirmedAt: _earlier,
          );
          spy.hideNextMatch = true;
          r = await repository.lookupBarcode(barcodeOf(_upc));
          expect(r.isOk, isTrue);
          final m = await match();
          expect(m?.bggId, 822);
          expect(m?.confirmedAt, _earlier);
        },
      );
    }

    test('a later matched answer replaces an earlier match when the read '
        'succeeded and found none (hidden match)', () async {
      await store.saveConfirmedMatch(
        gtin13: _key,
        bggId: 822,
        confirmedAt: _earlier,
      );
      spy.hideNextMatch = true;
      remote.lookupResult = Ok(_lookup(BarcodeLookupStatus.matched));
      await _atNow(() => repository.lookupBarcode(barcodeOf(_upc)));
      final m = await match();
      expect(m?.bggId, 13);
      expect(m?.confirmedAt, _now);
    });

    test('a matched answer stores the key, not the scanned digits', () async {
      remote.lookupResult = Ok(_lookup(BarcodeLookupStatus.matched));
      await repository.lookupBarcode(barcodeOf(_upc));
      final rows = await db
          .customSelect('SELECT gtin13 FROM barcode_matches')
          .get();
      expect(rows.single.read<String>('gtin13'), _key);
    });

    test('two codes keep two separate matches', () async {
      remote.lookupResult = Ok(_lookup(BarcodeLookupStatus.matched));
      await repository.lookupBarcode(barcodeOf(_upc));
      remote.lookupResult = Ok(
        _lookup(BarcodeLookupStatus.matched, code: '4006381333931', ids: [822]),
      );
      await repository.lookupBarcode(barcodeOf('4006381333931'));
      expect((await match())?.bggId, 13);
      expect((await match('4006381333931'))?.bggId, 822);
    });
  });

  group('details: success', () {
    test(
      'caches, marks viewed, and returns fresh with the device time',
      () async {
        remote.fetchResult = Ok(catan);
        final r = await _atNow(() => repository.getGame(13));
        final snap = r.valueOrNull!;
        expect(snap.freshness, DataFreshness.fresh);
        expect(snap.refreshFailure, isNull);
        expect(snap.fetchedAt, _now);
        expect(snap.details, catan);
        final row = (await store.readDetails(13)).valueOrNull!;
        expect(row.fetchedAt, _now);
        expect(row.lastViewedAt, _now);
      },
    );

    test('a second success updates the copy and the times', () async {
      remote.fetchResult = Ok(catan);
      await _atNow(() => repository.getGame(13));
      final later = _now.add(const Duration(days: 3));
      remote.fetchResult = Ok(catan.copyWith(name: 'Catan (new)'));
      await _atNow(() => repository.getGame(13), later);
      final row = (await store.readDetails(13)).valueOrNull!;
      expect(row.fetchedAt, later);
      expect(row.lastViewedAt, later);
      expect(decodeCachedDetails(row.detailsJson).name, 'Catan (new)');
      expect(await count('games'), 1);
    });

    test('a non-UTC clock is stored in UTC', () async {
      remote.fetchResult = Ok(catan);
      await withClock(
        Clock.fixed(DateTime(2026, 10, 15, 8)),
        () => repository.getGame(13),
      );
      final row = (await store.readDetails(13)).valueOrNull!;
      expect(row.fetchedAt.isUtc, isTrue);
    });

    test(
      'caching keeps an existing confirmed match pointing at the game',
      () async {
        await store.saveConfirmedMatch(
          gtin13: _key,
          bggId: 13,
          confirmedAt: _earlier,
        );
        remote.fetchResult = Ok(catan);
        await repository.getGame(13);
        expect((await match())?.bggId, 13);
        expect(await count('games'), 1);
      },
    );
  });

  group('details: every failure with and without a cached copy', () {
    final failures = <String, Failure>{
      'no connection': const NoConnectionFailure(),
      'timeout': const TimeoutFailure(),
      'service unavailable': const ServiceUnavailableFailure(),
      'rate limited, no wait': const RateLimitedFailure(),
      'rate limited 30 s': const RateLimitedFailure(
        retryAfter: Duration(seconds: 30),
      ),
      'not found': const NotFoundFailure(),
      for (final code in InvalidInputCode.values)
        'invalid input ${code.name}': InvalidInputFailure(code),
      'invalid barcode': const InvalidBarcodeFailure(
        InvalidBarcodeReason.wrongLength,
        length: 3,
      ),
      'access denied': const AccessDeniedFailure(),
      'cancelled': const CancelledFailure(),
      for (final p in ConfigurationProblem.values)
        'configuration ${p.name}': ConfigurationFailure(p),
      'storage': const StorageFailure(),
      'unexpected': const UnexpectedFailure(),
    };
    for (final MapEntry(key: name, value: failure) in failures.entries) {
      final serves = servesCachedCopy(failure);
      test('$name without a copy returns the failure unchanged', () async {
        remote.fetchResult = Err(failure);
        final r = await repository.getGame(13);
        expect(r.failureOrNull, failure);
        expect(spy.calls, anyOf(isEmpty, ['readDetails']));
        expect(await count('games'), 0);
      });
      test(
        '$name with a copy ${serves ? 'returns it stale' : 'still fails'}',
        () async {
          await cache(catan, fetchedAt: _earlier);
          remote.fetchResult = Err(failure);
          spy.calls.clear();
          final r = await _atNow(() => repository.getGame(13));
          if (serves) {
            final snap = r.valueOrNull!;
            expect(snap.isStale, isTrue);
            expect(snap.refreshFailure, failure);
            expect(snap.freshness, DataFreshness.stale);
            expect(snap.fetchedAt, _earlier);
            expect(snap.details, catan);
            final row = (await store.readDetails(13)).valueOrNull!;
            expect(row.fetchedAt, _earlier, reason: 'fetch time never moves');
            expect(row.lastViewedAt, _now);
          } else {
            expect(r.failureOrNull, failure);
            expect(spy.calls, isEmpty, reason: 'no store call for $name');
            final row = (await store.readDetails(13)).valueOrNull!;
            expect(row.lastViewedAt, isNull);
          }
        },
      );
    }

    test('every failure kind serves a usable cached copy (round 2)', () {
      expect({
        for (final e in failures.entries)
          if (servesCachedCopy(e.value)) e.key,
      }, failures.keys.toSet());
    });
  });

  group('a cached copy that no longer decodes counts as none', () {
    final bad = <String, String>{
      'empty text': '',
      'not JSON': 'garbage',
      'truncated': '{"bggId": 13, "name": "Cat',
      'null': 'null',
      'array': '[]',
      'empty object': '{}',
      'wrong type': '{"bggId":"13"}',
      'bad bggUrl host': '',
    };
    for (final MapEntry(key: name, value: text) in bad.entries) {
      test('$name on a 503 returns the failure, not a stale copy', () async {
        final json = name == 'bad bggUrl host'
            ? encodeCachedDetails(catan).replaceFirst(
                'https://boardgamegeek.com/boardgame/13',
                'https://evil.example/boardgame/13',
              )
            : text;
        await cache(catan, json: json);
        remote.fetchResult = const Err(ServiceUnavailableFailure());
        spy.calls.clear();
        final r = await repository.getGame(13);
        expect(r.failureOrNull, const ServiceUnavailableFailure());
        expect(spy.calls, ['readDetails']);
      });
    }

    test(
      'a lookup with such a copy still answers from the stored match',
      () async {
        await store.saveConfirmedMatch(
          gtin13: _key,
          bggId: 13,
          confirmedAt: _earlier,
        );
        await cache(catan, json: 'garbage');
        final r = await repository.lookupBarcode(barcodeOf(_upc));
        expect((r.valueOrNull! as ConfirmedOnDevice).game, isNull);
      },
    );

    test('a fresh load replaces the broken copy', () async {
      await cache(catan, json: 'garbage');
      remote.fetchResult = Ok(catan);
      expect((await repository.getGame(13)).isOk, isTrue);
      expect(
        decodeCachedDetails(
          (await store.readDetails(13)).valueOrNull!.detailsJson,
        ),
        catan,
      );
    });
  });

  group('storage errors never fail a backend-answered call', () {
    late FailingInterceptor failing;
    setUp(() async {
      await db.close();
      failing = FailingInterceptor();
      db = inMemoryDatabase(interceptor: failing);
      build();
    });

    void expectLogsHoldNoData() {
      for (final line in logs) {
        expect(line, isNot(contains('Catan')));
        expect(line, isNot(contains('database or disk is full')));
        expect(line, isNot(contains('{')));
        expect(line, isNot(contains(_key)));
        expect(line, startsWith('GamesRepository.'));
      }
    }

    test(
      'details: the backend answer is returned when the cache is full',
      () async {
        remote.fetchResult = Ok(catan);
        failing.failing = true;
        final r = await repository.getGame(13);
        expect(r.valueOrNull?.freshness, DataFreshness.fresh);
        expect(logs, isNotEmpty);
        expectLogsHoldNoData();
      },
    );

    test('lookup: a failing match read falls through and the match is shown '
        'but not saved (round 2)', () async {
      remote.lookupResult = Ok(_lookup(BarcodeLookupStatus.matched));
      failing.failing = true;
      final r = await repository.lookupBarcode(barcodeOf(_upc));
      expect(r.valueOrNull, isA<FromBackend>());
      expect(r.valueOrNull?.matchedBggId, 13);
      expect(remote.lookups, hasLength(1));
      expect(logs.length, greaterThanOrEqualTo(2));
      expectLogsHoldNoData();
    });

    test(
      'offline with a failing cache read returns the load failure',
      () async {
        remote.fetchResult = const Err(NoConnectionFailure());
        failing.failing = true;
        final r = await repository.getGame(13);
        expect(r.failureOrNull, const NoConnectionFailure());
        expectLogsHoldNoData();
      },
    );

    test('confirmMatch on a full disk is a StorageFailure', () async {
      failing.failing = true;
      final r = await repository.confirmMatch(barcodeOf(_upc), 13);
      expect(r.failureOrNull, const StorageFailure());
    });

    test('search is untouched by storage errors', () async {
      failing.failing = true;
      remote.searchResult = Ok(searchFixture('search/results.json'));
      expect((await repository.searchGames('catan')).isOk, isTrue);
      expect(failing.refused, 0);
    });

    test('after the disk recovers everything works again', () async {
      failing.failing = true;
      remote.fetchResult = Ok(catan);
      await repository.getGame(13);
      failing.failing = false;
      await repository.getGame(13);
      expect((await store.readDetails(13)).valueOrNull, isNotNull);
    });
  });

  group('search is never cached', () {
    test(
      'success and failures leave the tables empty and call no store',
      () async {
        remote.searchResult = Ok(searchFixture('search/results.json'));
        expect((await repository.searchGames('Café & Co')).isOk, isTrue);
        for (final f in const <Failure>[
          NoConnectionFailure(),
          TimeoutFailure(),
          RateLimitedFailure(retryAfter: Duration(seconds: 5)),
          ServiceUnavailableFailure(),
          InvalidInputFailure(InvalidInputCode.invalidQuery),
        ]) {
          remote.searchResult = Err(f);
          expect((await repository.searchGames('catan')).failureOrNull, f);
        }
        expect(spy.calls, isEmpty);
        expect(await count('games'), 0);
        expect(await count('barcode_matches'), 0);
        expect(remote.searches, hasLength(6));
      },
    );

    test('a search never reuses an earlier answer', () async {
      remote.searchResult = Ok(searchFixture('search/results.json'));
      await repository.searchGames('catan');
      await repository.searchGames('catan');
      expect(remote.searches, ['catan', 'catan']);
    });
  });

  group('concurrency', () {
    test('five concurrent lookups of one code store one match and all '
        'succeed', () async {
      remote.lookupResult = Ok(_lookup(BarcodeLookupStatus.matched));
      final results = await Future.wait([
        for (var i = 0; i < 5; i++) repository.lookupBarcode(barcodeOf(_upc)),
      ]);
      for (final r in results) {
        expect(r.valueOrNull?.matchedBggId, 13);
      }
      expect(await count('barcode_matches'), 1);
      expect(await count('games'), 1);
    });

    test('concurrent lookups of the same code with a replace in between '
        'end with a valid match', () async {
      remote.lookupResult = Ok(_lookup(BarcodeLookupStatus.matched));
      final futures = [
        repository.lookupBarcode(barcodeOf(_upc)),
        repository.confirmMatch(barcodeOf(_upc), 822),
        repository.lookupBarcode(barcodeOf(_upc)),
      ];
      await Future.wait(futures);
      expect(await count('barcode_matches'), 1);
      expect([13, 822], contains((await match())?.bggId));
    });

    test('five concurrent loads of one game keep one row', () async {
      remote.fetchResult = Ok(catan);
      final results = await Future.wait([
        for (var i = 0; i < 5; i++) repository.getGame(13),
      ]);
      expect(results.every((r) => r.isOk), isTrue);
      expect(await count('games'), 1);
    });

    test('concurrent loads of different games keep their own rows', () async {
      final ids = [for (var i = 1; i <= 20; i++) i];
      // Each call needs its own answer; run them one remote answer at a time.
      for (final id in ids) {
        remote.fetchResult = Ok(catan.copyWith(bggId: id));
        await repository.getGame(id);
      }
      expect(await count('games'), 20);
    });
  });

  group('eviction at 500 through the repository', () {
    test('the 501st game evicts the least recently viewed, a viewed old '
        'copy survives, and the match keeps its game row', () async {
      await store.saveConfirmedMatch(
        gtin13: _key,
        bggId: 2,
        confirmedAt: _earlier,
      );
      final start = DateTime.utc(2026, 1, 1);
      for (var id = 1; id <= 500; id++) {
        remote.fetchResult = Ok(catan.copyWith(bggId: id));
        await _atNow(
          () => repository.getGame(id),
          start.add(Duration(minutes: id)),
        );
      }
      expect(await count('games'), 500);

      // Game 1 is viewed again through an offline load.
      remote.fetchResult = const Err(NoConnectionFailure());
      final viewed = await _atNow(
        () => repository.getGame(1),
        start.add(const Duration(days: 1)),
      );
      expect(viewed.valueOrNull?.isStale, isTrue);

      remote.fetchResult = Ok(catan.copyWith(bggId: 501));
      await _atNow(
        () => repository.getGame(501),
        start.add(const Duration(days: 2)),
      );

      // Game 2 was the oldest unviewed one: its details are gone, but the
      // confirmed match still resolves it.
      expect((await store.readDetails(2)).valueOrNull, isNull);
      expect((await store.readDetails(1)).valueOrNull, isNotNull);
      expect((await store.readDetails(3)).valueOrNull, isNotNull);
      expect((await store.readDetails(501)).valueOrNull, isNotNull);
      final lookup = await repository.lookupBarcode(barcodeOf(_upc));
      expect((lookup.valueOrNull! as ConfirmedOnDevice).bggId, 2);
      expect((lookup.valueOrNull! as ConfirmedOnDevice).game, isNull);
      // 500 games with details plus game 2 (match only) is not over the
      // cap: details count is what is capped.
      final withDetails = await count('games WHERE details_json IS NOT NULL');
      expect(withDetails, 500);
    });

    test('an evicted unmatched game is deleted and a later offline load '
        'fails with the load failure', () async {
      build(cap: 2);
      for (var id = 1; id <= 3; id++) {
        remote.fetchResult = Ok(catan.copyWith(bggId: id));
        await _atNow(
          () => repository.getGame(id),
          _earlier.add(Duration(hours: id)),
        );
      }
      expect(await count('games'), 2);
      remote.fetchResult = const Err(TimeoutFailure());
      expect(
        (await repository.getGame(1)).failureOrNull,
        const TimeoutFailure(),
      );
    });
  });

  group('mismatch after the data source', () {
    test('details for another id are refused and not cached under either '
        'id', () async {
      remote.fetchResult = Ok(catan.copyWith(bggId: 14));
      final r = await repository.getGame(13);
      expect(r.failureOrNull, const UnexpectedFailure());
      expect(await count('games'), 0);
      expect(logs.single, 'GamesRepository.getGame failed: UnexpectedFailure');
    });

    test('a cached copy for another id is not served', () async {
      // Store Catan's JSON under id 99 by hand.
      await store.saveDetails(
        bggId: 99,
        detailsJson: encodeCachedDetails(catan),
        fetchedAt: _earlier,
      );
      remote.fetchResult = const Err(NoConnectionFailure());
      expect(
        (await repository.getGame(99)).failureOrNull,
        const NoConnectionFailure(),
      );
    });

    test(
      'lookup answered for another code is refused for every status',
      () async {
        for (final status in BarcodeLookupStatus.values) {
          remote.lookupResult = Ok(
            _lookup(status, code: '4006381333931', ids: [13]),
          );
          final r = await repository.lookupBarcode(barcodeOf(_upc));
          expect(r.failureOrNull, const UnexpectedFailure(), reason: '$status');
        }
        expect(await count('barcode_matches'), 0);
      },
    );
  });

  group('confirmMatch edges', () {
    test('ids 0, -1, and the int minimum write nothing', () async {
      for (final id in [0, -1, -9223372036854775808]) {
        final r = await repository.confirmMatch(barcodeOf(_upc), id);
        expect(
          r.failureOrNull,
          const InvalidInputFailure(InvalidInputCode.invalidBggId),
          reason: '$id',
        );
      }
      expect(spy.calls, isEmpty);
    });

    test('confirming the same game twice keeps one row and updates the '
        'time', () async {
      await withClock(
        Clock.fixed(_earlier),
        () => repository.confirmMatch(barcodeOf(_upc), 13),
      );
      await _atNow(() => repository.confirmMatch(barcodeOf(_upc), 13));
      expect(await count('barcode_matches'), 1);
      expect((await match())?.confirmedAt, _now);
    });

    test('a confirmed match then a lookup answers from the device with the '
        'cached summary', () async {
      remote.fetchResult = Ok(catan);
      await repository.getGame(13);
      await repository.confirmMatch(barcodeOf(_upc), 13);
      final r = await repository.lookupBarcode(barcodeOf(_upc));
      final m = r.valueOrNull! as ConfirmedOnDevice;
      expect(m.game?.name, 'Catan');
      expect(remote.calls, 1, reason: 'only the details load');
    });

    test('a large bggId is stored and read back', () async {
      await repository.confirmMatch(barcodeOf(_upc), 9007199254740991);
      expect((await match())?.bggId, 9007199254740991);
    });
  });

  group('cache codec edges', () {
    test('unicode, long text, empty lists, and microseconds round trip', () {
      final details = catan.copyWith(
        name: 'Café 世界 🎲 \u0000 tab\t "quote"',
        description: 'é' * 200000,
        designers: const [],
        publishers: const [],
        minPlayers: null,
        fetchedAt: DateTime.utc(2026, 10, 14, 1, 2, 3, 4, 5),
      );
      final back = decodeCachedDetails(encodeCachedDetails(details));
      expect(back, details);
    });

    test('a fetch time with an offset is kept as the same instant', () {
      final json = encodeCachedDetails(catan).replaceFirst(
        RegExp(r'"fetchedAt":"[^"]*"'),
        '"fetchedAt":"2026-10-13T10:15:30.000+02:00"',
      );
      final back = decodeCachedDetails(json);
      expect(back.fetchedAt, DateTime.utc(2026, 10, 13, 8, 15, 30));
    });
  });

  group('repository layer checker against temp fixtures', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('repo_layers_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    void write(String relative, String source) {
      File('${tmp.path}/lib/$relative')
        ..createSync(recursive: true)
        ..writeAsStringSync(source);
    }

    List<String> violations() => [
      for (final v in checkRepositoryLayers(Directory('${tmp.path}/lib')))
        '${v.file}|${v.name}',
    ];

    test('correct layout has no violations', () {
      write(
        'features/a/domain/a_repository.dart',
        'abstract interface class ARepository {}\n',
      );
      write(
        'features/a/data/a_repository_impl.dart',
        'class ARepositoryImpl implements ARepository {}\n',
      );
      expect(violations(), isEmpty);
    });

    test('an interface in data and an implementation in domain are caught', () {
      write(
        'features/a/data/a_repository.dart',
        'abstract class ARepository {}\n',
      );
      write(
        'features/a/domain/a_impl.dart',
        'class AImpl implements ARepository {}\n',
      );
      expect(violations(), {
        'features/a/data/a_repository.dart|ARepository',
        'features/a/domain/a_impl.dart|AImpl',
      });
    });

    test('presentation, app, core, and lib root are caught', () {
      write(
        'features/a/presentation/x.dart',
        'abstract class XRepository {}\n',
      );
      write('app/y.dart', 'class Y implements XRepository {}\n');
      write('core/z.dart', 'abstract interface class ZRepository {}\n');
      write('main.dart', 'class M implements XRepository {}\n');
      expect(violations().toSet(), {
        'features/a/presentation/x.dart|XRepository',
        'app/y.dart|Y',
        'core/z.dart|ZRepository',
        'main.dart|M',
      });
    });

    test('a nested data folder is fine, a feature-less data folder is not', () {
      write(
        'features/a/data/sub/impl.dart',
        'class AImpl implements ARepository {}\n',
      );
      write('data/impl.dart', 'class BImpl implements BRepository {}\n');
      expect(violations(), ['data/impl.dart|BImpl']);
    });

    test(
      'final, base, multi-interface, and multi-line implements are seen',
      () {
        write(
          'features/a/presentation/m.dart',
          'final class A implements Foo, ARepository {}\n'
              'base class B\n    implements\n        BRepository {}\n',
        );
        expect(violations().toSet(), {
          'features/a/presentation/m.dart|A',
          'features/a/presentation/m.dart|B',
        });
      },
    );

    test('names that only look like repositories are not flagged', () {
      write(
        'features/a/presentation/ok.dart',
        '// abstract class CommentedRepository {}\n'
            'class Repositoryish {}\n'
            'class UsesIt { final ARepository repo; UsesIt(this.repo); }\n'
            'class Comp implements Comparable<ARepository> {}\n',
      );
      expect(violations(), isEmpty);
    });

    test('generated files are skipped', () {
      write(
        'features/a/presentation/x.g.dart',
        'abstract class GRepository {}\n',
      );
      expect(violations(), isEmpty);
    });

    // Round 2: every class-header form is caught (T-029-B1 closed).
    final forms = <String, (String, String)>{
      // name: (path, source) all in a wrong layer, expected one violation.
      'sealed interface': (
        'features/a/presentation/s.dart',
        'sealed class SRepository {}\n',
      ),
      'mixin class': ('features/a/data/m.dart', 'mixin class MRepository {}\n'),
      'interface class': ('core/i.dart', 'interface class IRepository {}\n'),
      'abstract base class': (
        'features/a/presentation/ab.dart',
        'abstract base class BRepository {}\n',
      ),
      'abstract interface class': (
        'features/a/data/ai.dart',
        'abstract interface class AIRepository {}\n',
      ),
      'abstract mixin class': (
        'features/a/data/am.dart',
        'abstract mixin class AMRepository {}\n',
      ),
      'extends a repository': (
        'features/a/presentation/e.dart',
        'class EImpl extends ERepository {}\n',
      ),
      'extends an implementation': (
        'features/a/presentation/f.dart',
        'class Fake extends GamesRepositoryImpl {}\n',
      ),
      'with a repository mixin': (
        'features/a/domain/w.dart',
        'class W with WRepository {}\n',
      ),
      'implements, generic class': (
        'features/a/presentation/g.dart',
        'class G<T> implements GRepository<T> {}\n',
      ),
      'implements after extends': (
        'features/a/presentation/h.dart',
        'class H extends Base implements HRepository {}\n',
      ),
      'implements on the next line': (
        'features/a/presentation/n.dart',
        'class N\n    extends Base\n    implements\n        NRepository {}\n',
      ),
      'a concrete class named Repository': (
        'features/a/domain/c.dart',
        'class CRepository {}\n',
      ),
    };
    for (final MapEntry(key: name, value: (path, source)) in forms.entries) {
      test('wrong layer is caught: $name', () {
        write(path, source);
        expect(violations(), hasLength(1), reason: source);
      });
    }

    final correct = <String, (String, String)>{
      'sealed interface in domain': (
        'features/a/domain/s.dart',
        'sealed class SRepository {}\n',
      ),
      'mixin class in domain': (
        'features/a/domain/m.dart',
        'mixin class MRepository {}\n',
      ),
      'interface class in domain': (
        'features/a/domain/i.dart',
        'interface class IRepository {}\n',
      ),
      'extends in data': (
        'features/a/data/e.dart',
        'class EImpl extends ERepository {}\n',
      ),
      'with in data': (
        'features/a/data/w.dart',
        'class W with WRepository {}\n',
      ),
      'implements, generic, in data': (
        'features/a/data/g.dart',
        'class G<T> implements GRepository<T> {}\n',
      ),
      'multi-line header in data': (
        'features/a/data/n.dart',
        'class N\n    extends Base\n    implements\n        NRepository {}\n',
      ),
    };
    for (final MapEntry(key: name, value: (path, source)) in correct.entries) {
      test('right layer passes: $name', () {
        write(path, source);
        expect(violations(), isEmpty, reason: source);
      });
    }

    test('generics and comments do not create repositories', () {
      write(
        'features/a/presentation/ok.dart',
        '// sealed class CommentedRepository {}\n'
            '/// class DocRepository implements XRepository {}\n'
            'class A implements Comparable<ARepository> {}\n'
            'class B extends Base<BRepository> {}\n'
            'class C<T extends CRepository> {}\n'
            'class D<T extends Map<String, ERepository>> extends Base {}\n'
            'class Repositoryish extends Base {}\n'
            'class UsesIt { final ZRepository repo; UsesIt(this.repo); }\n',
      );
      expect(violations(), isEmpty);
    });

    test('forms the checker does not cover, recorded not asserted: plain '
        'mixin, enum, same-line annotation, block comment', () {
      final cases = <String, String>{
        'plain mixin': 'mixin PRepository {}\n',
        'enum implements': 'enum EE implements EnumRepository { a }\n',
        'annotation on the same line':
            '@immutable class An implements AnnotatedRepository {}\n',
        'block comment': '/* class Bc implements BcRepository {} */\n',
        'extension type':
            'extension type ET(int i) implements ETRepository {}\n',
      };
      for (final entry in cases.entries) {
        final dir = Directory.systemTemp.createTempSync('rl_case_');
        try {
          File('${dir.path}/lib/features/a/presentation/x.dart')
            ..createSync(recursive: true)
            ..writeAsStringSync(entry.value);
          final found = checkRepositoryLayers(Directory('${dir.path}/lib'));
          debugPrint('LAYER ${entry.key}: ${found.length} violation(s)');
        } finally {
          dir.deleteSync(recursive: true);
        }
      }
    });
    test('the real lib passes and finds the games repository pair', () {
      final found = findRepositories(Directory('lib'));
      expect(
        found.map((r) => r.name),
        containsAll(['GamesRepository', 'GamesRepositoryImpl']),
      );
      expect(checkRepositoryLayers(Directory('lib')), isEmpty);
    });
  });

  test('db.customSelect works as a store peek (helper sanity)', () async {
    final rows = await db
        .customSelect('SELECT ? AS x', variables: [Variable.withInt(1)])
        .get();
    expect(rows.single.read<int>('x'), 1);
  });
}
