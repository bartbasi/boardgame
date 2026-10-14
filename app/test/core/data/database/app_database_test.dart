import 'package:board_game_collector/core/data/database/app_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

/// Reads a PRAGMA (or any query) as plain rows.
Future<List<Map<String, Object?>>> _rows(AppDatabase db, String sql) async =>
    (await db.customSelect(sql).get()).map((row) => row.data).toList();

void main() {
  late AppDatabase db;

  setUp(() => db = inMemoryDatabase());
  tearDown(() => db.close());

  group('fresh install (AC1)', () {
    test('creates schema version 1', () async {
      expect(db.schemaVersion, 1);
      final version = await _rows(db, 'PRAGMA user_version');
      expect(version.single.values.single, 1);
    });

    test('has exactly the games and barcode_matches tables', () async {
      final tables = await _rows(
        db,
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name",
      );
      expect(tables.map((t) => t['name']), ['barcode_matches', 'games']);
    });

    test('games: surrogate id key, unique nullable bgg_id, details, '
        'fetched and viewed times', () async {
      final columns = await _rows(db, 'PRAGMA table_info(games)');
      final byName = {for (final c in columns) c['name']! as String: c};
      expect(byName.keys, [
        'id',
        'bgg_id',
        'details_json',
        'fetched_at',
        'last_viewed_at',
      ]);
      // pk is the 1-based position in the primary key, 0 when not in it.
      expect(byName['id']!['pk'], 1);
      expect(byName['id']!['type'], 'INTEGER');
      expect(byName['bgg_id']!['pk'], 0);
      expect(byName['bgg_id']!['notnull'], 0);
      expect(byName['bgg_id']!['type'], 'INTEGER');
      expect(byName['details_json']!['type'], 'TEXT');
      expect(byName['fetched_at']!['type'], 'INTEGER');
      expect(byName['last_viewed_at']!['type'], 'INTEGER');

      final uniqueIndexes = (await _rows(db, 'PRAGMA index_list(games)'))
          .where((index) => index['unique'] == 1)
          .map((index) => index['name']! as String);
      final uniqueColumns = [
        for (final index in uniqueIndexes)
          for (final column in await _rows(db, "PRAGMA index_info('$index')"))
            column['name'],
      ];
      expect(uniqueColumns, ['bgg_id']);
    });

    test('barcode_matches: GTIN-13 key, game id foreign key, confirmed '
        'time', () async {
      final columns = await _rows(db, 'PRAGMA table_info(barcode_matches)');
      final byName = {for (final c in columns) c['name']! as String: c};
      expect(byName.keys, ['gtin13', 'game_id', 'confirmed_at']);
      expect(byName['gtin13']!['pk'], 1);
      expect(byName['gtin13']!['type'], 'TEXT');
      expect(byName['game_id']!['pk'], 0);
      expect(byName['game_id']!['notnull'], 1);
      expect(byName['confirmed_at']!['notnull'], 1);

      final keys = await _rows(db, 'PRAGMA foreign_key_list(barcode_matches)');
      expect(keys, hasLength(1));
      expect(keys.single['table'], 'games');
      expect(keys.single['from'], 'game_id');
      expect(keys.single['to'], 'id');
    });

    test('barcode_matches.game_id has a non-unique index (R1-S1)', () async {
      final indexes = await _rows(db, 'PRAGMA index_list(barcode_matches)');
      final byName = {for (final i in indexes) i['name']! as String: i};
      expect(byName, contains('barcode_matches_game_id'));
      expect(byName['barcode_matches_game_id']!['unique'], 0);
      final columns = await _rows(
        db,
        "PRAGMA index_info('barcode_matches_game_id')",
      );
      expect(columns.map((c) => c['name']), ['game_id']);

      // SQLite uses it for the lookup the store's cleanup runs.
      final plan = await _rows(
        db,
        'EXPLAIN QUERY PLAN SELECT 1 FROM barcode_matches WHERE game_id = 1',
      );
      expect(
        plan.map((row) => row['detail']).join(' '),
        contains('barcode_matches_game_id'),
      );
    });

    test('no table uses bgg_id as its key', () async {
      for (final table in ['games', 'barcode_matches']) {
        final columns = await _rows(db, 'PRAGMA table_info($table)');
        final keyColumns = columns
            .where((c) => (c['pk']! as int) > 0)
            .map((c) => c['name']);
        expect(keyColumns, isNot(contains('bgg_id')), reason: table);
      }
    });

    test('foreign keys are enforced', () async {
      final pragma = await _rows(db, 'PRAGMA foreign_keys');
      expect(pragma.single.values.single, 1);
      await expectLater(
        db
            .into(db.barcodeMatches)
            .insert(
              BarcodeMatchesCompanion.insert(
                gtin13: '0036000291452',
                gameId: 999,
                confirmedAt: DateTime.utc(2026, 10, 13),
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('rejects barcode keys that are not 13 digits', () async {
      final gameId = await db
          .into(db.games)
          .insert(GamesCompanion.insert(bggId: const Value(13)));
      for (final key in ['036000291452', '00360002914520', '003600029145a']) {
        await expectLater(
          db
              .into(db.barcodeMatches)
              .insert(
                BarcodeMatchesCompanion.insert(
                  gtin13: key,
                  gameId: gameId,
                  confirmedAt: DateTime.utc(2026, 10, 13),
                ),
              ),
          throwsA(isA<SqliteException>()),
          reason: key,
        );
      }
    });

    test('rejects BGG ids below 1 and allows games without one', () async {
      for (final bggId in [0, -1]) {
        await expectLater(
          db.into(db.games).insert(GamesCompanion.insert(bggId: Value(bggId))),
          throwsA(isA<SqliteException>()),
          reason: '$bggId',
        );
      }
      await db.into(db.games).insert(GamesCompanion.insert());
      await db.into(db.games).insert(GamesCompanion.insert());
      expect(await db.select(db.games).get(), hasLength(2));
    });
  });

  group('EpochMillisConverter', () {
    const converter = EpochMillisConverter();

    test('stores UTC milliseconds and reads back UTC', () {
      final local = DateTime(2026, 10, 13, 9, 30, 15, 250);
      final stored = converter.toSql(local);
      expect(stored, local.millisecondsSinceEpoch);
      final read = converter.fromSql(stored);
      expect(read.isUtc, isTrue);
      expect(read, local.toUtc());
    });

    test('drops microseconds', () {
      final value = DateTime.utc(2026, 10, 13, 9, 30, 15, 250, 999);
      expect(
        converter.fromSql(converter.toSql(value)),
        DateTime.utc(2026, 10, 13, 9, 30, 15, 250),
      );
    });
  });
}
