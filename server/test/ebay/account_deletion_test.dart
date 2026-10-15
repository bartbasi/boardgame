import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

const _token = 'fake-token-fake-token-fake-token-fake-token';
const _url = 'https://api.example.com/ebay/marketplace-account-deletion';
const _config = EbayAccountDeletionConfig(
  verificationToken: _token,
  endpointUrl: _url,
);

/// Connection info as shelf_io puts it into the request context.
class _Connection implements HttpConnectionInfo {
  _Connection(String address) : remoteAddress = InternetAddress(address);

  @override
  final InternetAddress remoteAddress;

  @override
  int get remotePort => 50000;

  @override
  int get localPort => 8080;
}

/// A fake monotonic clock.
class _Clock {
  Duration now = Duration.zero;

  Duration call() => now;
}

/// A /v1 guard that refuses everything, standing in for app attestation
/// (T-066), so a test can show the eBay route never passes through it.
Middleware _refuseAllV1(List<String> seen) =>
    (inner) => (request) {
      seen.add(request.url.path);
      return jsonResponse(401, {'error': 'attestation required'});
    };

/// The app with the eBay endpoint on, its own limiter (fake clock), a /v1
/// guard that refuses everything, and captured logs.
class _EbayApp {
  _EbayApp({EbayAccountDeletionConfig? config = _config, bool limited = true}) {
    final resolver = ClientAddressResolver();
    ebayLimiter = RateLimiter(limit: ebayRateLimitPerMinute, now: clock.call);
    v1Limiter = RateLimiter(now: clock.call);
    handler = buildApp(
      version: 'v',
      logger: logs.logger(),
      databaseHealth: DatabaseHealth.alwaysUp(),
      v1Middleware: [rateLimit(v1Limiter, resolver), _refuseAllV1(v1Seen)],
      ebayAccountDeletion: config,
      ebayMiddleware: [if (limited) rateLimit(ebayLimiter, resolver)],
    );
  }

  final clock = _Clock();
  final logs = LogCapture();
  final v1Seen = <String>[];
  late final RateLimiter ebayLimiter;
  late final RateLimiter v1Limiter;
  late final Handler handler;

  Future<Response> send(
    String method,
    String pathAndQuery, {
    String peer = '203.0.113.7',
    Object? body,
    Map<String, String> headers = const {},
  }) async => handler(
    Request(
      method,
      Uri.parse('http://localhost$pathAndQuery'),
      body: body,
      headers: headers,
      context: {connectionInfoContextKey: _Connection(peer)},
    ),
  );

  Future<Response> challenge(String code, {String peer = '203.0.113.7'}) =>
      send(
        'GET',
        '$ebayAccountDeletionPath?challenge_code='
            '${Uri.encodeQueryComponent(code)}',
        peer: peer,
      );
}

/// A notification shaped like eBay's (EBAY-15), with marker values that must
/// never show up in a log line.
const _markers = [
  'MARKER-USERNAME-x7q',
  'MARKER-USERID-k2p',
  'MARKER-EIAS-m9z',
  'MARKER-NOTIFICATION-ID-r4t',
];
final _notification = jsonEncode({
  'metadata': {
    'topic': 'MARKETPLACE_ACCOUNT_DELETION',
    'schemaVersion': '1.0',
    'deprecated': false,
  },
  'notification': {
    'notificationId': _markers[3],
    'eventDate': '2026-10-14T10:00:00.000Z',
    'publishDate': '2026-10-14T10:00:01.000Z',
    'publishAttemptCount': 1,
    'data': {
      'username': _markers[0],
      'userId': _markers[1],
      'eiasToken': _markers[2],
    },
  },
});

void main() {
  group('AC1: challenge response', () {
    final fixture = jsonDecode(
      File('test/fixtures/ebay/account_deletion_challenge.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();

    test('challengeResponse matches the hashes computed outside Dart and '
        'stored in the fixture', () {
      expect(cases, hasLength(2));
      for (final c in cases) {
        expect(
          challengeResponse(
            c['challengeCode'] as String,
            c['verificationToken'] as String,
            c['endpointUrl'] as String,
          ),
          c['expectedChallengeResponse'],
        );
      }
    });

    test('the order matters: code, token, URL', () {
      final c = cases.first;
      final code = c['challengeCode'] as String;
      final expected = c['expectedChallengeResponse'];
      expect(challengeResponse(_token, code, _url), isNot(expected));
      expect(challengeResponse(_url, _token, code), isNot(expected));
    });

    test(
      'GET with challenge_code answers 200 application/json with only '
      '{"challengeResponse": <lowercase hex>} and no byte order mark',
      () async {
        final app = _EbayApp();
        for (final c in cases) {
          final response = await app.challenge(c['challengeCode'] as String);
          expect(response.statusCode, 200);
          expect(response.headers['content-type'], 'application/json');
          final bytes = await response.read().expand((chunk) => chunk).toList();
          expect(bytes.first, '{'.codeUnitAt(0), reason: 'no BOM');
          final body = jsonDecode(utf8.decode(bytes));
          expect(body, {'challengeResponse': c['expectedChallengeResponse']});
          expect(
            (body as Map)['challengeResponse'],
            matches(RegExp(r'^[0-9a-f]{64}$')),
          );
        }
      },
    );

    test(
      'a percent-encoded challenge code is hashed in its decoded form',
      () async {
        final app = _EbayApp();
        const code = 'a b+c/d=e&f';
        final response = await app.challenge(code);
        expect(response.statusCode, 200);
        expect(await jsonObjectOf(response), {
          'challengeResponse': challengeResponse(code, _token, _url),
        });
      },
    );

    test('the request log line holds no challenge code or hash', () async {
      final app = _EbayApp();
      const code = 'MARKER-CHALLENGE-v8w';
      final response = await app.challenge(code);
      final hash = challengeResponse(code, _token, _url);
      expect(response.statusCode, 200);
      final line = app.logs.lines.single;
      expect(jsonDecode(line), containsPair('route', ebayAccountDeletionPath));
      expect(line, isNot(contains(code)));
      expect(line, isNot(contains(hash)));
      expect(line, isNot(contains(_token)));
    });

    final bad = <String, String>{
      'no query': '',
      'another parameter only': '?code=123',
      'an empty challenge_code': '?challenge_code=',
      'challenge_code twice': '?challenge_code=1&challenge_code=2',
      'a challenge_code over the length limit':
          '?challenge_code=${'a' * (maxChallengeCodeLength + 1)}',
    };
    for (final MapEntry(key: name, value: query) in bad.entries) {
      test('GET with $name answers 400 invalid_challenge_code', () async {
        final app = _EbayApp();
        final response = await app.send(
          'GET',
          '$ebayAccountDeletionPath$query',
        );
        expect(response.statusCode, 400);
        expect(await jsonObjectOf(response), {
          'error': {
            'code': 'invalid_challenge_code',
            'message': 'Expected one challenge_code query parameter.',
          },
        });
      });
    }

    test('a stray % that is not an escape is kept literally, as Dart '
        'decodes it, and hashed', () async {
      final app = _EbayApp();
      final response = await app.send(
        'GET',
        '$ebayAccountDeletionPath?challenge_code=%zz',
      );
      expect(response.statusCode, 200);
      expect(await jsonObjectOf(response), {
        'challengeResponse': challengeResponse('%zz', _token, _url),
      });
    });

    test('a challenge code of exactly the length limit is accepted', () async {
      final app = _EbayApp();
      final code = 'a' * maxChallengeCodeLength;
      final response = await app.challenge(code);
      expect(response.statusCode, 200);
    });
  });

  group('AC2: notifications are acknowledged, never stored or logged', () {
    test('POST answers 204 with an empty body, and the only log line is the '
        'request line (method, route, status, duration)', () async {
      final app = _EbayApp();
      final response = await app.send(
        'POST',
        ebayAccountDeletionPath,
        body: _notification,
        headers: {
          'content-type': 'application/json',
          'x-ebay-signature': 'MARKER-SIGNATURE-b3n',
        },
      );
      expect(response.statusCode, 204);
      expect(await response.readAsString(), isEmpty);
      expect(EbayStatus.success.contains(response.statusCode), isTrue);

      final records = app.logs.records;
      expect(records, hasLength(1));
      expect(records.single.keys.toSet(), {
        'ts',
        'level',
        'msg',
        'method',
        'route',
        'status',
        'durationMs',
      });
      expect(records.single, containsPair('route', ebayAccountDeletionPath));
      expect(records.single, containsPair('status', 204));
      for (final marker in [..._markers, 'MARKER-SIGNATURE-b3n']) {
        expect(app.logs.lines.join('\n'), isNot(contains(marker)));
      }
    });

    test('any body is acknowledged without parsing: empty, not JSON, and '
        'binary', () async {
      final app = _EbayApp();
      for (final body in <Object?>[
        null,
        'not json {',
        [0, 255, 254, 1, 2],
      ]) {
        final response = await app.send(
          'POST',
          ebayAccountDeletionPath,
          body: body,
        );
        expect(response.statusCode, 204);
      }
    });

    test('a body over the size limit gets 413, by Content-Length or while '
        'reading, and is not logged', () async {
      final app = _EbayApp();
      final big = 'MARKER-BIG-'.padRight(maxNotificationBytes + 1, 'x');
      final declared = await app.send(
        'POST',
        ebayAccountDeletionPath,
        body: big,
      );
      expect(declared.statusCode, 413);
      expect(
        (await jsonObjectOf(declared))['error'],
        containsPair('code', 'payload_too_large'),
      );

      // No Content-Length: a stream whose chunks pass the limit.
      final streamed = await app.send(
        'POST',
        ebayAccountDeletionPath,
        body: Stream<List<int>>.fromIterable([
          utf8.encode('x' * maxNotificationBytes),
          utf8.encode('MARKER-BIG-tail'),
        ]),
      );
      expect(streamed.statusCode, 413);
      expect(app.logs.lines.join('\n'), isNot(contains('MARKER-BIG')));
    });

    test('exactly the size limit is still acknowledged', () async {
      final app = _EbayApp();
      final response = await app.send(
        'POST',
        ebayAccountDeletionPath,
        body: 'x' * maxNotificationBytes,
      );
      expect(response.statusCode, 204);
    });

    Handler routeWithDeadline(Duration deadline) {
      final router = Router(notFoundHandler: (_) => notFoundResponse());
      addEbayAccountDeletionRoutes(
        Routes(router, mountPath: ebayMountPath),
        _config,
        readTimeout: deadline,
      );
      return router.call;
    }

    test('a body that stalls gets 408 after the read timeout', () async {
      final stalled = StreamController<List<int>>();
      stalled.add(utf8.encode('{"metadata":'));
      final response =
          await routeWithDeadline(const Duration(milliseconds: 50))(
            Request(
              'POST',
              Uri.parse('http://localhost$ebayAccountDeletionRoute'),
              body: stalled.stream,
            ),
          );
      expect(response.statusCode, 408);
      expect(
        (await jsonObjectOf(response))['error'],
        containsPair('code', 'request_timeout'),
      );
      unawaited(stalled.close());
    });

    test('R1-M1: a body trickling one byte every quarter of the deadline gets '
        '408 at the overall deadline, and reading stops', () async {
      const deadline = Duration(milliseconds: 400);
      var cancelled = false;
      late final StreamController<List<int>> trickle;
      // Never ends by itself; each gap is far below the deadline, so a
      // per-chunk timeout would never fire.
      final ticker = Timer.periodic(deadline ~/ 4, (_) => trickle.add([0x20]));
      trickle = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
          ticker.cancel();
        },
      );
      addTearDown(ticker.cancel);
      final stopwatch = Stopwatch()..start();
      final response = await routeWithDeadline(deadline)(
        Request(
          'POST',
          Uri.parse('http://localhost$ebayAccountDeletionRoute'),
          body: trickle.stream,
        ),
      );
      stopwatch.stop();
      expect(response.statusCode, 408);
      expect(stopwatch.elapsed, greaterThanOrEqualTo(deadline));
      expect(stopwatch.elapsed, lessThan(deadline * 5));
      expect(cancelled, isTrue, reason: 'the body subscription is cancelled');
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('R1-M1: a body that completes before the deadline is acknowledged '
        'and its timer does not fire later', () async {
      final chunks = StreamController<List<int>>();
      final pending = routeWithDeadline(const Duration(milliseconds: 200))(
        Request(
          'POST',
          Uri.parse('http://localhost$ebayAccountDeletionRoute'),
          body: chunks.stream,
        ),
      );
      chunks.add(utf8.encode('{"a":'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      chunks.add(utf8.encode('1}'));
      await chunks.close();
      expect((await pending).statusCode, 204);
      // Past the deadline: nothing else happens (a second completion would
      // throw "Future already completed" into the zone).
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });

    test('R1-M1: the default deadline is 10 s for the whole body '
        '[ASSUMPTION]', () {
      expect(notificationReadTimeout, const Duration(seconds: 10));
    });

    test('the handler needs no database: it acknowledges while the database '
        'is down', () async {
      final logs = LogCapture();
      final handler = buildApp(
        version: 'v',
        logger: logs.logger(),
        databaseHealth: DatabaseHealth(
          probe: () async => throw StateError('database down'),
        ),
        ebayAccountDeletion: _config,
      );
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost$ebayAccountDeletionPath'),
          body: _notification,
        ),
      );
      expect(response.statusCode, 204);
    });

    test('source check: the endpoint code imports nothing that could store '
        'or log (no database, file, or logger code)', () {
      final source = File('lib/src/ebay/account_deletion.dart')
          .readAsStringSync();
      final imports = RegExp(
        r"^import '([^']+)';",
        multiLine: true,
      ).allMatches(source).map((m) => m[1]).toList();
      expect(imports, [
        'dart:async',
        'dart:convert',
        'package:crypto/crypto.dart',
        'package:shelf/shelf.dart',
        '../config/ebay_account_deletion_config.dart',
        '../http/responses.dart',
        '../http/routes.dart',
      ]);
      expect(source, isNot(contains('logger')));
      expect(source, isNot(contains('print(')));
    });

    test('over a real socket through bindAndServe: 204, the connection stays '
        'usable, and no output line holds any part of the body', () async {
      final logs = LogCapture();
      final handler = buildApp(
        version: 'v',
        logger: logs.logger(),
        databaseHealth: DatabaseHealth.alwaysUp(),
        ebayAccountDeletion: _config,
      );
      final server = await bindAndServe(
        handler,
        InternetAddress.loopbackIPv4,
        0,
        logs.logger(),
      );
      addTearDown(() => server.close(force: true));
      final client = HttpClient()..findProxy = (_) => 'DIRECT';
      addTearDown(() => client.close(force: true));

      for (var i = 0; i < 2; i++) {
        final request = await client.post(
          '127.0.0.1',
          server.port,
          ebayAccountDeletionPath,
        );
        request.headers.contentType = ContentType.json;
        request.write(_notification);
        final response = await request.close();
        expect(response.statusCode, 204);
        await response.drain<void>();
      }
      // The body was read (and dropped), so dart:io kept one connection.
      expect(server.connectionsInfo().total, 1);

      final get = await client.get(
        '127.0.0.1',
        server.port,
        '$ebayAccountDeletionPath?challenge_code=123',
      );
      final getResponse = await get.close();
      expect(getResponse.statusCode, 200);
      expect(jsonDecode(await utf8.decodeStream(getResponse)), {
        'challengeResponse':
            '967880bc59b69cc2b317b6b308cb914166ee664c2a04882ca5713562244f149c',
      });

      // Percent-encoding that is not UTF-8 cannot become a shelf Request;
      // bindAndServe answers 404 before the handler runs.
      final raw = await rawHttp(
        server.port,
        'GET $ebayAccountDeletionPath?challenge_code=%ff HTTP/1.1\r\n'
        'Host: 127.0.0.1\r\nConnection: close\r\n\r\n',
      );
      expect(raw, startsWith('HTTP/1.1 404'));

      final all = logs.lines.join('\n');
      for (final marker in _markers) {
        expect(all, isNot(contains(marker)));
      }
      expect(all, isNot(contains('%ff')));
      expect(logs.withMessage('request'), hasLength(4));
    });
  });

  group('AC5: no app attestation, own per-IP limit (300 per minute since '
      'round 2)', () {
    const limit = ebayRateLimitPerMinute;

    test('the eBay route never passes through the /v1 guards', () async {
      final app = _EbayApp();
      expect((await app.challenge('123')).statusCode, 200);
      expect(
        (await app.send(
          'POST',
          ebayAccountDeletionPath,
          body: '{}',
        )).statusCode,
        204,
      );
      expect(app.v1Seen, isEmpty);
      expect((await app.send('GET', '/v1/games/1')).statusCode, 401);
      expect(app.v1Seen, ['games/1']);
    });

    test('the limit is 300 requests per minute [ASSUMPTION, orchestrator '
        'decision in round 2; AC5 said 60]', () {
      expect(ebayRateLimitPerMinute, 300);
    });

    test('of limit + 10 requests from one IP within a minute, the limit '
        'succeed and 10 get '
        '429 rate_limited with Retry-After; GET and POST share the '
        'allowance', () async {
      final app = _EbayApp();
      final statuses = <int>[];
      for (var i = 0; i < limit + 10; i++) {
        app.clock.now = Duration(milliseconds: i * 100);
        final response = i.isEven
            ? await app.challenge('c$i')
            : await app.send('POST', ebayAccountDeletionPath, body: '{}');
        statuses.add(response.statusCode);
        if (response.statusCode == 429) {
          expect(response.headers['retry-after'], matches(RegExp(r'^\d+$')));
          expect(
            (await jsonObjectOf(response))['error'],
            containsPair('code', 'rate_limited'),
          );
        }
      }
      expect(statuses.where((s) => s == 200 || s == 204), hasLength(limit));
      expect(statuses.skip(limit), everyElement(429));
    });

    test('another IP is not affected, and after a full minute the first IP '
        'is allowed again', () async {
      final app = _EbayApp();
      for (var i = 0; i < limit; i++) {
        expect((await app.challenge('c$i')).statusCode, 200);
      }
      expect((await app.challenge('x')).statusCode, 429);
      expect((await app.challenge('x', peer: '198.51.100.9')).statusCode, 200);
      app.clock.now = rateLimitWindow;
      expect((await app.challenge('x')).statusCode, 200);
    });

    test('the eBay limiter and the /v1 limiter are separate', () async {
      final app = _EbayApp();
      for (var i = 0; i < limit; i++) {
        await app.challenge('c$i');
      }
      expect(app.ebayLimiter.trackedCount, 1);
      expect(app.v1Limiter.trackedCount, 0);
      // /v1 still has its own allowance for the same IP (the guard behind
      // the limiter answers 401, not 429).
      expect((await app.send('GET', '/v1/games/1')).statusCode, 401);
      expect(app.v1Limiter.trackedCount, 1);
    });

    test('/health is not limited by the eBay limiter', () async {
      final app = _EbayApp();
      for (var i = 0; i < limit + 1; i++) {
        await app.challenge('c$i');
      }
      expect((await app.send('GET', '/health')).statusCode, 200);
    });
  });

  group('endpoint off', () {
    test('without config, GET and POST on the path answer 404', () async {
      final app = _EbayApp(config: null);
      expect((await app.challenge('123')).statusCode, 404);
      expect(
        (await app.send(
          'POST',
          ebayAccountDeletionPath,
          body: '{}',
        )).statusCode,
        404,
      );
    });

    test(
      'with config, other methods and other /ebay paths answer 404',
      () async {
        final app = _EbayApp();
        expect(
          (await app.send(
            'PUT',
            ebayAccountDeletionPath,
            body: '{}',
          )).statusCode,
          404,
        );
        expect((await app.send('GET', '/ebay/other')).statusCode, 404);
        expect(
          (await app.send(
            'GET',
            '/v1$ebayAccountDeletionPath?challenge_code=1',
          )).statusCode,
          401,
        );
      },
    );
  });
}

/// eBay's accepted acknowledgement codes (EBAY-11).
abstract final class EbayStatus {
  static const success = {200, 201, 202, 204};
}
