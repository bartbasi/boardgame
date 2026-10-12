import 'failure.dart';

export 'failure.dart';

/// The outcome of an operation that can fail: either [Ok] with a value or
/// [Err] with a [Failure]. Pure Dart, so domain code can use it.
///
/// Switch over it exhaustively:
///
/// ```dart
/// switch (result) {
///   case Ok(:final value): show(value);
///   case Err(:final failure): showError(failure);
/// }
/// ```
sealed class Result<T> {
  const Result();

  /// Wraps a successful [value].
  const factory Result.ok(T value) = Ok<T>;

  /// Wraps a [failure].
  const factory Result.err(Failure failure) = Err<T>;

  /// True for [Ok].
  bool get isOk => this is Ok<T>;

  /// True for [Err].
  bool get isErr => this is Err<T>;

  /// The value of an [Ok], or null.
  T? get valueOrNull => switch (this) {
    Ok(:final value) => value,
    Err() => null,
  };

  /// The failure of an [Err], or null.
  Failure? get failureOrNull => switch (this) {
    Ok() => null,
    Err(:final failure) => failure,
  };

  /// Calls [onOk] or [onErr] and returns what it returns.
  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) =>
      switch (this) {
        Ok(:final value) => onOk(value),
        Err(:final failure) => onErr(failure),
      };

  /// Transforms the value of an [Ok]; an [Err] passes through unchanged.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok(:final value) => Ok<R>(transform(value)),
    Err(:final failure) => Err<R>(failure),
  };

  /// Chains another operation that can fail; an [Err] passes through.
  Result<R> flatMap<R>(Result<R> Function(T value) next) => switch (this) {
    Ok(:final value) => next(value),
    Err(:final failure) => Err<R>(failure),
  };
}

/// A successful result.
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  /// The value.
  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

/// A failed result.
final class Err<T> extends Result<T> {
  const Err(this.failure);

  /// What went wrong.
  final Failure failure;

  @override
  bool operator ==(Object other) => other is Err<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err, failure);

  @override
  String toString() => 'Err($failure)';
}
