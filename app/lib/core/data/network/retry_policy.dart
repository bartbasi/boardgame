import 'dart:io' show HttpDate;
import 'dart:math';

/// How the API client retries GET requests [ASSUMPTION, T-013 AC4 to AC10].
///
/// Waits use exponential backoff with full jitter: before retry n (1-based)
/// the client waits a random time between 0 and
/// `min(maxBackoff, baseDelay * factor^(n - 1))`. A Retry-After header from
/// the server replaces the backoff, unless it asks for more than
/// [maxRetryAfter], in which case the client does not retry at all.
final class RetryPolicy {
  /// Creates a policy. The defaults are the T-013 values.
  const RetryPolicy({
    this.baseDelay = const Duration(milliseconds: 500),
    this.factor = 2,
    this.maxBackoff = const Duration(seconds: 8),
    this.maxRetries = 3,
    this.maxRetryAfter = const Duration(seconds: 30),
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 15),
    this.totalTimeout = const Duration(seconds: 20),
  });

  /// The backoff ceiling before the first retry.
  final Duration baseDelay;

  /// How much the ceiling grows with each retry.
  final int factor;

  /// The largest backoff ceiling.
  final Duration maxBackoff;

  /// Retries after the first attempt, so at most `maxRetries + 1` attempts.
  final int maxRetries;

  /// The longest Retry-After the client waits for. A longer one ends the
  /// call with the failure, carrying the requested wait.
  final Duration maxRetryAfter;

  /// Time allowed to open a connection, per attempt.
  final Duration connectTimeout;

  /// Time allowed to receive the response, per attempt.
  final Duration receiveTimeout;

  /// Time allowed for one call, including every attempt and every wait.
  final Duration totalTimeout;

  /// The jittered wait before retry number [retry] (1 for the first retry).
  Duration backoff(int retry, Random random) {
    assert(retry >= 1, 'retry is 1-based');
    final ceilingMicros = min(
      maxBackoff.inMicroseconds,
      baseDelay.inMicroseconds * pow(factor, retry - 1).toInt(),
    );
    return Duration(
      microseconds: (ceilingMicros * random.nextDouble()).floor(),
    );
  }
}

/// Reads a Retry-After header value: either a number of seconds or an HTTP
/// date (RFC 9110 section 10.2.3). A date in the past gives zero. Returns
/// null when [value] is null or cannot be read.
Duration? parseRetryAfter(String? value, {required DateTime now}) {
  if (value == null) return null;
  final text = value.trim();
  if (text.isEmpty) return null;
  if (RegExp(r'^\d+$').hasMatch(text)) {
    // A huge value still means "wait longer than we will", so clamp it
    // instead of ignoring it (int.tryParse returns null on overflow).
    const maxSeconds = 0x7fffffff;
    final seconds = int.tryParse(text) ?? maxSeconds;
    return Duration(seconds: min(seconds, maxSeconds));
  }
  final DateTime date;
  try {
    date = HttpDate.parse(text);
  } on Object {
    return null;
  }
  final wait = date.difference(now);
  return wait.isNegative ? Duration.zero : wait;
}
