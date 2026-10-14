import 'dart:async';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

import '../support/database.dart';
import '../support/harness.dart';

/// QA round 2 for T-020: the sweep timer's lifecycle inside runServer, with a
/// fake timer. Needs the test database (CI runs it).

class _FakeTimer implements Timer {
  _FakeTimer(this.callback);
  final void Function(Timer) callback;
  int cancels = 0;
  bool active = true;

  @override
  void cancel() {
    cancels++;
    active = false;
  }

  @override
  bool get isActive => active;

  @override
  int get tick => 0;
}

void main() {
  final created = <_FakeTimer>[];

  setUp(created.clear);

  Timer factory(Duration interval, void Function(Timer) callback) {
    final t = _FakeTimer(callback);
    created.add(t);
    return t;
  }

  Future<int> run(
    Map<String, String> environment,
    Stream<ProcessSignal> signals, {
    LogCapture? out,
    void Function(HttpServer)? onListening,
    Duration dbTimeout = const Duration(seconds: 10),
  }) => runServer(
    environment: environment,
    shutdownSignals: signals,
    stdoutLine: (out ?? LogCapture()).call,
    stderrLine: LogCapture().call,
    address: InternetAddress.loopbackIPv4,
    onListening: onListening,
    periodicTimer: factory,
    databaseStartupTimeout: dbTimeout,
  );

  test('normal run: exactly one timer, alive while serving, cancelled once '
      'after shutdown', () async {
    final signals = StreamController<ProcessSignal>();
    final listening = Completer<HttpServer>();
    final exit = run(
      withTestDatabase({'PORT': '${await freePort()}', 'LOG_LEVEL': 'info'}),
      signals.stream,
      onListening: listening.complete,
    );
    await listening.future;
    expect(created, hasLength(1));
    expect(created.single.isActive, isTrue);
    expect(created.single.cancels, 0);

    signals.add(ProcessSignal.sigterm);
    expect(await exit, 0);
    expect(created, hasLength(1), reason: 'no second timer');
    expect(created.single.cancels, 1);
    expect(created.single.isActive, isFalse);
    await signals.close();
  });

  test('a failed bind still cancels the timer, and exits 1', () async {
    final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(blocker.close);
    final signals = StreamController<ProcessSignal>();
    final exit = await run(
      withTestDatabase({'PORT': '${blocker.port}', 'LOG_LEVEL': 'info'}),
      signals.stream,
    );
    expect(exit, listenErrorExitCode);
    expect(created, hasLength(1));
    expect(created.single.cancels, 1);
    expect(created.single.isActive, isFalse);
    await signals.close();
  });

  test('database unreachable at startup: no timer is ever created', () async {
    final signals = StreamController<ProcessSignal>();
    final exit = await run(
      {
        'PORT': '${await freePort()}',
        'LOG_LEVEL': 'info',
        ...TestPostgres.shared.serverEnvironment(
          host: '127.0.0.1',
          port: await freePort(),
        ),
      },
      signals.stream,
      dbTimeout: const Duration(seconds: 2),
    );
    expect(exit, databaseUnavailableExitCode);
    expect(created, isEmpty);
    await signals.close();
  });

  test('a signal during the database wait leaves no active timer', () async {
    final signals = StreamController<ProcessSignal>();
    final exit = run(
      {
        'PORT': '${await freePort()}',
        'LOG_LEVEL': 'info',
        ...TestPostgres.shared.serverEnvironment(
          host: '127.0.0.1',
          port: await freePort(),
        ),
      },
      signals.stream,
      dbTimeout: const Duration(seconds: 30),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    signals.add(ProcessSignal.sigterm);
    expect(await exit, 0);
    expect(created.where((t) => t.isActive), isEmpty);
    await signals.close();
  });

  test('two servers in one process each get their own timer', () async {
    final signals = StreamController<ProcessSignal>.broadcast();
    final l1 = Completer<HttpServer>();
    final l2 = Completer<HttpServer>();
    final e1 = run(
      withTestDatabase({'PORT': '${await freePort()}', 'LOG_LEVEL': 'info'}),
      signals.stream,
      onListening: l1.complete,
    );
    final e2 = run(
      withTestDatabase({'PORT': '${await freePort()}', 'LOG_LEVEL': 'info'}),
      signals.stream,
      onListening: l2.complete,
    );
    await Future.wait([l1.future, l2.future]);
    expect(created, hasLength(2));
    signals.add(ProcessSignal.sigterm);
    expect(await Future.wait([e1, e2]), [0, 0]);
    expect(created.map((t) => t.cancels), [1, 1]);
    await signals.close();
  });

  test('the sweep callback empties the running limiter without traffic '
      '(a tick after the window would clear it; here it must not break '
      'serving)', () async {
    final signals = StreamController<ProcessSignal>();
    final listening = Completer<HttpServer>();
    final exit = run(
      withTestDatabase({
        'PORT': '${await freePort()}',
        'LOG_LEVEL': 'info',
        'RATE_LIMIT_PER_MINUTE': '1',
      }),
      signals.stream,
      onListening: listening.complete,
    );
    final port = (await listening.future).port;
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    Future<int> get(String path) async {
      final r = await (await client.get('127.0.0.1', port, path)).close();
      await r.drain<void>();
      return r.statusCode;
    }

    expect(await get('/v1/nope'), 404);
    expect(await get('/v1/nope'), 429);
    // Ticks inside the window change nothing.
    for (var i = 0; i < 5; i++) {
      created.single.callback(created.single);
    }
    expect(await get('/v1/nope'), 429);
    expect(await get('/health'), 200);
    signals.add(ProcessSignal.sigterm);
    expect(await exit, 0);
    await signals.close();
  });
}
