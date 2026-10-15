// T-030 QA round 1: scanner edge cases with the fake camera and the fake
// permission service. Whole-app tests use ScannerFakes through pumpApp.
import 'dart:async';

import 'package:board_game_collector/features/scanner/data/permission_handler_camera_permissions.dart';
import 'package:board_game_collector/features/scanner/domain/barcode.dart';
import 'package:board_game_collector/features/scanner/domain/barcode_detection.dart';
import 'package:board_game_collector/features/scanner/domain/camera_permission.dart';
import 'package:board_game_collector/features/scanner/presentation/lookup_result_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/manual_entry_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/scan_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/scan_session.dart';
import 'package:board_game_collector/features/scanner/presentation/scanner_camera.dart';
import 'package:board_game_collector/features/scanner/presentation/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import '../helpers/fake_scanner.dart';
import '../helpers/pump_app.dart';

const _ean13 = '4006381333931';

ScanPhase _phase(WidgetTester tester) => tester
    .widgetList<ListenableBuilder>(find.byType(ListenableBuilder))
    .map((w) => w.listenable)
    .whereType<ScanSession>()
    .single
    .phase;

ScannerFakes _fakes({
  CameraPermission current = CameraPermission.granted,
  CameraPermission? answer = CameraPermission.granted,
  bool hasTorch = true,
  CameraStartResult start = CameraStartResult.started,
  bool statusFails = false,
}) => ScannerFakes(
  permissions: FakeCameraPermissions(
    current: current,
    answer: answer,
    statusFails: statusFails,
  ),
  camera: FakeScannerCamera(hasTorch: hasTorch, startResult: start),
);

Future<ScannerFakes> _open(
  WidgetTester tester, {
  ScannerFakes? scanner,
  Size size = WindowSizes.compact,
  double textScale = 1,
}) async {
  final fakes = await pumpApp(
    tester,
    scanner: scanner,
    size: size,
    textScale: textScale,
  );
  await tester.pumpAndSettle();
  return fakes;
}

Future<void> _lifecycle(
  WidgetTester tester,
  List<AppLifecycleState> states,
) async {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

const _toBackground = [
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
];
const _toForeground = [
  AppLifecycleState.hidden,
  AppLifecycleState.inactive,
  AppLifecycleState.resumed,
];

Future<void> _scan(WidgetTester tester, ScannerFakes fakes, String code) async {
  fakes.camera.emit(code);
  await tester.pump();
  await tester.pump(ScanSession.successDelay);
  await tester.pumpAndSettle();
}

int _results() =>
    find.byType(LookupResultScreen, skipOffstage: false).evaluate().length;

void main() {
  group('permission_handler status mapping', () {
    final expected = <PermissionStatus, CameraPermission>{
      PermissionStatus.granted: CameraPermission.granted,
      PermissionStatus.limited: CameraPermission.granted,
      PermissionStatus.provisional: CameraPermission.granted,
      PermissionStatus.denied: CameraPermission.denied,
      PermissionStatus.permanentlyDenied: CameraPermission.permanentlyDenied,
      PermissionStatus.restricted: CameraPermission.restricted,
    };
    test('every PermissionStatus value is mapped', () {
      expect(expected.keys.toSet(), PermissionStatus.values.toSet());
      for (final entry in expected.entries) {
        expect(
          PermissionHandlerCameraPermissions.mapStatus(entry.key),
          entry.value,
          reason: '${entry.key}',
        );
      }
    });
  });

  group('permission states and transitions', () {
    testWidgets('not asked yet (denied, never prompted): asks once, answer '
        'permanently denied shows the blocked panel', (tester) async {
      final fakes = _fakes(
        current: CameraPermission.denied,
        answer: CameraPermission.permanentlyDenied,
      );
      await _open(tester, scanner: fakes);
      expect(fakes.permissions.requestCount, 1);
      expect(_phase(tester), ScanPhase.permanentlyDenied);
      expect(fakes.camera.startCount, 0);
    });

    testWidgets('prompt answered restricted shows the restricted panel with '
        'no settings button', (tester) async {
      final fakes = _fakes(
        current: CameraPermission.denied,
        answer: CameraPermission.restricted,
      );
      await _open(tester, scanner: fakes);
      expect(_phase(tester), ScanPhase.restricted);
      expect(find.text('Open settings'), findsNothing);
      expect(find.text('Allow camera'), findsNothing);
      expect(fakes.camera.startCount, 0);
    });

    testWidgets('restricted at start never prompts', (tester) async {
      final fakes = _fakes(current: CameraPermission.restricted);
      await _open(tester, scanner: fakes);
      expect(fakes.permissions.requestCount, 0);
      expect(_phase(tester), ScanPhase.restricted);
    });

    testWidgets('permanently denied at start never prompts and shows Open '
        'settings', (tester) async {
      final fakes = _fakes(current: CameraPermission.permanentlyDenied);
      await _open(tester, scanner: fakes);
      expect(fakes.permissions.requestCount, 0);
      expect(find.text('Open settings'), findsOne);
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(fakes.permissions.openSettingsCount, 1);
    });

    testWidgets('settings: denied to granted starts the camera on return', (
      tester,
    ) async {
      final fakes = _fakes(current: CameraPermission.permanentlyDenied);
      await _open(tester, scanner: fakes);
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      // The app goes to settings and the user turns the camera on.
      await _lifecycle(tester, _toBackground);
      fakes.permissions.current = CameraPermission.granted;
      await _lifecycle(tester, _toForeground);
      expect(_phase(tester), ScanPhase.scanning);
      expect(fakes.camera.running, isTrue);
      expect(fakes.permissions.requestCount, 0);
    });

    testWidgets('settings: granted to revoked while away shows the blocked '
        'panel and the camera stays off', (tester) async {
      final fakes = await _open(tester);
      expect(_phase(tester), ScanPhase.scanning);
      await _lifecycle(tester, _toBackground);
      expect(fakes.camera.running, isFalse);
      fakes.permissions.current = CameraPermission.permanentlyDenied;
      await _lifecycle(tester, _toForeground);
      expect(_phase(tester), ScanPhase.permanentlyDenied);
      expect(fakes.camera.running, isFalse);
      expect(fakes.permissions.requestCount, 0);
    });

    testWidgets('revoked while away as plain denied after the prompt was '
        'shown: denied panel, no second prompt', (tester) async {
      final fakes = _fakes(
        current: CameraPermission.denied,
        answer: CameraPermission.granted,
      );
      await _open(tester, scanner: fakes);
      expect(fakes.permissions.requestCount, 1);
      await _lifecycle(tester, _toBackground);
      fakes.permissions.current = CameraPermission.denied;
      await _lifecycle(tester, _toForeground);
      expect(fakes.permissions.requestCount, 1);
      expect(_phase(tester), ScanPhase.denied);
    });

    testWidgets('Allow camera answered granted starts the camera', (
      tester,
    ) async {
      final fakes = _fakes(
        current: CameraPermission.denied,
        answer: CameraPermission.denied,
      );
      await _open(tester, scanner: fakes);
      expect(_phase(tester), ScanPhase.denied);
      fakes.permissions.answer = CameraPermission.granted;
      await tester.tap(find.text('Allow camera'));
      await tester.pumpAndSettle();
      expect(_phase(tester), ScanPhase.scanning);
      expect(fakes.permissions.requestCount, 2);
    });

    testWidgets('a permission check that fails shows camera not available '
        'and Retry recovers', (tester) async {
      final fakes = _fakes(statusFails: true);
      await _open(tester, scanner: fakes);
      expect(_phase(tester), ScanPhase.unavailable);
      expect(find.text('Camera not available'), findsOne);
      fakes.permissions.statusFails = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(_phase(tester), ScanPhase.scanning);
    });

    testWidgets('a camera that fails to start shows camera not available, '
        'manual entry stays one tap away', (tester) async {
      final fakes = _fakes(start: CameraStartResult.failed);
      await _open(tester, scanner: fakes);
      expect(_phase(tester), ScanPhase.unavailable);
      await tester.tap(find.widgetWithText(FilledButton, 'Enter barcode'));
      await tester.pumpAndSettle();
      expect(find.byType(ManualEntryScreen), findsOne);
    });

    testWidgets('the camera reports permission denied at start (revoked in '
        'between): the matching panel shows', (tester) async {
      final fakes = _fakes(start: CameraStartResult.permissionDenied);
      await _open(tester, scanner: fakes);
      // The fake still reports granted, so the panel is the plain one.
      expect(_phase(tester), anyOf(ScanPhase.denied, ScanPhase.unavailable));
      expect(fakes.camera.running, isFalse);
    });

    testWidgets('the app is paused while the system prompt is open: the '
        'answer applies after resume', (tester) async {
      final fakes = _fakes(current: CameraPermission.denied, answer: null);
      await _open(tester, scanner: fakes);
      expect(_phase(tester), ScanPhase.requesting);
      await _lifecycle(tester, _toBackground);
      fakes.permissions.completeRequest(CameraPermission.granted);
      await tester.pumpAndSettle();
      expect(fakes.camera.running, isFalse, reason: 'app in background');
      await _lifecycle(tester, _toForeground);
      expect(_phase(tester), ScanPhase.scanning);
      expect(fakes.camera.running, isTrue);
      expect(fakes.permissions.requestCount, 1);
    });

    testWidgets('leaving Scan while the prompt is open does not start the '
        'camera behind the other tab', (tester) async {
      final fakes = _fakes(current: CameraPermission.denied, answer: null);
      await _open(tester, scanner: fakes);
      await tapDestination(tester, 'Search');
      fakes.permissions.completeRequest(CameraPermission.granted);
      await tester.pumpAndSettle();
      expect(fakes.camera.running, isFalse);
      await tapDestination(tester, 'Scan');
      expect(fakes.camera.running, isTrue);
    });
  });

  group('lifecycle and tabs', () {
    testWidgets('twenty quick pause and resume cycles end with the camera '
        'running and no extra prompt', (tester) async {
      final fakes = await _open(tester);
      for (var i = 0; i < 20; i++) {
        await _lifecycle(tester, _toBackground);
        await _lifecycle(tester, _toForeground);
      }
      expect(fakes.camera.running, isTrue);
      expect(fakes.permissions.requestCount, 0);
      expect(_phase(tester), ScanPhase.scanning);
    });

    testWidgets('resume and background without pumping between them settle '
        'on the last state', (tester) async {
      final fakes = await _open(tester);
      for (final s in [..._toBackground, ..._toForeground, ..._toBackground]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pumpAndSettle();
      expect(fakes.camera.running, isFalse);
      await _lifecycle(tester, _toForeground);
      expect(fakes.camera.running, isTrue);
    });

    testWidgets('ten tab round trips: start and stop counts stay in step', (
      tester,
    ) async {
      final fakes = await _open(tester);
      for (var i = 0; i < 10; i++) {
        await tapDestination(tester, 'Collection');
        expect(fakes.camera.running, isFalse, reason: 'cycle $i away');
        await tapDestination(tester, 'Scan');
        expect(fakes.camera.running, isTrue, reason: 'cycle $i back');
      }
      expect(fakes.camera.startCount, 11);
    });

    testWidgets('background on another tab, resume on another tab: the camera '
        'stays off', (tester) async {
      final fakes = await _open(tester);
      await tapDestination(tester, 'Settings');
      await _lifecycle(tester, _toBackground);
      await _lifecycle(tester, _toForeground);
      expect(fakes.camera.running, isFalse);
      await tapDestination(tester, 'Scan');
      expect(fakes.camera.running, isTrue);
    });

    testWidgets('background while a lookup result is open, Back after resume '
        'restarts the camera', (tester) async {
      final fakes = await _open(tester);
      await _scan(tester, fakes, _ean13);
      expect(find.byType(LookupResultScreen), findsOne);
      expect(fakes.camera.running, isFalse);
      await _lifecycle(tester, _toBackground);
      await _lifecycle(tester, _toForeground);
      expect(fakes.camera.running, isFalse, reason: 'result still on top');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(fakes.camera.running, isTrue);
    });

    testWidgets('rotation with the camera running keeps one camera and does '
        'not restart it', (tester) async {
      final fakes = await _open(tester);
      final starts = fakes.camera.startCount;
      setTestWindow(tester, size: WindowSizes.landscape);
      await tester.pumpAndSettle();
      setTestWindow(tester);
      await tester.pumpAndSettle();
      expect(fakes.camera.running, isTrue);
      expect(fakes.camera.startCount, starts);
      expect(tester.takeException(), isNull);
    });
  });

  group('detections', () {
    final ignored = <String, (String, BarcodeFormat?)>{
      'empty string': ('', BarcodeFormat.ean13),
      'whitespace': ('   ', BarcodeFormat.ean13),
      'short digits': ('1234567', BarcodeFormat.ean8),
      'nine digits': ('123456789', BarcodeFormat.ean13),
      'ten digits': ('1234567890', BarcodeFormat.ean13),
      'fourteen digits (GTIN-14)': ('14006381333938', BarcodeFormat.ean13),
      'non-numeric EAN-13': ('40063813339AB', BarcodeFormat.ean13),
      'letters': ('ABCDEFGHIJKLM', BarcodeFormat.ean13),
      'full-width digits': ('４００６３８１３３３９３１', BarcodeFormat.ean13),
      'Arabic-Indic digits': ('٤٠٠٦٣٨١٣٣٣٩٣١', BarcodeFormat.ean13),
      'a 10,000 character string': ('9' * 10000, BarcodeFormat.ean13),
      'bad check digit EAN-13': ('4006381333932', BarcodeFormat.ean13),
      'bad check digit EAN-8': ('96385075', BarcodeFormat.ean8),
      'UPC-E (null format) with EAN-8 digits': ('96385074', null),
      'UPC-E (null format) with UPC-A digits': ('036000291452', null),
      'UPC-E short form 0123456': ('0123456', null),
      'UPC-E 8 digits 01234565': ('01234565', null),
      'QR code with a valid number inside': (_ean13, null),
    };
    for (final MapEntry(key: name, value: (raw, format)) in ignored.entries) {
      testWidgets('$name does nothing', (tester) async {
        final fakes = await _open(tester);
        tester.takeAnnouncements();
        fakes.camera.emit(raw, format: format);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.byType(LookupResultScreen), findsNothing);
        expect(find.byIcon(Icons.check), findsNothing);
        expect(tester.takeAnnouncements(), isEmpty);
        expect(_phase(tester), ScanPhase.scanning);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('surrounding whitespace on a valid code is accepted or '
        'ignored, never a crash', (tester) async {
      final fakes = await _open(tester);
      fakes.camera.emit(' $_ean13 ');
      await tester.pump();
      await tester.pump(ScanSession.successDelay);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_results(), lessThanOrEqualTo(1));
    });

    testWidgets('an ignored code does not start the 2 s window for the same '
        'code later', (tester) async {
      final fakes = await _open(tester);
      fakes.camera.emit(_ean13, format: null);
      await tester.pump(const Duration(milliseconds: 100));
      await _scan(tester, fakes, _ean13);
      expect(find.byType(LookupResultScreen), findsOne);
    });

    testWidgets('the same code twice back to back opens one lookup', (
      tester,
    ) async {
      final fakes = await _open(tester);
      fakes.camera.emit(_ean13);
      fakes.camera.emit(_ean13);
      await tester.pump();
      await tester.pump(ScanSession.successDelay);
      await tester.pumpAndSettle();
      expect(_results(), 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_results(), 0);
    });

    testWidgets('two different valid codes in one frame open one lookup, the '
        'first', (tester) async {
      final fakes = await _open(tester);
      fakes.camera.emitAll(const [
        BarcodeDetection(rawValue: _ean13, format: BarcodeFormat.ean13),
        BarcodeDetection(rawValue: '96385074', format: BarcodeFormat.ean8),
      ]);
      await tester.pump();
      await tester.pump(ScanSession.successDelay);
      await tester.pumpAndSettle();
      expect(_results(), 1);
      expect(
        tester
            .widget<LookupResultScreen>(find.byType(LookupResultScreen))
            .barcode
            .digits,
        _ean13,
      );
    });

    testWidgets('a different code detected during the 300 ms success step is '
        'dropped', (tester) async {
      final fakes = await _open(tester);
      fakes.camera.emit(_ean13);
      await tester.pump(const Duration(milliseconds: 100));
      fakes.camera.emit('96385074', format: BarcodeFormat.ean8);
      await tester.pump(ScanSession.successDelay);
      await tester.pumpAndSettle();
      expect(_results(), 1);
      expect(
        tester
            .widget<LookupResultScreen>(find.byType(LookupResultScreen))
            .barcode
            .digits,
        _ean13,
      );
    });

    testWidgets('a different code right after the lookup opened (route not '
        'yet current) still gives one lookup result', (tester) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final fakes = await _open(tester);
      tester.takeAnnouncements();
      fakes.camera.emit(_ean13);
      await tester.pump();
      await tester.pump(ScanSession.successDelay);
      // The push is started; emit another valid code before the next frame
      // settles the route change.
      fakes.camera.emit('96385074', format: BarcodeFormat.ean8);
      fakes.camera.emit('036000291452', format: BarcodeFormat.upcA);
      await tester.pumpAndSettle();
      expect(_results(), 1);
      // Only the first code got feedback (round 2: the session stays in
      // the detected state until the screen is covered).
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      expect(tester.takeAnnouncements(), hasLength(1));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_results(), 0);
    });

    testWidgets('detections while the lookup result is open are ignored', (
      tester,
    ) async {
      final fakes = await _open(tester);
      await _scan(tester, fakes, _ean13);
      fakes.camera.emit('96385074', format: BarcodeFormat.ean8);
      await tester.pumpAndSettle();
      expect(_results(), 1);
    });

    testWidgets('detections while the camera is still starting are ignored', (
      tester,
    ) async {
      final fakes = _fakes();
      fakes.camera.startGate = Completer<void>();
      await pumpApp(tester, scanner: fakes);
      await tester.pump();
      await tester.pump();
      fakes.camera.emit(_ean13);
      await tester.pump(ScanSession.successDelay);
      await tester.pump();
      expect(find.byType(LookupResultScreen), findsNothing);
      fakes.camera.startGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LookupResultScreen), findsNothing);
      expect(_phase(tester), ScanPhase.scanning);
    });

    testWidgets('a detection after the user left Scan is ignored', (
      tester,
    ) async {
      final fakes = await _open(tester);
      await tapDestination(tester, 'Search');
      fakes.camera.emit(_ean13);
      await tester.pump(ScanSession.successDelay);
      await tester.pumpAndSettle();
      expect(find.byType(LookupResultScreen), findsNothing);
      expect(find.byType(SearchScreen), findsOne);
    });

    testWidgets('a detection while in the denied state is ignored', (
      tester,
    ) async {
      final fakes = _fakes(current: CameraPermission.permanentlyDenied);
      await _open(tester, scanner: fakes);
      fakes.camera.emit(_ean13);
      await tester.pump(ScanSession.successDelay);
      await tester.pumpAndSettle();
      expect(find.byType(LookupResultScreen), findsNothing);
    });

    testWidgets('after Back the same code works again, and a different code '
        'works immediately', (tester) async {
      final fakes = await _open(tester);
      await _scan(tester, fakes, _ean13);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _scan(tester, fakes, '96385074');
      expect(_results(), 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _scan(tester, fakes, '96385074');
      expect(_results(), 1);
    });

    testWidgets('Back from the lookup result with the camera restarting does '
        'not open a second result from a stale detection', (tester) async {
      final fakes = await _open(tester);
      await _scan(tester, fakes, _ean13);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(_results(), 0);
    });
  });

  group('torch', () {
    testWidgets('no torch: no toggle, and tapping nothing breaks', (
      tester,
    ) async {
      final fakes = _fakes(hasTorch: false);
      await _open(tester, scanner: fakes);
      expect(find.byTooltip('Turn torch on'), findsNothing);
      expect(find.byTooltip('Turn torch off'), findsNothing);
      expect(fakes.camera.toggleCount, 0);
    });

    testWidgets('a torch that appears only after the camera started (hasTorch '
        'false then true) shows once running', (tester) async {
      final fakes = _fakes(hasTorch: false);
      await _open(tester, scanner: fakes);
      expect(find.byTooltip('Turn torch on'), findsNothing);
      fakes.camera.hasTorch = true;
      fakes.camera.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Turn torch on'), findsOne);
    });

    testWidgets('rapid double tap toggles twice and ends off', (tester) async {
      final fakes = await _open(tester);
      final toggle = find.byTooltip('Turn torch on');
      await tester.tap(toggle);
      await tester.pump();
      await tester.tap(find.byTooltip('Turn torch off'));
      await tester.pumpAndSettle();
      expect(fakes.camera.toggleCount, 2);
      expect(fakes.camera.torchOn, isFalse);
      expect(find.byTooltip('Turn torch on'), findsOne);
    });

    testWidgets('torch on, switch tab and back: the torch is off after the '
        'restart and the toggle says so', (tester) async {
      final fakes = await _open(tester);
      await tester.tap(find.byTooltip('Turn torch on'));
      await tester.pumpAndSettle();
      expect(fakes.camera.torchOn, isTrue);
      await tapDestination(tester, 'Search');
      await tapDestination(tester, 'Scan');
      expect(fakes.camera.torchOn, isFalse);
      expect(find.byTooltip('Turn torch on'), findsOne);
    });

    testWidgets('torch on, background and foreground: the torch is off and '
        'the toggle matches', (tester) async {
      final fakes = await _open(tester);
      await tester.tap(find.byTooltip('Turn torch on'));
      await tester.pumpAndSettle();
      await _lifecycle(tester, _toBackground);
      await _lifecycle(tester, _toForeground);
      expect(fakes.camera.torchOn, isFalse);
      expect(find.byTooltip('Turn torch on'), findsOne);
    });

    testWidgets('no toggle on the denied panel', (tester) async {
      final fakes = _fakes(current: CameraPermission.permanentlyDenied);
      await _open(tester, scanner: fakes);
      expect(find.byTooltip('Turn torch on'), findsNothing);
      expect(fakes.camera.toggleCount, 0);
    });
  });

  group('destination announcement exactly once', () {
    testWidgets('each tab change announces its title once, in both layouts', (
      tester,
    ) async {
      for (final size in [WindowSizes.compact, WindowSizes.expanded]) {
        await _open(tester, size: size);
        tester.takeAnnouncements();
        for (final entry in {
          'Search': 'Search',
          'Collection': 'Collection',
          'Settings': 'Settings',
          'Scan': 'Scan a barcode',
        }.entries) {
          await tapDestination(tester, entry.key);
          final announced = tester.takeAnnouncements();
          expect(announced, hasLength(1), reason: '${entry.key} at $size');
          expect(
            announced.single,
            isAccessibilityAnnouncement(
              entry.value,
              assertiveness: Assertiveness.polite,
              textDirection: TextDirection.ltr,
            ),
          );
        }
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('re-tapping the selected tab, rotation, resize, pause and '
        'resume announce nothing', (tester) async {
      await _open(tester);
      tester.takeAnnouncements();
      await tapDestination(tester, 'Scan');
      setTestWindow(tester, size: WindowSizes.expanded);
      await tester.pumpAndSettle();
      setTestWindow(tester);
      await tester.pumpAndSettle();
      await _lifecycle(tester, _toBackground);
      await _lifecycle(tester, _toForeground);
      expect(tester.takeAnnouncements(), isEmpty);
    });

    testWidgets('a valid scan announces the success text but no destination '
        'title (the lookup is pushed inside Scan)', (tester) async {
      final fakes = await _open(tester);
      tester.takeAnnouncements();
      await _scan(tester, fakes, _ean13);
      final announced = tester.takeAnnouncements();
      expect(announced, hasLength(1));
      expect(
        announced.single,
        isAccessibilityAnnouncement(
          'Barcode $_ean13 read. Looking up the game.',
          assertiveness: Assertiveness.polite,
          textDirection: TextDirection.ltr,
        ),
      );
    });

    testWidgets('Search by title announces Search once', (tester) async {
      await _open(tester);
      tester.takeAnnouncements();
      await tester.tap(find.widgetWithText(FilledButton, 'Search by title'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOne);
      expect(tester.takeAnnouncements(), hasLength(1));
    });
  });

  group('large text, landscape, and semantics', () {
    testWidgets('at 2.0 on compact the actions stack and both are in view', (
      tester,
    ) async {
      await _open(tester, textScale: 2);
      final manual = tester.getRect(
        find.widgetWithText(FilledButton, 'Enter barcode'),
      );
      final search = tester.getRect(
        find.widgetWithText(FilledButton, 'Search by title'),
      );
      debugPrint('STACK compact 2.0: manual $manual search $search');
      expect(search.top, greaterThanOrEqualTo(manual.bottom));
      expect(manual.height, greaterThanOrEqualTo(48));
      expect(search.height, greaterThanOrEqualTo(48));
      expect(search.bottom, lessThanOrEqualTo(WindowSizes.compact.height));
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('phone landscape at $scale: actions and hint are visible and '
          'at least 48 dp, record positions', (tester) async {
        await _open(tester, size: WindowSizes.landscape, textScale: scale);
        final manual = tester.getRect(
          find.widgetWithText(FilledButton, 'Enter barcode'),
        );
        final search = tester.getRect(
          find.widgetWithText(FilledButton, 'Search by title'),
        );
        debugPrint(
          'LANDSCAPE $scale: manual $manual search $search window '
          '${WindowSizes.landscape}',
        );
        for (final r in [manual, search]) {
          expect(r.height, greaterThanOrEqualTo(48));
          expect(r.bottom, lessThanOrEqualTo(WindowSizes.landscape.height));
          expect(r.top, greaterThanOrEqualTo(0));
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('semantics: viewfinder label, torch label, and both action '
        'labels exist', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await _open(tester);
        expect(
          find.semantics.byLabel('Camera view. Barcode scanning is active.'),
          findsOneWidget,
        );
        expect(find.semantics.byLabel('Turn torch on'), findsOneWidget);
        expect(find.semantics.byLabel('Enter barcode'), findsWidgets);
        expect(find.semantics.byLabel('Search by title'), findsWidgets);
        await tester.tap(find.byTooltip('Turn torch on'));
        await tester.pumpAndSettle();
        expect(find.semantics.byLabel('Turn torch off'), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('semantics: a panel state has a heading title and the '
        'actions stay', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final fakes = _fakes(current: CameraPermission.permanentlyDenied);
        await _open(tester, scanner: fakes);
        final title = find.semantics
            .byLabel('Camera access is blocked')
            .evaluate()
            .single;
        expect(title.flagsCollection.isHeader, isTrue);
        expect(find.semantics.byLabel('Open settings'), findsWidgets);
        expect(find.semantics.byLabel('Enter barcode'), findsWidgets);
        expect(
          find.semantics.byLabel('Camera view. Barcode scanning is active.'),
          findsNothing,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('every state at 2.0 landscape: actions reachable by tap', (
      tester,
    ) async {
      final states = <String, ScannerFakes Function()>{
        'denied': () => _fakes(
          current: CameraPermission.denied,
          answer: CameraPermission.denied,
        ),
        'blocked': () => _fakes(current: CameraPermission.permanentlyDenied),
        'restricted': () => _fakes(current: CameraPermission.restricted),
        'unavailable': () => _fakes(start: CameraStartResult.failed),
      };
      for (final entry in states.entries) {
        await _open(
          tester,
          scanner: entry.value(),
          size: WindowSizes.landscape,
          textScale: 2,
        );
        final button = find.widgetWithText(FilledButton, 'Enter barcode');
        expect(button, findsOne, reason: entry.key);
        await tester.tap(button, warnIfMissed: true);
        await tester.pumpAndSettle();
        expect(find.byType(ManualEntryScreen), findsOne, reason: entry.key);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
    });
  });

  group('whole-app wiring', () {
    testWidgets('the Scan screen is the first screen and uses the fake '
        'camera', (tester) async {
      final fakes = await _open(tester);
      expect(find.byType(ScanScreen), findsOne);
      expect(fakes.camera.startCount, 1);
      expect(find.byKey(fakePreviewKey), findsOne);
    });

    testWidgets('two apps in one test file do not share fakes', (tester) async {
      final a = await _open(tester);
      await _scan(tester, a, _ean13);
      await tester.pumpWidget(const SizedBox());
      final b = await _open(tester);
      expect(identical(a, b), isFalse);
      expect(find.byType(LookupResultScreen), findsNothing);
    });
  });
}
