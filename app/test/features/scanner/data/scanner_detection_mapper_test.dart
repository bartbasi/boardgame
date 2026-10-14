// T-030: mobile_scanner results to domain detections (AC4).
import 'package:board_game_collector/features/scanner/data/scanner_detection_mapper.dart';
import 'package:board_game_collector/features/scanner/domain/barcode.dart';
import 'package:board_game_collector/features/scanner/domain/barcode_detection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as scanner;

void main() {
  test('the camera looks for UPC-A, EAN-13, and EAN-8 only', () {
    expect(ScannerDetectionMapper.formats, [
      scanner.BarcodeFormat.upcA,
      scanner.BarcodeFormat.ean13,
      scanner.BarcodeFormat.ean8,
    ]);
  });

  group('formatOf', () {
    test('keeps the three accepted symbologies', () {
      expect(
        ScannerDetectionMapper.formatOf(scanner.BarcodeFormat.upcA),
        BarcodeFormat.upcA,
      );
      expect(
        ScannerDetectionMapper.formatOf(scanner.BarcodeFormat.ean13),
        BarcodeFormat.ean13,
      );
      expect(
        ScannerDetectionMapper.formatOf(scanner.BarcodeFormat.ean8),
        BarcodeFormat.ean8,
      );
    });

    test('drops every other symbology, UPC-E included (GS1-11)', () {
      const accepted = {
        scanner.BarcodeFormat.upcA,
        scanner.BarcodeFormat.ean13,
        scanner.BarcodeFormat.ean8,
      };
      for (final format in scanner.BarcodeFormat.values) {
        if (accepted.contains(format)) continue;
        expect(
          ScannerDetectionMapper.formatOf(format),
          isNull,
          reason: format.name,
        );
      }
    });
  });

  test('detectionsOf maps every barcode of a frame, in order', () {
    const capture = scanner.BarcodeCapture(
      barcodes: [
        scanner.Barcode(
          rawValue: '4006381333931',
          format: scanner.BarcodeFormat.ean13,
        ),
        scanner.Barcode(
          rawValue: '96385074',
          format: scanner.BarcodeFormat.upcE,
        ),
        scanner.Barcode(format: scanner.BarcodeFormat.qrCode),
      ],
    );
    expect(ScannerDetectionMapper.detectionsOf(capture), const [
      BarcodeDetection(rawValue: '4006381333931', format: BarcodeFormat.ean13),
      BarcodeDetection(rawValue: '96385074', format: null),
      BarcodeDetection(rawValue: null, format: null),
    ]);
  });

  test('an empty frame maps to no detections', () {
    expect(
      ScannerDetectionMapper.detectionsOf(const scanner.BarcodeCapture()),
      isEmpty,
    );
  });
}
