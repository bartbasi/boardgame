import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

import '../support/database.dart';

/// Column names that would hold personal data (T-019 AC8, PRD privacy
/// rules): a user id, device id, IP address, or user agent.
final _forbiddenColumn = RegExp(
  r'(^|_)(user|users|device|devices|ip|ips|ip_address|inet|agent|'
  r'user_agent|useragent|client|install|installation|account|email|phone)'
  r'(_|$)',
);

void main() {
  group('the migration list', () {
    test('is valid: versions 1, 2, 3, ... with snake_case names', () {
      expect(() => validateMigrations(schemaMigrations), returnsNormally);
      expect(schemaMigrations, isNotEmpty);
    });

    test('validateMigrations refuses gaps, bad names, and empty SQL', () {
      expect(
        () => validateMigrations(const [
          Migration(version: 1, name: 'a', sql: 'SELECT 1'),
          Migration(version: 3, name: 'c', sql: 'SELECT 1'),
        ]),
        throwsA(
          isA<MigrationStateException>().having(
            (e) => e.message,
            'message',
            contains('position 2 has version 3'),
          ),
        ),
      );
      expect(
        () => validateMigrations(const [
          Migration(version: 1, name: 'Bad-Name', sql: 'SELECT 1'),
        ]),
        throwsA(isA<MigrationStateException>()),
      );
      expect(
        () => validateMigrations(const [
          Migration(version: 1, name: 'empty', sql: '  \n'),
        ]),
        throwsA(isA<MigrationStateException>()),
      );
    });

    test('the checksum is the SHA-256 of the SQL and changes with it', () {
      const a = Migration(version: 1, name: 'x', sql: 'SELECT 1;');
      const b = Migration(version: 1, name: 'x', sql: 'SELECT 2;');
      // printf 'SELECT 1;' | sha256sum
      expect(
        a.checksum,
        '17db4fd369edb9244b9f91d9aeed145c3d04ad8ba6e95d06247f07a63527d11a',
      );
      expect(a.checksum, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(a.checksum, isNot(b.checksum));
      expect(
        a.checksum,
        const Migration(version: 9, name: 'y', sql: 'SELECT 1;').checksum,
      );
    });

    test('MigrationFailedException and MigrationStateException describe '
        'themselves without SQL', () {
      final failed = MigrationFailedException(
        version: 4,
        name: 'add_x',
        cause: StateError('boom'),
        causeStackTrace: StackTrace.empty,
      );
      expect(failed.message, 'migration 4 (add_x) failed and was rolled back');
      expect(failed.toString(), contains('MigrationFailedException'));
      expect(
        MigrationStateException('m').toString(),
        'MigrationStateException: m',
      );
    });

    test('T-019 AC8 (static): no migration names a column for a user id, '
        'device id, IP address, or user agent', () {
      final identifier = RegExp(r'[a-z_][a-z0-9_]*');
      for (final m in schemaMigrations) {
        final words = identifier
            .allMatches(m.sql.toLowerCase())
            .map((x) => x[0]!)
            .where(_forbiddenColumn.hasMatch);
        expect(words, isEmpty, reason: 'migration ${m.version} (${m.name})');
      }
    });
  });

  test('T-019 AC8: the migrated schema has no column for a user id, device '
      'id, IP address, or user agent, and no inet or cidr column', () async {
    final db = await TestPostgres.shared.createScratch();
    addTearDown(db.drop);
    final database = Database.open(DatabaseConfig.load(db.serverEnvironment()));
    addTearDown(database.close);
    await migrate(
      database.pool,
      schemaMigrations,
      Logger(minLevel: LogLevel.error, sink: (_) {}),
    );

    final columns = await db.query(
      "SELECT table_name || '.' || column_name, column_name, data_type "
      'FROM information_schema.columns '
      "WHERE table_schema = 'public' ORDER BY 1",
    );
    expect(columns, isNotEmpty);
    for (final [qualified, column as String, type] in columns) {
      expect(
        _forbiddenColumn.hasMatch(column),
        isFalse,
        reason: '$qualified looks like personal data',
      );
      expect(type, isNot(anyOf('inet', 'cidr', 'macaddr')));
    }
    // The games table follows the surrogate key decision (2026-10-11).
    final games = {
      for (final [q, _, type] in columns)
        if ((q! as String).startsWith('games.')) q: type,
    };
    expect(games, {
      'games.bgg_id': 'integer',
      'games.created_at': 'timestamp with time zone',
      'games.id': 'bigint',
    });
  });
}
