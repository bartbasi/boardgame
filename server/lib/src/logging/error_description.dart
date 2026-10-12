import 'dart:io';

/// The longest error description written to the log.
const maxErrorDescriptionLength = 300;

final _urlQuery = RegExp(r'\?[^\s,;)\]}"]*');
final _urlUserInfo = RegExp(r'(://)[^/\s@]+@');

/// Describes [error] for the log without the input that caused it.
///
/// The rule (also in server/README.md, "Logs"):
/// - Always log the error type separately (`errorType`), plus the stack trace.
/// - FormatException: only its message, never `source` or `offset` (the
///   source is the raw input: a barcode, a query, a response body).
/// - HttpException and SocketException: only their message, never the URI
///   or address they carry (a URI holds the path and query string).
/// - Anything else: `toString()` with URL query strings and user info
///   replaced by `<redacted>`.
/// - The result is cut to [maxErrorDescriptionLength] characters.
///
/// Code that wraps upstream errors must not put request data, tokens, or
/// response bodies into exception messages in the first place; this is the
/// safety net, not the policy.
String describeError(Object error) {
  final text = switch (error) {
    FormatException(:final message) => 'FormatException: $message',
    HttpException(:final message) => 'HttpException: $message',
    SocketException(:final message) => 'SocketException: $message',
    _ =>
      error
          .toString()
          .replaceAll(_urlQuery, '?<redacted>')
          .replaceAllMapped(_urlUserInfo, (m) => '${m[1]}<redacted>@'),
  };
  return text.length <= maxErrorDescriptionLength
      ? text
      : '${text.substring(0, maxErrorDescriptionLength)}...';
}
