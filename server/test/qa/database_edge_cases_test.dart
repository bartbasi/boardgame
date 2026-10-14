import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:postgres/postgres.dart' show ServerException;
import 'package:test/test.dart';

import '../support/database.dart';
import '../support/harness.dart';
import '../support/server_run.dart';

/// QA edge cases for T-019 on top of the developer's tests: config
/// parsing corners, migration atomicity and locking, startup failures that
/// are not "unreachable", runtime outages of different kinds, and the
/// /health route shape.
void main() {
  group('DatabaseConfig corners', () {
    Map<String, String> good([Map<String, String> over = const {}]) => {
      'DATABASE_HOST': 'db',
      'DATABASE_NAME': 'n',
      'DATABASE_USER': 'u',
      'DATABASE_PASSWORD': 'p',
      ...over,
    };

    for (final bad in [
      '+5',
      '-1',
      '5.0',
      '0x5',
      '1e1',
      '５', // full-width digit
      '5 5',
      '21',
      '100',
      '123456',
      'five',
      '٣', // Arabic-indic digit
    ]) {
      test('DATABASE_POOL_MAX=$bad is rejected', () {
        expect(
          () => DatabaseConfig.load(good({'DATABASE_POOL_MAX': bad})),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.message,
              'message',
              allOf(contains('DATABASE_POOL_MAX'), isNot(contains(bad))),
            ),
          ),
        );
      });
    }

    test('boundary pool sizes 1 and 20 pass, 0 and 21 fail', () {
      expect(DatabaseConfig.load(good({'DATABASE_POOL_MAX': '1'})).poolMax, 1);
      expect(
        DatabaseConfig.load(good({'DATABASE_POOL_MAX': '20'})).poolMax,
        20,
      );
      for (final v in ['0', '21']) {
        expect(
          () => DatabaseConfig.load(good({'DATABASE_POOL_MAX': v})),
          throwsA(isA<ConfigException>()),
        );
      }
    });

    test('surrounding spaces on a number are trimmed', () {
      final c = DatabaseConfig.load(
        good({'DATABASE_POOL_MAX': ' 7 ', 'DATABASE_PORT': ' 5433 '}),
      );
      expect(c.poolMax, 7);
      expect(c.port, 5433);
    });

    for (final badHost in [
      'host name',
      'http://db',
      'db/x',
      'db;drop',
      'dbé',
      'a' * 254,
    ]) {
      test('DATABASE_HOST=${badHost.length > 20 ? 'long' : badHost} is '
          'rejected', () {
        expect(
          () => DatabaseConfig.load(good({'DATABASE_HOST': badHost})),
          throwsA(isA<ConfigException>()),
        );
      });
    }

    test('a name of 63 multi-byte bytes passes, 64 bytes fails', () {
      // 'é' is 2 bytes: 31 of them are 62 bytes, plus one ASCII byte is 63.
      final ok = '${'é' * 31}a';
      expect(DatabaseConfig.load(good({'DATABASE_NAME': ok})).name, ok);
      final tooLong = 'é' * 32;
      expect(
        () => DatabaseConfig.load(good({'DATABASE_NAME': tooLong})),
        throwsA(isA<ConfigException>()),
      );
    });

    test('control characters in a name are rejected', () {
      for (final v in ['a\nb', 'a\x00b', 'a\x7fb', 'a\tb']) {
        expect(
          () => DatabaseConfig.load(good({'DATABASE_USER': v})),
          throwsA(isA<ConfigException>()),
        );
      }
    });

    test('a very long password is accepted and never printed', () {
      final secret = fakePassword('long') * 500;
      final c = DatabaseConfig.load(good({'DATABASE_PASSWORD': secret}));
      expect(c.password, secret);
      expect(c.toString(), isNot(contains('fake')));
    });

    test('a missing password with every other variable bad names only '
        'variables', () {
      final secret = fakePassword('x');
      try {
        DatabaseConfig.load({
          'DATABASE_HOST': 'bad host',
          'DATABASE_NAME': secret,
          'DATABASE_USER': '',
          'DATABASE_POOL_MAX': secret,
        });
        fail('should throw');
      } on ConfigException catch (e) {
        expect(e.message, isNot(contains(secret)));
        expect(e.problems.length, 4);
      }
    });
  });

  group('migrate() corners (real PostgreSQL)', () {
    late ScratchDatabase db;
    late Database database;
    late LogCapture logs;

    setUp(() async {
      db = await TestPostgres.shared.createScratch();
      addTearDown(db.drop);
      database = Database.open(
        DatabaseConfig.load({
          ...db.serverEnvironment(),
          'DATABASE_POOL_MAX': '3',
        }),
      );
      addTearDown(database.close);
      logs = LogCapture();
    });

    test('an empty migration list on an empty database creates only the '
        'history table and reports version 0', () async {
      final report = await migrate(database.pool, const [], logs.logger());
      expect(report.applied, isEmpty);
      expect(report.version, 0);
      final rows = await db.query(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema = 'public' ORDER BY 1",
      );
      expect(rows.map((r) => r.single), ['schema_migrations']);
    });

    test('an invalid list throws before touching the database', () async {
      final report = migrate(database.pool, const [
        Migration(version: 2, name: 'x', sql: 'SELECT 1'),
      ], logs.logger());
      await expectLater(report, throwsA(isA<MigrationStateException>()));
      final rows = await db.query(
        "SELECT count(*) FROM information_schema.tables "
        "WHERE table_schema = 'public'",
      );
      expect(rows.single.single, 0);
    });

    test('a statement timeout rolls the migration back and releases the '
        'advisory lock', () async {
      const slow = [
        Migration(
          version: 1,
          name: 'slow',
          sql: 'CREATE TABLE t (id int); SELECT pg_sleep(5);',
        ),
      ];
      await expectLater(
        migrate(
          database.pool,
          slow,
          logs.logger(),
          statementTimeout: const Duration(seconds: 1),
        ),
        throwsA(
          isA<MigrationFailedException>().having((e) => e.version, 'v', 1),
        ),
      );
      final rows = await db.query(
        "SELECT to_regclass('public.t') IS NOT NULL, "
        '(SELECT count(*) FROM schema_migrations)',
      );
      expect(rows.single, [false, 0]);
      // Lock released: a fixed migration 1 applies from the same pool.
      final report = await migrate(database.pool, const [
        Migration(version: 1, name: 'slow', sql: 'CREATE TABLE t (id int);'),
      ], logs.logger());
      expect(report.applied, [1]);
      final locks = await db.query(
        'SELECT count(*) FROM pg_locks WHERE locktype = @t AND database = '
        '(SELECT oid FROM pg_database WHERE datname = current_database())',
        parameters: {'t': 'advisory'},
      );
      expect(locks.single.single, 0);
    });

    test('the advisory lock is released after a failed migration', () async {
      await expectLater(
        migrate(database.pool, const [
          Migration(version: 1, name: 'bad', sql: 'SELEC 1'),
        ], logs.logger()),
        throwsA(isA<MigrationFailedException>()),
      );
      final locks = await db.query(
        'SELECT count(*) FROM pg_locks WHERE locktype = @t AND database = '
        '(SELECT oid FROM pg_database WHERE datname = current_database())',
        parameters: {'t': 'advisory'},
      );
      expect(locks.single.single, 0);
    });

    test(
      'a whitespace-only edit of an applied migration is detected',
      () async {
        const v1 = Migration(
          version: 1,
          name: 'a',
          sql: 'CREATE TABLE a (i int);',
        );
        const edited = Migration(
          version: 1,
          name: 'a',
          sql: 'CREATE TABLE a (i int); ',
        );
        await migrate(database.pool, const [v1], logs.logger());
        await expectLater(
          migrate(database.pool, const [edited], logs.logger()),
          throwsA(isA<MigrationStateException>()),
        );
      },
    );

    test('a renamed migration with identical SQL is accepted (the name is '
        'informational, the checksum is of the SQL)', () async {
      const v1 = Migration(
        version: 1,
        name: 'a',
        sql: 'CREATE TABLE a (i int);',
      );
      const renamed = Migration(
        version: 1,
        name: 'b',
        sql: 'CREATE TABLE a (i int);',
      );
      await migrate(database.pool, const [v1], logs.logger());
      final report = await migrate(database.pool, const [
        renamed,
      ], logs.logger());
      expect(report.applied, isEmpty);
    });

    test('a migration with an embedded COMMIT still rolls back everything '
        'when a later statement fails (atomicity)', () async {
      await expectLater(
        migrate(database.pool, const [
          Migration(
            version: 1,
            name: 'sneaky_commit',
            sql: 'CREATE TABLE sneaky (i int); COMMIT; SELECT 1/0;',
          ),
        ], logs.logger()),
        throwsA(isA<MigrationFailedException>()),
      );
      final rows = await db.query(
        "SELECT to_regclass('public.sneaky') IS NOT NULL",
      );
      expect(rows.single.single, isFalse, reason: 'DDL leaked past COMMIT');
    });

    test('many concurrent migrate calls from separate pools apply each '
        'version exactly once', () async {
      const list = [
        Migration(version: 1, name: 'a', sql: 'CREATE TABLE a (i int);'),
        Migration(version: 2, name: 'b', sql: 'CREATE TABLE b (i int);'),
      ];
      final pools = [
        for (var i = 0; i < 6; i++)
          Database.open(DatabaseConfig.load(db.serverEnvironment())),
      ];
      addTearDown(() => Future.wait(pools.map((p) => p.close())));
      final reports = await Future.wait([
        for (final p in pools) migrate(p.pool, list, logs.logger()),
      ]);
      final appliedTotal = reports.expand((r) => r.applied).toList()..sort();
      expect(appliedTotal, [1, 2]);
      expect(await db.query('SELECT count(*) FROM schema_migrations'), [
        [2],
      ]);
    });

    test('the real migration list applies with a pool of 1 (migrate holds '
        'one connection for the whole run)', () async {
      final single = Database.open(
        DatabaseConfig.load({
          ...db.serverEnvironment(),
          'DATABASE_POOL_MAX': '1',
        }),
      );
      addTearDown(single.close);
      final report = await migrate(
        single.pool,
        schemaMigrations,
        logs.logger(),
      );
      expect(report.version, schemaMigrations.length);
    });

    test('the games table enforces its constraints', () async {
      await migrate(database.pool, schemaMigrations, logs.logger());
      await db.query('INSERT INTO games (bgg_id) VALUES (13) RETURNING id');
      Future<void> bad(String sql, String sqlState) => expectLater(
        db.query(sql),
        throwsA(isA<ServerException>().having((e) => e.code, 'code', sqlState)),
      );
      await bad('INSERT INTO games (bgg_id) VALUES (13)', '23505');
      await bad('INSERT INTO games (bgg_id) VALUES (0)', '23514');
      await bad('INSERT INTO games (bgg_id) VALUES (-5)', '23514');
      await bad('INSERT INTO games (bgg_id) VALUES (NULL)', '23502');
      await bad('INSERT INTO games (id, bgg_id) VALUES (99, 14)', '428C9');
      // bgg_id is a 32-bit integer.
      await bad('INSERT INTO games (bgg_id) VALUES (2147483648)', '22003');
      await db.query('INSERT INTO games (bgg_id) VALUES (2147483647)');
    });
  });

  group('startup failures other than a closed port', () {
    final pg = TestPostgres.shared;

    Future<ServerRun> startWith(
      Map<String, String> over, {
      Duration timeout = const Duration(seconds: 2),
    }) async => ServerRun({
      'PORT': '${await freePort()}',
      'LOG_LEVEL': 'debug',
      ...pg.serverEnvironment(),
      ...over,
    }, databaseStartupTimeout: timeout).start();

    test('a database that does not exist exits 69 and logs 3D000, no '
        'password', () async {
      final run = await startWith({'DATABASE_NAME': 'no_such_db_qa'});
      expect(await run.exitCode, databaseUnavailableExitCode);
      expect(
        run.out.withMessage('database unreachable').single['error'],
        contains('3D000'),
      );
      expect(run.allLines.join(), isNot(contains(pg.password)));
    });

    test(
      'a role that does not exist exits 69 and logs the SQLSTATE only',
      () async {
        final run = await startWith({'DATABASE_USER': 'no_such_role_qa'});
        expect(await run.exitCode, databaseUnavailableExitCode);
        expect(run.allLines.join(), isNot(contains(pg.password)));
        expect(run.allLines.join(), isNot(contains('no_such_role_qa')));
      },
    );

    test(
      'a host name that does not resolve exits 69 without listening',
      () async {
        final run = await startWith({
          'DATABASE_HOST': 'no-such-host.invalid',
        }, timeout: const Duration(seconds: 3));
        expect(await run.exitCode, databaseUnavailableExitCode);
        expect(run.listening.isCompleted, isFalse);
        expect(run.allLines.join(), isNot(contains(pg.password)));
      },
    );

    test('nothing is listening on the server port while the database is '
        'unreachable', () async {
      final port = await freePort();
      final run = await startWith({
        'PORT': '$port',
        'DATABASE_HOST': '127.0.0.1',
        'DATABASE_PORT': '${await freePort()}',
      }, timeout: const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(seconds: 1));
      await expectLater(
        Socket.connect('127.0.0.1', port, timeout: const Duration(seconds: 1)),
        throwsA(isA<SocketException>()),
      );
      expect(await run.exitCode, databaseUnavailableExitCode);
    });

    test('DATABASE_POOL_MAX=1 starts, migrates, and answers /health', () async {
      final db = await pg.createScratch();
      addTearDown(db.drop);
      final run = ServerRun({
        'PORT': '${await freePort()}',
        'LOG_LEVEL': 'info',
        ...db.serverEnvironment(),
        'DATABASE_POOL_MAX': '1',
      }).start();
      final (status, body) = await run.get('/health');
      expect(status, 200);
      expect(body['database'], 'ok');
      // Several concurrent probes share the one connection without errors.
      final results = await Future.wait([
        for (var i = 0; i < 10; i++) run.get('/health'),
      ]);
      expect({for (final r in results) r.$1}, {200});
      expect(await run.stop(), 0);
    });

    test(
      'a signal while the database is unreachable exits 0 promptly',
      () async {
        final run = await startWith({
          'DATABASE_HOST': '127.0.0.1',
          'DATABASE_PORT': '${await freePort()}',
        }, timeout: const Duration(seconds: 30));
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        final watch = Stopwatch()..start();
        expect(await run.stop(), 0);
        expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
      },
    );
  });

  group('runtime outages', () {
    final pg = TestPostgres.shared;

    Future<(ScratchDatabase, ServerRun)> running() async {
      final db = await pg.createScratch();
      addTearDown(db.drop);
      final run = ServerRun({
        'PORT': '${await freePort()}',
        'LOG_LEVEL': 'info',
        ...db.serverEnvironment(),
      }).start();
      await run.port;
      addTearDown(() async {
        if (!run.exited) await run.stop();
      });
      return (db, run);
    }

    test('connections killed by the database (pg_terminate_backend) do '
        'not leave /health unavailable: the pool reconnects', () async {
      final (db, run) = await running();
      expect((await run.get('/health')).$1, 200);
      await db.query(
        'SELECT pg_terminate_backend(pid) FROM pg_stat_activity '
        'WHERE application_name = @a',
        parameters: {'a': 'boardgame-server'},
      );
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      var status = 0;
      for (var i = 0; i < 15 && status != 200; i++) {
        status = (await run.get('/health')).$1;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      expect(status, 200);
      expect(run.exited, isFalse);
    });

    test('the database being dropped under a running server gives 503 and '
        'the server keeps running', () async {
      final (db, run) = await running();
      expect((await run.get('/health')).$1, 200);
      await db.drop();
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      final watch = Stopwatch()..start();
      final (status, body) = await run.get('/health');
      expect(status, 503);
      expect(body['database'], 'unavailable');
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(run.exited, isFalse);
      expect(await run.stop(), 0);
    });

    test('shutdown while the database is down still exits 0 within the '
        'grace period', () async {
      final proxy = await TcpProxy.start(pg.host, pg.port);
      addTearDown(proxy.close);
      final run = ServerRun({
        'PORT': '${await freePort()}',
        'LOG_LEVEL': 'info',
        ...pg.serverEnvironment(host: '127.0.0.1', port: proxy.port),
      }).start();
      await run.port;
      await proxy.hang();
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await run.get('/health');
      final watch = Stopwatch()..start();
      expect(await run.stop(), 0);
      // The pool close waits at most 5 s, then HTTP drain.
      expect(watch.elapsed, lessThan(const Duration(seconds: 9)));
    });
  });

  group('/health shape', () {
    late ServerRun run;
    setUp(() async {
      run = ServerRun({
        'PORT': '${await freePort()}',
        'LOG_LEVEL': 'info',
        ...TestPostgres.shared.serverEnvironment(),
      }).start();
      await run.port;
      addTearDown(() async {
        if (!run.exited) await run.stop();
      });
    });

    Future<(int, Map<String, String>, String)> send(
      String method,
      String path,
    ) async {
      final client = HttpClient()..findProxy = (_) => 'DIRECT';
      try {
        final req = await client.open(
          method,
          '127.0.0.1',
          await run.port,
          path,
        );
        final res = await req.close();
        final body = await utf8.decodeStream(res);
        final headers = <String, String>{};
        res.headers.forEach((k, v) => headers[k] = v.join(','));
        return (res.statusCode, headers, body);
      } finally {
        client.close(force: true);
      }
    }

    test(
      '200 body has exactly status, version, and database, as JSON',
      () async {
        final (status, headers, body) = await send('GET', '/health');
        expect(status, 200);
        expect(headers['content-type'], contains('application/json'));
        expect((jsonDecode(body) as Map<String, dynamic>).keys.toSet(), {
          'status',
          'version',
          'database',
        });
      },
    );

    test('a query string does not change the answer', () async {
      expect((await send('GET', '/health?x=1&database=down')).$1, 200);
    });

    test('POST /health is not a 200 and holds no database detail', () async {
      final (status, _, body) = await send('POST', '/health');
      expect(status, isNot(200));
      expect(body, isNot(contains('postgres')));
    });

    test('the response never carries PostgreSQL connection details', () async {
      final (_, _, body) = await send('GET', '/health');
      final pg = TestPostgres.shared;
      expect(body, isNot(contains(pg.password)));
      expect(body, isNot(contains(pg.host)));
      expect(body, isNot(contains(pg.user)));
    });
  });
}
