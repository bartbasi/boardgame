import 'dart:collection';

/// Default requests allowed per client IP in one window
/// [ASSUMPTION: 60 per minute, T-020 AC1].
const defaultRateLimitPerWindow = 60;

/// Default most client IPs tracked at once
/// [ASSUMPTION: 100,000, T-020 AC7].
const defaultRateLimitMaxTracked = 100000;

/// The rate limit window (T-020: "per minute").
const rateLimitWindow = Duration(minutes: 1);

/// Counts requests per key (a client IP) in fixed windows, in memory only.
///
/// A key's window starts with its first request and lasts [window]. Up to
/// [limit] requests in that window are allowed; later ones are refused with
/// the time left until the window ends. When the window has passed, the key's
/// entry is removed, and its next request starts a new window.
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
/// addresses.
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
    if (limit < 1) throw ArgumentError.value(limit, 'limit', 'must be >= 1');
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
  /// per [window]. It gets no key, so a log line it writes holds no IP.
  final void Function()? onFull;

  final Duration Function() _now;
  final Map<String, _Entry> _entries = HashMap();
  final Queue<_Entry> _order = ListQueue();
  Duration? _lastFullCall;

  static Duration Function() _stopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  /// Number of keys held right now (after removing expired ones as of the
  /// last [hit] or [removeExpired]).
  int get trackedCount => _entries.length;

  /// Records one request for [key]. Returns null if it is allowed, or how
  /// long until [key]'s window ends if it is refused.
  Duration? hit(String key) {
    final now = _now();
    _removeExpired(now);
    final entry = _entries[key];
    if (entry == null) {
      if (_entries.length >= maxTracked) {
        _entries.remove(_order.removeFirst().key);
        _reportFull(now);
      }
      final created = _Entry(key, now + window);
      _entries[key] = created;
      _order.addLast(created);
      return null;
    }
    if (entry.count < limit) {
      entry.count++;
      return null;
    }
    return entry.endsAt - now;
  }

  void _reportFull(Duration now) {
    final last = _lastFullCall;
    if (last != null && now - last < window) return;
    _lastFullCall = now;
    onFull?.call();
  }

  /// Removes every entry whose window has passed.
  void removeExpired() => _removeExpired(_now());

  void _removeExpired(Duration now) {
    while (_order.isNotEmpty && _order.first.endsAt <= now) {
      _entries.remove(_order.removeFirst().key);
    }
  }
}

final class _Entry {
  _Entry(this.key, this.endsAt);

  final String key;
  final Duration endsAt;
  int count = 1;
}
