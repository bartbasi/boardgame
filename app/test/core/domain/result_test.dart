// T-013 AC1: the pure Dart Result type.
import 'package:board_game_collector/core/domain/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Result<int> ok = Ok(3);
  const Result<int> err = Err(NotFoundFailure());

  test('an exhaustive switch reaches both cases', () {
    String describe(Result<int> result) => switch (result) {
      Ok(:final value) => 'ok $value',
      Err(:final failure) => 'err $failure',
    };

    expect(describe(ok), 'ok 3');
    expect(describe(err), 'err NotFoundFailure()');
  });

  test('the named constructors build Ok and Err', () {
    expect(const Result<int>.ok(3), ok);
    expect(const Result<int>.err(NotFoundFailure()), err);
  });

  test('isOk, isErr, valueOrNull, and failureOrNull', () {
    expect(ok.isOk, isTrue);
    expect(ok.isErr, isFalse);
    expect(ok.valueOrNull, 3);
    expect(ok.failureOrNull, isNull);
    expect(err.isOk, isFalse);
    expect(err.isErr, isTrue);
    expect(err.valueOrNull, isNull);
    expect(err.failureOrNull, const NotFoundFailure());
  });

  test('fold calls the matching function', () {
    expect(ok.fold((v) => 'v$v', (f) => 'f'), 'v3');
    expect(err.fold((v) => 'v$v', (f) => 'f'), 'f');
  });

  test('map transforms Ok and passes Err through', () {
    expect(ok.map((v) => v * 2), const Ok(6));
    expect(err.map((v) => v * 2), const Err<int>(NotFoundFailure()));
  });

  test('flatMap chains Ok and passes Err through', () {
    expect(ok.flatMap((v) => Ok('$v')), const Ok('3'));
    expect(
      ok.flatMap<String>((v) => const Err(TimeoutFailure())),
      const Err<String>(TimeoutFailure()),
    );
    expect(err.flatMap((v) => Ok('$v')), const Err<String>(NotFoundFailure()));
  });

  test('equality, hashCode, and toString', () {
    expect(const Ok(3), const Ok(3));
    expect(const Ok(3), isNot(const Ok(4)));
    expect(const Ok(3).hashCode, const Ok(3).hashCode);
    expect(const Err<int>(TimeoutFailure()), const Err<int>(TimeoutFailure()));
    expect(
      const Err<int>(TimeoutFailure()),
      isNot(const Err<int>(NotFoundFailure())),
    );
    expect(
      const Err<int>(TimeoutFailure()).hashCode,
      const Err<int>(TimeoutFailure()).hashCode,
    );
    expect(const Ok(3), isNot(const Err<int>(TimeoutFailure())));
    expect(const Ok(3).toString(), 'Ok(3)');
    expect(
      const Err<int>(TimeoutFailure()).toString(),
      'Err(TimeoutFailure())',
    );
  });
}
