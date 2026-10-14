/// Typed failures returned through [Result] instead of exceptions.
///
/// The data layer catches every exception at its edge and maps it to one of
/// these cases, so nothing thrown by dio, dart:io, or a decoder crosses a
/// layer boundary. Presentation code switches over the sealed hierarchy and
/// shows plain-language copy (docs/ux/copy.md, `common.error*`); it never
/// shows a status code or exception text.
library;

import 'result.dart';

/// Base of every failure. Two failures are equal when they have the same
/// type and the same fields.
sealed class Failure {
  const Failure();

  /// The fields that take part in equality and [toString].
  List<Object?> get props => const [];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType || other is! Failure) return false;
    final mine = props;
    final theirs = other.props;
    if (mine.length != theirs.length) return false;
    for (var i = 0; i < mine.length; i++) {
      if (mine[i] != theirs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(props));

  @override
  String toString() =>
      props.isEmpty ? '$runtimeType()' : '$runtimeType(${props.join(', ')})';
}

/// The device could not reach our backend (no network, DNS failure,
/// connection refused or reset).
final class NoConnectionFailure extends Failure {
  const NoConnectionFailure();
}

/// The backend did not answer in time, or the whole call, including its
/// retries, ran past the client's time limit.
final class TimeoutFailure extends Failure {
  const TimeoutFailure();
}

/// The backend asked us to slow down (HTTP 429).
final class RateLimitedFailure extends Failure {
  const RateLimitedFailure({this.retryAfter});

  /// How long the backend asked us to wait, from the Retry-After header.
  /// Null when the header was missing or could not be read.
  final Duration? retryAfter;

  @override
  List<Object?> get props => [retryAfter];
}

/// The backend or a service behind it is down or overloaded (HTTP 502, 503,
/// or 504).
final class ServiceUnavailableFailure extends Failure {
  const ServiceUnavailableFailure();
}

/// The requested resource does not exist (HTTP 404 or 410).
final class NotFoundFailure extends Failure {
  const NotFoundFailure();
}

/// The backend rejected the input (HTTP 400 or 422).
final class InvalidInputFailure extends Failure {
  const InvalidInputFailure(this.code);

  /// Which input was wrong, from the error code in the response body.
  final InvalidInputCode code;

  @override
  List<Object?> get props => [code];
}

/// The API error codes that describe invalid input. Mirrors the input codes
/// of `ErrorCode` in packages/api_contract, so domain code does not depend
/// on the wire format.
enum InvalidInputCode {
  /// Not a valid UPC-A, EAN-13, or EAN-8 code.
  invalidBarcode,

  /// The search query is empty, too short, or too long.
  invalidQuery,

  /// The BGG id is not a positive integer.
  invalidBggId,

  /// The body had no readable error code, or a code that is not about input.
  unknown,
}

/// A barcode the app rejected on the device, before any request was sent.
///
/// Returned by `Barcode.parse` (features/scanner/domain). The backend's own
/// rejection of a barcode arrives as [InvalidInputFailure] with
/// [InvalidInputCode.invalidBarcode] instead.
final class InvalidBarcodeFailure extends Failure {
  const InvalidBarcodeFailure(this.reason, {required this.length});

  /// Why the barcode was rejected.
  final InvalidBarcodeReason reason;

  /// The length of the input after trimming surrounding whitespace, in
  /// UTF-16 code units (Dart's `String.length`), so it is not a character
  /// count when the input has emoji or other non-BMP text. It is meaningful
  /// as a digit count only for [InvalidBarcodeReason.wrongLength], where
  /// every unit is an ASCII digit; 0 there means the input was empty. Do not
  /// show it to the user for the other reasons.
  final int length;

  @override
  List<Object?> get props => [reason, length];
}

/// Why a barcode was rejected on the device. Checked in this order, so a
/// code with a letter is [nonDigit] even when its length is also wrong.
enum InvalidBarcodeReason {
  /// The input has a character that is not an ASCII digit 0 to 9.
  nonDigit,

  /// The input has a digit count other than 8 (EAN-8), 12 (UPC-A), or
  /// 13 (EAN-13), including an empty input.
  wrongLength,

  /// The last digit does not match the GS1 check digit of the others.
  badCheckDigit,
}

/// The backend refused the request (HTTP 401 or 403), for example when the
/// app's install could not be verified.
final class AccessDeniedFailure extends Failure {
  const AccessDeniedFailure();
}

/// The caller cancelled the request, for example because the user typed a
/// new search query. Screens usually ignore this failure.
final class CancelledFailure extends Failure {
  const CancelledFailure();
}

/// The app was built with a missing or unusable API base URL, so no request
/// was sent.
final class ConfigurationFailure extends Failure {
  const ConfigurationFailure(this.problem);

  /// What is wrong with the configuration.
  final ConfigurationProblem problem;

  @override
  List<Object?> get props => [problem];
}

/// Why the API configuration was refused.
enum ConfigurationProblem {
  /// `API_BASE_URL` was not set.
  missingBaseUrl,

  /// `API_BASE_URL` is not an absolute http or https URL with a host, or it
  /// has a query, fragment, or user info.
  malformedBaseUrl,

  /// `API_BASE_URL` uses http in a build that requires https.
  insecureBaseUrl,
}

/// The on-device database could not read or write (for example the disk is
/// full, the file is damaged, or the database was closed). Not retryable;
/// callers that have the data elsewhere, such as the backend, use that.
final class StorageFailure extends Failure {
  const StorageFailure();
}

/// Anything else: an unexpected status, a body that could not be decoded,
/// or an error we did not anticipate.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure();
}
