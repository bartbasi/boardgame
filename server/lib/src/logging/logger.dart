import 'dart:convert';

import 'error_description.dart';

/// Log levels, lowest to highest. LOG_LEVEL accepts these names.
enum LogLevel {
  debug,
  info,
  warning,
  error;

  /// Parses a LOG_LEVEL value. Returns null for anything else.
  static LogLevel? tryParse(String value) {
    for (final level in values) {
      if (level.name == value) return level;
    }
    return null;
  }
}

/// Writes structured logs as one JSON object per line.
///
/// Every line has `ts` (UTC ISO 8601), `level`, and `msg`, followed by the
/// caller's fields. Lines below [minLevel] are dropped. Newlines inside
/// values are escaped by the JSON encoder, so one call is always one line.
///
/// Privacy rule: callers pass only fields that hold no personal data. Never
/// log IP addresses, headers, query strings, or request bodies.
class Logger {
  /// Creates a logger that hands each line to [sink].
  Logger({
    required this.minLevel,
    required this._sink,
    this._clock = DateTime.now,
  });

  /// Lines below this level are dropped.
  final LogLevel minLevel;
  final void Function(String line) _sink;
  final DateTime Function() _clock;

  static const _reserved = {'ts', 'level', 'msg'};

  /// Whether a line at [level] would be written.
  bool isEnabled(LogLevel level) => level.index >= minLevel.index;

  /// Writes one line at [level] if it is enabled.
  void log(
    LogLevel level,
    String message, [
    Map<String, Object?> fields = const {},
  ]) {
    if (!isEnabled(level)) return;
    final line = <String, Object?>{
      'ts': _clock().toUtc().toIso8601String(),
      'level': level.name,
      'msg': message,
      for (final entry in fields.entries)
        if (!_reserved.contains(entry.key)) entry.key: entry.value,
    };
    _sink(jsonEncode(line, toEncodable: (Object? value) => value.toString()));
  }

  /// Writes a debug line.
  void debug(String message, [Map<String, Object?> fields = const {}]) =>
      log(LogLevel.debug, message, fields);

  /// Writes an info line.
  void info(String message, [Map<String, Object?> fields = const {}]) =>
      log(LogLevel.info, message, fields);

  /// Writes a warning line.
  void warning(String message, [Map<String, Object?> fields = const {}]) =>
      log(LogLevel.warning, message, fields);

  /// Writes an error line, with [error] and [stackTrace] when given.
  ///
  /// [error] is written as `errorType` (its runtime type) and `error`, a
  /// redacted description from [describeError] that never holds the input
  /// that caused it (no FormatException source, no URI, no query string).
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) => log(LogLevel.error, message, {
    ...fields,
    if (error != null) 'errorType': error.runtimeType.toString(),
    if (error != null) 'error': describeError(error),
    if (stackTrace != null) 'stack': stackTrace.toString(),
  });
}
