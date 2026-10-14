// Migration tests for AppDatabase (T-027 AC4).
//
// The exported schemas live in drift_schemas/app_database/ and the helpers
// in generated/ come from `dart run drift_dev make-migrations` (with one
// version, `dart run drift_dev schema generate --data-classes --companions
// drift_schemas/app_database/ test/drift/app_database/generated/`).
//
// When the schema changes: bump schemaVersion, write the migration step, run
// make-migrations (it keeps this file and regenerates the helpers), and add
// a data test below for the new step when it changes existing columns. The
// loop over GeneratedHelper.versions then covers every upgrade path.
import 'package:board_game_collector/core/data/database/app_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('the exported schemas start at 1 and end at the current version', () {
    final current = AppDatabase(NativeDatabase.memory());
    addTearDown(current.close);
    expect(GeneratedHelper.versions.first, 1);
    expect(GeneratedHelper.versions.last, current.schemaVersion);
  });

  test('a fresh database matches the exported current schema', () async {
    // An empty file, so AppDatabase's onCreate builds the tables; then every
    // table, column, and constraint is compared with the exported JSON.
    // Fails when the tables changed but the export was not regenerated.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, GeneratedHelper.versions.last);
  });

  test('onCreate builds the schema the code declares', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.validateDatabaseSchema();
  });

  group('simple database migrations', () {
    // Every upgrade from an older exported version to every newer one, with
    // empty tables. Empty while only version 1 exists.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  test('version 1 data opens unchanged in the current schema', () async {
    // Template for data tests of later steps: write rows with the old
    // schema's classes, open with AppDatabase, read them back.
    final schema = await verifier.schemaAt(1);
    final old = v1.DatabaseAtV1(schema.newConnection());
    await old
        .into(old.games)
        .insert(
          v1.GamesCompanion.insert(
            bggId: const Value(13),
            detailsJson: const Value('{}'),
            fetchedAt: const Value(1760356800000),
          ),
        );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    final game = await db.select(db.games).getSingle();
    expect(game.bggId, 13);
    expect(game.fetchedAt, DateTime.utc(2025, 10, 13, 12));
  });
}
