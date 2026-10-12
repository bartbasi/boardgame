import 'package:boardgame_server/boardgame_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

const _ip = '203.0.113.77';
const _userAgent = 'BoardGameCollector/9.9 (Pixel 42; secret-device-ua)';
const _body = '{"note":"private-body-content"}';
const _query = 'q=secret';

TestApp _app() => TestApp(
  addTestRoutes: (v1) {
    v1.get('/games/<bggId>', (request) {
      return jsonResponse(200, {'bggId': request.params['bggId']});
    });
    v1.add('POST', '/echo-length', (request) async {
      final body = await request.readAsString();
      return jsonResponse(200, {'length': body.length});
    });
    v1.get('/boom', (_) => throw StateError('boom'));
  },
);

void main() {
  group('one JSON line per request (T-008 AC7)', () {
    test('GET /health writes one line with ts, level, method, route, status, '
        'and durationMs', () async {
      final app = _app();

      await app.get('/health');

      expect(app.logs.lines, hasLength(1));
      final line = app.logs.records.single;
      expect(line.keys, [
        'ts',
        'level',
        'msg',
        'method',
        'route',
        'status',
        'durationMs',
      ]);
      expect(line['ts'], '2026-10-12T14:30:05.123Z');
      expect(line['level'], 'info');
      expect(line['msg'], 'request');
      expect(line['method'], 'GET');
      expect(line['route'], '/health');
      expect(line['status'], 200);
      expect(line['durationMs'], isA<num>());
      expect(line['durationMs'] as num, greaterThanOrEqualTo(0));
    });

    test('the timestamp is UTC ISO 8601 even when the clock is local', () {
      final lines = <String>[];
      Logger(
        minLevel: LogLevel.info,
        sink: lines.add,
        clock: () => DateTime(2026, 10, 12, 9, 30),
      ).info('x');

      final ts = RegExp(r'"ts":"([^"]+)"').firstMatch(lines.single)![1]!;
      expect(ts, endsWith('Z'));
      expect(DateTime.parse(ts), DateTime(2026, 10, 12, 9, 30).toUtc());
    });

    test('logs the route template, not the concrete path', () async {
      final app = _app();

      final response = await app.get('/v1/games/174430');

      expect(response.statusCode, 200);
      final line = app.logs.records.single;
      expect(line['route'], '/v1/games/{bggId}');
      expect(app.logs.lines.single, isNot(contains('174430')));
    });

    test(
      'an unknown path logs the route as <unmatched> with status 404',
      () async {
        final app = _app();

        await app.get('/v1/nope/private-path-segment');

        final line = app.logs.records.single;
        expect(line['route'], unmatchedRoute);
        expect(line['status'], 404);
        expect(app.logs.lines.single, isNot(contains('private-path-segment')));
      },
    );

    test('a 500 writes exactly one request line, at error level', () async {
      final app = _app();

      await app.get('/v1/boom');

      final requests = app.logs.withMessage('request');
      expect(requests, hasLength(1));
      expect(requests.single['status'], 500);
      expect(requests.single['level'], 'error');
      expect(requests.single['route'], '/v1/boom');
    });

    test('several requests write one line each', () async {
      final app = _app();

      await app.get('/health');
      await app.get('/v1/nope');
      await app.get('/v1/games/1');

      expect(app.logs.withMessage('request'), hasLength(3));
    });

    test('LOG_LEVEL=warning drops request lines below 500', () async {
      final app = TestApp(minLevel: LogLevel.warning);

      await app.get('/health');

      expect(app.logs.lines, isEmpty);
    });
  });

  group('no personal data in logs (T-008 AC8)', () {
    Future<List<String>> sendPrivateRequest(String method, String path) async {
      final app = _app();
      await app.handler(
        Request(
          method,
          Uri.parse('http://localhost$path?$_query'),
          headers: {
            'x-forwarded-for': '$_ip, 10.0.0.1',
            'x-real-ip': _ip,
            'user-agent': _userAgent,
            'authorization': 'Bearer token-abc-123',
            'x-custom-header': 'custom-header-value',
            'content-type': 'application/json',
          },
          body: _body,
        ),
      );
      return app.logs.lines;
    }

    final forbidden = [
      _ip,
      '10.0.0.1',
      _userAgent,
      'secret-device-ua',
      'BoardGameCollector',
      'q=secret',
      'secret',
      '?',
      _body,
      'private-body-content',
      'token-abc-123',
      'custom-header-value',
      'x-forwarded-for',
      'user-agent',
      'application/json',
    ];

    for (final (method, path) in [
      ('GET', '/health'),
      ('GET', '/v1/games/13'),
      ('POST', '/v1/echo-length'),
      ('GET', '/v1/nope'),
      ('GET', '/v1/boom'),
    ]) {
      test('$method $path with IP, user agent, query, headers, and body logs '
          'none of them', () async {
        final lines = await sendPrivateRequest(method, path);

        expect(lines, isNotEmpty);
        for (final line in lines) {
          for (final value in forbidden) {
            expect(line, isNot(contains(value)), reason: 'log line: $line');
          }
        }
      });
    }
  });
}
