/// The on-device database (T-027): Drift over SQLite.
///
/// Storage keys follow docs/decisions.md 2026-10-11 ("Storage keys"): every
/// game has an internal surrogate id as its primary key, and the BGG id is a
/// unique, nullable external id next to it. No table uses `bgg_id` as its
/// key, so a later data source can add games without a BGG id.
///
/// Schema changes: bump [AppDatabase.schemaVersion], add the step to
/// [AppDatabase.migration], run `dart run build_runner build` and
/// `dart run drift_dev make-migrations`, and extend
/// test/drift/app_database/migration_test.dart (app/README.md, "On-device
/// database").
library;

import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Stores a [DateTime] as UTC milliseconds since the epoch, so values sort
/// correctly in SQL and read back as UTC with millisecond precision.
class EpochMillisConverter extends TypeConverter<DateTime, int> {
  const EpochMillisConverter();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMillisecondsSinceEpoch(fromDb, isUtc: true);

  @override
  int toSql(DateTime value) => value.millisecondsSinceEpoch;
}

/// Games the app knows about: viewed games with their cached details, and
/// games that a confirmed barcode match points to.
@DataClassName('GameRow')
class Games extends Table {
  /// Internal surrogate id. Never leaves the data layer.
  IntColumn get id => integer().autoIncrement()();

  /// The BoardGameGeek id, unique when present.
  IntColumn get bggId => integer().nullable().unique().check(
    const CustomExpression<bool>('bgg_id > 0'),
  )();

  /// The cached game details as the backend's JSON. Null when the game has
  /// no cached details, for example after eviction when a barcode match
  /// still points to the game.
  TextColumn get detailsJson => text().nullable()();

  /// When [detailsJson] was fetched from the backend.
  IntColumn get fetchedAt =>
      integer().nullable().map(const EpochMillisConverter())();

  /// When the user last opened the game. Eviction removes the details of the
  /// least recently viewed games first.
  IntColumn get lastViewedAt =>
      integer().nullable().map(const EpochMillisConverter())();
}

/// Barcodes the user (or a single backend match) confirmed, keyed by the
/// 13-digit GTIN key from `Barcode.gtin13` (docs/decisions.md 2026-10-13).
///
/// `game_id` is indexed: deleting unused games and SQLite's foreign key
/// check on a games delete both look matches up by game (T-027 R1-S1).
@DataClassName('BarcodeMatchRow')
@TableIndex(name: 'barcode_matches_game_id', columns: {#gameId})
class BarcodeMatches extends Table {
  /// 13 ASCII digits.
  TextColumn get gtin13 => text().check(
    gtin13.length.equals(13) &
        const CustomExpression<bool>("gtin13 NOT GLOB '*[^0-9]*'"),
  )();

  /// The matched game's internal id.
  IntColumn get gameId => integer().references(Games, #id)();

  /// When the match was confirmed.
  IntColumn get confirmedAt => integer().map(const EpochMillisConverter())();

  @override
  Set<Column<Object>> get primaryKey => {gtin13};
}

/// The app's database. Open it with `openAppDatabase` (a background isolate)
/// in the app, or pass an in-memory executor in tests.
@DriftDatabase(tables: [Games, BarcodeMatches])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      // SQLite leaves foreign key checks off unless each connection asks.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
