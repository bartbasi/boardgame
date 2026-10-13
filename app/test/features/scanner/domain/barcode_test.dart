// T-026: the barcode value object and its validation.
import 'dart:io';

import 'package:board_game_collector/core/domain/result.dart';
import 'package:board_game_collector/features/scanner/domain/barcode.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../architecture/domain_purity.dart';

Barcode _ok(String input) {
  final result = Barcode.parse(input);
  expect(result, isA<Ok<Barcode>>(), reason: 'parsing "$input"');
  return result.valueOrNull!;
}

void main() {
  group('AC1: valid codes parse', () {
    final cases = <String, (BarcodeFormat, String)>{
      '036000291452': (BarcodeFormat.upcA, '0036000291452'),
      '012345678905': (BarcodeFormat.upcA, '0012345678905'),
      '4006381333931': (BarcodeFormat.ean13, '4006381333931'),
      '0036000291452': (BarcodeFormat.ean13, '0036000291452'),
      '96385074': (BarcodeFormat.ean8, '0000096385074'),
    };
    for (final MapEntry(key: input, value: (format, gtin13)) in cases.entries) {
      test(input, () {
        final barcode = _ok(input);
        expect(barcode.digits, input);
        expect(barcode.format, format);
        expect(barcode.gtin13, gtin13);
      });
    }
  });

  group('AC2: invalid codes fail with the reason', () {
    final cases = <String, (String, InvalidBarcodeReason, int)>{
      'bad check digit': (
        '036000291453',
        InvalidBarcodeReason.badCheckDigit,
        12,
      ),
      'too short': ('12345', InvalidBarcodeReason.wrongLength, 5),
      'non-digit': ('03600029145A', InvalidBarcodeReason.nonDigit, 12),
      'empty': ('', InvalidBarcodeReason.wrongLength, 0),
      '14 digits': ('00036000291452', InvalidBarcodeReason.wrongLength, 14),
      'whitespace only': ('   ', InvalidBarcodeReason.wrongLength, 0),
      'space inside': ('036000 291452', InvalidBarcodeReason.nonDigit, 13),
      'dash inside': ('0360-0029-1452', InvalidBarcodeReason.nonDigit, 14),
      'letter and wrong length': ('12A', InvalidBarcodeReason.nonDigit, 3),
      'non-ASCII digits': (
        '\u0660\u0663\u0666\u0660\u0660\u0660\u0662\u0669\u0661\u0664\u0665'
            '\u0662',
        InvalidBarcodeReason.nonDigit,
        12,
      ),
      'bad EAN-13 check digit': (
        '4006381333932',
        InvalidBarcodeReason.badCheckDigit,
        13,
      ),
      'bad EAN-8 check digit': (
        '96385075',
        InvalidBarcodeReason.badCheckDigit,
        8,
      ),
      '9 digits': ('963850740', InvalidBarcodeReason.wrongLength, 9),
      '11 digits': ('36000291452', InvalidBarcodeReason.wrongLength, 11),
    };
    for (final MapEntry(key: name, value: (input, reason, length))
        in cases.entries) {
      test(name, () {
        expect(
          Barcode.parse(input),
          Err<Barcode>(InvalidBarcodeFailure(reason, length: length)),
        );
      });
    }

    test('exactly one check digit is accepted for each length', () {
      for (final body in ['9638507', '03600029145', '400638133393']) {
        final accepted = [
          for (var d = 0; d <= 9; d++)
            if (Barcode.parse('$body$d').isOk) d,
        ];
        expect(accepted, hasLength(1), reason: body);
      }
    });
  });

  group('AC3: whitespace around the code is trimmed', () {
    test('spaces', () {
      final barcode = _ok(' 036000291452 ');
      expect(barcode.digits, '036000291452');
      expect(barcode.gtin13, '0036000291452');
    });

    test('tabs and newlines from a paste', () {
      expect(_ok('\t96385074\n').digits, '96385074');
    });

    test('the failure length counts the trimmed input', () {
      expect(
        Barcode.parse('  12345  '),
        const Err<Barcode>(
          InvalidBarcodeFailure(InvalidBarcodeReason.wrongLength, length: 5),
        ),
      );
    });
  });

  group('AC4: UPC-A and its EAN-13 form share one GTIN-13 key', () {
    test('both give 0036000291452 and are equal', () {
      final upcA = _ok('036000291452');
      final ean13 = _ok('0036000291452');
      expect(upcA.gtin13, '0036000291452');
      expect(ean13.gtin13, '0036000291452');
      expect(upcA, ean13);
      expect(upcA.hashCode, ean13.hashCode);
      expect({upcA, ean13}, hasLength(1));
    });

    test('EAN-8 and its zero-padded EAN-13 form share a key', () {
      expect(_ok('96385074'), _ok('0000096385074'));
    });

    test('different codes are not equal', () {
      expect(_ok('036000291452'), isNot(_ok('012345678905')));
      expect(_ok('036000291452'), isNot('0036000291452'));
    });

    test('toString shows only the key', () {
      expect(_ok('036000291452').toString(), 'Barcode(0036000291452)');
    });
  });

  test('AC5: the barcode file imports no Flutter or plugin package', () {
    final violations = checkDomainPurity(
      libDir: Directory('lib'),
      packageName: 'board_game_collector',
    ).where((v) => v.domainFile.contains('scanner/domain/barcode.dart'));
    expect(violations, isEmpty);
    final source = File('lib/features/scanner/domain/barcode.dart')
        .readAsStringSync();
    expect(source, isNot(contains('package:flutter')));
  });
}
