import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';

import '../logging/logger.dart';
import 'rate_limiter.dart';
import 'responses.dart';

/// The request context key under which shelf_io (1.4.x) puts the connection's
/// [HttpConnectionInfo].
const connectionInfoContextKey = 'shelf.io.connection_info';

/// Key used for a request whose peer address is unknown. shelf_io always sets
/// the connection info, so in production this only happens in in-process
/// tests that build a [Request] by hand; all such requests share one bucket.
const unknownClientKey = '<unknown>';

/// Finds the client IP address of a request (T-020 AC4).
///
/// The direct peer is the socket's remote address. When that peer is one of
/// [trustedProxies] (Caddy, by its fixed address on the Compose network), the
/// client is the last entry of X-Forwarded-For: the one Caddy itself added.
/// Entries to its left came from the client and can be forged, so they are
/// never used. When the peer is not trusted, X-Forwarded-For is ignored.
///
/// If a trusted peer sends no X-Forwarded-For, or its last entry is not an IP
/// address, the peer's own address is used (all such requests share Caddy's
/// bucket, which fails safe: it limits more, never less).
///
/// The result is a canonical text form, so `::ffff:192.0.2.1` and
/// `192.0.2.1`, or `2001:DB8::1` and `2001:db8:0::1`, count as one client.
/// It is used only as an in-memory key and is never logged.
class ClientAddressResolver {
  /// Creates a resolver that trusts X-Forwarded-For only from
  /// [trustedProxies].
  ClientAddressResolver({Iterable<InternetAddress> trustedProxies = const []})
    : _trusted = {for (final a in trustedProxies) canonicalAddress(a)};

  final Set<String> _trusted;

  /// The canonical client address of [request], or [unknownClientKey].
  String clientKey(Request request) {
    final info = request.context[connectionInfoContextKey];
    if (info is! HttpConnectionInfo) return unknownClientKey;
    final peer = canonicalAddress(info.remoteAddress);
    if (!_trusted.contains(peer)) return peer;
    final forwarded = request.headers['x-forwarded-for'];
    if (forwarded == null) return peer;
    // shelf joins repeated header lines with ",", so the last entry of the
    // joined value is the last entry of the last line.
    final last = InternetAddress.tryParse(forwarded.split(',').last.trim());
    return last == null ? peer : canonicalAddress(last);
  }
}

/// A canonical text form of [address]: dotted decimal for IPv4 (including
/// IPv4-mapped IPv6 addresses), eight lowercase hex groups for IPv6.
String canonicalAddress(InternetAddress address) {
  final raw = address.rawAddress;
  if (raw.length == 4) return raw.join('.');
  final mapped =
      raw.length == 16 &&
      raw.sublist(0, 10).every((b) => b == 0) &&
      raw[10] == 0xff &&
      raw[11] == 0xff;
  if (mapped) return raw.sublist(12).join('.');
  final groups = <String>[
    for (var i = 0; i + 1 < raw.length; i += 2)
      ((raw[i] << 8) | raw[i + 1]).toRadixString(16),
  ];
  return groups.join(':');
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
