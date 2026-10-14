import 'dart:io';

import 'package:board_game_collector/core/data/database/app_database.dart';
import 'package:board_game_collector/core/data/database/local_game_store.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../drift/app_database/generated/schema.dart';
import '../helpers/test_database.dart';

// QA edge cases for T-027: eviction boundaries, ties, time round trips,
// unicode, concurrency, file-level errors, and transaction rollback.

final DateTime _t0 = DateTime.utc(2026, 10, 13, 12);
DateTime _at(int minutes) => _t0.add(Duration(minutes: minutes));
String _json(int id) => '{"bggId":$id}';

T _ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected Ok, got $failure'),
};

void main() {
  indexTests();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late LocalGameStore store;

  setUp(() {
    db = inMemoryDatabase();
    store = LocalGameStore(db);
  });
  tearDown(() => db.close());

  Future<int> withDetails() async => (await (db.select(
    db.games,
  )..where((g) => g.detailsJson.isNotNull())).get()).length;
  Future<int> rows() async => (await db.select(db.games).get()).length;

  Future<void> save(int id, int minute, {int? viewed}) async {
    _ok(
      await store.saveDetails(
        bggId: id,
        detailsJson: _json(id),
        fetchedAt: _at(minute),
        viewedAt: viewed == null ? null : _at(viewed),
      ),
    );
  }

  group('eviction boundaries with the default cap of 500', () {
    test('exactly 500 games: nothing is evicted', () async {
      for (var i = 1; i <= 500; i++) {
        await save(i, i);
      }
      expect(await withDetails(), 500);
      expect(_ok(await store.readDetails(1)), isNotNull);
    });

    test('501 games: exactly one evicted, the oldest', () async {
      for (var i = 1; i <= 501; i++) {
        await save(i, i);
      }
      expect(await withDetails(), 500);
      expect(_ok(await store.readDetails(1)), isNull);
      expect(_ok(await store.readDetails(2)), isNotNull);
      expect(_ok(await store.readDetails(501)), isNotNull);
    });

    test('502 games: the two oldest are evicted', () async {
      for (var i = 1; i <= 502; i++) {
        await save(i, i);
      }
      expect(await withDetails(), 500);
      expect(_ok(await store.readDetails(1)), isNull);
      expect(_ok(await store.readDetails(2)), isNull);
      expect(_ok(await store.readDetails(3)), isNotNull);
    });

    test('re-saving an existing game at 500 evicts nothing', () async {
      for (var i = 1; i <= 500; i++) {
        await save(i, i);
      }
      await save(250, 9999);
      expect(await withDetails(), 500);
      expect(await rows(), 500);
    });

    test(
      'a cleared game saved again counts again and evicts another',
      () async {
        for (var i = 1; i <= 501; i++) {
          await save(i, i);
        }
        // Game 1 was evicted (and deleted). Saving it again is a new game.
        await save(1, 1000);
        expect(await withDetails(), 500);
        expect(_ok(await store.readDetails(1)), isNotNull);
        expect(_ok(await store.readDetails(2)), isNull);
      },
    );
  });

  group('eviction order', () {
    test(
      'a view older than the fetch time still counts as the recency',
      () async {
        final small = LocalGameStore(db, maxCachedDetails: 2);
        // A fetched late but viewed long ago; B fetched in between, unviewed.
        _ok(
          await small.saveDetails(
            bggId: 1,
            detailsJson: _json(1),
            fetchedAt: _at(100),
            viewedAt: _at(1),
          ),
        );
        _ok(
          await small.saveDetails(
            bggId: 2,
            detailsJson: _json(2),
            fetchedAt: _at(50),
          ),
        );
        _ok(
          await small.saveDetails(
            bggId: 3,
            detailsJson: _json(3),
            fetchedAt: _at(60),
          ),
        );
        expect(_ok(await small.readDetails(1)), isNull);
        expect(_ok(await small.readDetails(2)), isNotNull);
      },
    );

    test('markViewed protects a game from eviction', () async {
      final small = LocalGameStore(db, maxCachedDetails: 2);
      await small.saveDetails(
        bggId: 1,
        detailsJson: _json(1),
        fetchedAt: _at(1),
      );
      await small.saveDetails(
        bggId: 2,
        detailsJson: _json(2),
        fetchedAt: _at(2),
      );
      _ok(await small.markViewed(1, _at(10)));
      await small.saveDetails(
        bggId: 3,
        detailsJson: _json(3),
        fetchedAt: _at(3),
      );
      expect(_ok(await small.readDetails(1)), isNotNull);
      expect(_ok(await small.readDetails(2)), isNull);
    });

    test(
      'identical view and fetch times: the first stored goes first',
      () async {
        final small = LocalGameStore(db, maxCachedDetails: 3);
        for (var i = 1; i <= 3; i++) {
          _ok(
            await small.saveDetails(
              bggId: i,
              detailsJson: _json(i),
              fetchedAt: _at(5),
              viewedAt: _at(5),
            ),
          );
        }
        for (var i = 4; i <= 5; i++) {
          _ok(
            await small.saveDetails(
              bggId: i,
              detailsJson: _json(i),
              fetchedAt: _at(5),
              viewedAt: _at(5),
            ),
          );
          expect(await withDetails(), 3);
        }
        // Ties go to the lowest internal id, so 1 and 2 are gone.
        expect(_ok(await small.readDetails(1)), isNull);
        expect(_ok(await small.readDetails(2)), isNull);
        expect(_ok(await small.readDetails(3)), isNotNull);
      },
    );

    test('times differing only below a millisecond count as ties', () async {
      final small = LocalGameStore(db, maxCachedDetails: 1);
      _ok(
        await small.saveDetails(
          bggId: 1,
          detailsJson: _json(1),
          fetchedAt: DateTime.utc(2026, 1, 1, 0, 0, 0, 5, 900),
        ),
      );
      _ok(
        await small.saveDetails(
          bggId: 2,
          detailsJson: _json(2),
          fetchedAt: DateTime.utc(2026, 1, 1, 0, 0, 0, 5, 100),
        ),
      );
      // Game 2 is the one just saved, so it stays whatever the tie says.
      expect(_ok(await small.readDetails(2)), isNotNull);
      expect(_ok(await small.readDetails(1)), isNull);
    });

    test('the game just saved survives even with the oldest times', () async {
      final small = LocalGameStore(db, maxCachedDetails: 1);
      await small.saveDetails(
        bggId: 1,
        detailsJson: _json(1),
        fetchedAt: _at(500),
        viewedAt: _at(500),
      );
      _ok(
        await small.saveDetails(
          bggId: 2,
          detailsJson: _json(2),
          fetchedAt: DateTime.utc(1970),
        ),
      );
      expect(_ok(await small.readDetails(2)), isNotNull);
      expect(_ok(await small.readDetails(1)), isNull);
      expect(await withDetails(), 1);
    });

    test(
      'with cap 1 the same game saved repeatedly keeps its details',
      () async {
        final small = LocalGameStore(db, maxCachedDetails: 1);
        for (var i = 0; i < 3; i++) {
          await small.saveDetails(
            bggId: 7,
            detailsJson: _json(7),
            fetchedAt: _at(i),
          );
        }
        expect(await rows(), 1);
        expect(_ok(await small.readDetails(7)), isNotNull);
      },
    );

    test('evicting match-pointed games keeps their rows and the cap', () async {
      final small = LocalGameStore(db, maxCachedDetails: 2);
      for (var i = 1; i <= 2; i++) {
        await small.saveDetails(
          bggId: i,
          detailsJson: _json(i),
          fetchedAt: _at(i),
        );
        await small.saveConfirmedMatch(
          gtin13: '000000000000$i',
          bggId: i,
          confirmedAt: _at(i),
        );
      }
      for (var i = 3; i <= 6; i++) {
        await small.saveDetails(
          bggId: i,
          detailsJson: _json(i),
          fetchedAt: _at(i),
        );
      }
      expect(await withDetails(), 2);
      // Games 1 and 2 lost details but their rows (and matches) remain.
      expect(_ok(await small.readDetails(1)), isNull);
      expect(_ok(await small.readConfirmedMatch('0000000000001'))?.bggId, 1);
      expect(_ok(await small.readConfirmedMatch('0000000000002'))?.bggId, 2);
      // 3 and 4 were evicted with no match, so their rows are gone.
      expect(await rows(), 4);
    });
  });

  group('replace on new match', () {
    test(
      'replacing leaves one match row and removes the orphan game',
      () async {
        _ok(
          await store.saveConfirmedMatch(
            gtin13: '0036000291452',
            bggId: 13,
            confirmedAt: _at(1),
          ),
        );
        _ok(
          await store.saveConfirmedMatch(
            gtin13: '0036000291452',
            bggId: 822,
            confirmedAt: _at(2),
          ),
        );
        expect(await db.select(db.barcodeMatches).get(), hasLength(1));
        final games = await db.select(db.games).get();
        expect(games.map((g) => g.bggId), [822]);
      },
    );

    test(
      'confirming the same code and game again updates the time only',
      () async {
        for (final m in [1, 2]) {
          _ok(
            await store.saveConfirmedMatch(
              gtin13: '0036000291452',
              bggId: 13,
              confirmedAt: _at(m),
            ),
          );
        }
        expect(await rows(), 1);
        expect(
          _ok(await store.readConfirmedMatch('0036000291452'))?.confirmedAt,
          _at(2),
        );
      },
    );

    test('replacing back and forth 20 times still leaves one row', () async {
      for (var i = 0; i < 20; i++) {
        _ok(
          await store.saveConfirmedMatch(
            gtin13: '0036000291452',
            bggId: i.isEven ? 13 : 822,
            confirmedAt: _at(i),
          ),
        );
      }
      expect(await db.select(db.barcodeMatches).get(), hasLength(1));
      expect(await rows(), 1);
      expect(_ok(await store.readConfirmedMatch('0036000291452'))?.bggId, 822);
    });

    test(
      'replacing a match keeps a game that still has another code',
      () async {
        await store.saveConfirmedMatch(
          gtin13: '0000000000001',
          bggId: 13,
          confirmedAt: _at(1),
        );
        await store.saveConfirmedMatch(
          gtin13: '0000000000002',
          bggId: 13,
          confirmedAt: _at(1),
        );
        await store.saveConfirmedMatch(
          gtin13: '0000000000001',
          bggId: 822,
          confirmedAt: _at(2),
        );
        expect(_ok(await store.readConfirmedMatch('0000000000002'))?.bggId, 13);
        expect(await rows(), 2);
      },
    );

    test('leading zeros in the key are kept, not read as a number', () async {
      await store.saveConfirmedMatch(
        gtin13: '0000000000017',
        bggId: 5,
        confirmedAt: _at(1),
      );
      expect(_ok(await store.readConfirmedMatch('0000000000017'))?.bggId, 5);
      expect(_ok(await store.readConfirmedMatch('17')), isNull);
      expect(_ok(await store.readConfirmedMatch('0000000000018')), isNull);
    });
  });

  group('input values', () {
    test('unicode, emoji, and an embedded NUL in details round trip', () async {
      const text = '{"name":"Café & Co é中文 \u{1F3B2} Ünïcode","x":"a\u0000b"}';
      _ok(
        await store.saveDetails(bggId: 1, detailsJson: text, fetchedAt: _at(0)),
      );
      expect(_ok(await store.readDetails(1))?.detailsJson, text);
    });

    test('a 5 MB details string round trips', () async {
      final text = '{"d":"${'x' * (5 * 1024 * 1024)}"}';
      _ok(
        await store.saveDetails(bggId: 1, detailsJson: text, fetchedAt: _at(0)),
      );
      expect(_ok(await store.readDetails(1))?.detailsJson.length, text.length);
    });

    test('an empty details string is still cached details', () async {
      _ok(
        await store.saveDetails(bggId: 1, detailsJson: '', fetchedAt: _at(0)),
      );
      expect(_ok(await store.readDetails(1))?.detailsJson, '');
    });

    test('the largest 64 bit BGG id round trips', () async {
      const big = 9223372036854775807;
      _ok(
        await store.saveDetails(
          bggId: big,
          detailsJson: '{}',
          fetchedAt: _at(0),
        ),
      );
      expect(_ok(await store.readDetails(big))?.bggId, big);
    });

    test('null last view reads as null, set view reads back', () async {
      await save(1, 0);
      expect(_ok(await store.readDetails(1))?.lastViewedAt, isNull);
      await save(1, 0, viewed: 3);
      expect(_ok(await store.readDetails(1))?.lastViewedAt, _at(3));
    });

    for (final bad in [
      '',
      '123456789012',
      '12345678901234',
      '003600029145A',
      '003600029145\n',
      ' 003600029145',
      '００３６０００２９１４５２',
      "0036000291452' OR '1'='1",
    ]) {
      test(
        'a bad key ${bad.codeUnits.length} units long is StorageFailure and stores nothing',
        () async {
          final r = await store.saveConfirmedMatch(
            gtin13: bad,
            bggId: 13,
            confirmedAt: _at(0),
          );
          expect(r.failureOrNull, const StorageFailure());
          expect(await db.select(db.barcodeMatches).get(), isEmpty);
          // The failed save also left no game row behind.
          expect(await rows(), 0);
        },
      );

      test(
        'reading a bad key ${bad.codeUnits.length} units long returns null',
        () async {
          await store.saveConfirmedMatch(
            gtin13: '0036000291452',
            bggId: 13,
            confirmedAt: _at(0),
          );
          expect(_ok(await store.readConfirmedMatch(bad)), isNull);
        },
      );
    }
  });

  group('UTC and epoch round trips', () {
    final instants = <String, DateTime>{
      'US spring forward 2026-03-08 07:00 UTC': DateTime.utc(2026, 3, 8, 7),
      'US spring forward, one ms before': DateTime.utc(
        2026,
        3,
        8,
        6,
        59,
        59,
        999,
      ),
      'US fall back 2026-11-01 06:00 UTC': DateTime.utc(2026, 11, 1, 6),
      'US fall back, ambiguous hour': DateTime.utc(2026, 11, 1, 5, 30),
      'EU change 2026-03-29 01:00 UTC': DateTime.utc(2026, 3, 29, 1),
      'leap day': DateTime.utc(2028, 2, 29, 23, 59, 59, 999),
      'epoch': DateTime.utc(1970),
      'before the epoch': DateTime.utc(1969, 12, 31, 23, 59, 59, 500),
      'year 2100': DateTime.utc(2100, 1, 1),
      'year 9999': DateTime.utc(9999, 12, 31, 23, 59, 59, 999),
    };
    for (final MapEntry(key: name, value: t) in instants.entries) {
      test('$name round trips as the same UTC instant', () async {
        _ok(
          await store.saveDetails(
            bggId: 1,
            detailsJson: '{}',
            fetchedAt: t,
            viewedAt: t,
          ),
        );
        final read = _ok(await store.readDetails(1))!;
        expect(read.fetchedAt, t);
        expect(read.fetchedAt.isUtc, isTrue);
        expect(read.lastViewedAt, t);
        _ok(
          await store.saveConfirmedMatch(
            gtin13: '0036000291452',
            bggId: 1,
            confirmedAt: t,
          ),
        );
        expect(
          _ok(await store.readConfirmedMatch('0036000291452'))?.confirmedAt,
          t,
        );
      });

      test('$name given as local time is stored as the same instant', () async {
        _ok(
          await store.saveDetails(
            bggId: 1,
            detailsJson: '{}',
            fetchedAt: t.toLocal(),
          ),
        );
        expect(_ok(await store.readDetails(1))?.fetchedAt, t);
      });
    }

    test('stored values are integers in milliseconds', () async {
      await save(1, 0);
      final raw = await db
          .customSelect('SELECT fetched_at, typeof(fetched_at) t FROM games')
          .getSingle();
      expect(raw.read<int>('fetched_at'), _t0.millisecondsSinceEpoch);
      expect(raw.read<String>('t'), 'integer');
    });
  });

  group('concurrent writes', () {
    test('50 parallel saves of different games all land', () async {
      final results = await Future.wait([
        for (var i = 1; i <= 50; i++)
          store.saveDetails(bggId: i, detailsJson: _json(i), fetchedAt: _at(i)),
      ]);
      expect(results.every((r) => r is Ok), isTrue);
      expect(await withDetails(), 50);
    });

    test('parallel saves past the cap leave exactly the cap', () async {
      final small = LocalGameStore(db, maxCachedDetails: 10);
      final results = await Future.wait([
        for (var i = 1; i <= 60; i++)
          small.saveDetails(bggId: i, detailsJson: _json(i), fetchedAt: _at(i)),
      ]);
      expect(results.every((r) => r is Ok), isTrue);
      expect(await withDetails(), 10);
    });

    test('parallel saves of the same game give one row', () async {
      await Future.wait([
        for (var i = 0; i < 30; i++)
          store.saveDetails(bggId: 9, detailsJson: _json(9), fetchedAt: _at(i)),
      ]);
      expect(await rows(), 1);
    });

    test('parallel matches for one code leave one match row', () async {
      final results = await Future.wait([
        for (var i = 1; i <= 20; i++)
          store.saveConfirmedMatch(
            gtin13: '0036000291452',
            bggId: i,
            confirmedAt: _at(i),
          ),
      ]);
      expect(results.every((r) => r is Ok), isTrue);
      expect(await db.select(db.barcodeMatches).get(), hasLength(1));
      expect(await rows(), 1);
    });

    test('reads during writes never throw', () async {
      final futures = <Future<Object?>>[
        for (var i = 1; i <= 20; i++) ...[
          store.saveDetails(bggId: i, detailsJson: _json(i), fetchedAt: _at(i)),
          store.readDetails(i),
          store.markViewed(i, _at(i + 1)),
        ],
      ];
      final all = await Future.wait(futures);
      expect(all.whereType<Err<Object?>>(), isEmpty);
    });
  });

  group('transactions', () {
    test('a failure during eviction rolls the whole save back', () async {
      final fail = _FailOnUpdate();
      final d = inMemoryDatabase(interceptor: fail);
      addTearDown(d.close);
      final small = LocalGameStore(d, maxCachedDetails: 1);
      _ok(
        await small.saveDetails(
          bggId: 1,
          detailsJson: _json(1),
          fetchedAt: _at(1),
        ),
      );
      fail.on = true;
      final r = await small.saveDetails(
        bggId: 2,
        detailsJson: _json(2),
        fetchedAt: _at(2),
      );
      expect(r.failureOrNull, const StorageFailure());
      fail.on = false;
      // Neither the insert of game 2 nor the eviction of game 1 happened.
      expect(_ok(await small.readDetails(2)), isNull);
      expect(_ok(await small.readDetails(1)), isNotNull);
      expect((await d.select(d.games).get()), hasLength(1));
    });

    test('a failed match save leaves no game row and the old match', () async {
      await store.saveConfirmedMatch(
        gtin13: '0036000291452',
        bggId: 13,
        confirmedAt: _at(1),
      );
      final r = await store.saveConfirmedMatch(
        gtin13: '0036000291452',
        bggId: 0,
        confirmedAt: _at(2),
      );
      expect(r.failureOrNull, const StorageFailure());
      expect(_ok(await store.readConfirmedMatch('0036000291452'))?.bggId, 13);
      expect(await rows(), 1);
    });

    test('the database is usable after a failed operation', () async {
      await store.saveConfirmedMatch(
        gtin13: 'bad',
        bggId: 1,
        confirmedAt: _at(0),
      );
      await save(1, 0);
      expect(_ok(await store.readDetails(1)), isNotNull);
    });
  });

  group('file level errors map to StorageFailure', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('t027_qa_'));
    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // A handle may linger on Windows; the temp folder is disposable.
      }
    });

    Future<void> allOperationsFail(LocalGameStore s) async {
      final results = <Result<Object?>>[
        await s.saveDetails(bggId: 1, detailsJson: '{}', fetchedAt: _at(0)),
        await s.readDetails(1),
        await s.markViewed(1, _at(0)),
        await s.saveConfirmedMatch(
          gtin13: '0036000291452',
          bggId: 1,
          confirmedAt: _at(0),
        ),
        await s.readConfirmedMatch('0036000291452'),
      ];
      for (final r in results) {
        expect(r.failureOrNull, const StorageFailure());
      }
    }

    test('a corrupt file (not a database) fails every operation', () async {
      final file = File('${dir.path}/corrupt.sqlite')
        ..writeAsBytesSync(List<int>.generate(8192, (i) => (i * 31 + 7) % 256));
      final d = AppDatabase(NativeDatabase(file));
      addTearDown(d.close);
      final logged = <String>[];
      await allOperationsFail(LocalGameStore(d, log: logged.add));
      expect(logged, hasLength(5));
      // The log names only the error type, never the file path.
      expect(logged.join(), isNot(contains('corrupt.sqlite')));
    });

    test('a truncated database file fails every read and write', () async {
      final file = File('${dir.path}/trunc.sqlite');
      final good = AppDatabase(NativeDatabase(file));
      await LocalGameStore(good)
          .saveDetails(bggId: 1, detailsJson: '{}', fetchedAt: _at(0));
      await good.close();
      final bytes = file.readAsBytesSync();
      // Measured with drift 2.35 and the bundled SQLite: every cut that
      // leaves part of a file ("database disk image is malformed") fails.
      for (final length in [bytes.length ~/ 2 + 3, 100, 4096, 8192]) {
        file.writeAsBytesSync(bytes.sublist(0, length));
        final d = AppDatabase(NativeDatabase(file));
        final logged = <String>[];
        await allOperationsFail(LocalGameStore(d, log: logged.add));
        expect(logged, hasLength(5), reason: 'length $length');
        expect(logged.join(), isNot(contains('trunc.sqlite')));
        await d.close();
      }
    });

    test('a zero byte file is a new empty database, not a failure', () async {
      // Documents behavior: a file cut to nothing silently loses its data.
      final file = File('${dir.path}/empty.sqlite')..writeAsBytesSync([]);
      final d = AppDatabase(NativeDatabase(file));
      addTearDown(d.close);
      final s = LocalGameStore(d);
      expect(_ok(await s.readDetails(1)), isNull);
      _ok(await s.saveDetails(bggId: 1, detailsJson: '{}', fetchedAt: _at(0)));
      expect(_ok(await s.readDetails(1)), isNotNull);
    });

    test('background isolate errors log only the cause type', () async {
      final file = File('${dir.path}/bg_corrupt.sqlite')
        ..writeAsBytesSync(List<int>.generate(8192, (i) => (i * 17 + 3) % 256));
      final d = AppDatabase(NativeDatabase.createInBackground(file));
      addTearDown(d.close);
      final logged = <String>[];
      await allOperationsFail(LocalGameStore(d, log: logged.add));
      expect(logged, hasLength(5));
      for (final line in logged) {
        expect(
          line,
          matches(RegExp(r'^LocalGameStore\.\w+ failed: SqliteException$')),
        );
        expect(line, isNot(contains('bg_corrupt')));
      }
    });

    test('a path that is a directory fails every operation', () async {
      final path = Directory('${dir.path}/folder.sqlite')..createSync();
      final d = AppDatabase(NativeDatabase(File(path.path)));
      addTearDown(d.close);
      await allOperationsFail(LocalGameStore(d));
    });

    test(
      'a database locked by another connection fails, then recovers',
      () async {
        final file = File('${dir.path}/locked.sqlite');
        final holder = AppDatabase(NativeDatabase(file));
        addTearDown(holder.close);
        await holder.customSelect('SELECT 1').get();
        final other = AppDatabase(NativeDatabase(file));
        addTearDown(other.close);
        final s = LocalGameStore(other);
        _ok(
          await s.saveDetails(bggId: 1, detailsJson: '{}', fetchedAt: _at(0)),
        );

        await holder.customStatement('BEGIN EXCLUSIVE');
        final blocked = await s.readDetails(1);
        expect(blocked.failureOrNull, const StorageFailure());
        final blockedWrite = await s.saveDetails(
          bggId: 2,
          detailsJson: '{}',
          fetchedAt: _at(1),
        );
        expect(blockedWrite.failureOrNull, const StorageFailure());

        await holder.customStatement('ROLLBACK');
        expect(_ok(await s.readDetails(1)), isNotNull);
        expect(_ok(await s.readDetails(2)), isNull);
      },
    );

    test(
      'a file from a newer schema version fails and keeps its data',
      () async {
        final file = File('${dir.path}/newer.sqlite');
        final first = AppDatabase(NativeDatabase(file));
        await LocalGameStore(first)
            .saveDetails(bggId: 1, detailsJson: '{}', fetchedAt: _at(0));
        await first.customStatement('PRAGMA user_version = 99');
        await first.close();
        final before = file.readAsBytesSync();

        final d = AppDatabase(NativeDatabase(file));
        final s = LocalGameStore(d);
        final r = await s.readDetails(1);
        expect(r.failureOrNull, const StorageFailure());
        try {
          await d.close();
        } on Object {
          // Closing a database that never opened may complain; irrelevant.
        }

        // The failed open did not touch the file.
        expect(file.readAsBytesSync(), before);
      },
    );

    test('a file survives close and reopen (app restart)', () async {
      final file = File('${dir.path}/restart.sqlite');
      var d = AppDatabase(NativeDatabase(file));
      var s = LocalGameStore(d);
      _ok(
        await s.saveDetails(
          bggId: 1,
          detailsJson: '{"n":"Café"}',
          fetchedAt: _at(0),
          viewedAt: _at(1),
        ),
      );
      _ok(
        await s.saveConfirmedMatch(
          gtin13: '0036000291452',
          bggId: 1,
          confirmedAt: _at(2),
        ),
      );
      await d.close();

      d = AppDatabase(NativeDatabase(file));
      addTearDown(d.close);
      s = LocalGameStore(d);
      expect(_ok(await s.readDetails(1))?.detailsJson, '{"n":"Café"}');
      expect(_ok(await s.readDetails(1))?.lastViewedAt, _at(1));
      expect(_ok(await s.readConfirmedMatch('0036000291452'))?.bggId, 1);
      // Foreign keys are on again after the reopen.
      await expectLater(
        d.customStatement(
          "INSERT INTO barcode_matches VALUES ('0000000000000', 999, 0)",
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test(
      'a v1 file is opened by the current code and the store works on it',
      () async {
        final verifier = SchemaVerifier(GeneratedHelper());
        final schema = await verifier.schemaAt(1);
        final d = AppDatabase(schema.newConnection());
        addTearDown(d.close);
        final s = LocalGameStore(d);
        _ok(
          await s.saveDetails(bggId: 13, detailsJson: '{}', fetchedAt: _at(0)),
        );
        _ok(
          await s.saveConfirmedMatch(
            gtin13: '0036000291452',
            bggId: 13,
            confirmedAt: _at(1),
          ),
        );
        expect(_ok(await s.readConfirmedMatch('0036000291452'))?.bggId, 13);
        final v = await d.customSelect('PRAGMA user_version').getSingle();
        expect(v.read<int>('user_version'), 1);
      },
    );
  });
}

/// Fails every UPDATE once [on] is true.
class _FailOnUpdate extends QueryInterceptor {
  bool on = false;

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (on) {
      throw SqliteException(extendedResultCode: 13, message: 'disk full');
    }
    return super.runUpdate(executor, statement, args);
  }
}

/// Round 2: the index on barcode_matches.game_id (review R1-S1).
void indexTests() {
  group('barcode_matches.game_id index', () {
    Future<List<String>> indexNames(AppDatabase d) async {
      final rows = await d
          .customSelect("PRAGMA index_list('barcode_matches')")
          .get();
      return [for (final r in rows) r.read<String>('name')];
    }

    test('exists, non-unique, on game_id only, after a fresh create', () async {
      final d = inMemoryDatabase();
      addTearDown(d.close);
      expect(await indexNames(d), contains('barcode_matches_game_id'));
      final list = await d
          .customSelect("PRAGMA index_list('barcode_matches')")
          .get();
      final row = list.singleWhere(
        (r) => r.read<String>('name') == 'barcode_matches_game_id',
      );
      expect(row.read<int>('unique'), 0);
      final cols = await d
          .customSelect("PRAGMA index_info('barcode_matches_game_id')")
          .get();
      expect(cols.map((c) => c.read<String>('name')), ['game_id']);
    });

    test('exists in a database created from the exported v1 schema', () async {
      final schema = await SchemaVerifier(GeneratedHelper()).schemaAt(1);
      final d = AppDatabase(schema.newConnection());
      addTearDown(d.close);
      expect(await indexNames(d), contains('barcode_matches_game_id'));
      await d.validateDatabaseSchema();
    });

    test('is named in the exported JSON schema file', () {
      final text = File('drift_schemas/app_database/drift_schema_v1.json')
          .readAsStringSync();
      expect(text, contains('barcode_matches_game_id'));
    });

    test('two codes for one game both stay and use the index', () async {
      final d = inMemoryDatabase();
      addTearDown(d.close);
      final s = LocalGameStore(d);
      for (final code in ['0000000000001', '0000000000002']) {
        _ok(
          await s.saveConfirmedMatch(
            gtin13: code,
            bggId: 5,
            confirmedAt: _at(0),
          ),
        );
      }
      final plan = await d
          .customSelect(
            'EXPLAIN QUERY PLAN SELECT 1 FROM barcode_matches WHERE game_id = 1',
          )
          .get();
      expect(
        plan.map((r) => r.read<String>('detail')).join(' '),
        contains('barcode_matches_game_id'),
      );
    });
  });
}
