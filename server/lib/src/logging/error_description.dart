import 'dart:io';

import 'package:postgres/postgres.dart';

/// The longest error description written to the log.
const maxErrorDescriptionLength = 300;

/// A query string outside an absolute URL, such as `?q=...` in prose.
final _urlQuery = RegExp(r'\?[^\s,;)\]}"]*');

/// An absolute URL: scheme, authority (user info and host), then an optional
/// path, query string, and fragment. Each part stops at whitespace and at
/// characters that usually close a URL in prose.
final _url = RegExp(
  r'([A-Za-z][A-Za-z0-9+.\-]*://)'
  r'([^/\s?#,;)\]}"]*)'
  r'([^\s?#,;)\]}"]*)'
  r'(\?[^\s#,;)\]}"]*)?'
  r'(#[^\s,;)\]}"]*)?',
);

/// Describes [error] for the log without the input that caused it.
///
/// The rule (also in server/README.md, "Logs"):
/// - Always log the error type separately (`errorType`), plus the stack trace.
/// - FormatException: only its message, never `source` or `offset` (the
///   source is the raw input: a barcode, a query, a response body).
/// - HttpException and SocketException: only their message, never the URI
///   or address they carry (a URI holds the path and query string).
/// - PostgreSQL server errors (ServerException): only the severity and the
///   SQLSTATE code (https://www.postgresql.org/docs/18/errcodes-appendix.html).
///   Their message, detail, and hint can quote the values of a query (for
///   example "Key (bgg_id)=(13) already exists" or an invalid input value).
/// - Other errors of the PostgreSQL driver (PgException): only the type and
///   the severity. The driver puts query parameter values into some messages
///   (for example "Could not infer type of value '...'"), and a parameter
///   will be a barcode or search text.
/// - ArgumentError, and its subtypes RangeError and IndexError: only the
///   type, `name`, and `message`, never `invalidValue` (T-020 AC8). The
///   invalid value is often raw input, such as a path parameter.
/// - Anything else: `toString()`.
/// - Then, in every case, absolute URLs keep only their scheme and host:
///   user info, path, query string, and fragment each become `<redacted>`
///   (a path holds parameters such as a bggId, T-020 AC8). A query string
///   outside a URL, such as `?q=...`, is redacted too.
/// - The result is cut to [maxErrorDescriptionLength] characters.
///
/// Code that wraps upstream errors must not put request data, tokens, or
/// response bodies into exception messages in the first place; this is the
/// safety net, not the policy. A path without scheme and host (for example
/// `games/123` from shelf's relative `Request.url`) is not recognized, so
/// never put one in an exception message.
String describeError(Object error) {
  final text = switch (error) {
    FormatException(:final message) => 'FormatException: $message',
    HttpException(:final message) => 'HttpException: $message',
    SocketException(:final message) => 'SocketException: $message',
    ServerException(:final severity, :final code) =>
      'ServerException: ${severity.name} ${code ?? 'no SQLSTATE'}',
    PgException(:final severity) => '${error.runtimeType}: ${severity.name}',
    ArgumentError(:final name, :final message) =>
      '${error.runtimeType}${name == null ? '' : ' ($name)'}: '
          '${message ?? 'Invalid argument'}',
    _ => error.toString(),
  };
  final redacted = _redactUrls(text);
  return redacted.length <= maxErrorDescriptionLength
      ? redacted
      : '${redacted.substring(0, maxErrorDescriptionLength)}...';
}

String _redactUrls(String text) => text
    .replaceAllMapped(_url, (m) {
      final authority = m[2]!;
      final at = authority.lastIndexOf('@');
      final host = at < 0
          ? authority
          : '<redacted>@${authority.substring(at + 1)}';
      final path = m[3]!;
      return '${m[1]}$host'
          '${path.isEmpty || path == '/' ? path : '/<redacted>'}'
          '${m[4] == null ? '' : '?<redacted>'}'
          '${m[5] == null ? '' : '#<redacted>'}';
    })
    .replaceAll(_urlQuery, '?<redacted>');
