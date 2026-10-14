import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

import '../support/database.dart';
import '../support/harness.dart';
import '../support/server_run.dart';

/// Three migrations where each depends on the one before, so applying them
/// out of order would fail.
const _ordered = [
  Migration(
    version: 1,
    name: 'create_a',
    sql: 'CREATE TABLE a (id integer PRIMARY KEY);',
  ),
  Migration(
    version: 2,
    name: 'create_b',
    sql:
        'CREATE TABLE b (a_id integer REFERENCES a (id));\n'
        'INSERT INTO a VALUES (1);',
  ),
  Migration(version: 3, name: 'fill_b', sql: 'INSERT INTO b VALUES (1);'),
];

/// Migration 2 creates a table and inserts a row, then fails on a syntax
/// error, so its changes must roll back.
const _broken = [
  Migration(
    version: 1,
    name: 'create_ok',
    sql: 'CREATE TABLE ok_table (id integer);',
  ),
  Migration(
    version: 2,
    name: 'deliberately_broken',
    sql:
        'CREATE TABLE half_done (id integer);\n'
        'INSERT INTO ok_table VALUES (42);\n'
        'SELEC 1;',
  ),
  Migration(
    version: 3,
    name: 'never_reached',
    sql: 'CREATE TABLE never_reached (id integer);',
  ),
];

Future<Map<String, String>> _env(ScratchDatabase db) async => {
  'PORT': '${await freePort()}',
  'LOG_LEVEL': 'info',
  ...db.serverEnvironment(),
};

Future<ScratchDatabase> _scratch() async {
  final db = await TestPostgres.shared.createScratch();
  addTearDown(db.drop);
  return db;
}

Future<bool> _tableExists(ScratchDatabase db, String table) async {
  final rows = await db.query(
    'SELECT to_regclass(@name) IS NOT NULL',
    parameters: {'name': 'public.$table'},
  );
  return rows.single.single! as bool;
}

void main() {
  group('migrations at startup (T-019)', () {
    test('AC1: an empty database gets every migration in order, each in its '
        'own transaction, and every version is recorded', () async {
      final db = await _scratch();
      final run = ServerRun(await _env(db), migrations: _ordered).start();
      await run.port;

      final rows = await db.query(
        'SELECT version, name, checksum, xmin::text FROM schema_migrations '
        'ORDER BY version',
      );
      expect([for (final r in rows) r[0]], [1, 2, 3]);
      expect([for (final r in rows) r[1]], ['create_a', 'create_b', 'fill_b']);
      expect(
        [for (final r in rows) r[2]],
        [for (final m in _ordered) m.checksum],
      );
      // xmin is the id of the transaction that inserted the row: three
      // different ids mean three transactions.
      expect({for (final r in rows) r[3]}, hasLength(3));
      expect(await db.query('SELECT a_id FROM b'), [
        [1],
      ]);

      final applied = run.out.withMessage('migration applied');
      expect([for (final r in applied) r['version']], [1, 2, 3]);
      expect(
        [for (final r in applied) r['name']],
        ['create_a', 'create_b', 'fill_b'],
      );
      final done = run.out.withMessage('database schema up to date').single;
      expect(done['version'], 3);
      expect(done['appliedNow'], 3);
      // Migrations finish before the server listens.
      final messages = [for (final r in run.out.records) r['msg']];
      expect(
        messages.indexOf('database schema up to date'),
        lessThan(messages.indexOf('server started')),
      );

      expect(await run.stop(), 0);
    });

    test('AC1: the real schema migrations apply to an empty database and '
        'create the games table', () async {
      final db = await _scratch();
      final run = ServerRun(await _env(db)).start();
      await run.port;

      final rows = await db.query(
        'SELECT version, name FROM schema_migrations ORDER BY version',
      );
      expect(rows, [
        for (final m in schemaMigrations) [m.version, m.name],
      ]);
      expect(await _tableExists(db, 'games'), isTrue);
      expect(await run.stop(), 0);
    });

    test('AC2: a database already at the latest version runs no migration '
        'on the next start', () async {
      final db = await _scratch();
      final first = ServerRun(await _env(db), migrations: _ordered).start();
      await first.port;
      expect(await first.stop(), 0);
      final before = await db.query(
        'SELECT version, applied_at, xmin::text FROM schema_migrations '
        'ORDER BY version',
      );

      final second = ServerRun(await _env(db), migrations: _ordered).start();
      await second.port;

      expect(second.out.withMessage('migration applied'), isEmpty);
      final done = second.out.withMessage('database schema up to date').single;
      expect(done['version'], 3);
      expect(done['appliedNow'], 0);
      final after = await db.query(
        'SELECT version, applied_at, xmin::text FROM schema_migrations '
        'ORDER BY version',
      );
      expect(after, before);
      // Migration 2's insert ran once, not twice.
      expect(await db.query('SELECT count(*)::int FROM a'), [
        [1],
      ]);
      expect(await second.stop(), 0);
    });

    test(
      'AC2: a newer server applies only the migrations added since',
      () async {
        final db = await _scratch();
        final first = ServerRun(
          await _env(db),
          migrations: _ordered.sublist(0, 2),
        ).start();
        await first.port;
        expect(await first.stop(), 0);

        final second = ServerRun(await _env(db), migrations: _ordered).start();
        await second.port;
        final applied = second.out.withMessage('migration applied');
        expect([for (final r in applied) r['version']], [3]);
        expect(await second.stop(), 0);
      },
    );

    test('AC3: a failing migration rolls back, is logged by version and '
        'name, and the server exits non-zero without listening', () async {
      final db = await _scratch();
      final run = ServerRun(await _env(db), migrations: _broken).start();

      final code = await run.exitCode;
      expect(code, migrationFailedExitCode);
      expect(code, isNot(0));
      expect(run.listening.isCompleted, isFalse);

      // Migration 1 stays applied; nothing of migration 2 remains; 3 never
      // ran.
      expect(await db.query('SELECT version FROM schema_migrations'), [
        [1],
      ]);
      expect(await _tableExists(db, 'ok_table'), isTrue);
      expect(await _tableExists(db, 'half_done'), isFalse);
      expect(await db.query('SELECT count(*)::int FROM ok_table'), [
        [0],
      ]);
      expect(await _tableExists(db, 'never_reached'), isFalse);

      final failed = run.out.withMessage('migration failed').single;
      expect(failed['level'], 'error');
      expect(failed['version'], 2);
      expect(failed['name'], 'deliberately_broken');
      expect(failed['errorType'], contains('ServerException'));
      // 42601 is PostgreSQL's syntax_error SQLSTATE.
      expect(failed['error'], contains('42601'));
      expect(failed['dbMessage'], contains('syntax error'));
      expect(run.out.withMessage('server started'), isEmpty);
      expect(run.out.withMessage('migration applied'), hasLength(1));
    });

    test('AC3: a migration that fails at run time (not syntax) also rolls '
        'back', () async {
      final db = await _scratch();
      final run = ServerRun(
        await _env(db),
        migrations: const [
          Migration(
            version: 1,
            name: 'divide_by_zero',
            sql:
                'CREATE TABLE gone (id integer);\n'
                'INSERT INTO gone VALUES (1);\n'
                'SELECT 1 / 0;',
          ),
        ],
      ).start();

      expect(await run.exitCode, migrationFailedExitCode);
      expect(await _tableExists(db, 'gone'), isFalse);
      expect(await db.query('SELECT count(*)::int FROM schema_migrations'), [
        [0],
      ]);
      final failed = run.out.withMessage('migration failed').single;
      expect(failed['version'], 1);
      expect(failed['error'], contains('22012')); // division_by_zero
    });

    test(
      'a database at a version this server does not know stops startup',
      () async {
        final db = await _scratch();
        final first = ServerRun(await _env(db), migrations: _ordered).start();
        await first.port;
        expect(await first.stop(), 0);

        final older = ServerRun(
          await _env(db),
          migrations: _ordered.sublist(0, 2),
        ).start();
        expect(await older.exitCode, migrationFailedExitCode);
        final line = older.out.withMessage('migrations cannot run').single;
        expect(line['reason'], contains('version 3'));
        expect(older.listening.isCompleted, isFalse);
      },
    );

    test('an applied migration whose SQL changed stops startup', () async {
      final db = await _scratch();
      final first = ServerRun(await _env(db), migrations: _ordered).start();
      await first.port;
      expect(await first.stop(), 0);

      final edited = [
        _ordered[0],
        const Migration(
          version: 2,
          name: 'create_b',
          sql: 'CREATE TABLE b (a_id integer);',
        ),
        _ordered[2],
      ];
      final run = ServerRun(await _env(db), migrations: edited).start();
      expect(await run.exitCode, migrationFailedExitCode);
      expect(
        run.out.withMessage('migrations cannot run').single['reason'],
        contains('migration 2 (create_b) was changed'),
      );
    });

    test('a gap in the recorded history stops startup', () async {
      final db = await _scratch();
      final first = ServerRun(await _env(db), migrations: _ordered).start();
      await first.port;
      expect(await first.stop(), 0);
      await db.query('DELETE FROM schema_migrations WHERE version = 2');

      final run = ServerRun(await _env(db), migrations: _ordered).start();
      expect(await run.exitCode, migrationFailedExitCode);
      expect(
        run.out.withMessage('migrations cannot run').single['reason'],
        contains('missing version 2'),
      );
    });

    test('two servers migrating the same database at once apply each '
        'migration exactly once (advisory lock)', () async {
      final db = await _scratch();
      final config = DatabaseConfig.load(db.serverEnvironment());
      final a = Database.open(config);
      final b = Database.open(config);
      addTearDown(a.close);
      addTearDown(b.close);
      final logs = <String>[];
      final logger = Logger(minLevel: LogLevel.info, sink: logs.add);

      final reports = await Future.wait([
        migrate(a.pool, _ordered, logger),
        migrate(b.pool, _ordered, logger),
      ]);

      expect([...reports[0].applied, ...reports[1].applied]..sort(), [1, 2, 3]);
      expect(await db.query('SELECT count(*)::int FROM a'), [
        [1],
      ]);
      // The lock is released afterwards.
      final locks = await db.query(
        'SELECT count(*)::int FROM pg_locks l JOIN pg_database d '
        "ON d.oid = l.database WHERE l.locktype = 'advisory' "
        'AND d.datname = current_database()',
      );
      expect(locks, [
        [0],
      ]);
    });

    test(
      'an invalid migration list is refused before touching the database',
      () async {
        final db = await _scratch();
        final run = ServerRun(
          await _env(db),
          migrations: const [
            Migration(version: 2, name: 'starts_at_two', sql: 'SELECT 1;'),
          ],
        ).start();
        expect(await run.exitCode, migrationFailedExitCode);
        expect(
          run.out.withMessage('migrations cannot run').single['reason'],
          contains('versions must be 1, 2, 3'),
        );
        expect(await _tableExists(db, 'schema_migrations'), isFalse);
      },
    );

    test('R1-M1: a migration with an embedded COMMIT is refused before '
        'anything runs, so nothing leaks past a later failure', () async {
      final db = await _scratch();
      final run = ServerRun(
        await _env(db),
        migrations: const [
          Migration(
            version: 1,
            name: 'sneaky_commit',
            sql: 'CREATE TABLE sneaky (i int); COMMIT; SELECT 1/0;',
          ),
        ],
      ).start();
      expect(await run.exitCode, migrationFailedExitCode);
      expect(
        run.out.withMessage('migrations cannot run').single['reason'],
        contains('COMMIT statement'),
      );
      expect(run.listening.isCompleted, isFalse);
      expect(await _tableExists(db, 'sneaky'), isFalse);
      expect(await _tableExists(db, 'schema_migrations'), isFalse);
    });

    test('R1-M1: PL/pgSQL, DO, and BEGIN ATOMIC bodies pass validation and '
        'apply on real PostgreSQL', () async {
      final db = await _scratch();
      final run = ServerRun(
        await _env(db),
        migrations: const [
          Migration(
            version: 1,
            name: 'function_bodies',
            sql: r'''
CREATE TABLE t (i int, updated_at timestamptz);
CREATE FUNCTION touch() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
CREATE TRIGGER t_touch BEFORE INSERT ON t
  FOR EACH ROW EXECUTE FUNCTION touch();
DO $$
BEGIN
  INSERT INTO t (i) VALUES (1);
END
$$;
CREATE FUNCTION plus_one(x int) RETURNS int LANGUAGE sql
BEGIN ATOMIC
  SELECT CASE WHEN x > 0 THEN x + 1 ELSE 0 END;
END;
''',
          ),
        ],
      ).start();
      await run.port;
      final rows = await db.query(
        'SELECT plus_one(i), updated_at IS NOT NULL FROM t',
      );
      expect(rows.single, [2, true]);
      expect(await run.stop(), 0);
    });

    test(
      'the database ready line reports the server version and locale',
      () async {
        final db = await _scratch();
        final run = ServerRun(await _env(db)).start();
        await run.port;
        final ready = run.out.withMessage('database ready').single;
        expect(ready['serverVersion'], startsWith('18.'));
        expect(ready['localeProvider'], isIn(['builtin', 'icu', 'libc']));
        expect(ready['locale'], isA<String>());
        expect(ready['encoding'], 'UTF8');
        expect(await run.stop(), 0);
      },
    );

    test('a role that may not create tables stops startup before any '
        'migration, without printing its password', () async {
      final db = await _scratch();
      final role = 'limited_${db.name.substring(8)}';
      final password = fakePassword('limited');
      await db.query("CREATE ROLE $role LOGIN PASSWORD '$password'");
      addTearDown(() => db.query('DROP ROLE IF EXISTS $role'));
      // PostgreSQL 15 and later: only the owner may create in schema public.
      final run = ServerRun({
        ...await _env(db),
        'DATABASE_USER': role,
        'DATABASE_PASSWORD': password,
      }).start();

      expect(await run.exitCode, migrationFailedExitCode);
      final line = run.out.withMessage('migrations could not start').single;
      expect(line['error'], contains('42501')); // insufficient_privilege
      expect(run.listening.isCompleted, isFalse);
      for (final l in run.allLines) {
        expect(l, isNot(contains(password)));
      }
    });

    test('a shutdown signal during migrations lets the running migration '
        'finish, then exits 0 without listening', () async {
      final db = await _scratch();
      final run = ServerRun(
        await _env(db),
        migrations: const [
          Migration(
            version: 1,
            name: 'slow',
            sql: 'SELECT pg_sleep(1); CREATE TABLE slow_done (id integer);',
          ),
        ],
      ).start();
      while (run.out.withMessage('database ready').isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      run.signals.add(ProcessSignal.sigterm);

      expect(await run.exitCode, 0);
      expect(run.listening.isCompleted, isFalse);
      expect(run.out.withMessage('shutdown during startup'), hasLength(1));
      expect(await _tableExists(db, 'slow_done'), isTrue);
      expect(await db.query('SELECT version FROM schema_migrations'), [
        [1],
      ]);
    });
  });
}
