import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boardgame_server/boardgame_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

/// QA round 1 for T-084: the eBay marketplace account deletion endpoint.
/// Pure Dart (no database). Expected hashes below were computed outside Dart
/// on 2026-10-15 with: printf '%s' "$code$token$url" | sha256sum.

const _token = 'tok_ABC-123_tok_ABC-123_tok_ABC-123_';
const _url = 'https://api.example.com/ebay/marketplace-account-deletion';
const _upperUrl = 'https://API.Example.com/ebay/marketplace-account-deletion';
const _config = EbayAccountDeletionConfig(
  verificationToken: _token,
  endpointUrl: _url,
);
const _path = ebayAccountDeletionPath;

class _Conn implements HttpConnectionInfo {
  _Conn(String a) : remoteAddress = InternetAddress(a);
  @override
  final InternetAddress remoteAddress;
  @override
  int get remotePort => 1;
  @override
  int get localPort => 2;
}

class _Clock {
  Duration now = Duration.zero;
  Duration call() => now;
}

class _App {
  _App({
    EbayAccountDeletionConfig? config = _config,
    List<String> trusted = const [],
    int ebayMaxTracked = ebayRateLimitMaxTrackedIps,
  }) {
    final resolver = ClientAddressResolver(
      trustedProxies: [for (final t in trusted) InternetAddress(t)],
    );
    ebayLimiter = RateLimiter(
      limit: ebayRateLimitPerMinute,
      maxTracked: ebayMaxTracked,
      now: clock.call,
    );
    v1Limiter = RateLimiter(now: clock.call);
    Middleware spy() =>
        (inner) => (request) {
          v1Seen.add(request.url.path);
          return inner(request);
        };
    handler = buildApp(
      version: 'v',
      logger: logs.logger(),
      databaseHealth: DatabaseHealth.alwaysUp(),
      v1Middleware: [rateLimit(v1Limiter, resolver), spy()],
      ebayAccountDeletion: config,
      ebayMiddleware: [rateLimit(ebayLimiter, resolver)],
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
    Map<String, Object> headers = const {},
  }) async => handler(
    Request(
      method,
      Uri.parse('http://localhost$pathAndQuery'),
      body: body,
      headers: headers,
      context: {connectionInfoContextKey: _Conn(peer)},
    ),
  );

  Future<Response> get(String query, {String peer = '203.0.113.7'}) =>
      send('GET', '$_path$query', peer: peer);
}

Future<String> _hash(Response r) async =>
    (jsonDecode(await r.readAsString()) as Map)['challengeResponse'] as String;

void main() {
  group('GET challenge: independent vectors', () {
    // [code as sent on the wire, query string, token, url, expected]
    final vectors = <(String, String, String, String)>[
      (
        'abc',
        '?challenge_code=abc',
        _url,
        '0e62ade28207134bf2fe678f653e3a7f067578cdef567fb12c35c633e7cdf258',
      ),
      (
        'unicode',
        '?challenge_code=%C3%A9%E2%98%83',
        _url,
        'e41c6894fba63ae47b4867c438a932aa5ac9abf3be3171088cddc5dc4d68f2ba',
      ),
      (
        'emoji',
        '?challenge_code=%F0%9F%8E%B2',
        _url,
        '8f5e89902c59fc9c63b1a87bd95e519672395d796f78f806f2e4187b10f63e0b',
      ),
      (
        'space via %20',
        '?challenge_code=a%20b',
        _url,
        '97f73803668288466899c3f82f1b4087f13080c17996708ce7c355cca16f6e38',
      ),
      (
        'literal plus via %2B',
        '?challenge_code=a%2Bb',
        _url,
        '4aceaa5466b436da7bec9157466e706dc38f315501abd3e2dc3f6e352742da69',
      ),
      (
        'percent via %25',
        '?challenge_code=a%25b',
        _url,
        'c8ed578762d51434ebb3f87abf962645cf82e721db417c60b0bf9bfd27b61403',
      ),
      (
        '1024 characters',
        '?challenge_code=${'x' * 1024}',
        _url,
        'bd9bc674a2d5d3c7f686b35a237534c9866c90957b5b72d096d8187a644f5827',
      ),
      (
        'url hashed exactly as configured (upper-case host)',
        '?challenge_code=abc',
        _upperUrl,
        'e1fdbf8e1f654813c71ba497c64866c2321ee759fc41338031f3527f6e98b271',
      ),
    ];
    for (final (name, query, url, expected) in vectors) {
      test(name, () async {
        final app = _App(
          config: EbayAccountDeletionConfig(
            verificationToken: _token,
            endpointUrl: url,
          ),
        );
        final r = await app.get(query);
        expect(r.statusCode, 200);
        expect(await _hash(r), expected);
      });
    }

    test('the order is code, token, url (swapped vector differs)', () {
      expect(
        challengeResponse(_token, 'abc', _url),
        'b8c7d95703c3fb1cbe0eacfc4002aa16c2e53274ea3f9b067d396aa41586a33a',
      );
      expect(
        challengeResponse('abc', _token, _url),
        '0e62ade28207134bf2fe678f653e3a7f067578cdef567fb12c35c633e7cdf258',
      );
    });

    test('a "+" in the query is read as a space (form decoding), so it '
        'hashes like "a b"', () async {
      final r = await _App().get('?challenge_code=a+b');
      expect(
        await _hash(r),
        '97f73803668288466899c3f82f1b4087f13080c17996708ce7c355cca16f6e38',
      );
    });
  });

  group('GET challenge: exact response and rejected shapes', () {
    test('status, headers, and body are exactly as documented', () async {
      final r = await _App().get('?challenge_code=abc');
      expect(r.statusCode, 200);
      expect(r.headers['content-type'], 'application/json');
      expect(r.headers['cache-control'], 'no-store');
      final body = await r.readAsString();
      expect(
        body,
        '{"challengeResponse":"0e62ade28207134bf2fe678f653e3a7f067578cdef567fb12c35c633e7cdf258"}',
      );
      expect(body.codeUnitAt(0), 0x7B, reason: 'no BOM');
      expect(
        RegExp(r'^[0-9a-f]{64}$')
            .hasMatch(await _hash(await _App().get('?challenge_code=1'))),
        isTrue,
      );
    });

    test('other query parameters are ignored', () async {
      final r = await _App().get('?foo=1&challenge_code=abc&bar=%00&x[]=y');
      expect(r.statusCode, 200);
      expect(
        await _hash(r),
        '0e62ade28207134bf2fe678f653e3a7f067578cdef567fb12c35c633e7cdf258',
      );
    });

    for (final query in [
      '',
      '?',
      '?challenge_code',
      '?challenge_code=',
      '?challenge_code=&challenge_code=',
      '?challenge_code=a&challenge_code=b',
      '?challenge_code=a&challenge_code=a',
      '?Challenge_Code=abc',
      '?CHALLENGE_CODE=abc',
      '?challenge_code[]=abc',
      '?challengeCode=abc',
      '?code=abc',
      '?challenge_code%20=abc',
      '?x=challenge_code=abc',
      '?challenge_code=${'x' * 1025}',
      '?challenge_code=${'x' * 100000}',
    ]) {
      test(
        '400 for ${query.length > 60 ? '<${query.length} chars>' : query}',
        () async {
          final r = await _App().get(query);
          expect(r.statusCode, 400);
          expect(r.headers['content-type'], contains('application/json'));
          final body = jsonDecode(await r.readAsString()) as Map;
          expect((body['error'] as Map)['code'], 'invalid_challenge_code');
          expect(body.containsKey('challengeResponse'), isFalse);
        },
      );
    }

    test('a 400 never echoes the query', () async {
      final r = await _App().get('?challenge_code=&junk=SECRETMARK');
      expect(await r.readAsString(), isNot(contains('SECRETMARK')));
    });

    test('a code of one space or other whitespace is accepted as a code '
        '(it is non-empty)', () async {
      expect((await _App().get('?challenge_code=%20')).statusCode, 200);
      expect((await _App().get('?challenge_code=%0A')).statusCode, 200);
    });

    test('a NUL byte in the code is hashed, not rejected', () async {
      final r = await _App().get('?challenge_code=a%00b');
      expect(r.statusCode, 200);
    });

    test('route variants do not answer the challenge', () async {
      final app = _App();
      for (final path in [
        '$_path/?challenge_code=abc',
        '${_path.toUpperCase()}?challenge_code=abc',
        '/ebay?challenge_code=abc',
        '/ebay/?challenge_code=abc',
        '/ebay/marketplace-account-deletion/x?challenge_code=abc',
        '/marketplace-account-deletion?challenge_code=abc',
        '/v1$_path?challenge_code=abc',
        '/EBAY/marketplace-account-deletion?challenge_code=abc',
      ]) {
        final r = await app.send('GET', path);
        expect(r.statusCode, 404, reason: path);
      }
    });

    test('with the pair off the route is a plain 404', () async {
      final app = _App(config: null);
      expect((await app.get('?challenge_code=abc')).statusCode, 404);
      expect((await app.send('POST', _path, body: '{}')).statusCode, 404);
    });
  });

  group('other methods', () {
    for (final method in [
      'PUT',
      'DELETE',
      'PATCH',
      'HEAD',
      'OPTIONS',
      'TRACE',
    ]) {
      test('$method is not accepted and leaks nothing', () async {
        final app = _App();
        final r = await app.send(
          method,
          '$_path?challenge_code=abc',
          body: method == 'HEAD' || method == 'OPTIONS' ? null : 'SECRETMARK',
        );
        // shelf_router answers HEAD for a GET route: 200 with no body (Routes.get).
        if (method != 'HEAD') {
          expect(r.statusCode, isNot(anyOf(200, 201, 202, 204)));
        }
        final text = await r.readAsString();
        expect(text, isNot(contains('challengeResponse')));
        expect(text, isNot(contains('SECRETMARK')));
        expect(app.logs.lines.join(), isNot(contains('SECRETMARK')));
      });
    }
  });

  group('POST notification', () {
    const marker = 'SECRETMARK-user-9x';
    final json = jsonEncode({
      'notification': {
        'data': {'username': marker, 'userId': marker, 'eiasToken': marker},
      },
    });

    test('204 with an empty body for every body shape', () async {
      final bodies = <String, Object?>{
        'none': null,
        'empty string': '',
        'json': json,
        'non-json': 'not json $marker',
        'binary': List<int>.generate(2000, (i) => i % 256),
        'invalid utf-8': [0xff, 0xfe, 0xfd, 0x80],
        'json array': '[1,2,3]',
        'json null': 'null',
        'unicode': 'ünï☃ $marker',
        'nul bytes': List<int>.filled(100, 0),
        'exactly 64 KiB': 'x' * maxNotificationBytes,
      };
      for (final entry in bodies.entries) {
        final app = _App();
        final r = await app.send('POST', _path, body: entry.value);
        expect(r.statusCode, 204, reason: entry.key);
        expect(await r.readAsString(), isEmpty, reason: entry.key);
        final text = app.logs.lines.join();
        expect(text, isNot(contains(marker)), reason: entry.key);
        expect(app.logs.records, hasLength(1), reason: 'only the request line');
      }
    });

    test('content types of every kind are acknowledged', () async {
      for (final ct in [
        'application/json',
        'application/json; charset=utf-8',
        'text/plain',
        'application/x-www-form-urlencoded',
        'multipart/form-data; boundary=x',
        'application/octet-stream',
        'weird/type',
      ]) {
        final r = await _App().send(
          'POST',
          _path,
          body: json,
          headers: {'content-type': ct},
        );
        expect(r.statusCode, 204, reason: ct);
      }
    });

    test('over 64 KiB by Content-Length is 413 without reading', () async {
      final r = await _App().send(
        'POST',
        _path,
        body: 'x' * (maxNotificationBytes + 1),
      );
      expect(r.statusCode, 413);
      final body = jsonDecode(await r.readAsString()) as Map;
      expect((body['error'] as Map)['code'], 'payload_too_large');
    });

    test('over 64 KiB with no Content-Length (chunked) is 413 while '
        'reading', () async {
      Stream<List<int>> chunks() async* {
        for (var i = 0; i < 20; i++) {
          yield List.filled(4096, 0x41);
        }
      }

      final r = await _App().send('POST', _path, body: chunks());
      expect(r.statusCode, 413);
    });

    test('a chunked body at exactly the limit is accepted, one byte more '
        'is not', () async {
      Stream<List<int>> chunks(int total) async* {
        var left = total;
        while (left > 0) {
          final n = left < 1000 ? left : 1000;
          yield List.filled(n, 0x41);
          left -= n;
        }
      }

      expect(
        (await _App().send(
          'POST',
          _path,
          body: chunks(maxNotificationBytes),
        )).statusCode,
        204,
      );
      expect(
        (await _App().send(
          'POST',
          _path,
          body: chunks(maxNotificationBytes + 1),
        )).statusCode,
        413,
      );
    });

    test('a huge declared length is 413 even with no body', () async {
      final r = await _App().send(
        'POST',
        _path,
        headers: {'content-length': '99999999999'},
      );
      expect(r.statusCode, 413);
    });

    test(
      'a stalled body is 408 (the read timeout is a hook on the route)',
      () async {
        final router = Router(notFoundHandler: (_) => notFoundResponse());
        addEbayAccountDeletionRoutes(
          Routes(router, mountPath: ebayMountPath),
          _config,
          readTimeout: const Duration(milliseconds: 100),
        );
        final handler = router.call;
        final stalled = StreamController<List<int>>();
        addTearDown(stalled.close);
        stalled.add([1, 2, 3]);
        final r = await handler(
          Request(
            'POST',
            Uri.parse('http://localhost$ebayAccountDeletionRoute'),
            body: stalled.stream,
          ),
        );
        expect(r.statusCode, 408);
        expect(
          ((jsonDecode(await r.readAsString()) as Map)['error'] as Map)['code'],
          'request_timeout',
        );
      },
    );

    test('a body stream that errors does not crash the handler', () async {
      Stream<List<int>> bad() async* {
        yield [1, 2];
        throw const SocketException('reset');
      }

      final app = _App();
      Object? thrown;
      Response? r;
      try {
        r = await app.send('POST', _path, body: bad());
      } on Object catch (e) {
        thrown = e;
      }
      // Either an error response or a propagated error that the error
      // boundary turns into 500; never a 2xx.
      expect(r == null || r.statusCode >= 400, isTrue, reason: '$thrown');
    });

    test('POST ignores a challenge_code query', () async {
      final r = await _App().send(
        'POST',
        '$_path?challenge_code=abc',
        body: '{}',
      );
      expect(r.statusCode, 204);
      expect(await r.readAsString(), isEmpty);
    });

    test(
      'headers such as x-ebay-signature are neither checked nor logged',
      () async {
        final app = _App();
        final r = await app.send(
          'POST',
          _path,
          body: json,
          headers: {
            'x-ebay-signature': 'SECRETMARK-sig',
            'authorization': 'Bearer SECRETMARK-auth',
            'cookie': 'a=SECRETMARK-cookie',
          },
        );
        expect(r.statusCode, 204);
        expect(app.logs.lines.join(), isNot(contains('SECRETMARK')));
      },
    );

    test(
      'while the database is down the endpoint still acknowledges',
      () async {
        final handler = buildApp(
          version: 'v',
          logger: LogCapture().logger(),
          databaseHealth: DatabaseHealth(
            probe: () async => throw StateError('down'),
          ),
          ebayAccountDeletion: _config,
        );
        final r = await handler(
          Request('POST', Uri.parse('http://localhost$_path'), body: json),
        );
        expect(r.statusCode, 204);
      },
    );
  });

  group('routing and limits', () {
    test(
      'the eBay route never reaches the /v1 guards or the /v1 limiter',
      () async {
        final app = _App();
        for (var i = 0; i < 30; i++) {
          await app.get('?challenge_code=c$i');
          await app.send('POST', _path, body: '{}');
        }
        expect(app.v1Seen, isEmpty);
        expect(app.v1Limiter.trackedCount, 0);
        expect(app.ebayLimiter.trackedCount, 1);
      },
    );

    test('/v1 traffic does not spend the eBay allowance', () async {
      final app = _App();
      for (var i = 0; i < 100; i++) {
        await app.send('GET', '/v1/x');
      }
      expect(app.v1Seen, isNotEmpty);
      expect((await app.get('?challenge_code=a')).statusCode, 200);
      expect(app.ebayLimiter.trackedCount, 1);
    });

    test('300 requests a minute: GET and POST share it, the 301st is 429 '
        'with Retry-After, a minute later it resets', () async {
      final app = _App();
      for (var i = 0; i < ebayRateLimitPerMinute ~/ 2; i++) {
        expect((await app.get('?challenge_code=c$i')).statusCode, 200);
        expect((await app.send('POST', _path, body: '{}')).statusCode, 204);
      }
      final limited = await app.get('?challenge_code=x');
      expect(limited.statusCode, 429);
      expect(limited.headers['retry-after'], matches(RegExp(r'^[1-9][0-9]*$')));
      final body = jsonDecode(await limited.readAsString()) as Map;
      expect((body['error'] as Map)['code'], 'rate_limited');
      expect((await app.send('POST', _path, body: '{}')).statusCode, 429);
      expect(
        (await app.get('?challenge_code=x', peer: '198.51.100.9')).statusCode,
        200,
      );
      app.clock.now = const Duration(minutes: 1);
      expect((await app.get('?challenge_code=x')).statusCode, 200);
    });

    test('the 429 and 400 responses carry no hash', () async {
      final app = _App();
      for (var i = 0; i < ebayRateLimitPerMinute; i++) {
        await app.get('?challenge_code=c');
      }
      final r = await app.get('?challenge_code=c');
      expect(await r.readAsString(), isNot(contains('challengeResponse')));
    });

    test('the table is capped at 10,000 addresses', () async {
      expect(ebayRateLimitMaxTrackedIps, 10000);
      expect(ebayRateLimitPerMinute, 300);
      final app = _App(ebayMaxTracked: 50);
      for (var i = 0; i < 500; i++) {
        await app.get('?challenge_code=a', peer: '10.0.${i ~/ 250}.${i % 250}');
      }
      expect(app.ebayLimiter.trackedCount, lessThanOrEqualTo(50));
    });

    test('X-Forwarded-For is trusted only from the trusted proxy and only '
        'its last entry counts', () async {
      final app = _App(trusted: const ['10.213.7.10']);
      Future<int> via(String peer, String xff) async => (await app.send(
        'GET',
        '$_path?challenge_code=a',
        peer: peer,
        headers: {'x-forwarded-for': xff},
      )).statusCode;
      // The full allowance as client 203.0.113.5 behind the proxy, forged prefixes.
      for (var i = 0; i < ebayRateLimitPerMinute; i++) {
        expect(
          await via(
            '10.213.7.10',
            'f$i.0.0.1, 203.0.113.5'.replaceFirst('f$i', '9'),
          ),
          200,
        );
      }
      expect(await via('10.213.7.10', '1.1.1.1, 203.0.113.5'), 429);
      expect(await via('10.213.7.10', '1.1.1.1, 203.0.113.6'), 200);
      // An untrusted peer's header is ignored: it is limited by its socket.
      for (var i = 0; i < ebayRateLimitPerMinute; i++) {
        expect(await via('198.51.100.1', '8.8.${i % 250}.1'), 200);
      }
      expect(await via('198.51.100.1', '8.8.8.99'), 429);
    });
  });

  group('no value in any log line', () {
    test('code, hash, token, url, body, headers, forwarded header', () async {
      final app = _App(trusted: const ['10.213.7.10']);
      const code = 'SECRETMARK-code-1';
      final r = await app.send(
        'GET',
        '$_path?challenge_code=$code&x=SECRETMARK-extra',
        peer: '10.213.7.10',
        headers: {
          'x-forwarded-for': '203.0.113.99',
          'user-agent': 'SECRETMARK-ua',
        },
      );
      final hash = await _hash(r);
      await app.send('POST', _path, body: 'SECRETMARK-body');
      for (var i = 0; i < 70; i++) {
        await app.get('?challenge_code=$code');
      }
      final all = app.logs.lines.join('\n');
      for (final bad in [
        code,
        hash,
        _token,
        'api.example.com',
        'SECRETMARK',
        '203.0.113.99',
      ]) {
        expect(all, isNot(contains(bad)), reason: bad);
      }
    });
  });

  group('over a real socket', () {
    late HttpServer server;
    late HttpClient client;

    setUp(() async {
      final handler = buildApp(
        version: 'v',
        logger: LogCapture().logger(),
        databaseHealth: DatabaseHealth.alwaysUp(),
        ebayAccountDeletion: _config,
      );
      server = await bindAndServe(
        handler,
        InternetAddress.loopbackIPv4,
        0,
        LogCapture().logger(),
      );
      client = HttpClient()..findProxy = (_) => 'DIRECT';
      addTearDown(() async {
        client.close(force: true);
        await server.close(force: true);
      });
    });

    test('a chunked POST over 64 KiB gets 413', () async {
      // The server answers 413 as soon as the limit is passed and may close
      // the connection while the client is still writing, so on some
      // platforms the client sees a reset instead of the response. Either
      // outcome is acceptable; a 2xx never is.
      var status = 0;
      var reset = false;
      try {
        final req = await client.post('127.0.0.1', server.port, _path);
        req.headers.chunkedTransferEncoding = true;
        for (var i = 0; i < 40; i++) {
          req.add(List.filled(4096, 0x41));
        }
        final res = await req.close();
        status = res.statusCode;
        await res.drain<void>();
      } on SocketException {
        reset = true;
      } on HttpException {
        reset = true;
      }
      expect(status == 413 || reset, isTrue, reason: 'status $status');
    });

    test('a chunked POST under the limit gets 204 and the connection is '
        'reusable', () async {
      for (var i = 0; i < 3; i++) {
        final req = await client.post('127.0.0.1', server.port, _path);
        req.headers.chunkedTransferEncoding = true;
        req.add(utf8.encode('{"a":'));
        req.add(utf8.encode('1}'));
        final res = await req.close();
        expect(res.statusCode, 204);
        await res.drain<void>();
      }
    });

    test('the challenge over the wire: headers and body', () async {
      final req = await client.get(
        '127.0.0.1',
        server.port,
        '$_path?challenge_code=abc',
      );
      final res = await req.close();
      expect(res.statusCode, 200);
      expect(res.headers.value('content-type'), 'application/json');
      expect(
        await utf8.decodeStream(res),
        '{"challengeResponse":"0e62ade28207134bf2fe678f653e3a7f067578cdef567fb12c35c633e7cdf258"}',
      );
    });

    test('a bad percent-encoding in the query does not crash or answer 200', () async {
      final socket = await Socket.connect('127.0.0.1', server.port);
      socket.write(
        'GET $_path?challenge_code=%FF%FE HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n',
      );
      final reply = await utf8.decodeStream(socket);
      expect(reply, isNot(startsWith('HTTP/1.1 200')));
      await socket.close();
    });
  });

  group('config: the pair', () {
    Map<String, String> env(String? token, String? url) => {
      ebayAccountDeletionTokenVariable: ?token,
      ebayAccountDeletionUrlVariable: ?url,
    };
    EbayAccountDeletionConfig? load(String? token, String? url) =>
        EbayAccountDeletionConfig.load(env(token, url));

    test('neither (missing, empty, blank) means off', () {
      expect(load(null, null), isNull);
      expect(load('', ''), isNull);
      expect(load('   ', '\t'), isNull);
    });

    test('one only, in either direction, is an error naming both '
        'variables and printing no value', () {
      for (final (t, u) in [
        (_token, null),
        (null, _url),
        (_token, ''),
        ('', _url),
      ]) {
        try {
          load(t, u);
          fail('should throw');
        } on ConfigException catch (e) {
          expect(e.message, contains('EBAY_ACCOUNT_DELETION'));
          expect(e.message, isNot(contains(_token)));
          expect(e.message, isNot(contains('api.example.com')));
        }
      }
    });

    test(
      'both valid load, and surrounding whitespace is trimmed from both',
      () {
        final c = load('  $_token\n', '\t$_url  ')!;
        expect(c.verificationToken, _token);
        expect(c.endpointUrl, _url);
        expect(c.toString(), isNot(contains(_token)));
      },
    );

    test('each problem names its variable and never its value', () {
      const secretToken = 'bad token with spaces SECRETMARK';
      const secretUrl = 'http://SECRETMARK.example.com/x';
      try {
        load(secretToken, secretUrl);
        fail('should throw');
      } on ConfigException catch (e) {
        expect(e.problems, hasLength(2));
        expect(e.message, isNot(contains('SECRETMARK')));
        expect(e.message, contains(ebayAccountDeletionTokenVariable));
        expect(e.message, contains(ebayAccountDeletionUrlVariable));
      }
    });
  });

  group('config: token bounds and charset', () {
    String t(int n, [String c = 'a']) => c * n;
    test('31 fails, 32 and 80 pass, 81 fails', () {
      expect(isValidVerificationToken(t(31)), isFalse);
      expect(isValidVerificationToken(t(32)), isTrue);
      expect(isValidVerificationToken(t(80)), isTrue);
      expect(isValidVerificationToken(t(81)), isFalse);
      expect(isValidVerificationToken(''), isFalse);
    });

    test('allowed characters pass', () {
      expect(isValidVerificationToken('aZ09_-${t(30)}'), isTrue);
      expect(isValidVerificationToken('-' * 32), isTrue);
      expect(isValidVerificationToken('_' * 32), isTrue);
      expect(isValidVerificationToken('0' * 32), isTrue);
    });

    for (final bad in [
      '.',
      '~',
      '=',
      '+',
      '/',
      ' ',
      '\t',
      '\n',
      '\r',
      ':',
      '@',
      '!',
      '"',
      "'",
      'é',
      'ß',
      'ａ' /* full-width a */,
      '٣' /* arabic digit */,
      '\u0000',
      '\u200b',
      '🎲',
    ]) {
      test(
        'one "${bad.replaceAll('\n', '\\n').replaceAll('\r', '\\r').replaceAll('\t', '\\t')}" '
        '(U+${bad.runes.first.toRadixString(16)}) in an otherwise valid '
        'token fails',
        () {
          expect(isValidVerificationToken('${t(20)}$bad${t(20)}'), isFalse);
          expect(isValidVerificationToken('$bad${t(40)}'), isFalse);
          expect(isValidVerificationToken('${t(40)}$bad'), isFalse);
        },
      );
    }

    test('a trailing newline is not smuggled past the anchor', () {
      expect(isValidVerificationToken('${t(40)}\n'), isFalse);
    });
  });

  group('config: URL rules', () {
    const base = 'https://api.example.com$_path';
    String? problem(String u) => endpointUrlProblem(u);

    test('good URLs', () {
      for (final u in [
        base,
        'https://api.example.com:8443$_path',
        'https://a.b.c.d.example.co.uk$_path',
        'https://xn--bcher-kva.example$_path',
        'https://93.184.216.34$_path',
        'https://[2606:4700:4700::1111]$_path',
        'https://[::ffff:93.184.216.34]$_path',
      ]) {
        expect(problem(u), isNull, reason: u);
      }
    });

    test('scheme', () {
      for (final u in [
        'http://api.example.com$_path',
        'HTTP://api.example.com$_path',
        'ftp://api.example.com$_path',
        'wss://api.example.com$_path',
        '//api.example.com$_path',
        'api.example.com$_path',
        '',
        'https:api.example.com$_path',
        'javascript:alert(1)',
      ]) {
        expect(problem(u), isNotNull, reason: u);
      }
      // Round 2: an upper-case scheme is refused as non-canonical.
      expect(problem('HTTPS://api.example.com$_path'), isNotNull);
    });

    test('user info, query, fragment, empty query and fragment markers', () {
      for (final u in [
        'https://user@api.example.com$_path',
        'https://user:pw@api.example.com$_path',
        'https://api.example.com$_path?x=1',
        'https://api.example.com$_path?',
        'https://api.example.com$_path#f',
        'https://api.example.com$_path#',
        'https://api.example.com$_path?x#f',
      ]) {
        expect(problem(u), isNotNull, reason: u);
      }
    });

    test('the path must equal the route exactly', () {
      for (final u in [
        'https://api.example.com',
        'https://api.example.com/',
        'https://api.example.com$_path/',
        'https://api.example.com$_path/extra',
        'https://api.example.com${_path.toUpperCase()}',
        'https://api.example.com/ebay',
        'https://api.example.com/ebay/',
        'https://api.example.com/v1$_path',
        'https://api.example.com//ebay/marketplace-account-deletion',
        'https://api.example.com/ebay//marketplace-account-deletion',
        'https://api.example.com/ebay%2Fmarketplace-account-deletion',
        'https://api.example.com/ebay/marketplace-account-deletion;x=1',
        'https://api.example.com/ebay/marketplace-account-deletion%20',
      ]) {
        expect(problem(u), isNotNull, reason: u);
      }
    });

    test('localhost in every form', () {
      for (final h in [
        'localhost',
        'LOCALHOST',
        'localhost.',
        'foo.localhost',
        'a.b.localhost',
        '127.0.0.1',
        '127.1',
        '127.0.1',
        '0x7f.0.0.1',
        '0x7f000001',
        '2130706433',
        '017700000001',
        '0177.0.0.1',
        '[::1]',
        '[0:0:0:0:0:0:0:1]',
        '[::ffff:127.0.0.1]',
        '[::]',
        '0.0.0.0',
        '0',
      ]) {
        expect(problem('https://$h$_path'), isNotNull, reason: h);
      }
    });

    test('internal IPv4 ranges', () {
      for (final h in [
        '10.0.0.1',
        '10.255.255.255',
        '172.16.0.1',
        '172.31.255.255',
        '192.168.0.1',
        '192.168.255.255',
        '169.254.169.254',
        '100.64.0.1',
        '100.127.255.255',
        '192.0.0.1',
        '192.0.2.1',
        '198.18.0.1',
        '198.19.255.255',
        '198.51.100.1',
        '203.0.113.1',
        '224.0.0.1',
        '239.255.255.255',
        '240.0.0.1',
        '255.255.255.255',
        '0.1.2.3',
      ]) {
        expect(problem('https://$h$_path'), isNotNull, reason: h);
      }
    });

    test('just outside the internal IPv4 ranges is public', () {
      for (final h in [
        '9.255.255.255',
        '11.0.0.1',
        '172.15.255.255',
        '172.32.0.1',
        '192.167.255.255',
        '192.169.0.1',
        '169.253.0.1',
        '169.255.0.1',
        '100.63.255.255',
        '100.128.0.1',
        '198.17.255.255',
        '198.20.0.1',
        '8.8.8.8',
        '1.1.1.1',
        '223.255.255.255',
        '192.0.1.1',
        '192.0.3.1',
        '198.51.99.1',
        '198.51.101.1',
        '203.0.112.1',
        '203.0.114.1',
      ]) {
        expect(problem('https://$h$_path'), isNull, reason: h);
      }
    });

    test('internal IPv6 forms', () {
      for (final h in [
        '[::1]',
        '[::]',
        '[fe80::1]',
        '[fc00::1]',
        '[fd12:3456::1]',
        '[ff02::1]',
        '[2001:db8::1]',
        '[2001:0DB8:0:0:0:0:0:1]',
        '[::ffff:10.0.0.1]',
        '[::ffff:192.168.1.1]',
        '[::ffff:169.254.169.254]',
        '[::ffff:7f00:1]',
        '[64:ff9b::7f00:1]',
        '[::7f00:1]',
        '[1000::1]',
      ]) {
        expect(problem('https://$h$_path'), isNotNull, reason: h);
      }
    });

    test('host names: shape rules', () {
      for (final h in [
        'example',
        'internal',
        'example.123',
        'example.c',
        'example.com.',
        '.example.com',
        'exa mple.com',
        'exa_mple.com',
        '-example.com',
        'example-.com',
        'a..example.com',
        '${'a' * 64}.example.com',
        '1.2.3',
        '1.2.3.4.5',
        '1.2.3.4.',
        '999.999.999.999',
        'example.xn--',
        'bücher.example',
        '例え.jp',
      ]) {
        expect(problem('https://$h$_path'), isNotNull, reason: h);
      }
    });

    test('a very long URL is rejected without a crash', () {
      expect(problem('https://${'a' * 3000}.example.com$_path'), isNotNull);
      expect(problem('https://api.example.com$_path${'x' * 3000}'), isNotNull);
    });

    test('the reason never holds the URL or part of it', () {
      for (final u in [
        'http://SECRETMARK.example.com$_path',
        'https://user:SECRETMARK@api.example.com$_path',
        'https://api.example.com/SECRETMARK',
        'https://SECRETMARK/',
        'https://api.example.com$_path?SECRETMARK=1',
      ]) {
        final p = problem(u)!;
        expect(p, isNot(contains('SECRETMARK')), reason: u);
        expect(p, isNot(contains('example.com')), reason: u);
      }
    });

    test('round 2: equivalent spellings of the right URL are refused as '
        'non-canonical, so the hashed string is what eBay calls', () {
      for (final u in [
        'https://@api.example.com$_path',
        'https://api.example.com/ebay/./marketplace-account-deletion',
        'https://api.example.com/x/../ebay/marketplace-account-deletion',
        'https://api.example.com/ebay/marketplace%2Daccount-deletion',
        'https://api.example.com:$_path',
        'https://ex%61mple.com$_path',
        // Upper-case and mixed-case spellings.
        'https://API.Example.com$_path',
        'https://API.EXAMPLE.COM$_path',
        'https://api.EXAMPLE.com$_path',
        'HTTPS://api.example.com$_path',
        'Https://api.example.com$_path',
        'hTTps://api.example.com$_path',
        // More needless escapes and normalizable forms.
        'https://api.example.com/ebay/marketplace%2daccount-deletion',
        'https://api.example.com/%65bay/marketplace-account-deletion',
        'https://api.example.com/ebay/marketplace-account-%64eletion',
        'https://api.example.com/ebay/marketplace-account-deletion/.',
        'https://api.example.com/ebay/marketplace-account-deletion/x/..',
        'https://api.example.com/./ebay/marketplace-account-deletion',
        'https://%61pi.example.com$_path',
        'https://:@api.example.com$_path',
        'https://api.example.com:/ebay/marketplace-account-deletion',
        // The default port is dropped by normalization, so ":443" is refused.
        'https://api.example.com:443$_path',
        // Leading and trailing whitespace is trimmed by load(), but not by
        // the problem check itself.
        ' https://api.example.com$_path',
        'https://api.example.com$_path ',
        'https://api.example.com$_path\n',
      ]) {
        expect(problem(u), isNotNull, reason: u);
      }
    });

    test('round 2: the canonical-form reason names the rule and holds no '
        'part of the URL', () {
      final p = problem('https://API.Example.com$_path')!;
      expect(p, contains('canonical'));
      expect(p, isNot(contains('API')));
      expect(p, isNot(contains('example.com')));
      expect(p, isNot(contains('ebay/marketplace')));
    });

    test('round 2: a specific problem is still reported before the '
        'canonical rule', () {
      expect(problem('HTTP://api.example.com$_path'), contains('https'));
      expect(problem('https://LOCALHOST$_path'), contains('localhost'));
      expect(problem('https://10.0.0.1$_path'), contains('internal'));
      expect(problem('https://User@api.example.com$_path'), contains('user'));
    });

    test('round 2: canonical forms with a port, an IPv6 literal (lower-case '
        'hex), an A-label, and a digit host still pass', () {
      for (final u in [
        'https://api.example.com:8443$_path',
        'https://[2606:4700:4700::1111]$_path',
        'https://xn--bcher-kva.example$_path',
        'https://93.184.216.34$_path',
        'https://a-b.c-d.example.org$_path',
      ]) {
        expect(problem(u), isNull, reason: u);
      }
    });

    test('round 2: an IPv6 literal with upper-case hex is refused (Dart '
        'writes it lower-case)', () {
      expect(problem('https://[2606:4700:4700::ABCD]$_path'), isNotNull);
    });

    test('round 2: load() trims whitespace first, then judges the trimmed '
        'string', () {
      final c = EbayAccountDeletionConfig.load({
        ebayAccountDeletionTokenVariable: 'a' * 40,
        ebayAccountDeletionUrlVariable: ' https://api.example.com$_path\n',
      })!;
      expect(c.endpointUrl, 'https://api.example.com$_path');
      expect(
        () => EbayAccountDeletionConfig.load({
          ebayAccountDeletionTokenVariable: 'a' * 40,
          ebayAccountDeletionUrlVariable: 'https://API.example.com$_path',
        }),
        throwsA(isA<ConfigException>()),
      );
    });

    test('observed and accepted: internal-looking DNS names pass because '
        'no lookup is made (pinned, not a requirement)', () {
      // .local, .internal, .lan, .corp are letter-only top-level labels.
      for (final h in ['printer.local', 'db.internal', 'x.lan', 'x.corp']) {
        expect(problem('https://$h$_path'), isNull, reason: h);
      }
    });

    test('observed and accepted: 6to4 and Teredo prefixes inside 2000::/3 '
        'pass (pinned)', () {
      expect(problem('https://[2002:7f00:1::]$_path'), isNull);
      expect(problem('https://[2001::1]$_path'), isNull);
    });
  });

  group('startup (no database needed for config failures)', () {
    Future<(int, List<String>, List<String>)> start(
      Map<String, String> env,
    ) async {
      final out = <String>[];
      final err = <String>[];
      final code = await runServer(
        environment: {
          'PORT': '8080',
          'LOG_LEVEL': 'info',
          'DATABASE_HOST': 'db.invalid',
          'DATABASE_NAME': 'n',
          'DATABASE_USER': 'u',
          'DATABASE_PASSWORD': 'p',
          ...env,
        },
        shutdownSignals: const Stream.empty(),
        stdoutLine: out.add,
        stderrLine: err.add,
      );
      return (code, out, err);
    }

    test(
      'only a token: exit 78, one line, no value, nothing on stdout',
      () async {
        final (code, out, err) = await start({
          ebayAccountDeletionTokenVariable: 'SECRETMARK-${'t' * 30}',
        });
        expect(code, configErrorExitCode);
        expect(out, isEmpty);
        expect(err, hasLength(1));
        expect(err.single, isNot(contains('SECRETMARK')));
        expect(err.single, contains(ebayAccountDeletionUrlVariable));
      },
    );

    test('only a URL: exit 78', () async {
      final (code, _, err) = await start({
        ebayAccountDeletionUrlVariable: _url,
      });
      expect(code, configErrorExitCode);
      expect(err.single, isNot(contains('api.example.com')));
    });

    test(
      'an invalid pair next to a bad PORT: one line names all, no value',
      () async {
        final (code, _, err) = await start({
          'PORT': 'x',
          ebayAccountDeletionTokenVariable: 'short',
          ebayAccountDeletionUrlVariable: 'http://SECRETMARK.example.com/',
        });
        expect(code, configErrorExitCode);
        expect(err, hasLength(1));
        for (final n in [
          'PORT',
          ebayAccountDeletionTokenVariable,
          ebayAccountDeletionUrlVariable,
        ]) {
          expect(err.single, contains(n));
        }
        expect(err.single, isNot(contains('SECRETMARK')));
        expect(err.single, isNot(contains('short')));
      },
    );
  });

  group('no eBay user data in the schema', () {
    test(
      'migrations name no seller, buyer, user, account, or token column',
      () {
        final forbidden = RegExp(
          r'seller|buyer|user|account|eias|ebay_?id|feedback|notification|email|address|phone',
          caseSensitive: false,
        );
        for (final m in schemaMigrations) {
          expect(
            forbidden.allMatches(m.sql).map((x) => x[0]).toList(),
            isEmpty,
            reason: 'migration ${m.version} ${m.name}',
          );
        }
      },
    );

    test('the guard itself catches the identifiers an eBay notification '
        'carries', () {
      final guard = RegExp(
        r'seller|buyer|username|user_name|user_id|userid|eias',
        caseSensitive: false,
      );
      for (final sql in [
        'CREATE TABLE x (username text)',
        'CREATE TABLE x (userId text)',
        'CREATE TABLE x (eiasToken text)',
        'CREATE TABLE x (seller_id text)',
        'CREATE TABLE x (buyer text)',
        'CREATE TABLE x (user_id text)',
      ]) {
        expect(guard.hasMatch(sql), isTrue, reason: sql);
      }
    });
  });
}
