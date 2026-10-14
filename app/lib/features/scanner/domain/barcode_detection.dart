import 'barcode.dart';

/// One code the camera read, before any validation (T-030).
///
/// The data layer maps the scanner plugin's result to this, so the domain
/// does not depend on the plugin.
final class BarcodeDetection {
  const BarcodeDetection({required this.rawValue, required this.format});

  /// The text the scanner decoded, or null when it decoded no text.
  final String? rawValue;

  /// The symbology the scanner reported, or null for every symbology the
  /// app does not accept (QR, UPC-E, Code 128 and the rest).
  ///
  /// The symbology matters on its own: an 8-digit UPC-E can pass the EAN-8
  /// check digit, so only the reported symbology tells them apart (GS1-11,
  /// docs/decisions.md 2026-10-13).
  final BarcodeFormat? format;

  @override
  bool operator ==(Object other) =>
      other is BarcodeDetection &&
      other.rawValue == rawValue &&
      other.format == format;

  @override
  int get hashCode => Object.hash(rawValue, format);

  @override
  String toString() => 'BarcodeDetection($rawValue, ${format?.name})';
}
