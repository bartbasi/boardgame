import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('HealthResponse round trip (AC3)', () {
    for (final path in listFixtures('health')) {
      test('$path decodes and encodes back to the same JSON', () {
        final json = readFixture(path);
        expect(HealthResponse.fromJson(json).toJson(), equals(json));
      });
    }

    test('health/ok.json decodes to status ok and its version', () {
      final health = HealthResponse.fromJson(readFixture('health/ok.json'));
      expect(
        health,
        const HealthResponse(status: 'ok', version: '0.1.0+abc1234'),
      );
    });
  });

  group('HealthResponse with unknown fields (AC4)', () {
    test('an extra field is ignored', () {
      final health = HealthResponse.fromJson(
        readFixture('variants/health_extra_field.json'),
      );
      expect(
        health,
        const HealthResponse(status: 'ok', version: '0.1.0+abc1234'),
      );
      expect(health.toJson(), {'status': 'ok', 'version': '0.1.0+abc1234'});
    });
  });

  group('HealthResponse with missing or invalid fields (AC5)', () {
    for (final path in [
      'malformed/health_missing_version.json',
      'malformed/health_wrong_type.json',
    ]) {
      test('$path throws CheckedFromJsonException', () {
        final json = readFixture(path);
        expect(
          () => HealthResponse.fromJson(json),
          throwsA(
            isA<CheckedFromJsonException>().having(
              (e) => e.key,
              'key',
              'version',
            ),
          ),
        );
      });
    }
  });

  group('HealthResponse value semantics', () {
    test('copyWith, equality, and toString', () {
      const health = HealthResponse(status: 'ok', version: '1.0.0');
      final changed = health.copyWith(version: '1.0.1');
      expect(changed.status, 'ok');
      expect(changed.version, '1.0.1');
      expect(changed, isNot(health));
      expect(
        health.hashCode,
        const HealthResponse(status: 'ok', version: '1.0.0').hashCode,
      );
      expect(health.toString(), contains('1.0.0'));
    });
  });
}
