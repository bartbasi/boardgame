import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:boardgame_server/boardgame_server.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

const _secretText = 'db password hunter2 at /srv/app/secret.dart';

/// Strings that would reveal the framework or an exception in a body.
const _leakMarkers = [
  'shelf',
  'Route not found',
  'Internal Server Error',
  'Exception',
  'StateError',
  'Bad state',
  '#0',
  '.dart',
  'hunter2',
];

void expectNoLeaks(String body) {
  for (final marker in _leakMarkers) {
    expect(body, isNot(contains(marker)), reason: 'body leaks "$marker"');
  }
}

TestApp _appWithThrowingRoutes() => TestApp(
  addTestRoutes: (v1) {
    v1.get('/boom', (_) => throw StateError(_secretText));
    v1.get('/boom-async', (_) async {
      await Future<void>.delayed(Duration.zero);
      throw const FormatException(_secretText);
    });
    v1.get('/boom-error', (_) => throw ArgumentError(_secretText));
    v1.get(
      '/sends-unknown',
      (_) => errorResponse(400, ErrorCode.unknown, 'should never be sent'),
    );
  },
);

void main() {
  group('unknown routes (T-008 AC2)', () {
    for (final path in [
      '/v1/nope',
      '/v1/',
      '/v1',
      '/',
      '/nope?q=1',
      '/v1/games/1/extra',
    ]) {
      test('GET $path is 404 with the not_found envelope and no framework '
          'text', () async {
        final response = await TestApp().get(path);

        expect(response.statusCode, 404);
        expect(response.mimeType, 'application/json');
        final body = await response.readAsString();
        expectNoLeaks(body);
        final envelope = ErrorEnvelope.fromJson(
          jsonDecode(body) as Map<String, dynamic>,
        );
        expect(envelope.error.code, ErrorCode.notFound);
        expect(envelope.error.message, 'Not found.');
      });
    }

    test(
      'the response has no X-Powered-By or server framework header',
      () async {
        final response = await TestApp().get('/v1/nope');

        expect(response.headers.keys, isNot(contains('x-powered-by')));
      },
    );
  });

  group('unhandled errors (T-008 AC3)', () {
    for (final route in ['/v1/boom', '/v1/boom-async', '/v1/boom-error']) {
      test('GET $route is 500 internal_error with no exception text in the '
          'body', () async {
        final app = _appWithThrowingRoutes();

        final response = await app.get(route);

        expect(response.statusCode, 500);
        expect(response.mimeType, 'application/json');
        final body = await response.readAsString();
        expectNoLeaks(body);
        final envelope = ErrorEnvelope.fromJson(
          jsonDecode(body) as Map<String, dynamic>,
        );
        expect(envelope.error.code, ErrorCode.internalError);
      });

      test(
        'GET $route logs the error and its stack trace at error level',
        () async {
          final app = _appWithThrowingRoutes();

          await app.get(route);

          final errors = app.logs.withMessage('unhandled error');
          expect(errors, hasLength(1));
          final line = errors.single;
          expect(line['level'], 'error');
          expect(line['error'], contains(_secretText));
          expect(line['stack'], isA<String>());
          expect(line['stack'] as String, contains('errors_test.dart'));
          expect(line['route'], route);
          expect(line['method'], 'GET');
        },
      );
    }
  });

  group('the server never sends ErrorCode.unknown (T-007 decision)', () {
    test('errorResponse throws ArgumentError for ErrorCode.unknown', () {
      expect(
        () => errorResponse(400, ErrorCode.unknown, 'x'),
        throwsArgumentError,
      );
    });

    test('a handler that tries to send unknown gets 500 internal_error '
        'instead', () async {
      final app = _appWithThrowingRoutes();

      final response = await app.get('/v1/sends-unknown');

      expect(response.statusCode, 500);
      final body = await response.readAsString();
      expect(body, isNot(contains('"unknown"')));
      final envelope = ErrorEnvelope.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
      expect(envelope.error.code, ErrorCode.internalError);
    });

    for (final code in ErrorCode.values.where((c) => c != ErrorCode.unknown)) {
      test('errorResponse sends ${code.wireName} as a code the contract '
          'knows', () async {
        final response = errorResponse(400, code, 'Message.');

        final json = await jsonObjectOf(response);
        expect(json, {
          'error': {'code': code.wireName, 'message': 'Message.'},
        });
        final decoded = ErrorEnvelope.fromJson(json);
        expect(decoded.error.code, code);
        expect(decoded.error.code, isNot(ErrorCode.unknown));
      });
    }

    test('every built-in error response uses a known code', () async {
      for (final response in [notFoundResponse(), internalErrorResponse()]) {
        final envelope = ErrorEnvelope.fromJson(await jsonObjectOf(response));
        expect(envelope.error.code, isNot(ErrorCode.unknown));
      }
    });
  });
}
