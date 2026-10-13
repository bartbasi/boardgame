import 'package:board_game_collector/core/data/network/failure_mapper.dart';
import 'package:board_game_collector/core/domain/failure.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:board_game_collector/features/scanner/domain/barcode.dart';
import 'package:flutter_test/flutter_test.dart';

InvalidBarcodeFailure? fail(String input) {
  final f = Barcode.parse(input).failureOrNull;
  return f is InvalidBarcodeFailure ? f : null;
}

String withCheck(String body) {
  var sum = 0;
  final p = body.padLeft(12, '0');
  for (var i = 0; i < 12; i++) {
    final d = p.codeUnitAt(i) - 48;
    sum += i.isOdd ? d * 3 : d;
  }
  return '$body${(10 - sum % 10) % 10}';
}

void main() {
  group('T-026 QA: separators and whitespace', () {
    for (final s in [
      '0360-0029-1452',
      '036000 291452',
      '036000.291452',
      '036000291452-',
      '+036000291452',
    ]) {
      test('"$s" is nonDigit', () {
        expect(fail(s)?.reason, InvalidBarcodeReason.nonDigit);
      });
    }
    test('Unicode whitespace around the code is trimmed', () {
      expect(Barcode.parse(' 036000291452 ').isOk, isTrue);
      expect(Barcode.parse('\r\n036000291452\r\n').isOk, isTrue);
    });
    test('trailing newline does not slip past the digit regex', () {
      expect(
        Barcode.parse('036000291452\n').valueOrNull?.digits,
        '036000291452',
      );
    });
  });

  group('T-026 QA: non-ASCII and hostile input', () {
    test('Arabic-Indic digits are nonDigit', () {
      expect(fail('٠٣٦٠٠٠٢٩١٤٥٢')?.reason, InvalidBarcodeReason.nonDigit);
    });
    test('full-width digits are nonDigit', () {
      expect(fail('０３６０００２９１４５２')?.reason, InvalidBarcodeReason.nonDigit);
    });
    test('null byte inside and at the end is nonDigit', () {
      expect(fail('0360002\u000091452')?.reason, InvalidBarcodeReason.nonDigit);
      expect(fail('036000291452\u0000')?.reason, InvalidBarcodeReason.nonDigit);
    });
    test('emoji and surrogate pairs are nonDigit', () {
      expect(fail('0360002914😀')?.reason, InvalidBarcodeReason.nonDigit);
    });
    test('very long digit input is wrongLength with the full length', () {
      final f = fail('1' * 100000);
      expect(f?.reason, InvalidBarcodeReason.wrongLength);
      expect(f?.length, 100000);
    });
    test('very long non-digit input is nonDigit', () {
      expect(fail('a' * 100000)?.reason, InvalidBarcodeReason.nonDigit);
    });
  });

  group('T-026 QA: every length 0 to 15', () {
    for (var n = 0; n <= 15; n++) {
      test('$n digits', () {
        final body = n == 0 ? '' : withCheck('1' * (n - 1));
        final result = Barcode.parse(body);
        if (n == 8 || n == 12 || n == 13) {
          expect(result.isOk, isTrue);
        } else {
          final f = fail(body);
          expect(f?.reason, InvalidBarcodeReason.wrongLength);
          expect(f?.length, n);
        }
      });
    }
  });

  group('T-026 QA: check digit off by one', () {
    for (final entry in {
      'EAN-8': '9638507',
      'UPC-A': '03600029145',
      'EAN-13': '400638133393',
    }.entries) {
      test('${entry.key}: +1 and -1 on the check digit fail', () {
        final good = withCheck(entry.value);
        final c = int.parse(good[good.length - 1]);
        for (final delta in [1, -1, 9]) {
          final bad = '${entry.value}${(c + delta + 10) % 10}';
          expect(
            fail(bad)?.reason,
            InvalidBarcodeReason.badCheckDigit,
            reason: bad,
          );
        }
      });
    }
    test('a transposed pair of digits is caught', () {
      expect(fail('036000921452')?.reason, InvalidBarcodeReason.badCheckDigit);
    });
  });

  group('T-026 QA: all zeros and leading zeros', () {
    test('all-zero codes are valid (check digit 0)', () {
      for (final n in [8, 12, 13]) {
        final r = Barcode.parse('0' * n);
        expect(r.isOk, isTrue, reason: '$n');
        expect(r.valueOrNull?.gtin13, '0' * 13);
      }
    });
    test('leading zeros are kept in digits', () {
      final b = Barcode.parse('00000000').valueOrNull!;
      expect(b.digits, '00000000');
      expect(b.format, BarcodeFormat.ean8);
    });
    test('EAN-13 starting with 0 is reported as ean13 but equals UPC-A', () {
      final a = Barcode.parse('036000291452').valueOrNull!;
      final b = Barcode.parse('0036000291452').valueOrNull!;
      expect(a.format, BarcodeFormat.upcA);
      expect(b.format, BarcodeFormat.ean13);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.gtin13, b.gtin13);
    });
    test('different codes are not equal; same code read twice is equal', () {
      final a = Barcode.parse('4006381333931').valueOrNull!;
      expect(a, Barcode.parse('4006381333931').valueOrNull);
      expect(a == Barcode.parse('036000291452').valueOrNull, isFalse);
    });
  });

  group('T-026 QA: failure fits the sealed pattern', () {
    test('InvalidBarcodeFailure is a Failure and not retryable', () {
      const f = InvalidBarcodeFailure(
        InvalidBarcodeReason.badCheckDigit,
        length: 12,
      );
      expect(f, isA<Failure>());
      expect(isRetryable(f), isFalse);
      expect(
        f,
        const InvalidBarcodeFailure(
          InvalidBarcodeReason.badCheckDigit,
          length: 12,
        ),
      );
      expect(
        f ==
            const InvalidBarcodeFailure(
              InvalidBarcodeReason.badCheckDigit,
              length: 11,
            ),
        isFalse,
      );
    });
  });
}
