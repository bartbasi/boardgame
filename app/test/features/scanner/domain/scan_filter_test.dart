// T-030: which camera detections open a lookup (AC4, AC5, AC6).
import 'package:board_game_collector/features/scanner/domain/barcode.dart';
import 'package:board_game_collector/features/scanner/domain/barcode_detection.dart';
import 'package:board_game_collector/features/scanner/domain/scan_filter.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

BarcodeDetection _d(
  String? raw, [
  BarcodeFormat? format = BarcodeFormat.ean13,
]) => BarcodeDetection(rawValue: raw, format: format);

void main() {
  group('BarcodeDetection', () {
    test('equality, hash, and toString use the text and the format', () {
      expect(_d('1'), _d('1'));
      expect(_d('1').hashCode, _d('1').hashCode);
      expect(_d('1'), isNot(_d('2')));
      expect(_d('1'), isNot(_d('1', BarcodeFormat.ean8)));
      expect(_d('1', null).toString(), 'BarcodeDetection(1, null)');
      expect(_d('1').toString(), 'BarcodeDetection(1, ean13)');
    });
  });

  group('accepted codes (AC2)', () {
    final cases = <String, BarcodeFormat>{
      '4006381333931': BarcodeFormat.ean13,
      '036000291452': BarcodeFormat.upcA,
      '96385074': BarcodeFormat.ean8,
      // iOS reports a UPC-A as EAN-13 with a leading zero.
      '0036000291452': BarcodeFormat.ean13,
    };
    for (final MapEntry(key: raw, value: format) in cases.entries) {
      test('$raw reported as ${format.name} passes with its own digits', () {
        final barcode = ScanFilter().accept(_d(raw, format));
        expect(barcode, isNotNull);
        expect(barcode!.digits, raw);
      });
    }
  });

  group('ignored detections (AC4, AC5)', () {
    test('other symbologies: QR, UPC-E, Code 128 (null format)', () {
      final filter = ScanFilter();
      expect(filter.accept(_d('https://example.com', null)), isNull);
      expect(filter.accept(_d('ABC-123', null)), isNull);
      // GS1-11: a UPC-E whose 8 digits pass the EAN-8 check digit.
      expect(Barcode.parse('96385074').isOk, isTrue);
      expect(filter.accept(_d('96385074', null)), isNull);
      // A valid EAN-13 text in a symbology the app does not accept.
      expect(filter.accept(_d('4006381333931', null)), isNull);
    });

    test('a bad check digit, a wrong length, letters, and no text', () {
      final filter = ScanFilter();
      expect(filter.accept(_d('036000291453', BarcodeFormat.upcA)), isNull);
      expect(filter.accept(_d('12345')), isNull);
      expect(filter.accept(_d('40063813339A1')), isNull);
      expect(filter.accept(_d(null)), isNull);
    });
  });

  group('debounce (AC6)', () {
    test('the window is 2 s', () {
      expect(ScanFilter.defaultWindow, const Duration(seconds: 2));
      expect(ScanFilter().window, ScanFilter.defaultWindow);
    });

    test('5 reads within 500 ms pass once', () {
      fakeAsync((async) {
        final filter = ScanFilter(stopwatch: clock.stopwatch);
        final passed = <Barcode>[];
        for (var i = 0; i < 5; i++) {
          final barcode = filter.accept(_d('4006381333931'));
          if (barcode != null) passed.add(barcode);
          async.elapse(const Duration(milliseconds: 100));
        }
        expect(passed, hasLength(1));
      });
    });

    test('the same code passes again at 2 s, not at 1999 ms', () {
      fakeAsync((async) {
        final filter = ScanFilter(stopwatch: clock.stopwatch);
        expect(filter.accept(_d('4006381333931')), isNotNull);
        async.elapse(const Duration(milliseconds: 1999));
        expect(filter.accept(_d('4006381333931')), isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(filter.accept(_d('4006381333931')), isNotNull);
      });
    });

    test('UPC-A and its EAN-13 form are the same code', () {
      fakeAsync((async) {
        final filter = ScanFilter(stopwatch: clock.stopwatch);
        expect(
          filter.accept(_d('036000291452', BarcodeFormat.upcA)),
          isNotNull,
        );
        expect(filter.accept(_d('0036000291452')), isNull);
      });
    });

    test('a different code passes at once', () {
      fakeAsync((async) {
        final filter = ScanFilter(stopwatch: clock.stopwatch);
        expect(filter.accept(_d('4006381333931')), isNotNull);
        expect(
          filter.accept(_d('036000291452', BarcodeFormat.upcA)),
          isNotNull,
        );
      });
    });

    test('reset lets the same code pass again at once', () {
      fakeAsync((async) {
        final filter = ScanFilter(stopwatch: clock.stopwatch);
        expect(filter.accept(_d('4006381333931')), isNotNull);
        filter.reset();
        expect(filter.accept(_d('4006381333931')), isNotNull);
      });
    });

    test('a custom window', () {
      fakeAsync((async) {
        final filter = ScanFilter(
          window: const Duration(milliseconds: 100),
          stopwatch: clock.stopwatch,
        );
        expect(filter.accept(_d('4006381333931')), isNotNull);
        async.elapse(const Duration(milliseconds: 100));
        expect(filter.accept(_d('4006381333931')), isNotNull);
      });
    });
  });
}
