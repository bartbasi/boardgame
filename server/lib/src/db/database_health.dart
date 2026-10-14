import 'dart:async';

/// How long GET /health waits for the database before it answers 503
/// (T-019 AC6 requires an answer within 2 s, measured through Caddy). A
/// healthy `SELECT 1` takes about a millisecond, a new connection with
/// SCRAM authentication a few tens.
const databaseHealthTimeout = Duration(seconds: 1);

/// How long one probe result is reused.
const databaseHealthCacheFor = Duration(seconds: 1);

/// The database part of GET /health (T-019 AC6).
///
/// /health is open to anyone (no attestation, no rate limit), so a flood of
/// health requests must not turn into a flood of database queries or use up
/// the connection pool:
/// - at most one probe runs at a time; concurrent checks share it;
/// - a result is reused for [cacheFor];
/// - a check waits at most [timeout] and then reports unavailable, while a
///   probe that hangs (for example a connect to a host that does not answer)
///   keeps running in the background until the driver's own timeout ends it,
///   and no new probe starts before it does;
/// - while such a slow probe has already run for [timeout] or longer, checks
///   answer unavailable at once instead of waiting again. (Seen in Compose:
///   with the postgres container stopped, resolving its name on the
///   internal network hangs for seconds.)
final class DatabaseHealth {
  /// Creates a health check that calls [probe], which must complete normally
  /// when the database answers and throw otherwise. [onChange] is called
  /// when a probe result differs from the previous one; before the first
  /// probe the database counts as up, because the server checked it at
  /// startup.
  DatabaseHealth({
    required this._probe,
    this.timeout = databaseHealthTimeout,
    this.cacheFor = databaseHealthCacheFor,
    this._clock = DateTime.now,
    this._onChange,
  });

  /// A health check that always reports the database as available, for
  /// tests of routes that do not involve the database.
  factory DatabaseHealth.alwaysUp() => DatabaseHealth(probe: () async {});

  /// Longest wait for one check.
  final Duration timeout;

  /// How long a result is reused.
  final Duration cacheFor;

  final Future<void> Function() _probe;
  final DateTime Function() _clock;
  final void Function(bool up)? _onChange;

  Future<bool>? _inFlight;
  DateTime? _inFlightSince;
  bool? _lastResult;
  DateTime? _lastAt;

  /// Whether the database answered, from a fresh or recent probe.
  Future<bool> isUp() async {
    final last = _lastResult;
    final lastAt = _lastAt;
    if (last != null &&
        lastAt != null &&
        _clock().difference(lastAt) < cacheFor) {
      return last;
    }
    final running = _inFlight;
    final since = _inFlightSince;
    if (running != null &&
        since != null &&
        _clock().difference(since) >= timeout) {
      return false;
    }
    final Future<bool> probe;
    if (running != null) {
      probe = running;
    } else {
      _inFlightSince = _clock();
      // Cleared in whenComplete, which always runs after this assignment,
      // even when the probe fails at once.
      probe = _inFlight = _run().whenComplete(() {
        _inFlight = null;
        _inFlightSince = null;
      });
    }
    try {
      return await probe.timeout(timeout);
    } on TimeoutException {
      return false;
    }
  }

  Future<bool> _run() async {
    bool up;
    try {
      await _probe();
      up = true;
    } on Object {
      up = false;
    }
    final previous = _lastResult ?? true;
    _lastResult = up;
    _lastAt = _clock();
    if (previous != up) _onChange?.call(up);
    return up;
  }
}
