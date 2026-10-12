import 'package:api_contract/api_contract.dart';
import 'package:boardgame_server/boardgame_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

/// A guard that records every path it sees and can reject or throw.
class _Guard {
  final seen = <String>[];
  Response? reject;
  bool throws = false;

  Middleware get middleware =>
      (inner) => (request) {
        seen.add(request.requestedUri.path);
        if (throws) throw StateError('guard failed ?q=secret');
        return reject ?? inner(request);
      };
}

void main() {
  group('/v1 middleware at the mount (T-008 review R1-G1)', () {
    late _Guard first;
    late _Guard second;
    late Handler handler;
    late LogCapture logs;

    setUp(() {
      first = _Guard();
      second = _Guard();
      logs = LogCapture();
      handler = buildApp(
        version: 'v',
        logger: logs.logger(),
        v1Middleware: [first.middleware, second.middleware],
        addTestRoutes: (v1) => v1.get('/games/<bggId>', (_) {
          return jsonResponse(200, {'ok': true});
        }),
      );
    });

    Future<Response> get(String path) =>
        Future.value(handler(Request('GET', Uri.parse('http://h$path'))));

    test('runs for a matched /v1 route', () async {
      final response = await get('/v1/games/7');

      expect(response.statusCode, 200);
      expect(first.seen, ['/v1/games/7']);
      expect(second.seen, ['/v1/games/7']);
    });

    for (final path in ['/v1/nope', '/v1', '/v1/', '/v1/games/7/extra']) {
      test(
        'runs for the unmatched /v1 path $path, which is still 404',
        () async {
          final response = await get(path);

          expect(response.statusCode, 404);
          expect(first.seen, hasLength(1));
          expect(second.seen, hasLength(1));
          final envelope = ErrorEnvelope.fromJson(await jsonObjectOf(response));
          expect(envelope.error.code, ErrorCode.notFound);
        },
      );
    }

    test('does not run for /health or other non-/v1 paths', () async {
      await get('/health');
      await get('/nope');
      await get('/v1x');

      expect(first.seen, isEmpty);
    });

    test('runs in list order, and a rejection is logged once by the request '
        'log', () async {
      first.reject = errorResponse(429, ErrorCode.rateLimited, 'Slow down.');

      final response = await get('/v1/games/7');

      expect(response.statusCode, 429);
      expect(second.seen, isEmpty);
      final line = logs.withMessage('request').single;
      expect(line['status'], 429);
      expect(line['route'], unmatchedRoute);
    });

    test('a guard that throws gives the 500 envelope and one request line, '
        'with no request data in the log', () async {
      first.throws = true;

      final response = await get('/v1/games/7?q=secret');

      expect(response.statusCode, 500);
      final envelope = ErrorEnvelope.fromJson(await jsonObjectOf(response));
      expect(envelope.error.code, ErrorCode.internalError);
      expect(logs.withMessage('request'), hasLength(1));
      expect(logs.withMessage('unhandled error'), hasLength(1));
      for (final line in logs.lines) {
        expect(line, isNot(contains('secret')));
      }
    });
  });

  test('a HijackException from a handler becomes a 500 envelope', () async {
    final app = TestApp(
      addTestRoutes: (v1) =>
          v1.get('/hijack', (_) => throw const HijackException()),
    );

    final response = await app.get('/v1/hijack');

    expect(response.statusCode, 500);
    final envelope = ErrorEnvelope.fromJson(await jsonObjectOf(response));
    expect(envelope.error.code, ErrorCode.internalError);
  });

  test('loggableMethod keeps standard methods and hides others', () {
    for (final m in [
      'GET',
      'HEAD',
      'POST',
      'PUT',
      'PATCH',
      'DELETE',
      'OPTIONS',
    ]) {
      expect(loggableMethod(m), m);
    }
    expect(loggableMethod('SECRETMETHOD'), otherMethod);
    expect(loggableMethod('get'), otherMethod);
  });
}
