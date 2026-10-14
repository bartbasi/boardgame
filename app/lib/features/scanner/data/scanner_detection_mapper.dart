import 'package:mobile_scanner/mobile_scanner.dart' as scanner;

import '../domain/barcode.dart';
import '../domain/barcode_detection.dart';

/// Maps the mobile_scanner plugin's results to domain detections (T-030).
///
/// Only UPC-A, EAN-13, and EAN-8 keep a format; every other symbology,
/// UPC-E included, maps to a null format so the scanner ignores it.
abstract final class ScannerDetectionMapper {
  /// The symbologies the camera is asked to look for.
  static const List<scanner.BarcodeFormat> formats = [
    scanner.BarcodeFormat.upcA,
    scanner.BarcodeFormat.ean13,
    scanner.BarcodeFormat.ean8,
  ];

  /// The domain format for [format], or null when the app does not accept
  /// it.
  static BarcodeFormat? formatOf(scanner.BarcodeFormat format) =>
      switch (format) {
        scanner.BarcodeFormat.upcA => BarcodeFormat.upcA,
        scanner.BarcodeFormat.ean13 => BarcodeFormat.ean13,
        scanner.BarcodeFormat.ean8 => BarcodeFormat.ean8,
        _ => null,
      };

  /// One detection per barcode in [capture], in the plugin's order.
  static List<BarcodeDetection> detectionsOf(scanner.BarcodeCapture capture) =>
      [
        for (final barcode in capture.barcodes)
          BarcodeDetection(
            rawValue: barcode.rawValue,
            format: formatOf(barcode.format),
          ),
      ];
}
