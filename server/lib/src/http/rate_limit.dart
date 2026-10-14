import 'dart:async';
import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';

import '../logging/logger.dart';
import 'rate_limiter.dart';
import 'responses.dart';

/// The request context key under which shelf_io (1.4.x) puts the connection's
/// [HttpConnectionInfo].
const connectionInfoContextKey = 'shelf.io.connection_info';

/// Key for a request whose peer address is unknown. shelf_io always sets the
/// connection info, so in production this happens only in in-process tests
/// that build a [Request] by hand; all such requests share one bucket. No
/// address maps to it: it would be the IPv6 prefix ffff:ffff:ffff:ffff::/64,
/// which is multicast (ff00::/8) and never a source address.
const unknownClientKey = -1;

/// Finds the rate limit key of a request's client (T-020 AC4).
///
/// The direct peer is the socket's remote address. When that peer is one of
/// [ClientAddressResolver.new]'s trusted proxies (Caddy, by its fixed address
/// on the Compose network), the client is the last entry of X-Forwarded-For:
/// the one Caddy itself added. Entries to its left came from the client and
/// can be forged, so they are never used. When the peer is not trusted,
/// X-Forwarded-For is ignored.
///
/// If a trusted peer sends no X-Forwarded-For, or its last entry is not an IP
/// address, the peer's own address is used (all such requests share Caddy's
/// bucket, which fails safe: it limits more, never less).
///
/// Because that shared bucket would make all users share one limit, such a
/// request calls [onUnusableForwarded] (at most once per [warnEvery], with no
/// value), so the operator sees it (T-020 review R1-G2).
///
/// The key comes from [addressKey]. It is used only in memory and never
/// logged.
class ClientAddressResolver {
  /// Creates a resolver that trusts X-Forwarded-For only from
  /// [trustedProxies], compared by exact address. [now] is a monotonic clock
  /// for the warning's rate limit (default a [Stopwatch]).
  ClientAddressResolver({
    Iterable<InternetAddress> trustedProxies = const [],
    this.onUnusableForwarded,
    this.warnEvery = rateLimitWindow,
    Duration Function()? now,
  }) : _trusted = {for (final a in trustedProxies) canonicalAddress(a)},
       _now = now ?? _stopwatchClock();

  final Set<String> _trusted;

  /// Called when a trusted proxy sends no usable X-Forwarded-For entry, at
  /// most once per [warnEvery]. Gets no value, so its log line holds none.
  final void Function()? onUnusableForwarded;

  /// Least time between two [onUnusableForwarded] calls.
  final Duration warnEvery;

  final Duration Function() _now;
  Duration? _lastWarning;

  static Duration Function() _stopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  /// The rate limit key of [request]'s client, or [unknownClientKey].
  int clientKey(Request request) {
    final info = request.context[connectionInfoContextKey];
    if (info is! HttpConnectionInfo) return unknownClientKey;
    final peer = info.remoteAddress;
    if (!_trusted.contains(canonicalAddress(peer))) return addressKey(peer);
    final forwarded = request.headers['x-forwarded-for'];
    // shelf joins repeated header lines with ",", so the last entry of the
    // joined value is the last entry of the last line.
    final last = forwarded == null
        ? null
        : InternetAddress.tryParse(forwarded.split(',').last.trim());
    if (last == null) {
      _warnUnusable();
      return addressKey(peer);
    }
    return addressKey(last);
  }

  void _warnUnusable() {
    final now = _now();
    final last = _lastWarning;
    if (last != null && now - last < warnEvery) return;
    _lastWarning = now;
    onUnusableForwarded?.call();
  }
}

/// The warning [ClientAddressResolver.onUnusableForwarded] writes: no value
/// and no address.
void Function() logUnusableForwarded(Logger logger) =>
    () => logger.warning(
      'trusted proxy sent no usable client address, limiting by the proxy '
      'address',
    );

/// Default interval of [startRateLimitSweep] [ASSUMPTION: 10 s].
const rateLimitSweepInterval = Duration(seconds: 10);

/// Creates a periodic timer; [Timer.periodic] in production, a fake in tests.
typedef PeriodicTimerFactory = Timer Function(
  Duration interval,
  void Function(Timer timer) callback,
);

/// Removes expired limiter entries every [interval] even when no request
/// arrives (T-020 AC6, review R1-S2), so an address is held at most
/// [interval] after its window passes. Cancel the returned timer at
/// shutdown.
Timer startRateLimitSweep(
  RateLimiter limiter, {
  Duration interval = rateLimitSweepInterval,
  PeriodicTimerFactory periodic = Timer.periodic,
}) => periodic(interval, (_) => limiter.removeExpired());

/// The rate limit key of [address], an integer so the limiter holds no
/// per-entry objects:
/// - IPv4, and IPv4-mapped IPv6 (`::ffff:192.0.2.1`): the 32-bit address, so
///   both forms count as one client.
/// - Other IPv6: the 64-bit /64 prefix [ASSUMPTION, T-020 handoff]. One
///   subscriber usually gets a whole /64 and can use any of its 2^64
///   addresses, so limiting per full address would let one client rotate past
///   the limit and fill the table.
///
/// The two ranges cannot collide for real clients: an IPv6 prefix below
/// 2^32 lies in 0000::/32, which is reserved and not global unicast.
int addressKey(InternetAddress address) {
  final raw = address.rawAddress;
  if (raw.length == 4) return _bigEndian(raw, 0, 4);
  if (_isIPv4Mapped(raw)) return _bigEndian(raw, 12, 4);
  // 8 bytes overflow into the sign bit, which is fine: native ints are 64-bit
  // two's complement, and only equality matters.
  return _bigEndian(raw, 0, 8);
}

int _bigEndian(List<int> bytes, int start, int length) {
  var value = 0;
  for (var i = start; i < start + length; i++) {
    value = (value << 8) | bytes[i];
  }
  return value;
}

bool _isIPv4Mapped(List<int> raw) {
  for (var i = 0; i < 10; i++) {
    if (raw[i] != 0) return false;
  }
  return raw[10] == 0xff && raw[11] == 0xff;
}

/// A canonical text form of [address] for comparing trusted proxies: dotted
/// decimal for IPv4 (including IPv4-mapped IPv6), eight lowercase hex groups
/// for other IPv6. Never logged.
String canonicalAddress(InternetAddress address) {
  final raw = address.rawAddress;
  if (raw.length == 4) return raw.join('.');
  if (_isIPv4Mapped(raw)) return raw.sublist(12).join('.');
  return [
    for (var i = 0; i + 1 < raw.length; i += 2)
      ((raw[i] << 8) | raw[i + 1]).toRadixString(16),
  ].join(':');
}

/// Whole seconds for a Retry-After header: [wait] rounded up, at least 1
/// (T-020 AC1).
int retryAfterSeconds(Duration wait) {
  final micros = wait.inMicroseconds;
  final seconds =
      (micros + Duration.microsecondsPerSecond - 1) ~/
      Duration.microsecondsPerSecond;
  return seconds < 1 ? 1 : seconds;
}

/// 429 with the `rate_limited` envelope and a Retry-After header.
Response rateLimitedResponse(Duration wait) {
  final response = errorResponse(
    429,
    ErrorCode.rateLimited,
    'Too many requests. Please wait a moment and try again.',
  );
  return response.change(
    headers: {'retry-after': '${retryAfterSeconds(wait)}'},
  );
}

/// Per-IP rate limiting for /v1 (T-020). Mounted first in `v1Middleware`, so
/// it runs before attestation and never for /health.
///
/// A refused request gets [rateLimitedResponse] and goes no further. The
/// request log still writes its one line (status 429, route `<unmatched>`
/// because routing never ran). Nothing here logs a client address.
Middleware rateLimit(RateLimiter limiter, ClientAddressResolver resolver) =>
    (Handler inner) {
      return (Request request) {
        final wait = limiter.hit(resolver.clientKey(request));
        if (wait != null) return rateLimitedResponse(wait);
        return inner(request);
      };
    };

/// The warning [RateLimiter.onFull] writes: the configured maximum only, no
/// address.
void Function() logRateLimiterFull(Logger logger, int maxTracked) =>
    () => logger.warning('rate limiter full, evicting oldest entries', {
      'maxTracked': maxTracked,
    });
