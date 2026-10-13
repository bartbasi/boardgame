/// The barcode value object: parsing, validation, and the GTIN-13 key.
///
/// Pure Dart (T-026). Requirement for the server's barcode validation in
/// T-025 (not built yet): it must apply the same rules and the same
/// GTIN-13 key, so the app never sends a code the server would reject with
/// `invalid_barcode` and both match stores use one key per product.
library;

import 'package:board_game_collector/core/domain/result.dart';

/// The barcode symbologies the app accepts, told apart by digit count.
enum BarcodeFormat {
  /// 8 digits.
  ean8,

  /// 12 digits, the usual US retail code.
  upcA,

  /// 13 digits. A UPC-A code with a leading 0 is also 13 digits and is
  /// reported as EAN-13.
  ean13,
}

/// A validated UPC-A, EAN-13, or EAN-8 barcode.
///
/// Two barcodes are equal when they have the same [gtin13], so a UPC-A code
/// and the same code written as EAN-13 with a leading 0 are the same value.
/// Equal barcodes can still differ in [digits] and [format]
/// (`036000291452` is upcA, `0036000291452` is ean13), and a Set or Map
/// keeps whichever came first. To show the code the user scanned or typed,
/// read [digits] from the instance [parse] returned for that input, not
/// from a deduplicated collection.
final class Barcode {
  const Barcode._(this.digits, this.format, this.gtin13);

  /// Parses [input], ignoring whitespace around it.
  ///
  /// Returns [Ok] with the barcode, or [Err] with an [InvalidBarcodeFailure]
  /// that says why the input was rejected. The checks run in this order:
  /// non-digit characters, then length, then the check digit.
  static Result<Barcode> parse(String input) {
    final digits = input.trim();
    if (!_onlyDigits.hasMatch(digits)) {
      return _invalid(InvalidBarcodeReason.nonDigit, digits);
    }
    final format = switch (digits.length) {
      8 => BarcodeFormat.ean8,
      12 => BarcodeFormat.upcA,
      13 => BarcodeFormat.ean13,
      _ => null,
    };
    if (format == null) {
      return _invalid(InvalidBarcodeReason.wrongLength, digits);
    }
    final gtin13 = digits.padLeft(13, '0');
    if (_checkDigit(gtin13) != gtin13.codeUnitAt(12) - _zero) {
      return _invalid(InvalidBarcodeReason.badCheckDigit, digits);
    }
    return Ok(Barcode._(digits, format, gtin13));
  }

  /// The digits as entered or scanned, without surrounding whitespace.
  final String digits;

  /// The symbology, from the number of [digits].
  final BarcodeFormat format;

  /// The 13-digit key used for lookups and for the local and server match
  /// stores: the digits padded on the left with zeros to 13 (one zero for
  /// UPC-A, five for EAN-8). `036000291452` becomes `0036000291452` and
  /// `96385074` becomes `0000096385074`. Leading zeros are only filler and
  /// do not change the GTIN or its check digit; GS1's 14-digit storage form
  /// is this key with one more leading zero (docs/api-research.md section
  /// 11, GS1-03 to GS1-08; docs/decisions.md 2026-10-13).
  final String gtin13;

  @override
  bool operator ==(Object other) => other is Barcode && other.gtin13 == gtin13;

  @override
  int get hashCode => gtin13.hashCode;

  @override
  String toString() => 'Barcode($gtin13)';
}

final RegExp _onlyDigits = RegExp(r'^[0-9]*$');

final int _zero = '0'.codeUnitAt(0);

Result<Barcode> _invalid(InvalidBarcodeReason reason, String trimmed) =>
    Err(InvalidBarcodeFailure(reason, length: trimmed.length));

/// The GS1 check digit for the first 12 digits of [gtin13]. From the right
/// of those 12 digits, weights alternate 3, 1, 3, and so on; left padding
/// with zeros does not change the result, so one rule serves all formats.
int _checkDigit(String gtin13) {
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    final digit = gtin13.codeUnitAt(i) - _zero;
    sum += i.isOdd ? digit * 3 : digit;
  }
  return (10 - sum % 10) % 10;
}
