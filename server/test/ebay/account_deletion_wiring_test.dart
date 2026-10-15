import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

import '../support/database.dart';
import '../support/harness.dart';

/// T-084: runServer reads the eBay endpoint settings, fails fast on bad
/// ones, and serves the endpoint behind its own limiter.
const _token = 'fake-token-fake-token-fake-token-fake-token';
const _url = 'https://api.example.com/ebay/marketplace-account-deletion';

void main() {
  final sweepIntervals = <Duration>[];
  final sweepTimers = <Timer>[];

  setUp(() {
    sweepIntervals.clear();
    sweepTimers.clear();
  });
  tearDown(() {
    for (final timer in sweepTimers) {
      timer.cancel();
    }
  });

  (Future<int>, Completer<HttpServer>, LogCapture, LogCapture) start(
    Map<String, String> environment,
    StreamController<ProcessSignal> signals,
  ) {
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
      periodicTimer: (interval, callback) {
        sweepIntervals.add(interval);
        final timer = Timer.periodic(interval, callback);
        sweepTimers.add(timer);
        return timer;
      },
    );
    return (exit, listening, out, err);
  }

  test('AC3 and AC4 at startup: a bad token or URL stops the server with '
      'exit 78, naming both variables and printing neither value', () async {
    final signals = StreamController<ProcessSignal>();
    const badToken = 'too-short-secret-value';
    const badUrl = 'http://10.0.0.5/ebay/marketplace-account-deletion';
    final (exit, listening, out, err) = start({
      'PORT': '8080',
      'LOG_LEVEL': 'info',
      ebayAccountDeletionTokenVariable: badToken,
      ebayAccountDeletionUrlVariable: badUrl,
    }, signals);

    expect(await exit, configErrorExitCode);
    expect(listening.isCompleted, isFalse);
    expect(out.lines, isEmpty);
    final line = err.lines.single;
    expect(line, contains('$ebayAccountDeletionTokenVariable is invalid'));
    expect(line, contains('$ebayAccountDeletionUrlVariable is invalid'));
    // The other loaders still report their problems in the same line.
    expect(line, contains('DATABASE_HOST is missing'));
    expect(line, isNot(contains(badToken)));
    expect(line, isNot(contains('10.0.0.5')));
    unawaited(signals.close());
  });

  test('only one of the pair set stops startup with exit 78', () async {
    final signals = StreamController<ProcessSignal>();
    final (exit, _, _, err) = start({
      'PORT': '8080',
      'LOG_LEVEL': 'info',
      ebayAccountDeletionTokenVariable: _token,
    }, signals);
    expect(await exit, configErrorExitCode);
    expect(
      err.lines.single,
      contains(
        '$ebayAccountDeletionUrlVariable is '
        'missing',
      ),
    );
    expect(err.lines.single, isNot(contains(_token)));
    unawaited(signals.close());
  });

  // Needs the test database (TEST_DATABASE_*), like every test that starts
  // the server; runs in CI.
  test(
    'the running server answers the challenge, acknowledges a '
    'notification, limits the endpoint separately, and logs no value',
    () async {
      final signals = StreamController<ProcessSignal>();
      final environment = withTestDatabase({
        'PORT': '${await freePort()}',
        'LOG_LEVEL': 'info',
        // 1 per minute on /v1 shows the eBay endpoint has its own allowance.
        'RATE_LIMIT_PER_MINUTE': '1',
        ebayAccountDeletionTokenVariable: _token,
        ebayAccountDeletionUrlVariable: _url,
      });
      final (exit, listening, out, _) = start(environment, signals);
      final port = (await listening.future).port;
      final client = HttpClient()..findProxy = (_) => 'DIRECT';
      addTearDown(() => client.close(force: true));

      expect(
        out.withMessage('eBay account deletion endpoint').single,
        containsPair('enabled', true),
      );
      // One sweep timer per limiter (/v1 and eBay).
      expect(sweepIntervals, hasLength(2));

      final get = await client.get(
        '127.0.0.1',
        port,
        '$ebayAccountDeletionPath?challenge_code=123',
      );
      final getResponse = await get.close();
      expect(getResponse.statusCode, 200);
      expect(getResponse.headers.contentType?.mimeType, 'application/json');
      expect(jsonDecode(await utf8.decodeStream(getResponse)), {
        'challengeResponse': challengeResponse('123', _token, _url),
      });

      final post = await client.post('127.0.0.1', port, ebayAccountDeletionPath)
        ..headers.contentType = ContentType.json
        ..write('{"notification":{"data":{"username":"MARKER-USER-w1"}}}');
      final postResponse = await post.close();
      expect(postResponse.statusCode, 204);
      await postResponse.drain<void>();

      // 58 more requests reach the eBay limit of 60; the next is refused.
      for (var i = 0; i < 58; i++) {
        final r = await (await client.get(
          '127.0.0.1',
          port,
          '$ebayAccountDeletionPath?challenge_code=c$i',
        )).close();
        expect(r.statusCode, 200);
        await r.drain<void>();
      }
      final refused = await (await client.get(
        '127.0.0.1',
        port,
        '$ebayAccountDeletionPath?challenge_code=x',
      )).close();
      expect(refused.statusCode, 429);
      await refused.drain<void>();

      // The same client still has its own /v1 allowance (1 per minute here).
      Future<int> v1Status() async {
        final r = await (await client.get('127.0.0.1', port, '/v1/x')).close();
        await r.drain<void>();
        return r.statusCode;
      }

      expect(await v1Status(), 404);
      expect(await v1Status(), 429);

      signals.add(ProcessSignal.sigterm);
      expect(await exit, 0);

      final all = out.lines.join('\n');
      expect(all, isNot(contains('MARKER-USER-w1')));
      expect(all, isNot(contains(_token)));
      expect(all, isNot(contains('challenge_code')));
    },
  );

  test('without the pair the endpoint is off and startup says so', () async {
    final signals = StreamController<ProcessSignal>();
    final environment = withTestDatabase({
      'PORT': '${await freePort()}',
      'LOG_LEVEL': 'info',
    });
    final (exit, listening, out, _) = start(environment, signals);
    final port = (await listening.future).port;
    final client = HttpClient()..findProxy = (_) => 'DIRECT';
    addTearDown(() => client.close(force: true));

    expect(
      out.withMessage('eBay account deletion endpoint').single,
      containsPair('enabled', false),
    );
    expect(sweepIntervals, hasLength(1));
    final response = await (await client.get(
      '127.0.0.1',
      port,
      '$ebayAccountDeletionPath?challenge_code=123',
    )).close();
    expect(response.statusCode, 404);
    await response.drain<void>();

    signals.add(ProcessSignal.sigterm);
    expect(await exit, 0);
  });
}
