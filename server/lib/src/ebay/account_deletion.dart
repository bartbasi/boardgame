import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';

import '../config/ebay_account_deletion_config.dart';
import '../http/responses.dart';
import '../http/routes.dart';

/// Query parameter carrying eBay's challenge code (EBAY-12).
const challengeCodeParameter = 'challenge_code';

/// Longest challenge code accepted [ASSUMPTION: 1,024 characters]. eBay
/// documents no format or length; its example is `123`.
const maxChallengeCodeLength = 1024;

/// Largest notification body read [ASSUMPTION: 64 KiB]. eBay's notification
/// is a small JSON object (EBAY-15); a bigger body is not one, and reading
/// stops there.
const maxNotificationBytes = 64 * 1024;

/// The whole notification body must arrive within this time from the start
/// of reading [ASSUMPTION: 10 s total]. It is one overall deadline, not a gap
/// between chunks: a client trickling one byte every few seconds would
/// otherwise hold a connection for days (T-084 review R1-M1). eBay's
/// notification is a small JSON object, so 10 s is generous.
const notificationReadTimeout = Duration(seconds: 10);

/// Requests allowed per client IP per minute on the eBay endpoint
/// [ASSUMPTION: 300, orchestrator decision in T-084 round 2; AC5 said 60].
/// eBay sends up to about 1,500 notifications a day (EBAY-16) from
/// unpublished addresses and marks the URL down after 24 hours of failures,
/// while the handler costs almost nothing, so refusing a burst is the bigger
/// risk. Slow bodies are bounded by [notificationReadTimeout], not by this.
const ebayRateLimitPerMinute = 300;

/// Most client IPs the eBay endpoint's limiter tracks [ASSUMPTION: 10,000].
/// Only eBay should call it, so this is far below the /v1 limiter's table
/// and costs well under 1 MB.
const ebayRateLimitMaxTrackedIps = 10000;

/// The `challengeResponse` value (EBAY-11, EBAY-13): SHA-256 of
/// [challengeCode], [verificationToken], and [endpointUrl] concatenated in
/// that order (UTF-8), as lowercase hexadecimal.
String challengeResponse(
  String challengeCode,
  String verificationToken,
  String endpointUrl,
) => sha256
    .convert(utf8.encode('$challengeCode$verificationToken$endpointUrl'))
    .toString();

/// Registers GET and POST [ebayAccountDeletionRoute] on [routes], the
/// registrar of the router mounted at [ebayMountPath], so the full path is
/// [ebayAccountDeletionPath].
///
/// - GET with one non-empty `challenge_code`: 200 `application/json`
///   `{"challengeResponse": "<hex>"}` (EBAY-11 to EBAY-14). Any other GET:
///   400 with the error envelope and the server-only code
///   `invalid_challenge_code`.
/// - POST: the body is read in chunks and discarded, never parsed, kept, or
///   logged, then 204 (EBAY-11: 200, 201, 202, or 204). The body is read
///   only so dart:io can keep the connection open for Caddy (it closes a
///   connection whose request body was left unread). We hold no eBay user
///   data (T-084 AC6), so there is nothing to delete. The `x-ebay-signature`
///   header is not checked (proposed decision in docs/handoffs/T-084.md).
///   A body over [maxNotificationBytes] gets 413, and a body not complete
///   within [notificationReadTimeout] of the start of reading (one overall
///   deadline) gets 408; neither is eBay's notification. In both cases
///   reading stops, and dart:io closes the connection after the response.
///
/// Nothing here logs. The request log writes its usual line (method, route
/// template, status, duration).
///
/// [readTimeout] is a test hook: the overall body deadline (default
/// [notificationReadTimeout]).
void addEbayAccountDeletionRoutes(
  Routes routes,
  EbayAccountDeletionConfig config, {
  Duration readTimeout = notificationReadTimeout,
}) {
  routes.get(ebayAccountDeletionRoute, (request) {
    final code = _challengeCode(request);
    if (code == null) return _invalidChallengeResponse();
    return Response(
      200,
      body: jsonEncode({
        'challengeResponse': challengeResponse(
          code,
          config.verificationToken,
          config.endpointUrl,
        ),
      }),
      headers: const {
        'content-type': 'application/json',
        'cache-control': 'no-store',
      },
    );
  });
  routes.add(
    'POST',
    ebayAccountDeletionRoute,
    (request) => _acknowledge(request, readTimeout),
  );
}

String? _challengeCode(Request request) {
  // A query whose percent-encoding is not UTF-8 never gets here: shelf's
  // Request refuses it, and bindAndServe answers 404 first.
  final values = request.url.queryParametersAll[challengeCodeParameter];
  if (values == null || values.length != 1) return null;
  final code = values.single;
  if (code.isEmpty || code.length > maxChallengeCodeLength) return null;
  return code;
}

Response _invalidChallengeResponse() => jsonResponse(400, {
  'error': {
    'code': 'invalid_challenge_code',
    'message': 'Expected one challenge_code query parameter.',
  },
});

Future<Response> _acknowledge(Request request, Duration deadline) {
  final length = request.contentLength;
  if (length != null && length > maxNotificationBytes) {
    return Future.value(_tooLargeResponse());
  }
  final result = Completer<Response>();
  late final StreamSubscription<List<int>> body;
  late final Timer timer;

  void finish(Response response, {bool stopReading = false}) {
    if (result.isCompleted) return;
    timer.cancel();
    if (stopReading) unawaited(body.cancel());
    result.complete(response);
  }

  var total = 0;
  body = request.read().listen(
    (chunk) {
      total += chunk.length;
      if (total > maxNotificationBytes) {
        finish(_tooLargeResponse(), stopReading: true);
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      if (result.isCompleted) return;
      timer.cancel();
      // The error boundary turns this into a 500, never a 2xx.
      result.completeError(error, stackTrace);
    },
    onDone: () => finish(Response(204)),
    cancelOnError: true,
  );
  // One deadline for the whole body (review R1-M1), not per chunk.
  timer = Timer(
    deadline,
    () => finish(
      jsonResponse(408, {
        'error': {
          'code': 'request_timeout',
          'message': 'The request body did not arrive in time.',
        },
      }),
      stopReading: true,
    ),
  );
  return result.future;
}

Response _tooLargeResponse() => jsonResponse(413, {
  'error': {
    'code': 'payload_too_large',
    'message': 'The request body is too large.',
  },
});
