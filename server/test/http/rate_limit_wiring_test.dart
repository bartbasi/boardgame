import 'dart:async';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

import '../support/database.dart';
import '../support/harness.dart';

/// T-020: runServer reads the rate limit settings and mounts the limiter as
/// the first /v1 guard.
void main() {
  Future<(Future<int>, Completer<HttpServer>, LogCapture, LogCapture)> start(
    Map<String, String> environment,
    StreamController<ProcessSignal> signals,
  ) async {
    final out = LogCapture();
    final err = LogCapture();
    final listening = Completer<HttpServer>();
    final exit = runServer(
      environment: environment,
      shutdownSignals: signals.stream,
      stdoutLine: out.call,
      stderrLine: err.call,
      address: InternetAddress.loopbackIPv4,
      clock: () => fixedNow,
      onListening: listening.complete,
      addTestRoutes: (v1) => v1.get('/ok', (_) => jsonResponse(200, {})),
    );
    return (exit, listening, out, err);
  }

  test('an invalid rate limit setting stops startup with exit 78, naming '
      'the variable', () async {
    final signals = StreamController<ProcessSignal>();
    final (exit, listening, out, err) = await start({
      'PORT': '8080',
      'LOG_LEVEL': 'info',
      'RATE_LIMIT_PER_MINUTE': 'lots',
      'TRUSTED_PROXY_ADDRESSES': 'caddy',
    }, signals);

    expect(await exit, configErrorExitCode);
    expect(listening.isCompleted, isFalse);
    final line = err.lines.single;
    expect(line, contains('RATE_LIMIT_PER_MINUTE is invalid'));
    expect(line, contains('TRUSTED_PROXY_ADDRESSES is invalid'));
    expect(line, isNot(contains('lots')));
    unawaited(signals.close());
  });

  test('the running server limits /v1 per forwarded client from a trusted '
      'proxy, leaves /health alone, and logs no address', () async {
    final signals = StreamController<ProcessSignal>();
    final environment = withTestDatabase({
      'PORT': '${await freePort()}',
      'LOG_LEVEL': 'info',
      'RATE_LIMIT_PER_MINUTE': '2',
      'TRUSTED_PROXY_ADDRESSES': '127.0.0.1',
    });
    final (exit, listening, out, _) = await start(environment, signals);
    final port = (await listening.future).port;
    final client = HttpClient();
    addTearDown(() => client.close(force: true));

    Future<HttpClientResponse> get(String path, String forwardedFor) async {
      final request = await client.get('127.0.0.1', port, path);
      request.headers.set('x-forwarded-for', forwardedFor);
      final response = await request.close();
      await response.drain<void>();
      return response;
    }

    final codes = [
      for (var i = 0; i < 3; i++)
        (await get('/v1/ok', '203.0.113.61')).statusCode,
    ];
    final limited = await get('/v1/ok', '203.0.113.61');
    final other = await get('/v1/ok', '203.0.113.62');
    final health = [
      for (var i = 0; i < 5; i++)
        (await get('/health', '203.0.113.61')).statusCode,
    ];

    expect(codes, [200, 200, 429]);
    expect(limited.statusCode, 429);
    expect(int.parse(limited.headers.value('retry-after')!), greaterThan(0));
    expect(other.statusCode, 200);
    expect(health, everyElement(200));

    signals.add(ProcessSignal.sigterm);
    expect(await exit, 0);
    for (final line in out.lines) {
      expect(line, isNot(contains('203.0.113')));
      expect(line, isNot(contains('127.0.0.1')));
    }
    unawaited(signals.close());
  });
}
