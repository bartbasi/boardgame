import 'dart:async';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

/// Unit tests for the probe scheduling in DatabaseHealth: caching, sharing
/// one probe, and the time limit. The probe here is a plain function, not
/// the database driver; the driver is tested against a real PostgreSQL in
/// health_test.dart (T-019 AC6, AC7).
void main() {
  var now = DateTime.utc(2026, 10, 13);
  DateTime clock() => now;

  setUp(() => now = DateTime.utc(2026, 10, 13));

  test('a result is reused for cacheFor, then probed again', () async {
    var calls = 0;
    final health = DatabaseHealth(probe: () async => calls++, clock: clock);

    expect(await health.isUp(), isTrue);
    expect(await health.isUp(), isTrue);
    expect(calls, 1);

    now = now.add(databaseHealthCacheFor);
    expect(await health.isUp(), isTrue);
    expect(calls, 2);
  });

  test('concurrent checks share one probe', () async {
    var calls = 0;
    final gate = Completer<void>();
    final health = DatabaseHealth(
      probe: () {
        calls++;
        return gate.future;
      },
      clock: clock,
    );

    final checks = [for (var i = 0; i < 10; i++) health.isUp()];
    gate.complete();
    expect(await Future.wait(checks), everyElement(isTrue));
    expect(calls, 1);
  });

  test('a probe that throws reports unavailable', () async {
    final health = DatabaseHealth(
      probe: () async => throw StateError('down'),
      clock: clock,
    );
    expect(await health.isUp(), isFalse);
  });

  test(
    'a probe that fails synchronously does not block later probes',
    () async {
      var calls = 0;
      final health = DatabaseHealth(
        probe: () {
          calls++;
          throw StateError('sync');
        },
        clock: clock,
        cacheFor: Duration.zero,
      );
      expect(await health.isUp(), isFalse);
      expect(await health.isUp(), isFalse);
      expect(calls, 2);
    },
  );

  test('a hanging probe answers unavailable after the timeout, and no new '
      'probe starts until it ends', () async {
    var calls = 0;
    final gate = Completer<void>();
    final health = DatabaseHealth(
      probe: () {
        calls++;
        return gate.future;
      },
      timeout: const Duration(milliseconds: 50),
      cacheFor: Duration.zero,
      clock: clock,
    );

    expect(await health.isUp(), isFalse);
    expect(await health.isUp(), isFalse);
    expect(calls, 1);

    gate.complete();
    await Future<void>.delayed(Duration.zero);
    expect(await health.isUp(), isTrue);
    expect(calls, 2);
  });

  test('while a probe has hung for the whole timeout, checks answer '
      'unavailable at once', () async {
    final gate = Completer<void>();
    final health = DatabaseHealth(
      probe: () => gate.future,
      timeout: const Duration(seconds: 1),
      cacheFor: Duration.zero,
      clock: clock,
    );

    // The first check waits for the probe (shared, still running).
    final first = health.isUp();
    now = now.add(const Duration(seconds: 1));
    final watch = Stopwatch()..start();
    expect(await health.isUp(), isFalse);
    expect(watch.elapsed, lessThan(const Duration(milliseconds: 500)));

    gate.complete();
    expect(await first, isTrue);
  });

  test('onChange fires on each change, starting from "up"', () async {
    final changes = <bool>[];
    var fail = false;
    final health = DatabaseHealth(
      probe: () async {
        if (fail) throw StateError('down');
      },
      clock: clock,
      cacheFor: Duration.zero,
      onChange: changes.add,
    );

    await health.isUp();
    expect(changes, isEmpty);
    fail = true;
    await health.isUp();
    await health.isUp();
    expect(changes, [false]);
    fail = false;
    await health.isUp();
    expect(changes, [false, true]);
  });

  test('the defaults keep /health under 2 s (T-019 AC6)', () {
    expect(databaseHealthTimeout, lessThan(const Duration(seconds: 2)));
  });

  group('healthResponse', () {
    test('up: 200 with status and database "ok"', () async {
      final response = healthResponse(version: 'v1', databaseUp: true);
      expect(response.statusCode, 200);
      expect(await jsonObjectOf(response), {
        'status': 'ok',
        'version': 'v1',
        'database': 'ok',
      });
    });

    test('down: 503 with status and database "unavailable"', () async {
      final response = healthResponse(version: 'v1', databaseUp: false);
      expect(response.statusCode, 503);
      expect(response.headers['content-type'], 'application/json');
      expect(await jsonObjectOf(response), {
        'status': 'unavailable',
        'version': 'v1',
        'database': 'unavailable',
      });
    });

    test('the route uses the health check it is given', () async {
      final app = TestApp(
        databaseHealth: DatabaseHealth(
          probe: () async => throw StateError('down'),
        ),
      );
      final response = await app.get('/health');
      expect(response.statusCode, 503);
      expect((await jsonObjectOf(response))['database'], 'unavailable');
      expect(app.logs.withMessage('request').single['status'], 503);
    });
  });
}
