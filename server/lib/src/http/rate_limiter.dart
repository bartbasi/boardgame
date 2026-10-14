import 'dart:collection';

/// Default requests allowed per client in one window
/// [ASSUMPTION: 60 per minute, T-020 AC1].
const defaultRateLimitPerWindow = 60;

/// Default most clients tracked at once
/// [ASSUMPTION: 100,000, T-020 AC7].
const defaultRateLimitMaxTracked = 100000;

/// The rate limit window (T-020: "per minute").
const rateLimitWindow = Duration(minutes: 1);

/// Largest per-window limit the packed counter supports.
const maxRateLimitPerWindow = _countMask;

const _countBits = 14;
const _countMask = (1 << _countBits) - 1;

/// Counts requests per client key in fixed windows, in memory only.
///
/// A key is an integer derived from the client address (see
/// `ClientAddressResolver.clientKey`). A key's window starts with its first
/// request and lasts [window]. Up to [limit] requests in that window are
/// allowed; later ones are refused with the time left until the window ends.
/// When the window has passed, the key's entry is removed, and its next
/// request starts a new window.
///
/// Privacy (T-020 AC6): keys live only in this object's memory. Nothing here
/// logs, persists, or exposes a key; only [trackedCount] is visible. An entry
/// is removed as soon as its window has passed (checked on every [hit]), so no
/// key outlives its window by more than the time until the next request.
///
/// Memory (T-020 AC7): at most [maxTracked] keys are held. When a new key
/// arrives and the table is full, the oldest entry (the one whose window
/// started first) is evicted. An evicted key starts over with a fresh window,
/// which favours bounded memory over strictness during a flood of distinct
/// addresses. Each entry is two small integers in a map plus one in a queue
/// (no per-entry objects), about 5 MB at 100,000 entries (server/README.md).
///
/// Every window has the same length and the clock never goes back, so
/// insertion order is also expiry order: expired and evicted entries are
/// always at the front of [_order], and each [hit] costs O(1) amortized.
class RateLimiter {
  /// Creates a limiter. [now] is a monotonic clock (elapsed time since some
  /// fixed start); it defaults to a [Stopwatch] started here. Tests pass a
  /// fake one.
  RateLimiter({
    this.limit = defaultRateLimitPerWindow,
    this.maxTracked = defaultRateLimitMaxTracked,
    this.window = rateLimitWindow,
    Duration Function()? now,
    this.onFull,
  }) : _now = now ?? _stopwatchClock() {
    if (limit < 1 || limit > maxRateLimitPerWindow) {
      throw ArgumentError.value(
        limit,
        'limit',
        'must be from 1 to $maxRateLimitPerWindow',
      );
    }
    if (maxTracked < 1) {
      throw ArgumentError.value(maxTracked, 'maxTracked', 'must be >= 1');
    }
    if (window <= Duration.zero) {
      throw ArgumentError.value(window, 'window', 'must be positive');
    }
  }

  /// Requests allowed per key in one window.
  final int limit;

  /// Most keys held at once.
  final int maxTracked;

  /// Length of a window.
  final Duration window;

  /// Called when an entry is evicted because the table is full, at most once
  /// per [window]. It gets no key, so a log line it writes holds no address.
  final void Function()? onFull;

  final Duration Function() _now;

  /// Key to (window end in microseconds << [_countBits]) | count.
  final Map<int, int> _entries = {};

  /// Keys in the order their windows started (and end).
  final Queue<int> _order = ListQueue();

  int? _lastFullCallMicros;

  static Duration Function() _stopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  /// Number of keys held right now (after removing expired ones as of the
  /// last [hit] or [removeExpired]).
  int get trackedCount => _entries.length;

  /// Records one request for [key]. Returns null if it is allowed, or how
  /// long until [key]'s window ends if it is refused.
  Duration? hit(int key) {
    final now = _now().inMicroseconds;
    _removeExpired(now);
    final packed = _entries[key];
    if (packed == null) {
      if (_entries.length >= maxTracked) {
        _entries.remove(_order.removeFirst());
        _reportFull(now);
      }
      _entries[key] = ((now + window.inMicroseconds) << _countBits) | 1;
      _order.addLast(key);
      return null;
    }
    final count = packed & _countMask;
    if (count < limit) {
      _entries[key] = packed + 1;
      return null;
    }
    return Duration(microseconds: (packed >> _countBits) - now);
  }

  void _reportFull(int now) {
    final last = _lastFullCallMicros;
    if (last != null && now - last < window.inMicroseconds) return;
    _lastFullCallMicros = now;
    onFull?.call();
  }

  /// Removes every entry whose window has passed.
  void removeExpired() => _removeExpired(_now().inMicroseconds);

  void _removeExpired(int now) {
    while (_order.isNotEmpty) {
      final key = _order.first;
      if ((_entries[key]! >> _countBits) > now) return;
      _entries.remove(_order.removeFirst());
    }
  }
}
