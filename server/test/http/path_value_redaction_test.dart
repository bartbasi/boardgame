import 'package:api_contract/api_contract.dart';
import 'package:boardgame_server/boardgame_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

/// T-020 AC8 (T-008 review R2-S1): exception text that holds a path value
/// must not reach the log.
void main() {
  late LogCapture logs;
  late Handler handler;

  setUp(() {
    logs = LogCapture();
    handler = buildApp(
      version: 'v',
      logger: logs.logger(),
      databaseHealth: DatabaseHealth.alwaysUp(),
      v1Middleware: [
        // A /v1 guard that fails with the request URL in its message.
        (inner) => (request) {
          if (request.headers['x-guard'] == 'throw') {
            throw StateError('guard failed for ${request.requestedUri}');
          }
          return inner(request);
        },
      ],
      addTestRoutes: (v1) => v1.get('/games/<bggId>', (request) {
        final value = request.params['bggId'];
        throw ArgumentError.value(value, 'bggId', 'must be a positive integer');
      }),
    );
  });

  Future<Response> get(String path, {Map<String, String>? headers}) async =>
      handler(
        Request('GET', Uri.parse('http://localhost$path'), headers: headers),
      );

  Future<void> expectInternalErrorWithoutSecret(Response response) async {
    expect(response.statusCode, 500);
    final body = await response.readAsString();
    expect(body, isNot(contains('secret-123')));
    final envelope = ErrorEnvelope.fromJson(
      await jsonObjectOf(Response(200, body: body)),
    );
    expect(envelope.error.code, ErrorCode.internalError);
    for (final line in logs.lines) {
      expect(line, isNot(contains('secret-123')));
    }
  }

  test('a handler throwing ArgumentError.value with the path value gives '
      'the 500 envelope and logs name and message only', () async {
    await expectInternalErrorWithoutSecret(await get('/v1/games/secret-123'));

    final error = logs.withMessage('unhandled error').single;
    expect(error['errorType'], 'ArgumentError');
    expect(error['error'], 'ArgumentError (bggId): must be a positive integer');
    expect(error['route'], '/v1/games/{bggId}');
  });

  test('a /v1 guard throwing a StateError with the request URL gives the '
      '500 envelope and logs the URL with scheme and host only', () async {
    await expectInternalErrorWithoutSecret(
      await get('/v1/games/secret-123?q=x', headers: {'x-guard': 'throw'}),
    );

    final error = logs.withMessage('unhandled error').single;
    expect(
      error['error'],
      'Bad state: guard failed for http://localhost/<redacted>?<redacted>',
    );
  });
}
