// T-013 AC1: the sealed Failure hierarchy.
import 'package:board_game_collector/core/domain/failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// One example of every failure. The switch in [_copyKey] has no default,
/// so adding a case to the sealed class breaks compilation here until the
/// test is updated.
final List<Failure> _everyFailure = [
  const NoConnectionFailure(),
  const TimeoutFailure(),
  const RateLimitedFailure(retryAfter: Duration(seconds: 3)),
  const RateLimitedFailure(),
  const ServiceUnavailableFailure(),
  const NotFoundFailure(),
  const InvalidInputFailure(InvalidInputCode.invalidBarcode),
  const InvalidBarcodeFailure(InvalidBarcodeReason.badCheckDigit, length: 12),
  const AccessDeniedFailure(),
  const CancelledFailure(),
  const ConfigurationFailure(ConfigurationProblem.insecureBaseUrl),
  const StorageFailure(),
  const UnexpectedFailure(),
];

/// The kind of copy.md string a screen would show for each failure. Keys
/// from docs/ux/copy.md; the real mapping arrives with the first screen
/// that shows network errors.
String _copyKey(Failure failure) => switch (failure) {
  NoConnectionFailure() => 'common.offlineNoData',
  TimeoutFailure() => 'common.errorTimeoutBody',
  RateLimitedFailure(retryAfter: null) => 'common.errorRateLimitedBodyNoTime',
  RateLimitedFailure(retryAfter: _?) => 'common.errorRateLimitedBody',
  ServiceUnavailableFailure() => 'common.errorUnavailableBody',
  NotFoundFailure() => 'not found (screen specific)',
  InvalidInputFailure() => 'invalid input (screen specific)',
  InvalidBarcodeFailure() => 'manualEntry.error* (by reason)',
  AccessDeniedFailure() => 'common.errorGenericBody',
  CancelledFailure() => 'nothing shown',
  ConfigurationFailure() => 'common.errorGenericBody',
  StorageFailure() => 'common.errorGenericBody',
  UnexpectedFailure() => 'common.errorGenericBody',
};

void main() {
  test('an exhaustive switch covers every case (AC1)', () {
    expect(_everyFailure.map(_copyKey).toList(), [
      'common.offlineNoData',
      'common.errorTimeoutBody',
      'common.errorRateLimitedBody',
      'common.errorRateLimitedBodyNoTime',
      'common.errorUnavailableBody',
      'not found (screen specific)',
      'invalid input (screen specific)',
      'manualEntry.error* (by reason)',
      'common.errorGenericBody',
      'nothing shown',
      'common.errorGenericBody',
      'common.errorGenericBody',
      'common.errorGenericBody',
    ]);
  });

  test('rate limited carries an optional retry-after', () {
    expect(
      const RateLimitedFailure(retryAfter: Duration(seconds: 3)).retryAfter,
      const Duration(seconds: 3),
    );
    expect(const RateLimitedFailure().retryAfter, isNull);
  });

  test('invalid input carries the API error code', () {
    for (final code in InvalidInputCode.values) {
      expect(InvalidInputFailure(code).code, code);
    }
  });

  test('invalid barcode carries the reason and the trimmed length', () {
    const failure = InvalidBarcodeFailure(
      InvalidBarcodeReason.nonDigit,
      length: 12,
    );
    expect(failure.reason, InvalidBarcodeReason.nonDigit);
    expect(failure.length, 12);
  });

  test('configuration carries the problem', () {
    expect(
      const ConfigurationFailure(ConfigurationProblem.missingBaseUrl).problem,
      ConfigurationProblem.missingBaseUrl,
    );
  });

  group('value equality', () {
    test('same type and fields are equal with the same hash', () {
      for (final failure in _everyFailure) {
        final copy = switch (failure) {
          RateLimitedFailure(:final retryAfter) => RateLimitedFailure(
            retryAfter: retryAfter,
          ),
          InvalidInputFailure(:final code) => InvalidInputFailure(code),
          InvalidBarcodeFailure(:final reason, :final length) =>
            InvalidBarcodeFailure(reason, length: length),
          ConfigurationFailure(:final problem) => ConfigurationFailure(problem),
          _ => failure,
        };
        expect(copy, failure);
        expect(copy.hashCode, failure.hashCode);
      }
    });

    test('different fields or types are not equal', () {
      expect(
        const RateLimitedFailure(retryAfter: Duration(seconds: 3)),
        isNot(const RateLimitedFailure(retryAfter: Duration(seconds: 4))),
      );
      expect(
        const RateLimitedFailure(),
        isNot(const RateLimitedFailure(retryAfter: Duration.zero)),
      );
      expect(
        const InvalidInputFailure(InvalidInputCode.invalidQuery),
        isNot(const InvalidInputFailure(InvalidInputCode.invalidBggId)),
      );
      expect(
        const InvalidBarcodeFailure(InvalidBarcodeReason.nonDigit, length: 5),
        isNot(
          const InvalidBarcodeFailure(
            InvalidBarcodeReason.wrongLength,
            length: 5,
          ),
        ),
      );
      expect(
        const InvalidBarcodeFailure(
          InvalidBarcodeReason.wrongLength,
          length: 5,
        ),
        isNot(
          const InvalidBarcodeFailure(
            InvalidBarcodeReason.wrongLength,
            length: 6,
          ),
        ),
      );
      expect(const TimeoutFailure(), isNot(const NoConnectionFailure()));
      expect(const NotFoundFailure(), isNot('NotFoundFailure()'));
    });

    test('every pair of distinct examples differs', () {
      for (var i = 0; i < _everyFailure.length; i++) {
        for (var j = 0; j < _everyFailure.length; j++) {
          if (i == j) continue;
          expect(_everyFailure[i], isNot(_everyFailure[j]));
        }
      }
    });
  });

  test('toString names the type and fields, never anything else', () {
    expect(const TimeoutFailure().toString(), 'TimeoutFailure()');
    expect(
      const RateLimitedFailure(retryAfter: Duration(seconds: 3)).toString(),
      'RateLimitedFailure(0:00:03.000000)',
    );
    expect(
      const InvalidInputFailure(InvalidInputCode.invalidBarcode).toString(),
      'InvalidInputFailure(InvalidInputCode.invalidBarcode)',
    );
    expect(
      const InvalidBarcodeFailure(
        InvalidBarcodeReason.wrongLength,
        length: 0,
      ).toString(),
      'InvalidBarcodeFailure(InvalidBarcodeReason.wrongLength, 0)',
    );
  });
}
