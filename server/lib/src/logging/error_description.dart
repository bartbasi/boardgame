import 'dart:io';

import 'package:postgres/postgres.dart';

/// The longest error description written to the log.
const maxErrorDescriptionLength = 300;

/// A query string outside an absolute URL, such as `?q=...` in prose: from
/// `?` up to whitespace.
final _proseQuery = RegExp(r'\?\S*');

/// An absolute URL: a scheme, `://`, and everything up to whitespace.
///
/// Deliberately not a URL grammar (T-020 review R1-M1): `,` `;` `)` and
/// similar characters are legal in hosts and paths, so any rule that stops
/// at "prose punctuation" lets the rest of a path through. Punctuation after
/// a URL in prose is redacted with it, which loses nothing that matters.
final _url = RegExp(r'([A-Za-z][A-Za-z0-9+.\-]*://)(\S*)');

/// A host that is safe to keep: a name or IPv4 address, or a bracketed IPv6
/// literal, each with an optional port. Anything else (a client-chosen Host
/// such as `x;y`) is redacted too.
final _safeHost = RegExp(
  r'^(?:[A-Za-z0-9.\-]+|\[[0-9A-Fa-f:.]+\])(?::[0-9]{1,5})?$',
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
///   from `scheme://` up to whitespace, user info and everything after the
///   host (path, query string, fragment) become `<redacted>` (a path holds
///   parameters such as a bggId, T-020 AC8). The host is kept only if it is
///   a plain name, IPv4 address, or bracketed IPv6 literal with an optional
///   port; otherwise it is redacted too (the Host header is client
///   controlled). A query string outside a URL, from `?` up to whitespace,
///   is redacted too.
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
    .replaceAllMapped(_url, (m) => '${m[1]}${_redactAfterScheme(m[2]!)}')
    .replaceAll(_proseQuery, '?<redacted>');

/// Redacts what follows `scheme://` up to whitespace: user info always, the
/// host unless it matches [_safeHost], and the path, query, and fragment
/// whole (each shown as one `<redacted>` marker if present).
String _redactAfterScheme(String rest) {
  final authorityEnd = rest.indexOf(RegExp('[/?#]'));
  final authority = authorityEnd < 0 ? rest : rest.substring(0, authorityEnd);
  final tail = authorityEnd < 0 ? '' : rest.substring(authorityEnd);

  final at = authority.lastIndexOf('@');
  final host = at < 0 ? authority : authority.substring(at + 1);
  final out = StringBuffer()
    ..write(at < 0 ? '' : '<redacted>@')
    ..write(host.isEmpty || _safeHost.hasMatch(host) ? host : '<redacted>');

  final queryAt = tail.indexOf('?');
  final fragmentAt = tail.indexOf('#');
  final pathEnd = [
    queryAt,
    fragmentAt,
  ].where((i) => i >= 0).fold(tail.length, (a, b) => a < b ? a : b);
  final path = tail.substring(0, pathEnd);
  if (path == '/') {
    out.write('/');
  } else if (path.isNotEmpty) {
    out.write('/<redacted>');
  }
  if (queryAt >= 0 && (fragmentAt < 0 || queryAt < fragmentAt)) {
    out.write('?<redacted>');
  } else if (fragmentAt >= 0) {
    out.write('#<redacted>');
  }
  return out.toString();
}
