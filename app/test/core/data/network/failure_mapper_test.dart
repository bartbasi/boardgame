// T-013 AC8, AC11, AC16: mapping statuses, errors, and bodies to failures.
import 'dart:io';

import 'package:board_game_collector/core/data/network/failure_mapper.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http.dart';

void main() {
  group('decodeJsonObject', () {
    test('returns a JSON object', () {
      expect(decodeJsonObject('{"a": 1}'), {'a': 1});
      expect(decodeJsonObject(contractFixture('health/ok.json')), {
        'status': 'ok',
        'version': '0.1.0+abc1234',
      });
    });

    for (final body in [
      null,
      '',
      '[]',
      '[{"a": 1}]',
      '"ok"',
      '42',
      'null',
      'true',
      '{"a": ',
      '<html></html>',
    ]) {
      test('returns null for $body', () {
        expect(decodeJsonObject(body), isNull);
      });
    }
  });

  group('failureForStatus', () {
    final cases = <int, Failure>{
      400: const InvalidInputFailure(InvalidInputCode.unknown),
      401: const AccessDeniedFailure(),
      403: const AccessDeniedFailure(),
      404: const NotFoundFailure(),
      405: const UnexpectedFailure(),
      408: const TimeoutFailure(),
      409: const UnexpectedFailure(),
      410: const NotFoundFailure(),
      418: const UnexpectedFailure(),
      422: const InvalidInputFailure(InvalidInputCode.unknown),
      429: const RateLimitedFailure(),
      500: const UnexpectedFailure(),
      501: const UnexpectedFailure(),
      502: const ServiceUnavailableFailure(),
      503: const ServiceUnavailableFailure(),
      504: const ServiceUnavailableFailure(),
      302: const UnexpectedFailure(),
      100: const UnexpectedFailure(),
    };
    for (final MapEntry(key: status, value: failure) in cases.entries) {
      test('$status gives $failure', () {
        expect(failureForStatus(status), failure);
      });
    }

    test('429 carries the retry-after it is given', () {
      expect(
        failureForStatus(429, retryAfter: const Duration(seconds: 9)),
        const RateLimitedFailure(retryAfter: Duration(seconds: 9)),
      );
    });

    final codes = <String, InvalidInputCode>{
      'error/invalid_barcode.json': InvalidInputCode.invalidBarcode,
      'error/invalid_query.json': InvalidInputCode.invalidQuery,
      'error/invalid_bgg_id.json': InvalidInputCode.invalidBggId,
      'error/not_found.json': InvalidInputCode.unknown,
      'error/rate_limited.json': InvalidInputCode.unknown,
      'error/upstream_unavailable.json': InvalidInputCode.unknown,
      'error/internal_error.json': InvalidInputCode.unknown,
      'variants/error_unknown_code.json': InvalidInputCode.unknown,
      'variants/error_extra_field.json': InvalidInputCode.unknown,
      'malformed/error_missing_code.json': InvalidInputCode.unknown,
      'malformed/error_missing_error.json': InvalidInputCode.unknown,
      'malformed/error_missing_message.json': InvalidInputCode.unknown,
      'malformed/error_null_message.json': InvalidInputCode.unknown,
    };
    for (final MapEntry(key: fixture, value: code) in codes.entries) {
      test('400 with $fixture carries $code', () {
        expect(
          failureForStatus(400, body: contractFixture(fixture)),
          InvalidInputFailure(code),
        );
      });
    }

    test('extra fields next to an input code are ignored', () {
      const body =
          '{"error": {"code": "invalid_query", "message": "x", "hint": 1},'
          ' "requestId": "r1"}';
      expect(
        failureForStatus(422, body: body),
        const InvalidInputFailure(InvalidInputCode.invalidQuery),
      );
    });
  });

  group('failureForError', () {
    final request = RequestOptions(path: '/health');
    DioException dio(
      DioExceptionType type, {
      Object? error,
      Response<Object?>? res,
    }) => DioException(
      requestOptions: request,
      type: type,
      error: error,
      response: res,
    );

    test('every DioExceptionType maps to a failure', () {
      for (final type in DioExceptionType.values) {
        expect(failureForError(dio(type)), isA<Failure>(), reason: '$type');
      }
    });

    test('bad response maps by its status and body', () {
      expect(
        failureForError(
          dio(
            DioExceptionType.badResponse,
            res: Response<String>(
              requestOptions: request,
              statusCode: 400,
              data: contractFixture('error/invalid_query.json'),
            ),
          ),
        ),
        const InvalidInputFailure(InvalidInputCode.invalidQuery),
      );
      expect(
        failureForError(
          dio(
            DioExceptionType.badResponse,
            res: Response<Object>(
              requestOptions: request,
              statusCode: 503,
              data: const {'not': 'a string'},
            ),
          ),
        ),
        const ServiceUnavailableFailure(),
      );
      expect(
        failureForError(
          dio(
            DioExceptionType.badResponse,
            res: Response<String>(requestOptions: request),
          ),
        ),
        const UnexpectedFailure(),
      );
    });

    test('unknown with a SocketException means no connection', () {
      expect(
        failureForError(
          dio(DioExceptionType.unknown, error: const SocketException('x')),
        ),
        const NoConnectionFailure(),
      );
    });

    test('anything that is not a DioException is unexpected', () {
      expect(failureForError(StateError('x')), const UnexpectedFailure());
      expect(
        failureForError(const SocketException('x')),
        const UnexpectedFailure(),
      );
    });
  });

  test('isRetryable', () {
    expect(isRetryable(const NoConnectionFailure()), isTrue);
    expect(isRetryable(const TimeoutFailure()), isTrue);
    expect(isRetryable(const RateLimitedFailure()), isTrue);
    expect(isRetryable(const ServiceUnavailableFailure()), isTrue);
    expect(isRetryable(const NotFoundFailure()), isFalse);
    expect(
      isRetryable(const InvalidInputFailure(InvalidInputCode.unknown)),
      isFalse,
    );
    expect(isRetryable(const AccessDeniedFailure()), isFalse);
    expect(isRetryable(const CancelledFailure()), isFalse);
    expect(
      isRetryable(
        const ConfigurationFailure(ConfigurationProblem.missingBaseUrl),
      ),
      isFalse,
    );
    expect(isRetryable(const UnexpectedFailure()), isFalse);
  });
}
