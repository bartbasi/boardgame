import 'dart:async';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

import '../support/database.dart';
import '../support/harness.dart';
import '../support/server_run.dart';

/// Startup when PostgreSQL is missing, slow, or refuses the login, and the
/// pool size (T-019 AC4, AC5), against a real PostgreSQL.
void main() {
  final pg = TestPostgres.shared;

  Future<Map<String, String>> envVia(TcpProxy proxy) async => {
    'PORT': '${await freePort()}',
    'LOG_LEVEL': 'info',
    ...pg.serverEnvironment(host: '127.0.0.1', port: proxy.port),
  };

  test('PostgreSQL unreachable for the whole startup timeout: exit 69, '
      'nothing listens, and the password is never printed', () async {
    final proxy = await TcpProxy.start(pg.host, pg.port);
    addTearDown(proxy.close);
    await proxy.down();

    final run = ServerRun(
      await envVia(proxy),
      // Windows takes about 2 s to report a refused loopback connection.
      databaseStartupTimeout: const Duration(seconds: 6),
    ).start();

    expect(await run.exitCode, databaseUnavailableExitCode);
    expect(databaseUnavailableExitCode, 69);
    expect(run.listening.isCompleted, isFalse);
    final retry = run.out.withMessage('database not reachable yet, retrying');
    expect(retry.single['level'], 'warning');
    final gaveUp = run.out.withMessage('database unreachable').single;
    expect(gaveUp['level'], 'error');
    expect(gaveUp['attempts'], greaterThanOrEqualTo(2));
    expect(gaveUp['timeoutMs'], 6000);
    for (final line in run.allLines) {
      expect(line, isNot(contains(pg.password)));
    }
  });

  test('PostgreSQL that comes up during the startup wait: the server '
      'starts', () async {
    final proxy = await TcpProxy.start(pg.host, pg.port);
    addTearDown(proxy.close);
    await proxy.down();

    final run = ServerRun(await envVia(proxy)).start();
    // Wait until the first attempt has failed.
    while (run.out
        .withMessage('database not reachable yet, retrying')
        .isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(run.listening.isCompleted, isFalse);
    await proxy.up();

    await run.port;
    final reachable = run.out.withMessage('database reachable').single;
    expect(reachable['attempts'], greaterThanOrEqualTo(2));
    expect((await run.get('/health')).$1, 200);
    expect(await run.stop(), 0);
  });

  test(
    'a shutdown signal while waiting for PostgreSQL exits 0 at once',
    () async {
      final proxy = await TcpProxy.start(pg.host, pg.port);
      addTearDown(proxy.close);
      await proxy.down();

      final run = ServerRun(
        await envVia(proxy),
        databaseStartupTimeout: const Duration(seconds: 30),
      ).start();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final watch = Stopwatch()..start();
      run.signals.add(ProcessSignal.sigterm);

      expect(await run.exitCode, 0);
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
      expect(run.out.withMessage('shutdown during startup'), hasLength(1));
      expect(run.listening.isCompleted, isFalse);
    },
  );

  test('AC4: a wrong password exits 69 and neither password appears in '
      'any output', () async {
    final wrong = fakePassword('wrong');
    final run = ServerRun({
      'PORT': '${await freePort()}',
      'LOG_LEVEL': 'debug',
      ...pg.serverEnvironment(),
      'DATABASE_PASSWORD': wrong,
    }, databaseStartupTimeout: const Duration(seconds: 2)).start();

    expect(await run.exitCode, databaseUnavailableExitCode);
    final gaveUp = run.out.withMessage('database unreachable').single;
    // 28P01 is invalid_password.
    expect(gaveUp['error'], contains('28P01'));
    for (final line in run.allLines) {
      expect(line, isNot(contains(wrong)));
      expect(line, isNot(contains(pg.password)));
    }
  });

  test('AC4: invalid database settings exit 78 naming each variable, '
      'never the password or another value', () async {
    final secret = fakePassword('config');
    final err = <String>[];
    final out = <String>[];
    final code = await runServer(
      environment: {
        'PORT': '8080',
        'LOG_LEVEL': 'info',
        'DATABASE_HOST': 'bad host',
        'DATABASE_PORT': '99999',
        'DATABASE_NAME': 'n' * 64,
        'DATABASE_USER': '',
        'DATABASE_PASSWORD': secret,
        'DATABASE_POOL_MAX': '0',
      },
      shutdownSignals: const Stream.empty(),
      stdoutLine: out.add,
      stderrLine: err.add,
    );

    expect(code, configErrorExitCode);
    expect(out, isEmpty);
    final line = err.single;
    for (final name in [
      'DATABASE_HOST is invalid',
      'DATABASE_PORT is invalid',
      'DATABASE_NAME is invalid',
      'DATABASE_USER is missing',
      'DATABASE_POOL_MAX is invalid',
    ]) {
      expect(line, contains(name));
    }
    expect(line, isNot(contains('DATABASE_PASSWORD')));
    expect(line, isNot(contains(secret)));
    expect(line, isNot(contains('bad host')));
    expect(line, isNot(contains('99999')));
  });

  test('AC4: a config line names a missing PORT and a missing password '
      'together', () async {
    final err = <String>[];
    final code = await runServer(
      environment: {
        'LOG_LEVEL': 'info',
        ...pg.serverEnvironment(),
        'DATABASE_PASSWORD': '   ',
      },
      shutdownSignals: const Stream.empty(),
      stdoutLine: (_) {},
      stderrLine: err.add,
    );
    expect(code, configErrorExitCode);
    expect(err.single, contains('PORT is missing'));
    expect(err.single, contains('DATABASE_PASSWORD is missing'));
  });

  test(
    'AC5: the pool never opens more connections than DATABASE_POOL_MAX',
    () async {
      final db = await pg.createScratch();
      addTearDown(db.drop);
      final config = DatabaseConfig.load({
        ...db.serverEnvironment(),
        'DATABASE_POOL_MAX': '2',
      });
      expect(config.poolMax, 2);
      final database = Database.open(config);
      addTearDown(database.close);

      // Five slow queries at once; at most two may run.
      final queries = [
        for (var i = 0; i < 5; i++)
          database.pool.execute('SELECT pg_sleep(0.3)'),
      ];
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final rows = await db.query(
        'SELECT count(*)::int FROM pg_stat_activity '
        "WHERE application_name = 'boardgame-server' "
        'AND datname = current_database()',
      );
      await Future.wait(queries);
      expect(rows.single.single, 2);
    },
  );

  test('describeError keeps only the SQLSTATE of a real server error, not '
      'the values PostgreSQL quotes', () async {
    final db = await pg.createScratch();
    addTearDown(db.drop);
    final connection = await db.connect();
    addTearDown(connection.close);
    await connection.execute('CREATE TABLE t (v integer UNIQUE)');
    await connection.execute('INSERT INTO t VALUES (424242)');

    Object? error;
    try {
      await connection.execute('INSERT INTO t VALUES (424242)');
    } on Object catch (e) {
      error = e;
    }
    // The driver's own text quotes the value.
    expect(error.toString(), contains('424242'));
    final described = describeError(error!);
    expect(described, isNot(contains('424242')));
    expect(described, contains('23505')); // unique_violation
  });
}
