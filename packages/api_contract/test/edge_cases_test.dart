import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

Map<String, dynamic> _env(Object? code, Object? message) => {
  'error': {'code': code, 'message': message},
};

void main() {
  group('ErrorEnvelope edge cases', () {
    test('empty message is accepted and preserved', () {
      final e = ErrorEnvelope.fromJson(_env('not_found', ''));
      expect(e.error.message, '');
      expect(e.toJson()['error'], containsPair('message', ''));
    });

    test('unicode message round trips through JSON text', () {
      const msg = 'Prüfziffer falsch ☃ \u{1F3B2} 日本語';
      final text = jsonEncode(
        ErrorEnvelope(
          error: const ApiError(code: ErrorCode.invalidBarcode, message: msg),
        ).toJson(),
      );
      final back = ErrorEnvelope.fromJson(
        jsonDecode(text) as Map<String, dynamic>,
      );
      expect(back.error.message, msg);
    });

    test('very large message (1 MB) round trips', () {
      final msg = 'x' * (1024 * 1024);
      final back = ErrorEnvelope.fromJson(_env('internal_error', msg));
      expect(back.error.message.length, msg.length);
    });

    test('empty string code maps to unknown', () {
      expect(
        ErrorEnvelope.fromJson(_env('', 'm')).error.code,
        ErrorCode.unknown,
      );
    });

    test('code matching is case sensitive', () {
      expect(
        ErrorEnvelope.fromJson(_env('NOT_FOUND', 'm')).error.code,
        ErrorCode.unknown,
      );
    });

    test('camelCase code on the wire is not accepted as known', () {
      expect(
        ErrorEnvelope.fromJson(_env('notFound', 'm')).error.code,
        ErrorCode.unknown,
      );
    });

    test('null code fails with a typed error naming code', () {
      expect(
        () => ErrorEnvelope.fromJson(_env(null, 'm')),
        throwsA(
          isA<CheckedFromJsonException>().having((e) => e.key, 'key', 'code'),
        ),
      );
    });

    test('numeric message fails with a typed error naming message', () {
      expect(
        () => ErrorEnvelope.fromJson(_env('not_found', 5)),
        throwsA(
          isA<CheckedFromJsonException>().having(
            (e) => e.key,
            'key',
            'message',
          ),
        ),
      );
    });

    test('error as a string instead of an object fails typed', () {
      expect(
        () => ErrorEnvelope.fromJson({'error': 'boom'}),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });

    test('error as null fails typed', () {
      expect(
        () => ErrorEnvelope.fromJson({'error': null}),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });

    test('empty object fails typed', () {
      expect(
        () => ErrorEnvelope.fromJson(<String, dynamic>{}),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });

    test('encoding ErrorCode.unknown writes "unknown"', () {
      const e = ErrorEnvelope(
        error: ApiError(code: ErrorCode.unknown, message: 'm'),
      );
      expect((e.toJson()['error'] as Map)['code'], 'unknown');
    });

    test('every ErrorCode value encodes then decodes to itself', () {
      for (final c in ErrorCode.values) {
        final e = ErrorEnvelope(
          error: ApiError(code: c, message: 'm'),
        );
        expect(ErrorEnvelope.fromJson(e.toJson()).error.code, c);
        expect(c.wireName, isNotEmpty);
      }
    });

    test('wire names are unique', () {
      final names = ErrorCode.values.map((c) => c.wireName).toSet();
      expect(names.length, ErrorCode.values.length);
    });

    test('equality and hashCode follow values', () {
      final a = ErrorEnvelope.fromJson(_env('not_found', 'm'));
      final b = ErrorEnvelope.fromJson(_env('not_found', 'm'));
      final c = ErrorEnvelope.fromJson(_env('not_found', 'other'));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.toString(), contains('ErrorCode.notFound'));
      expect(a.toString(), contains('message: m'));
    });
  });

  group('HealthResponse edge cases', () {
    test('empty strings are accepted', () {
      final h = HealthResponse.fromJson({'status': '', 'version': ''});
      expect(h.status, '');
      expect(h.version, '');
    });

    test('unknown status string is kept as is', () {
      final h = HealthResponse.fromJson({'status': 'degraded', 'version': '1'});
      expect(h.status, 'degraded');
    });

    test('unicode and long version round trip', () {
      final v = 'é' * 10000;
      final h = HealthResponse.fromJson({'status': 'ok', 'version': v});
      expect(h.toJson(), {'status': 'ok', 'version': v});
    });

    test('null status fails typed naming status', () {
      expect(
        () => HealthResponse.fromJson({'status': null, 'version': '1'}),
        throwsA(
          isA<CheckedFromJsonException>().having((e) => e.key, 'key', 'status'),
        ),
      );
    });

    test('missing status fails typed', () {
      expect(
        () => HealthResponse.fromJson({'version': '1'}),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });

    test('list value for version fails typed', () {
      expect(
        () => HealthResponse.fromJson({'status': 'ok', 'version': <int>[]}),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });

    test('equality and copyWith', () {
      const a = HealthResponse(status: 'ok', version: '1');
      expect(a, const HealthResponse(status: 'ok', version: '1'));
      expect(a.copyWith(version: '2').version, '2');
      expect(a, isNot(a.copyWith(status: 'x')));
    });
  });
}
