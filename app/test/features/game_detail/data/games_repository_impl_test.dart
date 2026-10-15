// T-029: the games repository against a fake remote data source and the
// real LocalGameStore on an in-memory database. Answers come from the
// recorded api_contract fixtures; times come from a fixed clock.
import 'package:board_game_collector/core/data/database/app_database.dart';
import 'package:board_game_collector/core/data/database/local_game_store.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:board_game_collector/features/game_detail/data/game_details_codec.dart';
import 'package:board_game_collector/features/game_detail/data/games_repository_impl.dart';
import 'package:board_game_collector/features/game_detail/domain/barcode_lookup.dart';
import 'package:board_game_collector/features/game_detail/domain/game_details.dart';
import 'package:board_game_collector/features/game_detail/domain/game_details_snapshot.dart';
import 'package:board_game_collector/features/game_detail/domain/game_lookup_result.dart';
import 'package:board_game_collector/features/game_detail/domain/game_search_results.dart';
import 'package:board_game_collector/features/game_detail/domain/game_summary.dart';
import 'package:board_game_collector/features/game_detail/domain/games_repository.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_games.dart';
import '../../../helpers/test_database.dart';

/// The fixed "now" of every test.
final DateTime _now = DateTime.utc(2026, 10, 14, 12);

/// A time well before [_now], for things stored earlier.
final DateTime _earlier = DateTime.utc(2026, 10, 11, 9, 30);

const String _upc = '036000291452';
const String _key = '0036000291452';

const GameSummary _catanSummary = GameSummary(
  bggId: 13,
  name: 'Catan',
  yearPublished: 1995,
  bggUrl: 'https://boardgamegeek.com/boardgame/13',
);

const GameSummary _carcassonne = GameSummary(
  bggId: 822,
  name: 'Carcassonne',
  yearPublished: 2000,
  bggUrl: 'https://boardgamegeek.com/boardgame/822',
);

/// Runs [body] with the clock fixed at [_now].
Future<T> _atNow<T>(Future<T> Function() body) =>
    withClock(Clock.fixed(_now), body);

void main() {
  late AppDatabase db;
  late LocalGameStore store;
  late StoreSpy spy;
  late FakeGamesRemote remote;
  late List<String> logs;
  late GamesRepositoryImpl repository;
  late GameDetails catan;

  setUp(() {
    db = inMemoryDatabase();
    store = LocalGameStore(db);
    spy = StoreSpy(store);
    remote = FakeGamesRemote();
    logs = [];
    repository = GamesRepositoryImpl(
      remote: remote,
      detailsCache: spy,
      matchStore: spy,
      log: logs.add,
    );
    catan = detailsFixture('game_detail/full.json');
  });

  tearDown(() => db.close());

  Future<void> storeMatch(int bggId, {DateTime? at}) async {
    final saved = await store.saveConfirmedMatch(
      gtin13: _key,
      bggId: bggId,
      confirmedAt: at ?? _earlier,
    );
    expect(saved.isOk, isTrue);
  }

  Future<void> cacheDetails(
    GameDetails details, {
    String? json,
    DateTime? fetchedAt,
  }) async {
    final saved = await store.saveDetails(
      bggId: details.bggId,
      detailsJson: json ?? encodeCachedDetails(details),
      fetchedAt: fetchedAt ?? _earlier,
    );
    expect(saved.isOk, isTrue);
  }

  Future<ConfirmedMatch?> storedMatch() async =>
      (await store.readConfirmedMatch(_key)).valueOrNull;

  group('AC1: a stored confirmed match answers without a request', () {
    test('a lookup for $_upc finds the match stored for $_key', () async {
      await storeMatch(13);

      final result = await _atNow(
        () => repository.lookupBarcode(barcodeOf(_upc)),
      );

      expect(
        result,
        Ok<GameLookupResult>(
          GameLookupResult.confirmedOnDevice(
            gtin13: _key,
            bggId: 13,
            confirmedAt: _earlier,
          ),
        ),
      );
      expect(result.valueOrNull?.matchedBggId, 13);
      expect(remote.calls, 0);
    });

    test('with cached details, the match carries the game summary', () async {
      await storeMatch(13);
      await cacheDetails(catan);

      final result = await repository.lookupBarcode(barcodeOf(_upc));

      final match = result.valueOrNull! as ConfirmedOnDevice;
      expect(match.game, _catanSummary);
      expect(remote.calls, 0);
    });

    test('unreadable cached details leave the summary out', () async {
      await storeMatch(13);
      await cacheDetails(catan, json: '{"bggId": 13');

      final result = await repository.lookupBarcode(barcodeOf(_upc));

      final match = result.valueOrNull! as ConfirmedOnDevice;
      expect(match.bggId, 13);
      expect(match.game, isNull);
      expect(remote.calls, 0);
      expect(logs, ['GamesRepository.decodeDetails failed: FormatException']);
    });

    test('cached details of another game leave the summary out', () async {
      await storeMatch(13);
      final carcassonneJson = encodeCachedDetails(
        catan.copyWith(
          bggId: 822,
          bggUrl: 'https://boardgamegeek.com/boardgame/822',
        ),
      );
      await cacheDetails(catan, json: carcassonneJson);

      final result = await repository.lookupBarcode(barcodeOf(_upc));

      expect((result.valueOrNull! as ConfirmedOnDevice).game, isNull);
      expect(logs, ['GamesRepository.decodeDetails failed: wrong game']);
    });

    test(
      'a match store that cannot be read falls back to the backend',
      () async {
        spy.failNextMatchRead = true;
        remote.lookupResult = Ok(lookupFixture('lookup/candidates.json'));

        final result = await repository.lookupBarcode(barcodeOf(_upc));

        expect(result.valueOrNull, isA<FromBackend>());
        expect(remote.lookups.single.gtin13, _key);
        expect(logs, [
          'GamesRepository.readConfirmedMatch failed: StorageFailure',
        ]);
      },
    );
  });

  group('AC2: a single backend match is stored as confirmed', () {
    test('status matched with one game stores it for the barcode', () async {
      final lookup = lookupFixture('lookup/matched.json');
      remote.lookupResult = Ok(lookup);

      final result = await _atNow(
        () => repository.lookupBarcode(barcodeOf(_upc)),
      );

      expect(
        result,
        Ok<GameLookupResult>(GameLookupResult.fromBackend(lookup)),
      );
      expect(result.valueOrNull?.matchedBggId, 13);
      final match = await storedMatch();
      expect(match?.bggId, 13);
      expect(match?.confirmedAt, _now);
    });

    test('the next lookup answers from the device', () async {
      remote.lookupResult = Ok(lookupFixture('lookup/matched.json'));
      await repository.lookupBarcode(barcodeOf(_upc));
      expect(remote.calls, 1);

      final again = await repository.lookupBarcode(barcodeOf(_key));

      expect(again.valueOrNull, isA<ConfirmedOnDevice>());
      expect(again.valueOrNull?.matchedBggId, 13);
      expect(remote.calls, 1);
    });

    test('a match that cannot be saved is still returned', () async {
      final lookup = lookupFixture('lookup/matched.json');
      remote.lookupResult = Ok(lookup);
      spy.failMatchSaves = true;

      final result = await repository.lookupBarcode(barcodeOf(_upc));

      expect(
        result,
        Ok<GameLookupResult>(GameLookupResult.fromBackend(lookup)),
      );
      expect(await storedMatch(), isNull);
      expect(logs, [
        'GamesRepository.saveConfirmedMatch failed: StorageFailure',
      ]);
    });

    test('a matched answer for another code is refused', () async {
      remote.lookupResult = Ok(
        lookupFixture('lookup/matched.json').copyWith(gtin13: '4006381333931'),
      );

      final result = await repository.lookupBarcode(barcodeOf(_upc));

      expect(result, const Err<GameLookupResult>(UnexpectedFailure()));
      expect(await storedMatch(), isNull);
      expect(spy.calls, ['readConfirmedMatch']);
      expect(logs, ['GamesRepository.lookupBarcode failed: UnexpectedFailure']);
    });

    test('a failed lookup is returned unchanged and stores nothing', () async {
      remote.lookupResult = const Err(NoConnectionFailure());

      final result = await repository.lookupBarcode(barcodeOf(_upc));

      expect(result, const Err<GameLookupResult>(NoConnectionFailure()));
      expect(await storedMatch(), isNull);
      expect(spy.calls, ['readConfirmedMatch']);
    });
  });

  group('AC3: confirming a different game replaces the stored match', () {
    test('confirming 822 replaces the match to 13', () async {
      await storeMatch(13);

      final result = await _atNow(
        () => repository.confirmMatch(barcodeOf(_upc), 822),
      );

      expect(result.isOk, isTrue);
      final match = await storedMatch();
      expect(match?.bggId, 822);
      expect(match?.confirmedAt, _now);
      final lookup = await repository.lookupBarcode(barcodeOf(_upc));
      expect(lookup.valueOrNull?.matchedBggId, 822);
      expect(remote.calls, 0);
    });

    test('confirming a code with no match stores it', () async {
      final result = await repository.confirmMatch(barcodeOf(_upc), 13);

      expect(result.isOk, isTrue);
      expect((await storedMatch())?.bggId, 13);
    });

    test('a game id below 1 is refused and the match is unchanged', () async {
      await storeMatch(13);

      for (final bggId in [0, -5]) {
        final result = await repository.confirmMatch(barcodeOf(_upc), bggId);
        expect(
          result,
          const Err<void>(InvalidInputFailure(InvalidInputCode.invalidBggId)),
        );
      }
      expect((await storedMatch())?.bggId, 13);
      expect(spy.calls, isEmpty);
    });

    test('a store that cannot save gives StorageFailure', () async {
      spy.failMatchSaves = true;

      final result = await repository.confirmMatch(barcodeOf(_upc), 822);

      expect(result, const Err<void>(StorageFailure()));
    });
  });

  group('AC4: a successful load is fresh, cached, and marked viewed', () {
    test('loading bggId 13 online', () async {
      remote.fetchResult = Ok(catan);

      final result = await _atNow(() => repository.getGame(13));

      expect(
        result,
        Ok(
          GameDetailsSnapshot(
            details: catan,
            freshness: DataFreshness.fresh,
            fetchedAt: _now,
          ),
        ),
      );
      expect(result.valueOrNull?.isStale, isFalse);
      expect(result.valueOrNull?.refreshFailure, isNull);
      expect(remote.fetches, [13]);
      final cached = (await store.readDetails(13)).valueOrNull!;
      expect(decodeCachedDetails(cached.detailsJson), catan);
      expect(cached.fetchedAt, _now);
      expect(cached.lastViewedAt, _now);
    });

    test('details of another game are refused and not cached', () async {
      remote.fetchResult = Ok(
        catan.copyWith(
          bggId: 822,
          bggUrl: 'https://boardgamegeek.com/boardgame/822',
        ),
      );

      final result = await repository.getGame(13);

      expect(result, const Err<GameDetailsSnapshot>(UnexpectedFailure()));
      expect(spy.calls, ['readDetails'], reason: 'no copy, nothing saved');
      expect(await db.select(db.games).get(), isEmpty);
      expect(logs, ['GamesRepository.getGame failed: UnexpectedFailure']);
    });

    test('details of another game fall back to the cached copy', () async {
      await cacheDetails(catan, fetchedAt: _earlier);
      remote.fetchResult = Ok(
        catan.copyWith(
          name: 'Carcassonne',
          bggId: 822,
          bggUrl: 'https://boardgamegeek.com/boardgame/822',
        ),
      );

      final result = await _atNow(() => repository.getGame(13));

      expect(result.valueOrNull?.isStale, isTrue);
      expect(result.valueOrNull?.details, catan);
      expect(spy.calls, isNot(contains('saveDetails')));
      final cached = (await store.readDetails(13)).valueOrNull!;
      expect(decodeCachedDetails(cached.detailsJson), catan);
    });

    test('a fresh load replaces an older cached copy', () async {
      await cacheDetails(catan.copyWith(name: 'Old name'));
      remote.fetchResult = Ok(catan);

      await _atNow(() => repository.getGame(13));

      final cached = (await store.readDetails(13)).valueOrNull!;
      expect(decodeCachedDetails(cached.detailsJson).name, 'Catan');
      expect(cached.fetchedAt, _now);
    });

    test('a cache that cannot be written still returns fresh data', () async {
      final failing = FailingInterceptor();
      final failingDb = inMemoryDatabase(interceptor: failing);
      addTearDown(failingDb.close);
      final failingStore = LocalGameStore(failingDb);
      final repo = GamesRepositoryImpl(
        remote: remote,
        detailsCache: failingStore,
        matchStore: failingStore,
        log: logs.add,
      );
      remote.fetchResult = Ok(catan);
      failing.failing = true;

      final result = await _atNow(() => repo.getGame(13));

      expect(result.valueOrNull?.freshness, DataFreshness.fresh);
      expect(result.valueOrNull?.details, catan);
      expect(logs, ['GamesRepository.saveDetails failed: StorageFailure']);
    });
  });

  group('AC5: when loading fails, the cached copy is returned stale', () {
    // Every failure serves the cached copy (PRD 8.2; orchestrator decision
    // in round 2, review R1-G2), not only the network ones.
    final failures = <String, Failure>{
      'no connection': const NoConnectionFailure(),
      'timeout': const TimeoutFailure(),
      'service unavailable': const ServiceUnavailableFailure(),
      'rate limited': const RateLimitedFailure(
        retryAfter: Duration(seconds: 30),
      ),
      'not found': const NotFoundFailure(),
      'invalid input': const InvalidInputFailure(InvalidInputCode.invalidBggId),
      'access denied': const AccessDeniedFailure(),
      'cancelled': const CancelledFailure(),
      'configuration': const ConfigurationFailure(
        ConfigurationProblem.missingBaseUrl,
      ),
      'storage': const StorageFailure(),
      'unexpected': const UnexpectedFailure(),
    };

    for (final MapEntry(key: name, value: failure) in failures.entries) {
      test('$name with a cached copy', () async {
        await cacheDetails(catan, fetchedAt: _earlier);
        remote.fetchResult = Err(failure);

        final result = await _atNow(() => repository.getGame(13));

        expect(
          result,
          Ok(
            GameDetailsSnapshot(
              details: catan,
              freshness: DataFreshness.stale,
              fetchedAt: _earlier,
              refreshFailure: failure,
            ),
          ),
        );
        expect(result.valueOrNull?.isStale, isTrue);
        final cached = (await store.readDetails(13)).valueOrNull!;
        expect(cached.lastViewedAt, _now, reason: 'the view is recorded');
        expect(cached.fetchedAt, _earlier, reason: 'the copy is not renewed');
      });

      test('$name without a cached copy is returned unchanged', () async {
        remote.fetchResult = Err(failure);

        final result = await repository.getGame(13);

        expect(result, Err<GameDetailsSnapshot>(failure));
        expect(spy.calls, ['readDetails']);
      });
    }

    test('a cache that cannot be read gives the load failure', () async {
      final failing = FailingInterceptor();
      final failingDb = inMemoryDatabase(interceptor: failing);
      addTearDown(failingDb.close);
      final failingStore = LocalGameStore(failingDb);
      final repo = GamesRepositoryImpl(
        remote: remote,
        detailsCache: failingStore,
        matchStore: failingStore,
        log: logs.add,
      );
      remote.fetchResult = const Err(TimeoutFailure());
      failing.failing = true;

      final result = await repo.getGame(13);

      expect(result, const Err<GameDetailsSnapshot>(TimeoutFailure()));
      expect(logs, ['GamesRepository.readDetails failed: StorageFailure']);
    });

    test('an unreadable cached copy gives the load failure', () async {
      await cacheDetails(catan, json: '[1, 2]');
      remote.fetchResult = const Err(NoConnectionFailure());

      final result = await repository.getGame(13);

      expect(result, const Err<GameDetailsSnapshot>(NoConnectionFailure()));
      expect(logs, ['GamesRepository.decodeDetails failed: FormatException']);
    });

    test('a copy whose BGG link breaks the contract is not used', () async {
      await cacheDetails(
        catan,
        json: encodeCachedDetails(
          catan.copyWith(bggUrl: 'https://evil.example/boardgame/13'),
        ),
      );
      remote.fetchResult = const Err(NoConnectionFailure());

      final result = await repository.getGame(13);

      expect(result, const Err<GameDetailsSnapshot>(NoConnectionFailure()));
    });

    test('a view that cannot be recorded still returns the copy', () async {
      final noViews = _FailingMarkViewed(store);
      final repo = GamesRepositoryImpl(
        remote: remote,
        detailsCache: noViews,
        matchStore: noViews,
        log: logs.add,
      );
      await cacheDetails(catan);
      remote.fetchResult = const Err(NoConnectionFailure());

      final result = await repo.getGame(13);

      expect(result.valueOrNull?.isStale, isTrue);
      expect(logs, ['GamesRepository.markViewed failed: StorageFailure']);
    });
  });

  group('AC6: no cached copy and no connection', () {
    test('gives the no connection failure', () async {
      remote.fetchResult = const Err(NoConnectionFailure());

      final result = await repository.getGame(13);

      expect(result, const Err<GameDetailsSnapshot>(NoConnectionFailure()));
      expect(spy.calls, ['readDetails']);
      expect((await store.readDetails(13)).valueOrNull, isNull);
    });
  });

  group('AC7: title search is not cached', () {
    test('results pass through and nothing is stored', () async {
      final results = searchFixture('search/results.json');
      remote.searchResult = Ok(results);

      final result = await repository.searchGames('catan');

      expect(result, Ok(results));
      expect(remote.searches, ['catan']);
      expect(spy.calls, isEmpty);
      expect(await db.select(db.games).get(), isEmpty);
      expect(await db.select(db.barcodeMatches).get(), isEmpty);
    });

    final failures = <Failure>[
      const NoConnectionFailure(),
      const TimeoutFailure(),
      const RateLimitedFailure(retryAfter: Duration(seconds: 30)),
      const ServiceUnavailableFailure(),
      const InvalidInputFailure(InvalidInputCode.invalidQuery),
      const CancelledFailure(),
      const UnexpectedFailure(),
    ];
    for (final failure in failures) {
      test('$failure passes through unchanged', () async {
        remote.searchResult = Err(failure);

        final result = await repository.searchGames('ca');

        expect(result, Err<GameSearchResults>(failure));
        expect(spy.calls, isEmpty);
      });
    }
  });

  group('AC10: only a matched answer for the looked-up code is stored', () {
    final cases = <String, BarcodeLookup>{
      'candidates (3 games)': lookupFixture('lookup/candidates.json'),
      'none': const BarcodeLookup(
        gtin13: _key,
        status: BarcodeLookupStatus.none,
        games: [],
      ),
      'unavailable': const BarcodeLookup(
        gtin13: _key,
        status: BarcodeLookupStatus.unavailable,
        games: [],
      ),
      'unknown with one game': const BarcodeLookup(
        gtin13: _key,
        status: BarcodeLookupStatus.unknown,
        games: [_catanSummary],
      ),
      'unknown with no games': const BarcodeLookup(
        gtin13: _key,
        status: BarcodeLookupStatus.unknown,
        games: [],
      ),
      'matched for a different code': const BarcodeLookup(
        gtin13: '4006381333931',
        status: BarcodeLookupStatus.matched,
        games: [_catanSummary],
      ),
      'matched with two games': const BarcodeLookup(
        gtin13: _key,
        status: BarcodeLookupStatus.matched,
        games: [_catanSummary, _carcassonne],
      ),
    };

    test('the candidates fixture is for $_key with 3 games', () {
      final candidates = cases['candidates (3 games)']!;
      expect(candidates.gtin13, _key);
      expect(candidates.status, BarcodeLookupStatus.candidates);
      expect(candidates.games, hasLength(3));
    });

    for (final MapEntry(key: name, value: lookup) in cases.entries) {
      test('$name: nothing is stored when no match existed', () async {
        remote.lookupResult = Ok(lookup);

        final result = await repository.lookupBarcode(barcodeOf(_upc));

        // An answer for another code is a broken contract (T-028 D2), so
        // it is a failure rather than a result to show.
        expect(
          result,
          lookup.gtin13 == _key
              ? Ok<GameLookupResult>(GameLookupResult.fromBackend(lookup))
              : const Err<GameLookupResult>(UnexpectedFailure()),
        );
        expect(result.valueOrNull?.matchedBggId, isNull);
        expect(await storedMatch(), isNull);
        expect(spy.calls, ['readConfirmedMatch']);
      });

      test('$name: an earlier match is unchanged', () async {
        await storeMatch(822, at: _earlier);
        // The stored match normally answers first; hiding it once sends the
        // lookup to the backend, so its answer is what is being tested, and
        // the repository is free to save (review R1-S1).
        spy.hideNextMatch = true;
        remote.lookupResult = Ok(lookup);

        await _atNow(() => repository.lookupBarcode(barcodeOf(_upc)));

        expect(remote.calls, 1);
        final match = await storedMatch();
        expect(match?.bggId, 822);
        expect(match?.confirmedAt, _earlier);
      });
    }

    test('matched for $_key replaces a hidden earlier match (control: the '
        'runs above could see a write)', () async {
      await storeMatch(822, at: _earlier);
      spy.hideNextMatch = true;
      remote.lookupResult = Ok(lookupFixture('lookup/matched.json'));

      await _atNow(() => repository.lookupBarcode(barcodeOf(_upc)));

      final match = await storedMatch();
      expect(match?.bggId, 13);
      expect(match?.confirmedAt, _now);
    });

    test('a matched answer is not saved when the stored match could not '
        'be read, so an earlier choice of 822 survives (R1-S1)', () async {
      await storeMatch(822, at: _earlier);
      spy.failNextMatchRead = true;
      final lookup = lookupFixture('lookup/matched.json');
      remote.lookupResult = Ok(lookup);

      final result = await _atNow(
        () => repository.lookupBarcode(barcodeOf(_upc)),
      );

      expect(
        result,
        Ok<GameLookupResult>(GameLookupResult.fromBackend(lookup)),
      );
      expect(result.valueOrNull?.matchedBggId, 13);
      final match = await storedMatch();
      expect(match?.bggId, 822);
      expect(match?.confirmedAt, _earlier);
      expect(spy.calls, ['readConfirmedMatch']);
      expect(logs, [
        'GamesRepository.readConfirmedMatch failed: StorageFailure',
        'GamesRepository.saveConfirmedMatch skipped: stored match unknown',
      ]);
    });

    test('isStorableMatch accepts only matched, same code, one game', () {
      final barcode = barcodeOf(_upc);
      expect(
        isStorableMatch(lookupFixture('lookup/matched.json'), barcode),
        isTrue,
      );
      for (final lookup in cases.values) {
        expect(isStorableMatch(lookup, barcode), isFalse, reason: '$lookup');
      }
    });
  });

  group('servesCachedCopy', () {
    test('is true for every failure type (round 2, R1-G2)', () {
      const all = <Failure>[
        NoConnectionFailure(),
        TimeoutFailure(),
        ServiceUnavailableFailure(),
        RateLimitedFailure(),
        NotFoundFailure(),
        InvalidInputFailure(InvalidInputCode.unknown),
        InvalidBarcodeFailure(InvalidBarcodeReason.badCheckDigit, length: 12),
        AccessDeniedFailure(),
        CancelledFailure(),
        ConfigurationFailure(ConfigurationProblem.insecureBaseUrl),
        StorageFailure(),
        UnexpectedFailure(),
      ];
      for (final failure in all) {
        expect(servesCachedCopy(failure), isTrue, reason: '$failure');
      }
    });
  });

  test('the implementation is a GamesRepository (AC8)', () {
    expect(repository, isA<GamesRepository>());
  });
}

/// A details cache whose markViewed always fails; the rest delegates.
class _FailingMarkViewed extends StoreSpy {
  _FailingMarkViewed(super.store);

  @override
  Future<Result<void>> markViewed(int bggId, DateTime viewedAt) async =>
      const Err(StorageFailure());
}
