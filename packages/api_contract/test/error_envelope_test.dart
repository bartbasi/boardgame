import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('ErrorEnvelope round trip (AC2)', () {
    final fixtures = listFixtures('error');

    test('there is one fixture for every known error code', () {
      final known = ErrorCode.values.where((c) => c != ErrorCode.unknown);
      final expected = known.map((c) => 'error/${c.wireName}.json').toSet();
      expect(fixtures.toSet(), expected);
    });

    for (final path in fixtures) {
      test('$path decodes and encodes back to the same JSON', () {
        final json = readFixture(path);
        final envelope = ErrorEnvelope.fromJson(json);
        expect(envelope.error.code, isNot(ErrorCode.unknown));
        expect(envelope.toJson(), equals(json));
      });
    }

    test('fixture name matches the decoded code', () {
      for (final path in fixtures) {
        final envelope = ErrorEnvelope.fromJson(readFixture(path));
        expect(path, 'error/${envelope.error.code.wireName}.json');
      }
    });
  });

  group('ErrorEnvelope with unknown fields (AC4)', () {
    test('extra fields at both levels are ignored', () {
      final envelope = ErrorEnvelope.fromJson(
        readFixture('variants/error_extra_field.json'),
      );
      expect(
        envelope,
        const ErrorEnvelope(
          error: ApiError(code: ErrorCode.notFound, message: 'Not found.'),
        ),
      );
      expect(envelope.toJson(), {
        'error': {'code': 'not_found', 'message': 'Not found.'},
      });
    });
  });

  group('ErrorEnvelope with missing or invalid fields (AC5)', () {
    for (final path in [
      'malformed/error_missing_code.json',
      'malformed/error_missing_message.json',
      'malformed/error_missing_error.json',
      'malformed/error_null_message.json',
    ]) {
      test('$path throws CheckedFromJsonException', () {
        final json = readFixture(path);
        expect(
          () => ErrorEnvelope.fromJson(json),
          throwsA(isA<CheckedFromJsonException>()),
        );
      });
    }

    test('the exception names the missing field', () {
      final json = readFixture('malformed/error_missing_message.json');
      try {
        ErrorEnvelope.fromJson(json);
        fail('expected CheckedFromJsonException');
      } on CheckedFromJsonException catch (e) {
        expect(e.key, 'message');
      }
    });

    test('ApiError.fromJson alone also throws a typed exception', () {
      expect(
        () => ApiError.fromJson(<String, dynamic>{'code': 'not_found'}),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });
  });

  group('Unknown error codes (AC6)', () {
    test('brand_new_code decodes to ErrorCode.unknown', () {
      final envelope = ErrorEnvelope.fromJson(
        readFixture('variants/error_unknown_code.json'),
      );
      expect(envelope.error.code, ErrorCode.unknown);
      expect(envelope.error.message, 'A code added by a newer server.');
    });

    test('a non-string code also decodes to ErrorCode.unknown', () {
      final error = ApiError.fromJson(<String, dynamic>{
        'code': 42,
        'message': 'm',
      });
      expect(error.code, ErrorCode.unknown);
    });
  });

  group('ErrorCode wire names', () {
    test('every code has the documented snake_case name', () {
      expect(ErrorCode.values.map((c) => c.wireName).toList(), [
        'invalid_barcode',
        'invalid_query',
        'invalid_bgg_id',
        'not_found',
        'rate_limited',
        'upstream_unavailable',
        'internal_error',
        'unknown',
      ]);
    });
  });

  group('ApiError value semantics', () {
    test('equal values are equal and copyWith changes one field', () {
      const a = ApiError(code: ErrorCode.rateLimited, message: 'Slow down.');
      const b = ApiError(code: ErrorCode.rateLimited, message: 'Slow down.');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(message: 'Wait.').message, 'Wait.');
      expect(a.copyWith(message: 'Wait.').code, ErrorCode.rateLimited);
      expect(a.toString(), contains('rateLimited'));
    });

    test('envelope copyWith replaces the nested error', () {
      const envelope = ErrorEnvelope(
        error: ApiError(code: ErrorCode.notFound, message: 'Not found.'),
      );
      final changed = envelope.copyWith.error(code: ErrorCode.internalError);
      expect(changed.error.code, ErrorCode.internalError);
      expect(changed.error.message, 'Not found.');
      expect(changed, isNot(envelope));
      expect(envelope.toString(), contains('notFound'));
    });
  });
}
