import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

void main() {
  group('GET /health (T-008 AC1)', () {
    test('returns 200 JSON that decodes as HealthResponse with status ok and '
        'the build version', () async {
      final app = TestApp(version: '0.1.0+abc1234');

      final response = await app.get('/health');

      expect(response.statusCode, 200);
      expect(response.mimeType, 'application/json');
      final health = HealthResponse.fromJson(await jsonObjectOf(response));
      expect(
        health,
        const HealthResponse(status: 'ok', version: '0.1.0+abc1234'),
      );
    });

    test('is not under /v1', () async {
      final response = await TestApp().get('/v1/health');

      expect(response.statusCode, 404);
    });

    test('ignores a query string', () async {
      final response = await TestApp().get('/health?probe=1');

      expect(response.statusCode, 200);
    });

    test('answers HEAD for health checks without a body', () async {
      final response = await TestApp().send('HEAD', '/health');

      expect(response.statusCode, 200);
    });

    test('POST /health is 404 not_found', () async {
      final response = await TestApp().send('POST', '/health');

      expect(response.statusCode, 404);
      final envelope = ErrorEnvelope.fromJson(await jsonObjectOf(response));
      expect(envelope.error.code, ErrorCode.notFound);
    });
  });
}
