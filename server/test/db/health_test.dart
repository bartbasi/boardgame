import 'dart:async';

import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import '../support/database.dart';
import '../support/harness.dart';
import '../support/server_run.dart';

/// GET /health against a real PostgreSQL reached through a TCP proxy, so the
/// test can take the database away and bring it back (T-019 AC6, AC7).
void main() {
  late TcpProxy proxy;
  late ServerRun run;

  setUp(() async {
    final pg = TestPostgres.shared;
    proxy = await TcpProxy.start(pg.host, pg.port);
    addTearDown(proxy.close);
    run = ServerRun({
      'PORT': '${await freePort()}',
      'LOG_LEVEL': 'info',
      ...pg.serverEnvironment(host: '127.0.0.1', port: proxy.port),
    }).start();
    await run.port;
    addTearDown(() async {
      if (!run.exited) await run.stop();
    });
  });

  /// Polls /health until it returns [status] or [within] passes.
  Future<(int, Map<String, dynamic>)> waitFor(
    int status, {
    Duration within = const Duration(seconds: 15),
  }) async {
    final watch = Stopwatch()..start();
    while (true) {
      final result = await run.get('/health');
      if (result.$1 == status || watch.elapsed > within) return result;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  test(
    'AC6: with PostgreSQL reachable, /health is 200 with database "ok"',
    () async {
      final (status, body) = await run.get('/health');
      expect(status, 200);
      expect(body['database'], 'ok');
      expect(body['status'], 'ok');
      expect(
        HealthResponse.fromJson(body),
        const HealthResponse(status: 'ok', version: '1.0.0+db'),
      );
    },
  );

  test('AC6: with PostgreSQL down, /health is 503 with database '
      '"unavailable" within 2 s, the server keeps running, and it recovers '
      'when PostgreSQL comes back', () async {
    expect((await run.get('/health')).$1, 200);

    await proxy.down();
    // Let the 1 s cache of the last good result run out, so the next
    // request really probes the database.
    await Future<void>.delayed(const Duration(milliseconds: 1100));

    final watch = Stopwatch()..start();
    final (status, body) = await run.get('/health');
    final elapsed = watch.elapsed;
    expect(status, 503);
    expect(body['database'], 'unavailable');
    expect(body['status'], 'unavailable');
    expect(body['version'], '1.0.0+db');
    expect(elapsed, lessThan(const Duration(seconds: 2)));

    // Still running: more requests are answered and runServer has not
    // returned.
    for (var i = 0; i < 3; i++) {
      expect((await run.get('/health')).$1, 503);
    }
    expect(run.exited, isFalse);
    // The warning comes when the probe itself ends, which can be after the
    // 503 answers (Windows takes about 2 s to report a refused connection).
    for (var i = 0; i < 100; i++) {
      if (run.out.withMessage('database unavailable').isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(
      run.out.withMessage('database unavailable').single['level'],
      'warning',
    );

    await proxy.up();
    final (backStatus, backBody) = await waitFor(200);
    expect(backStatus, 200);
    expect(backBody['database'], 'ok');
    expect(run.out.withMessage('database available again'), hasLength(1));
    expect(run.exited, isFalse);
  });

  test('AC6: with PostgreSQL hanging (accepts, never answers), /health is '
      '503 within 2 s', () async {
    await proxy.hang();
    await Future<void>.delayed(const Duration(milliseconds: 1100));

    for (var i = 0; i < 3; i++) {
      final watch = Stopwatch()..start();
      final (status, body) = await run.get('/health');
      expect(status, 503);
      expect(body['database'], 'unavailable');
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    }

    await proxy.up();
    expect((await waitFor(200)).$1, 200);
  });

  test('a burst of /health requests while the database is down still '
      'answers each within 2 s', () async {
    await proxy.down();
    await Future<void>.delayed(const Duration(milliseconds: 1100));

    final watch = Stopwatch()..start();
    final results = await Future.wait([
      for (var i = 0; i < 20; i++) run.get('/health'),
    ]);
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    expect({for (final r in results) r.$1}, {503});
  });

  test('AC4: no log line holds the database password, through startup, an '
      'outage, and recovery', () async {
    await proxy.down();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await run.get('/health');
    await proxy.up();
    await waitFor(200);
    await run.stop();

    final password = TestPostgres.shared.password;
    expect(run.allLines, isNotEmpty);
    for (final line in run.allLines) {
      expect(line, isNot(contains(password)));
    }
  });
}
