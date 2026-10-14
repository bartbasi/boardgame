// Only compile-time constants, which have no executable lines, so the file
// never appears in lcov.info; the marker exempts it from the CI coverage gate
// (T-011). test/db/migrations_test.dart and the database tests load it.
// coverage:ignore-file

import 'migration.dart';

/// Every schema migration, oldest first. The server applies the ones the
/// database has not recorded yet at startup (lib/src/db/migration.dart).
///
/// Append only: never edit, reorder, or remove a merged entry. Reviewers and
/// PM read this file for T-019 AC8 (no column for a user id, device id, IP
/// address, or user agent); test/db/migrations_test.dart also checks the SQL
/// and the migrated schema.
const List<Migration> schemaMigrations = [
  Migration(version: 1, name: 'create_games', sql: _createGames),
];

/// Games get our own surrogate key; the BGG id is a unique external id
/// (docs/decisions.md 2026-10-11, storage keys), so the data model survives
/// a change of game data source. Later tickets add columns for cached BGG
/// data (T-022), barcodes, and price snapshots in their own migrations.
const _createGames = '''
CREATE TABLE games (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  bgg_id integer NOT NULL UNIQUE CHECK (bgg_id > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE games IS
  'One row per game. id is our surrogate key; bgg_id is BoardGameGeek''s id.';
''';
