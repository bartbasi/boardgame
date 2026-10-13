import 'package:json_annotation/json_annotation.dart';

/// Decodes a JSON number that must be a whole number of at least 1, such as
/// a BGG id or a player count.
///
/// Rejects null, strings, fractions (`1.5`), zero, and negative numbers. A
/// whole-valued double such as `13.0` is accepted as 13. Inside a DTO's
/// `fromJson` the error surfaces as [CheckedFromJsonException] naming the
/// field. Error messages never contain the rejected value.
class PositiveIntConverter implements JsonConverter<int, Object> {
  /// Creates the converter.
  const PositiveIntConverter();

  @override
  int fromJson(Object json) {
    final value = _wholeNumber(json);
    if (value == null || value < 1) {
      throw const FormatException('must be a whole number of at least 1');
    }
    return value;
  }

  @override
  Object toJson(int object) => object;
}

/// Decodes a JSON number that must be a whole number, which may be zero or
/// negative (used for years, so a year before the common era fits).
class WholeNumberConverter implements JsonConverter<int, Object> {
  /// Creates the converter.
  const WholeNumberConverter();

  @override
  int fromJson(Object json) {
    final value = _wholeNumber(json);
    if (value == null) {
      throw const FormatException('must be a whole number');
    }
    return value;
  }

  @override
  Object toJson(int object) => object;
}

/// Decodes an ISO 8601 timestamp that must be in UTC: it ends in `Z` or
/// carries an explicit offset such as `+00:00`. A timestamp without a zone
/// is rejected, because its meaning would depend on the reader's time zone.
///
/// Encodes with [DateTime.toIso8601String] after converting to UTC, so the
/// output always ends in `Z`.
class UtcDateTimeConverter implements JsonConverter<DateTime, Object> {
  /// Creates the converter.
  const UtcDateTimeConverter();

  @override
  DateTime fromJson(Object json) {
    if (json is! String) {
      throw const FormatException('must be an ISO 8601 UTC timestamp string');
    }
    final parsed = DateTime.parse(json);
    if (!parsed.isUtc) {
      throw const FormatException('must be in UTC (end in Z or an offset)');
    }
    _checkCalendarFields(json);
    return parsed;
  }

  /// `YYYY-MM-DDThh:mm[:ss]` at the start of the text, before any fraction
  /// or zone.
  static final _fields = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[Tt ](\d{2}):(\d{2})(?::(\d{2}))?',
  );

  /// [DateTime.parse] rolls impossible values over (month 13, day 45, hour
  /// 24, second 60) instead of rejecting them. This rebuilds the written
  /// date and time and requires every field to come back unchanged. It
  /// also requires the extended form with dashes and colons, which is what
  /// the server sends.
  static void _checkCalendarFields(String text) {
    final match = _fields.firstMatch(text);
    if (match == null) {
      throw const FormatException(
        'must use the extended form YYYY-MM-DDThh:mm:ss',
      );
    }
    final written = [
      for (var i = 1; i <= 6; i++) int.parse(match.group(i) ?? '0'),
    ];
    final rebuilt = DateTime.utc(
      written[0],
      written[1],
      written[2],
      written[3],
      written[4],
      written[5],
    );
    final actual = [
      rebuilt.year,
      rebuilt.month,
      rebuilt.day,
      rebuilt.hour,
      rebuilt.minute,
      rebuilt.second,
    ];
    for (var i = 0; i < written.length; i++) {
      if (written[i] != actual[i]) {
        throw const FormatException('is not a real calendar date and time');
      }
    }
  }

  @override
  Object toJson(DateTime object) => object.toUtc().toIso8601String();
}

/// Decodes a normalized barcode: a GTIN-13 string of exactly 13 ASCII
/// digits. The server pads UPC-A codes with a leading zero and validates
/// the check digit before it answers, so the contract checks only the form.
class Gtin13Converter implements JsonConverter<String, Object> {
  /// Creates the converter.
  const Gtin13Converter();

  static final _gtin13 = RegExp(r'^[0-9]{13}$');

  @override
  String fromJson(Object json) {
    if (json is! String || !_gtin13.hasMatch(json)) {
      throw const FormatException('must be a GTIN-13 string of 13 digits');
    }
    return json;
  }

  @override
  Object toJson(String object) => object;
}

/// The largest whole number a double holds exactly (2^53 - 1). Beyond it,
/// [double.toInt] can clamp (1e300 becomes the 64-bit maximum), so larger
/// doubles are rejected rather than silently changed.
const _maxSafeDouble = 9007199254740991.0;

int? _wholeNumber(Object json) {
  if (json is int) return json;
  if (json is double &&
      json.isFinite &&
      json.abs() <= _maxSafeDouble &&
      json == json.truncateToDouble()) {
    return json.toInt();
  }
  return null;
}
