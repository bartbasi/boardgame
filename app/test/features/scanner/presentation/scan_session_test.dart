// T-030 round 2: the scan session on its own, with fake time (review R1-M1
// and R1-S2).
import 'package:board_game_collector/features/scanner/domain/barcode.dart';
import 'package:board_game_collector/features/scanner/domain/camera_permission.dart';
import 'package:board_game_collector/features/scanner/domain/scan_filter.dart';
import 'package:board_game_collector/features/scanner/presentation/scan_session.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_scanner.dart';

class _Harness {
  _Harness({FakeCameraPermissions? permissions, this.opens = true})
    : permissions = permissions ?? FakeCameraPermissions() {
    session = ScanSession(
      permissions: this.permissions,
      camera: camera,
      filter: ScanFilter(stopwatch: clock.stopwatch),
      promptShown: () => _promptShown,
      markPromptShown: () => _promptShown = true,
      onDetected: detected.add,
      onOpen: (barcode) {
        opened.add(barcode);
        return opens;
      },
    );
  }

  final FakeCameraPermissions permissions;
  final FakeScannerCamera camera = FakeScannerCamera();
  late final ScanSession session;
  bool _promptShown = false;

  /// What onOpen answers: whether the lookup started opening.
  bool opens;
  final List<Barcode> detected = [];
  final List<Barcode> opened = [];
}

void main() {
  group('R1-M1 the prompt only for a user who was never asked', () {
    test('never asked: the session asks', () {
      fakeAsync((async) {
        final h = _Harness(
          permissions: FakeCameraPermissions(current: CameraPermission.denied),
        );
        h.session.setActive(true);
        async.flushMicrotasks();
        expect(h.permissions.wasDeniedBeforeCount, 1);
        expect(h.permissions.requestCount, 1);
        expect(h.session.phase, ScanPhase.scanning);
        h.session.dispose();
      });
    });

    test('denied in an earlier run: Denied panel, no prompt', () {
      fakeAsync((async) {
        final h = _Harness(
          permissions: FakeCameraPermissions(
            current: CameraPermission.denied,
            deniedBefore: true,
          ),
        );
        h.session.setActive(true);
        async.flushMicrotasks();
        expect(h.permissions.requestCount, 0);
        expect(h.session.phase, ScanPhase.denied);

        // "Allow camera" still asks.
        h.session.allowCamera();
        async.flushMicrotasks();
        expect(h.permissions.requestCount, 1);
        expect(h.session.phase, ScanPhase.scanning);
        h.session.dispose();
      });
    });

    test('an unknown answer counts as asked: no prompt', () {
      fakeAsync((async) {
        final h = _Harness(
          permissions: FakeCameraPermissions(current: CameraPermission.denied)
            ..deniedBeforeFails = true,
        );
        h.session.setActive(true);
        async.flushMicrotasks();
        expect(h.permissions.requestCount, 0);
        expect(h.session.phase, ScanPhase.denied);
        h.session.dispose();
      });
    });

    test('a granted or blocked permission does not ask the platform', () {
      fakeAsync((async) {
        for (final current in [
          CameraPermission.granted,
          CameraPermission.permanentlyDenied,
          CameraPermission.restricted,
        ]) {
          final h = _Harness(
            permissions: FakeCameraPermissions(current: current),
          );
          h.session.setActive(true);
          async.flushMicrotasks();
          expect(h.permissions.wasDeniedBeforeCount, 0, reason: current.name);
          h.session.dispose();
        }
      });
    });
  });

  group('R1-S2 after the lookup opens, no further detections', () {
    test('a different code before the screen hides gets no feedback', () {
      fakeAsync((async) {
        final h = _Harness();
        h.session.setActive(true);
        async.flushMicrotasks();
        expect(h.session.phase, ScanPhase.scanning);

        h.camera.emit('4006381333931');
        async.elapse(ScanSession.successDelay);
        expect(h.opened.map((b) => b.digits), ['4006381333931']);
        expect(h.session.phase, ScanPhase.detected);

        // The lookup is opening, but the screen has not gone inactive yet.
        h.camera.emit('036000291452', format: BarcodeFormat.upcA);
        async.elapse(const Duration(seconds: 1));
        expect(h.detected, hasLength(1));
        expect(h.opened, hasLength(1));

        // The push hides the scanner; coming back scans again.
        h.session.setActive(false);
        async.flushMicrotasks();
        expect(h.session.phase, ScanPhase.starting);
        h.session.setActive(true);
        async.flushMicrotasks();
        expect(h.session.phase, ScanPhase.scanning);
        h.camera.emit('036000291452', format: BarcodeFormat.upcA);
        expect(h.detected, hasLength(2));
        h.session.dispose();
      });
    });

    test('when nothing opened, scanning goes on', () {
      fakeAsync((async) {
        final h = _Harness(opens: false);
        h.session.setActive(true);
        async.flushMicrotasks();
        h.camera.emit('4006381333931');
        async.elapse(ScanSession.successDelay);
        expect(h.opened, hasLength(1));
        expect(h.session.phase, ScanPhase.scanning);
        h.camera.emit('036000291452', format: BarcodeFormat.upcA);
        expect(h.detected, hasLength(2));
        h.session.dispose();
      });
    });
  });
}
