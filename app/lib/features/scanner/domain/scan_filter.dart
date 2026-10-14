import 'package:board_game_collector/core/domain/result.dart';

import 'barcode.dart';
import 'barcode_detection.dart';

/// Decides which camera detections open a lookup (T-030, scanner.md
/// section 4, "Detected").
///
/// A detection passes when:
/// 1. the scanner reported UPC-A, EAN-13, or EAN-8 (other symbologies,
///    including UPC-E, are dropped before parsing; GS1-11),
/// 2. `Barcode.parse` accepts its text (digits, length, check digit), and
/// 3. the same code (same GTIN-13 key) did not pass in the last [window].
///
/// Everything else is ignored silently. Call [reset] when the user comes
/// back to the scanner, so the same code can be scanned again at once.
class ScanFilter {
  /// [stopwatch] creates the monotonic clock that measures [window]; tests
  /// pass `clock.stopwatch` so fake time applies.
  ScanFilter({
    this.window = defaultWindow,
    Stopwatch Function() stopwatch = Stopwatch.new,
  }) : _stopwatch = stopwatch()..start();

  /// How long the same code is ignored after it passed: 2 s
  /// [ASSUMPTION] (scanner.md section 4; T-030 AC6).
  static const Duration defaultWindow = Duration(seconds: 2);

  /// See [defaultWindow].
  final Duration window;

  final Stopwatch _stopwatch;

  /// GTIN-13 key of the last code that passed, and when it passed.
  String? _lastKey;
  Duration _lastAt = Duration.zero;

  /// Returns the barcode to look up, or null when [detection] is ignored.
  ///
  /// The returned instance comes from parsing this detection's own text, so
  /// its `digits` are what was scanned.
  Barcode? accept(BarcodeDetection detection) {
    final raw = detection.rawValue;
    if (detection.format == null || raw == null) return null;
    final Barcode barcode;
    switch (Barcode.parse(raw)) {
      case Ok(:final value):
        barcode = value;
      case Err():
        return null;
    }
    final now = _stopwatch.elapsed;
    if (barcode.gtin13 == _lastKey && now - _lastAt < window) return null;
    _lastKey = barcode.gtin13;
    _lastAt = now;
    return barcode;
  }

  /// Forgets the last code, so it passes again right away.
  void reset() => _lastKey = null;
}
