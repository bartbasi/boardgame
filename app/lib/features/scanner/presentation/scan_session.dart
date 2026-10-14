import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/domain/result.dart';
import '../domain/barcode.dart';
import '../domain/barcode_detection.dart';
import '../domain/camera_permission.dart';
import '../domain/scan_filter.dart';
import 'scanner_camera.dart';

part 'scan_session.g.dart';

/// What the scanner screen shows (scanner.md section 4).
enum ScanPhase {
  /// Checking the permission or starting the camera; also while paused.
  starting,

  /// The system permission prompt is open (first open only).
  requesting,

  /// Live preview; valid detections open the lookup.
  scanning,

  /// A code was read; the success feedback shows before the lookup opens.
  detected,

  /// Permission denied; the app can ask again.
  denied,

  /// Permission denied for good; only system settings can change it.
  permanentlyDenied,

  /// iOS parental or device policy blocks the camera.
  restricted,

  /// The camera could not start.
  unavailable,
}

/// Whether the camera permission prompt was already shown by the scanner
/// in this app run (T-030 AC1, scanner.md section 1: the prompt appears
/// only when the scanner is first opened).
///
/// After that, "denied" shows the Denied panel and its "Allow camera"
/// button asks again. Kept for the app run only, not stored: on Android a
/// "denied" status cannot tell "never asked" from "denied once", so the
/// next app run asks once more, and Android itself stops asking after the
/// second denial.
@Riverpod(keepAlive: true)
class CameraPromptShown extends _$CameraPromptShown {
  @override
  bool build() => false;

  /// Records that the prompt was shown.
  void markShown() => state = true;
}

/// The scanner screen's state machine (T-030): permission, camera start
/// and stop, detection filtering, and the success step.
///
/// The screen tells it when the scanner is visible ([setActive]); it never
/// touches the camera while the screen is hidden. Work runs one step at a
/// time: a visibility change during a permission request or a camera start
/// is applied when that step ends.
class ScanSession extends ChangeNotifier {
  ScanSession({
    required this._permissions,
    required this._camera,
    required this._filter,
    required this._promptShown,
    required this._markPromptShown,
    required this.onDetected,
    required this.onOpen,
  }) {
    _camera.addListener(notifyListeners);
    _detections = _camera.detections.listen(_onDetections);
  }

  /// How long the success feedback shows before the lookup opens
  /// (scanner.md section 4: 300 ms).
  static const Duration successDelay = Duration(milliseconds: 300);

  /// After this long in scanning with no valid detection, the hint changes
  /// to `scanner.hintSlow` (scanner.md section 4).
  static const Duration slowHintDelay = Duration(seconds: 8);

  final CameraPermissionRepository _permissions;
  final ScannerCamera _camera;
  final ScanFilter _filter;
  final bool Function() _promptShown;
  final void Function() _markPromptShown;

  /// Called once per accepted code, when the success feedback starts
  /// (haptic and announcement).
  final void Function(Barcode barcode) onDetected;

  /// Called [successDelay] after [onDetected], to open the lookup result.
  final void Function(Barcode barcode) onOpen;

  late final StreamSubscription<List<BarcodeDetection>> _detections;

  ScanPhase _phase = ScanPhase.starting;
  Barcode? _detected;
  bool _slowHint = false;
  bool _active = false;
  bool _askNow = false;
  bool _syncing = false;
  bool _syncAgain = false;
  bool _disposed = false;
  bool _hasTorch = false;
  bool _cameraWanted = false;
  Timer? _successTimer;
  Timer? _slowHintTimer;

  /// The current state.
  ScanPhase get phase => _phase;

  /// The code being confirmed while [phase] is [ScanPhase.detected].
  Barcode? get detected => _detected;

  /// Whether the hint should be `scanner.hintSlow`.
  bool get slowHint => _slowHint;

  /// Whether the preview is built: from the moment the camera starts until
  /// it stops. The plugin needs its preview in the tree before it starts.
  bool get cameraInUse =>
      _cameraWanted &&
      (_phase == ScanPhase.starting ||
          _phase == ScanPhase.scanning ||
          _phase == ScanPhase.detected);

  /// The torch as the toggle shows it. While the camera restarts, a device
  /// known to have a torch keeps the toggle (disabled).
  TorchStatus get torch {
    final torch = _camera.torch;
    if (torch != TorchStatus.unavailable) return torch;
    return _hasTorch && _phase == ScanPhase.starting && _cameraWanted
        ? TorchStatus.off
        : TorchStatus.unavailable;
  }

  /// Whether the torch toggle reacts to taps (not while the camera starts).
  bool get torchEnabled =>
      _phase == ScanPhase.scanning || _phase == ScanPhase.detected;

  /// Called by the screen when it becomes visible (its route is current,
  /// its tab is selected, and the app is in the foreground) or hidden.
  void setActive(bool active) {
    if (active == _active) return;
    _active = active;
    if (active) _filter.reset();
    unawaited(_sync());
  }

  /// "Allow camera" on the Denied panel: shows the system prompt again.
  void allowCamera() {
    _askNow = true;
    unawaited(_sync());
  }

  /// "Retry" on the Camera unavailable panel.
  void retry() => unawaited(_sync());

  /// "Open settings" on the Permanently denied panel. The permission is
  /// checked again when the app returns to the foreground.
  Future<void> openSettings() async {
    await _permissions.openSettings();
  }

  /// Switches the torch.
  Future<void> toggleTorch() async {
    if (!torchEnabled) return;
    await _camera.toggleTorch();
  }

  Future<void> _sync() async {
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncAgain = false;
        await _syncOnce();
      } while (_syncAgain && !_disposed);
    } finally {
      _syncing = false;
    }
  }

  /// Whether the step that just awaited is stale: the session was disposed,
  /// or the screen was hidden meanwhile (the loop in [_sync] runs again).
  bool get _interrupted => _disposed || !_active;

  Future<void> _syncOnce() async {
    if (_disposed) return;
    if (!_active) {
      _cancelTimers();
      _cameraWanted = false;
      await _camera.stop();
      if (_isScanningPhase) _setPhase(ScanPhase.starting);
      return;
    }
    if (_phase == ScanPhase.scanning || _phase == ScanPhase.detected) return;

    // Keep a panel on screen while the permission is checked again (back
    // from settings), so it does not flash.
    if (!_isPanelPhase) _setPhase(ScanPhase.starting);
    var permission = await _permissions.status();
    if (_interrupted) return _again();

    if (permission case Ok(value: CameraPermission.denied)
        when _askNow || !_promptShown()) {
      _askNow = false;
      _markPromptShown();
      _setPhase(ScanPhase.requesting);
      permission = await _permissions.request();
      if (_interrupted) return _again();
    }
    _askNow = false;

    switch (permission) {
      case Err():
        _setPhase(ScanPhase.unavailable);
      case Ok(value: CameraPermission.granted):
        await _startCamera();
      case Ok(value: CameraPermission.denied):
        _setPhase(ScanPhase.denied);
      case Ok(value: CameraPermission.permanentlyDenied):
        _setPhase(ScanPhase.permanentlyDenied);
      case Ok(value: CameraPermission.restricted):
        _setPhase(ScanPhase.restricted);
    }
  }

  Future<void> _startCamera() async {
    _cameraWanted = true;
    _setPhase(ScanPhase.starting);
    final result = await _camera.start();
    if (_interrupted) {
      _cameraWanted = false;
      return _again();
    }
    switch (result) {
      case CameraStartResult.started:
        _hasTorch = _hasTorch || _camera.torch != TorchStatus.unavailable;
        _setPhase(ScanPhase.scanning);
      case CameraStartResult.permissionDenied:
        _cameraWanted = false;
        // Revoked meanwhile: show the matching panel on the next check.
        final permission = await _permissions.status();
        if (_interrupted) return _again();
        _setPhase(switch (permission) {
          Ok(value: CameraPermission.permanentlyDenied) =>
            ScanPhase.permanentlyDenied,
          Ok(value: CameraPermission.restricted) => ScanPhase.restricted,
          Ok(value: CameraPermission.denied) => ScanPhase.denied,
          _ => ScanPhase.unavailable,
        });
      case CameraStartResult.failed:
        _cameraWanted = false;
        _setPhase(ScanPhase.unavailable);
    }
  }

  void _again() => _syncAgain = true;

  bool get _isScanningPhase =>
      _phase == ScanPhase.scanning ||
      _phase == ScanPhase.detected ||
      _phase == ScanPhase.starting;

  bool get _isPanelPhase =>
      _phase == ScanPhase.denied ||
      _phase == ScanPhase.permanentlyDenied ||
      _phase == ScanPhase.restricted ||
      _phase == ScanPhase.unavailable;

  void _onDetections(List<BarcodeDetection> detections) {
    if (_disposed || !_active || _phase != ScanPhase.scanning) return;
    for (final detection in detections) {
      final barcode = _filter.accept(detection);
      if (barcode == null) continue;
      _detected = barcode;
      _setPhase(ScanPhase.detected);
      onDetected(barcode);
      _successTimer = Timer(successDelay, () {
        _successTimer = null;
        if (_disposed || _phase != ScanPhase.detected) return;
        onOpen(barcode);
        // If nothing opened (the screen stayed visible), keep scanning.
        if (_active) _setPhase(ScanPhase.scanning);
      });
      return;
    }
  }

  void _setPhase(ScanPhase phase) {
    if (_disposed) return;
    final previous = _phase;
    _phase = phase;
    if (phase != ScanPhase.detected) _detected = null;
    if (phase == ScanPhase.scanning) {
      if (previous != ScanPhase.scanning) {
        _slowHintTimer?.cancel();
        _slowHintTimer = Timer(slowHintDelay, () {
          _slowHintTimer = null;
          _slowHint = true;
          notifyListeners();
        });
      }
    } else {
      _slowHintTimer?.cancel();
      _slowHintTimer = null;
      _slowHint = false;
    }
    notifyListeners();
  }

  void _cancelTimers() {
    _successTimer?.cancel();
    _successTimer = null;
    _slowHintTimer?.cancel();
    _slowHintTimer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTimers();
    _camera.removeListener(notifyListeners);
    unawaited(_detections.cancel());
    super.dispose();
  }
}
