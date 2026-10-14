import 'dart:async';

import 'package:board_game_collector/core/domain/result.dart';
import 'package:board_game_collector/features/scanner/data/permission_handler_camera_permissions.dart';
import 'package:board_game_collector/features/scanner/domain/barcode.dart';
import 'package:board_game_collector/features/scanner/domain/barcode_detection.dart';
import 'package:board_game_collector/features/scanner/domain/camera_permission.dart';
import 'package:board_game_collector/features/scanner/presentation/scanner_camera.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
// Riverpod 3 exports Override from misc.dart.
import 'package:flutter_riverpod/misc.dart' show Override;

/// Key of the fake camera preview, a neutral box (scanner.md section 8:
/// goldens replace the camera preview with a placeholder).
const Key fakePreviewKey = Key('fake-camera-preview');

/// A [ScannerCamera] for widget tests (T-030): no plugin, no platform
/// channel. Tests drive it with [emit], [startResult], and [hasTorch], and
/// read [startCount], [stopCount], [running], and [torchOn].
class FakeScannerCamera extends ChangeNotifier implements ScannerCamera {
  FakeScannerCamera({
    this.hasTorch = true,
    this.startResult = CameraStartResult.started,
  });

  /// Whether the device has a torch.
  bool hasTorch;

  /// What the next [start] returns.
  CameraStartResult startResult;

  /// When set, [start] waits for it (a camera that is slow to start).
  Completer<void>? startGate;

  final StreamController<List<BarcodeDetection>> _detections =
      StreamController.broadcast(sync: true);

  int startCount = 0;
  int stopCount = 0;
  int toggleCount = 0;
  bool running = false;
  bool torchOn = false;
  bool disposed = false;

  /// How many previews are in the tree.
  int previewsBuilt = 0;

  @override
  TorchStatus get torch => !running || !hasTorch
      ? TorchStatus.unavailable
      : torchOn
      ? TorchStatus.on
      : TorchStatus.off;

  @override
  Stream<List<BarcodeDetection>> get detections => _detections.stream;

  /// Sends one camera frame with [detections].
  void emitAll(List<BarcodeDetection> detections) =>
      _detections.add(detections);

  /// Sends one camera frame with one code of [format] (null: a symbology
  /// the app does not accept, such as QR, UPC-E, or Code 128).
  void emit(String rawValue, {BarcodeFormat? format = BarcodeFormat.ean13}) =>
      emitAll([BarcodeDetection(rawValue: rawValue, format: format)]);

  @override
  Future<CameraStartResult> start() async {
    startCount++;
    final gate = startGate;
    if (gate != null) await gate.future;
    running = startResult == CameraStartResult.started;
    notifyListeners();
    return startResult;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    if (!running) return;
    running = false;
    torchOn = false;
    notifyListeners();
  }

  @override
  Future<void> toggleTorch() async {
    toggleCount++;
    if (!running || !hasTorch) return;
    torchOn = !torchOn;
    notifyListeners();
  }

  @override
  Widget buildPreview({required Key key}) => KeyedSubtree(
    key: key,
    child: Builder(
      builder: (context) => ColoredBox(
        key: fakePreviewKey,
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
    ),
  );

  @override
  void dispose() {
    disposed = true;
    unawaited(_detections.close());
    super.dispose();
  }
}

/// A [CameraPermissionRepository] for widget tests. [current] is what
/// [status] returns; [answer] is what the user picks in the system prompt
/// (null keeps the prompt open until [completeRequest]).
class FakeCameraPermissions implements CameraPermissionRepository {
  FakeCameraPermissions({
    this.current = CameraPermission.granted,
    this.answer = CameraPermission.granted,
    this.statusFails = false,
  });

  CameraPermission current;
  CameraPermission? answer;
  bool statusFails;

  /// Runs at each [status] call, after [statusCount] went up and before
  /// [current] is read.
  void Function()? onStatus;

  int statusCount = 0;
  int requestCount = 0;
  int openSettingsCount = 0;

  Completer<CameraPermission>? _pending;

  /// Answers an open prompt (when [answer] was null).
  void completeRequest(CameraPermission result) {
    current = result;
    _pending?.complete(result);
    _pending = null;
  }

  @override
  Future<Result<CameraPermission>> status() async {
    statusCount++;
    onStatus?.call();
    if (statusFails) return const Err(UnexpectedFailure());
    return Ok(current);
  }

  @override
  Future<Result<CameraPermission>> request() async {
    requestCount++;
    final answer = this.answer;
    if (answer == null) {
      final pending = _pending = Completer<CameraPermission>();
      return Ok(await pending.future);
    }
    current = answer;
    return Ok(answer);
  }

  @override
  Future<Result<bool>> openSettings() async {
    openSettingsCount++;
    return const Ok(true);
  }
}

/// The fakes one test uses. Each widget test gets new ones from
/// [scannerOverrides], so nothing leaks between tests.
class ScannerFakes {
  ScannerFakes({FakeCameraPermissions? permissions, FakeScannerCamera? camera})
    : permissions = permissions ?? FakeCameraPermissions(),
      camera = camera ?? FakeScannerCamera();

  final FakeCameraPermissions permissions;

  /// The camera the next scanner screen gets. Every scanner screen gets
  /// this same instance.
  final FakeScannerCamera camera;

  /// Provider overrides that put these fakes in the app.
  List<Override> get overrides => [
    cameraPermissionRepositoryProvider.overrideWithValue(permissions),
    scannerCameraFactoryProvider.overrideWithValue(() => camera),
    // The scanner's debounce window follows fake time (T-030 AC6).
    scanStopwatchFactoryProvider.overrideWithValue(clock.stopwatch),
  ];
}
