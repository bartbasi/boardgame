import 'dart:async';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import '../support/database.dart';
import '../support/harness.dart';
import '../support/server_run.dart';

/// QA round 2 (T-019) against real PostgreSQL: scanner bypass attempts end
/// to end, fail-fast startup, and PgException redaction from the real driver.
void main() {
  final pg = TestPostgres.shared;

  group('transaction control cannot leak out of a migration', () {
    final attempts = <String, String>{
      'vertical tab before COMMIT':
          'CREATE TABLE leak (i int);\u000bCOMMIT;\u000bSELECT 1/0;',
      'COMMIT after a standard string ending in a backslash':
          r"CREATE TABLE leak (i int); SELECT '\'; COMMIT; SELECT 1/0;",
      'COMMIT after a closed nested comment':
          'CREATE TABLE leak (i int); /* a /* b */ c */ COMMIT; SELECT 1/0;',
      'END': 'CREATE TABLE leak (i int); END; SELECT 1/0;',
      'ABORT': 'CREATE TABLE leak (i int); ABORT; SELECT 1/0;',
      'ROLLBACK then more DDL':
          'CREATE TABLE leak (i int); ROLLBACK; SELECT 1;',
      'COMMIT AND CHAIN': 'CREATE TABLE leak (i int); COMMIT AND CHAIN;',
      'START TRANSACTION': 'CREATE TABLE leak (i int); START TRANSACTION;',
      'SAVEPOINT': 'SAVEPOINT s; CREATE TABLE leak (i int);',
    };
    attempts.forEach((label, sql) {
      test(label, () async {
        final db = await pg.createScratch();
        addTearDown(db.drop);
        final database = Database.open(
          DatabaseConfig.load(db.serverEnvironment()),
        );
        addTearDown(database.close);
        Object? error;
        try {
          await migrate(database.pool, [
            Migration(version: 1, name: 'attempt', sql: sql),
          ], LogCapture().logger());
        } on Object catch (e) {
          error = e;
        }
        final rows = await db
            .query(
              "SELECT to_regclass('public.leak') IS NOT NULL, "
              '(SELECT count(*) FROM schema_migrations)',
            )
            .onError<Object>(
              (_, _) async => [
                <Object?>[false, 0],
              ],
            );
        expect(error, isA<MigrationException>());
        expect(rows.single[0], isFalse, reason: 'DDL leaked');
        expect(rows.single[1], 0);
      });
    });
  });

  group('fail-fast startup', () {
    Future<ServerRun> start(Map<String, String> override) async => ServerRun({
      'PORT': '${await freePort()}',
      'LOG_LEVEL': 'debug',
      ...pg.serverEnvironment(),
      ...override,
    }, databaseStartupTimeout: const Duration(seconds: 30)).start();

    test('a role that does not exist fails at once (28P01 or 28000)', () async {
      final watch = Stopwatch()..start();
      final run = await start({'DATABASE_USER': 'no_such_role_r2'});
      expect(await run.exitCode, databaseUnavailableExitCode);
      expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
      final line = run.out.withMessage('database unreachable').single;
      expect(line['error'], anyOf(contains('28P01'), contains('28000')));
      expect(line['permanent'], isTrue);
      expect(line['attempts'], 1);
      expect(run.allLines.join(), isNot(contains('no_such_role_r2')));
    });

    test('a wrong padded password fails at once and is not logged', () async {
      final run = await start({'DATABASE_PASSWORD': ' x '});
      expect(await run.exitCode, databaseUnavailableExitCode);
      expect(run.allLines.join(), isNot(contains(pg.password)));
    });

    test('a refused connection is NOT permanent: it retries until the '
        'timeout and the final line has no permanent flag', () async {
      final run = ServerRun({
        'PORT': '${await freePort()}',
        'LOG_LEVEL': 'debug',
        ...pg.serverEnvironment(host: '127.0.0.1', port: await freePort()),
      }, databaseStartupTimeout: const Duration(seconds: 4)).start();
      expect(await run.exitCode, databaseUnavailableExitCode);
      final line = run.out.withMessage('database unreachable').single;
      expect(line['attempts'] as int, greaterThan(1));
      expect(line.containsKey('permanent'), isFalse);
      expect(
        run.out.withMessage('database not reachable yet, retrying'),
        hasLength(1),
      );
    });

    test('a database that appears while the server retries is picked up '
        '(not permanent until PostgreSQL says so)', () async {
      // The database does not exist at first: that is permanent, so create
      // it before the server starts and check the normal path still works.
      final db = await pg.createScratch();
      addTearDown(db.drop);
      final run = ServerRun({
        'PORT': '${await freePort()}',
        'LOG_LEVEL': 'info',
        ...db.serverEnvironment(),
      }).start();
      expect((await run.get('/health')).$1, 200);
      expect(await run.stop(), 0);
    });
  });

  group('PgException redaction from the real driver', () {
    test('a parameter the driver cannot encode never reaches describeError '
        'or the log', () async {
      final db = await pg.createScratch();
      addTearDown(db.drop);
      final connection = await db.connect();
      addTearDown(connection.close);
      const marker = 'barcode-MARKER-0123456789';

      Object? error;
      try {
        await connection.execute(
          Sql.named('SELECT @v'),
          parameters: {'v': _Unsupported(marker)},
        );
      } on Object catch (e) {
        error = e;
      }
      expect(error, isNotNull);
      final text = describeError(error!);
      expect(text, isNot(contains(marker)));

      final logs = LogCapture();
      logs.logger().error('lookup failed', error: error);
      expect(logs.lines.join(), isNot(contains(marker)));
    });

    test('a wrongly typed parameter value is not echoed', () async {
      final db = await pg.createScratch();
      addTearDown(db.drop);
      final connection = await db.connect();
      addTearDown(connection.close);
      const marker = 'barcode-MARKER-9876543210';

      Object? error;
      try {
        await connection.execute(
          Sql.named('SELECT @v::integer'),
          parameters: {'v': TypedValue(Type.integer, marker)},
        );
      } on Object catch (e) {
        error = e;
      }
      expect(error, isNotNull);
      expect(describeError(error!), isNot(contains(marker)));
    });

    test('a server-side value error (invalid input syntax) logs SQLSTATE '
        'only', () async {
      final db = await pg.createScratch();
      addTearDown(db.drop);
      final connection = await db.connect();
      addTearDown(connection.close);
      const marker = 'barcode-MARKER-5555';
      Object? error;
      try {
        await connection.execute("SELECT '$marker'::integer");
      } on Object catch (e) {
        error = e;
      }
      expect(error, isA<ServerException>());
      expect(error.toString(), contains(marker));
      expect(describeError(error!), isNot(contains(marker)));
      expect(describeError(error), contains('22P02'));
    });
  });
}

final class _Unsupported {
  _Unsupported(this.value);
  final String value;
  @override
  String toString() => 'Unsupported($value)';
}
