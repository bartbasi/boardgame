import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as scanner;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/scanner_detection_mapper.dart';
import '../domain/barcode_detection.dart';

part 'scanner_camera.g.dart';

/// The torch as the scanner shows it.
enum TorchStatus {
  /// The camera has no torch, or its state is not known yet: the toggle is
  /// hidden.
  unavailable,

  /// The torch is off.
  off,

  /// The torch is on.
  on,
}

/// How a camera start ended.
enum CameraStartResult {
  /// The preview runs and detections arrive.
  started,

  /// The platform refused the camera because the permission is missing
  /// (for example revoked while the app was in the background).
  permissionDenied,

  /// Anything else: no camera, the camera is in use, or a plugin error.
  failed,
}

/// The camera behind the scanner screen (T-030).
///
/// One instance per scanner screen. The screen builds [buildPreview] while
/// the camera may run, then calls [start]; it calls [stop] when the screen
/// is hidden. Widget tests use a fake; [MobileScannerCamera] is the real
/// one.
abstract class ScannerCamera implements Listenable {
  /// The torch; listeners hear about changes.
  TorchStatus get torch;

  /// The codes the camera reads, one list per camera frame.
  Stream<List<BarcodeDetection>> get detections;

  /// Starts the preview and detection. Never throws.
  Future<CameraStartResult> start();

  /// Stops the preview, detection, and torch. Never throws.
  Future<void> stop();

  /// Switches the torch on or off. Never throws.
  Future<void> toggleTorch();

  /// The live preview, filling its box. [key] keeps the same preview when
  /// the layout moves it (rotation).
  Widget buildPreview({required Key key});

  /// Releases the camera.
  void dispose();
}

/// Creates the scanner screen's camera. Tests override it with a fake.
@riverpod
ScannerCamera Function() scannerCameraFactory(Ref ref) =>
    MobileScannerCamera.new;

/// Creates the stopwatch that measures the scanner's debounce window.
/// Tests override it with `clock.stopwatch`, so fake time applies.
@riverpod
Stopwatch Function() scanStopwatchFactory(Ref ref) => Stopwatch.new;

/// [ScannerCamera] on top of mobile_scanner (BSD-3-Clause): Google ML Kit
/// on Android (bundled model, MLKIT-05 and MLKIT-06; approved 2026-10-11),
/// Apple Vision on iOS.
///
/// Not covered by widget tests: it needs a real camera (manual checks in
/// docs/handoffs/T-030.md).
class MobileScannerCamera extends ChangeNotifier implements ScannerCamera {
  MobileScannerCamera()
    : _controller = scanner.MobileScannerController(
        autoStart: false,
        formats: ScannerDetectionMapper.formats,
      ) {
    _controller.addListener(_onControllerChanged);
  }

  final scanner.MobileScannerController _controller;
  TorchStatus _torch = TorchStatus.unavailable;
  bool _disposed = false;

  @override
  TorchStatus get torch => _torch;

  @override
  Stream<List<BarcodeDetection>> get detections => _controller.barcodes
      .map(ScannerDetectionMapper.detectionsOf)
      // A frame the plugin could not decode is not an error for the user.
      .handleError((Object _) {});

  void _onControllerChanged() {
    final torch = switch (_controller.value.torchState) {
      scanner.TorchState.on => TorchStatus.on,
      scanner.TorchState.off || scanner.TorchState.auto => TorchStatus.off,
      scanner.TorchState.unavailable => TorchStatus.unavailable,
    };
    if (torch != _torch) {
      _torch = torch;
      notifyListeners();
    }
  }

  @override
  Future<CameraStartResult> start() async {
    try {
      await _controller.start();
    } on Object {
      return CameraStartResult.failed;
    }
    final value = _controller.value;
    final error = value.error;
    if (error == null && value.isRunning) return CameraStartResult.started;
    return error?.errorCode == scanner.MobileScannerErrorCode.permissionDenied
        ? CameraStartResult.permissionDenied
        : CameraStartResult.failed;
  }

  @override
  Future<void> stop() async {
    try {
      await _controller.stop();
    } on Object {
      // Already stopped or never started.
    }
  }

  @override
  Future<void> toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } on Object {
      // The camera is not running; the toggle is disabled then anyway.
    }
  }

  @override
  Widget buildPreview({required Key key}) => scanner.MobileScanner(
    key: key,
    controller: _controller,
    // The screen draws its own starting and error states.
    placeholderBuilder: (context) => const SizedBox.expand(),
    errorBuilder: (context, error) => const SizedBox.expand(),
  );

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _controller.removeListener(_onControllerChanged);
    unawaited(_controller.dispose().catchError((Object _) {}));
    super.dispose();
  }
}
