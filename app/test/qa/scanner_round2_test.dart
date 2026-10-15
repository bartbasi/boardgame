// T-030 QA round 2: deniedBefore, the detected-state gap, symbology versus
// digit count, and the manifest. Whole-app tests use ScannerFakes.
import 'dart:io';

import 'package:board_game_collector/features/scanner/domain/barcode.dart';
import 'package:board_game_collector/features/scanner/domain/barcode_detection.dart';
import 'package:board_game_collector/features/scanner/domain/camera_permission.dart';
import 'package:board_game_collector/features/scanner/domain/scan_filter.dart';
import 'package:board_game_collector/features/scanner/presentation/lookup_result_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/manual_entry_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/scan_session.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_scanner.dart';
import '../helpers/pump_app.dart';

const _ean13 = '4006381333931';
const _upcA = '036000291452';
const _ean8 = '96385074';
const _upcAAsEan13 = '0036000291452';

ScanPhase _phase(WidgetTester tester) => tester
    .widgetList<ListenableBuilder>(find.byType(ListenableBuilder))
    .map((w) => w.listenable)
    .whereType<ScanSession>()
    .single
    .phase;

ScannerFakes _fakes({
  CameraPermission current = CameraPermission.granted,
  CameraPermission? answer = CameraPermission.granted,
  bool deniedBefore = false,
  bool deniedBeforeFails = false,
}) {
  final permissions = FakeCameraPermissions(
    current: current,
    answer: answer,
    deniedBefore: deniedBefore,
  )..deniedBeforeFails = deniedBeforeFails;
  return ScannerFakes(permissions: permissions);
}

Future<ScannerFakes> _open(WidgetTester tester, ScannerFakes fakes) async {
  await pumpApp(tester, scanner: fakes);
  await tester.pumpAndSettle();
  return fakes;
}

List<String> _recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
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
  return calls;
}

BarcodeDetection _d(String raw, BarcodeFormat? format) =>
    BarcodeDetection(rawValue: raw, format: format);

void main() {
  group('deniedBefore across every permission state', () {
    // status, deniedBefore answer -> does the session ask by itself?
    final cases = <String, (CameraPermission, bool, bool, bool)>{
      // name: (status, deniedBefore, deniedBeforeFails, asks)
      'denied, never asked': (CameraPermission.denied, false, false, true),
      'denied, denied in an earlier run': (
        CameraPermission.denied,
        true,
        false,
        false,
      ),
      'denied, rationale check fails': (
        CameraPermission.denied,
        false,
        true,
        false,
      ),
      'granted, deniedBefore true': (
        CameraPermission.granted,
        true,
        false,
        false,
      ),
      'granted, rationale fails': (
        CameraPermission.granted,
        false,
        true,
        false,
      ),
      'permanently denied, deniedBefore false': (
        CameraPermission.permanentlyDenied,
        false,
        false,
        false,
      ),
      'restricted, deniedBefore false': (
        CameraPermission.restricted,
        false,
        false,
        false,
      ),
    };
    for (final MapEntry(key: name, value: c) in cases.entries) {
      final (status, before, fails, asks) = c;
      testWidgets('$name: ${asks ? 'asks once' : 'never asks'}', (
        tester,
      ) async {
        final fakes = _fakes(
          current: status,
          answer: CameraPermission.granted,
          deniedBefore: before,
          deniedBeforeFails: fails,
        );
        await _open(tester, fakes);
        expect(fakes.permissions.requestCount, asks ? 1 : 0);
        // The rationale is asked only when the status is denied.
        expect(
          fakes.permissions.wasDeniedBeforeCount,
          status == CameraPermission.denied ? 1 : 0,
        );
        final expectedPhase = asks || status == CameraPermission.granted
            ? ScanPhase.scanning
            : switch (status) {
                CameraPermission.denied => ScanPhase.denied,
                CameraPermission.permanentlyDenied =>
                  ScanPhase.permanentlyDenied,
                CameraPermission.restricted => ScanPhase.restricted,
                CameraPermission.granted => ScanPhase.scanning,
              };
        expect(_phase(tester), expectedPhase);
        expect(fakes.camera.running, expectedPhase == ScanPhase.scanning);
      });
    }

    testWidgets('a second open in the same run does not ask the rationale '
        'again after the prompt was shown', (tester) async {
      final fakes = _fakes(
        current: CameraPermission.denied,
        answer: CameraPermission.denied,
      );
      await _open(tester, fakes);
      expect(fakes.permissions.requestCount, 1);
      final rationaleCalls = fakes.permissions.wasDeniedBeforeCount;
      for (var i = 0; i < 3; i++) {
        await tapDestination(tester, 'Search');
        await tapDestination(tester, 'Scan');
      }
      expect(fakes.permissions.requestCount, 1);
      expect(fakes.permissions.wasDeniedBeforeCount, rationaleCalls);
      expect(_phase(tester), ScanPhase.denied);
    });

    testWidgets('Allow camera still asks after a denial in an earlier run, '
        'and every tap asks again', (tester) async {
      final fakes = _fakes(
        current: CameraPermission.denied,
        answer: CameraPermission.denied,
        deniedBefore: true,
      );
      await _open(tester, fakes);
      expect(fakes.permissions.requestCount, 0);
      for (var i = 1; i <= 3; i++) {
        await tester.tap(find.text('Allow camera'));
        await tester.pumpAndSettle();
        expect(fakes.permissions.requestCount, i);
        expect(_phase(tester), ScanPhase.denied);
      }
      fakes.permissions.answer = CameraPermission.granted;
      await tester.tap(find.text('Allow camera'));
      await tester.pumpAndSettle();
      expect(_phase(tester), ScanPhase.scanning);
    });

    testWidgets('Allow camera answered permanently denied shows the blocked '
        'panel with Open settings', (tester) async {
      final fakes = _fakes(
        current: CameraPermission.denied,
        answer: CameraPermission.permanentlyDenied,
        deniedBefore: true,
      );
      await _open(tester, fakes);
      await tester.tap(find.text('Allow camera'));
      await tester.pumpAndSettle();
      expect(_phase(tester), ScanPhase.permanentlyDenied);
      expect(find.text('Open settings'), findsOne);
    });

    testWidgets('Allow camera tapped twice in one frame asks at most once '
        'per tap and never throws', (tester) async {
      final fakes = _fakes(
        current: CameraPermission.denied,
        answer: CameraPermission.denied,
        deniedBefore: true,
      );
      await _open(tester, fakes);
      await tester.tap(find.text('Allow camera'));
      await tester.tap(find.text('Allow camera'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(fakes.permissions.requestCount, inInclusiveRange(1, 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a rationale answer that changes while the app is away does '
        'not prompt on resume (prompt already shown)', (tester) async {
      final fakes = _fakes(
        current: CameraPermission.denied,
        answer: CameraPermission.denied,
      );
      await _open(tester, fakes);
      expect(fakes.permissions.requestCount, 1);
      fakes.permissions.deniedBefore = false;
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(fakes.permissions.requestCount, 1);
    });

    test('session level: leaving during the rationale check applies the '
        'latest state and never asks while inactive', () {
      fakeAsync((async) {
        final permissions = FakeCameraPermissions(
          current: CameraPermission.denied,
        );
        var shown = false;
        final session = ScanSession(
          permissions: permissions,
          camera: FakeScannerCamera(),
          filter: ScanFilter(stopwatch: clock.stopwatch),
          promptShown: () => shown,
          markPromptShown: () => shown = true,
          onDetected: (_) {},
          onOpen: (_) => true,
        );
        session.setActive(true);
        // Deactivate before the async chain finishes.
        session.setActive(false);
        async.flushMicrotasks();
        expect(permissions.requestCount, 0);
        session.setActive(true);
        async.flushMicrotasks();
        expect(permissions.requestCount, 1);
        session.dispose();
      });
    });
  });

  group('the detected-state gap', () {
    testWidgets('a second code during the success step gets no haptic and no '
        'announcement', (tester) async {
      final haptics = _recordHaptics(tester);
      final fakes = await _open(tester, _fakes());
      tester.takeAnnouncements();
      fakes.camera.emit(_ean13);
      await tester.pump(const Duration(milliseconds: 50));
      fakes.camera.emit(_ean8);
      fakes.camera.emit(_upcA);
      await tester.pump(ScanSession.successDelay);
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      expect(tester.takeAnnouncements(), hasLength(1));
      expect(
        tester
            .widget<LookupResultScreen>(find.byType(LookupResultScreen))
            .barcode
            .digits,
        _ean13,
      );
    });

    testWidgets('codes after the lookup opened get no feedback either, even '
        'before the route change settles', (tester) async {
      final haptics = _recordHaptics(tester);
      final fakes = await _open(tester, _fakes());
      tester.takeAnnouncements();
      fakes.camera.emit(_ean13);
      await tester.pump();
      await tester.pump(ScanSession.successDelay);
      fakes.camera.emit(_ean8);
      fakes.camera.emit(_upcA);
      await tester.pumpAndSettle();
      expect(haptics, hasLength(1));
      expect(tester.takeAnnouncements(), hasLength(1));
      expect(find.byType(LookupResultScreen, skipOffstage: false), findsOne);
    });

    testWidgets('after Back the scanner is scanning again and a new code '
        'gets feedback', (tester) async {
      final haptics = _recordHaptics(tester);
      final fakes = await _open(tester, _fakes());
      fakes.camera.emit(_ean13);
      await tester.pump();
      await tester.pump(ScanSession.successDelay);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_phase(tester), ScanPhase.scanning);
      fakes.camera.emit(_ean8);
      await tester.pump();
      expect(_phase(tester), ScanPhase.detected);
      await tester.pump(ScanSession.successDelay);
      await tester.pumpAndSettle();
      expect(haptics, hasLength(2));
      expect(find.byType(LookupResultScreen, skipOffstage: false), findsOne);
    });

    testWidgets('nothing opened (manual entry was already opening): no '
        'result, no crash, scanning goes on after Back', (tester) async {
      final haptics = _recordHaptics(tester);
      final fakes = await _open(tester, _fakes());
      tester.takeAnnouncements();
      // Tap Enter barcode and, before the frame, a code is read.
      await tester.tap(find.widgetWithText(FilledButton, 'Enter barcode'));
      fakes.camera.emit(_ean13);
      await tester.pump();
      await tester.pump(ScanSession.successDelay);
      await tester.pumpAndSettle();
      expect(find.byType(ManualEntryScreen), findsOne);
      expect(
        find.byType(LookupResultScreen, skipOffstage: false),
        findsNothing,
      );
      debugPrint(
        'RACE haptics $haptics announcements '
        '${tester.takeAnnouncements().length}',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_phase(tester), ScanPhase.scanning);
      fakes.camera.emit(_ean13);
      await tester.pump();
      await tester.pump(ScanSession.successDelay);
      await tester.pumpAndSettle();
      expect(find.byType(LookupResultScreen), findsOne);
    });

    testWidgets('leaving Scan during the success step: no result opens '
        'behind the new tab and returning scans again', (tester) async {
      final fakes = await _open(tester, _fakes());
      fakes.camera.emit(_ean13);
      await tester.pump(const Duration(milliseconds: 100));
      await tapDestination(tester, 'Search');
      await tester.pump(ScanSession.successDelay);
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Scan');
      expect(_phase(tester), ScanPhase.scanning);
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.byType(LookupResultScreen, skipOffstage: false),
        findsNothing,
      );
      fakes.camera.emit(_ean13);
      await tester.pump();
      await tester.pump(ScanSession.successDelay);
      await tester.pumpAndSettle();
      expect(find.byType(LookupResultScreen), findsOne);
    });
  });

  group('symbology versus digit count', () {
    final codes = <String, String>{
      'EAN-8': _ean8,
      'UPC-A (12)': _upcA,
      'EAN-13': _ean13,
      'UPC-A as EAN-13 (leading 0)': _upcAAsEan13,
    };
    final formats = <String, BarcodeFormat?>{
      'ean8': BarcodeFormat.ean8,
      'upcA': BarcodeFormat.upcA,
      'ean13': BarcodeFormat.ean13,
      'null (UPC-E, QR, unknown)': null,
    };
    bool fits(BarcodeFormat? format, String code) => switch (format) {
      BarcodeFormat.ean8 => code.length == 8,
      BarcodeFormat.upcA || BarcodeFormat.ean13 => code.length >= 12,
      null => false,
    };
    for (final f in formats.entries) {
      for (final c in codes.entries) {
        test('${c.key} reported as ${f.key}', () {
          final barcode = ScanFilter().accept(_d(c.value, f.value));
          if (fits(f.value, c.value)) {
            expect(barcode?.digits, c.value);
          } else {
            expect(barcode, isNull);
          }
        });
      }
    }

    test('a rejected mismatch does not start the 2 s window', () {
      final filter = ScanFilter();
      expect(filter.accept(_d(_ean13, BarcodeFormat.ean8)), isNull);
      expect(filter.accept(_d(_ean13, BarcodeFormat.ean13)), isNotNull);
    });

    test('UPC-A and its EAN-13 form are one code inside the window', () {
      fakeAsync((async) {
        final filter = ScanFilter(stopwatch: clock.stopwatch);
        expect(filter.accept(_d(_upcAAsEan13, BarcodeFormat.ean13)), isNotNull);
        async.elapse(const Duration(milliseconds: 500));
        expect(filter.accept(_d(_upcA, BarcodeFormat.upcA)), isNull);
        async.elapse(const Duration(milliseconds: 1500));
        expect(filter.accept(_d(_upcA, BarcodeFormat.upcA)), isNotNull);
      });
    });

    test('UPC-E 8 digits with an EAN-8 check digit is ignored when the '
        'scanner says UPC-E (null), but accepted as EAN-8 when it says '
        'EAN-8', () {
      expect(ScanFilter().accept(_d(_ean8, null)), isNull);
      expect(ScanFilter().accept(_d(_ean8, BarcodeFormat.ean8)), isNotNull);
    });

    test('a null raw value and a null format never pass', () {
      expect(
        ScanFilter().accept(
          const BarcodeDetection(rawValue: null, format: null),
        ),
        isNull,
      );
      expect(
        ScanFilter().accept(
          const BarcodeDetection(rawValue: null, format: BarcodeFormat.ean13),
        ),
        isNull,
      );
    });

    testWidgets('the fake emit without a format chooses the symbology from '
        'the digit count (EAN-8 test still means an EAN-8)', (tester) async {
      final fakes = await _open(tester, _fakes());
      final seen = <BarcodeDetection>[];
      final sub = fakes.camera.detections.listen((d) => seen.addAll(d));
      addTearDown(sub.cancel);
      fakes.camera.emit(_ean8);
      fakes.camera.emit(_upcA);
      fakes.camera.emit(_ean13);
      fakes.camera.emit('12345');
      fakes.camera.emit(_ean8, format: null);
      expect(seen.map((d) => d.format).toList(), [
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.ean13,
        BarcodeFormat.ean13,
        null,
      ]);
      await tester.pumpAndSettle();
    });

    testWidgets('on screen: an EAN-8 reported as EAN-13 is ignored, an '
        'EAN-13 reported as EAN-8 is ignored, no feedback', (tester) async {
      final haptics = _recordHaptics(tester);
      final fakes = await _open(tester, _fakes());
      tester.takeAnnouncements();
      fakes.camera.emit(_ean8, format: BarcodeFormat.ean13);
      fakes.camera.emit(_ean13, format: BarcodeFormat.ean8);
      fakes.camera.emit(_upcA, format: BarcodeFormat.ean8);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(haptics, isEmpty);
      expect(tester.takeAnnouncements(), isEmpty);
      expect(_phase(tester), ScanPhase.scanning);
      expect(find.byType(LookupResultScreen), findsNothing);
    });
  });

  group('Android manifest declarations', () {
    String read(String path) => File(path).readAsStringSync();

    test('both camera features are declared once and not required', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      for (final feature in [
        'android.hardware.camera',
        'android.hardware.camera.autofocus',
      ]) {
        final pattern = RegExp(
          '<uses-feature\\s+android:name="${RegExp.escape(feature)}"'
          '\\s+android:required="(true|false)"\\s*/>',
        );
        final matches = pattern.allMatches(manifest).toList();
        expect(matches, hasLength(1), reason: feature);
        expect(matches.single.group(1), 'false', reason: feature);
      }
    });

    test('no source manifest requires a camera feature', () {
      for (final flavor in ['main', 'debug', 'profile']) {
        final file = File('android/app/src/$flavor/AndroidManifest.xml');
        if (!file.existsSync()) continue;
        final text = file.readAsStringSync();
        final required = RegExp(
          r'<uses-feature[^>]*android\.hardware\.camera[^>]*required="true"',
        );
        expect(required.hasMatch(text), isFalse, reason: flavor);
      }
    });

    test('CAMERA is declared once, only in the main manifest', () {
      final main = read('android/app/src/main/AndroidManifest.xml');
      expect(
        RegExp('android.permission.CAMERA').allMatches(main),
        hasLength(1),
      );
      for (final flavor in ['debug', 'profile']) {
        final file = File('android/app/src/$flavor/AndroidManifest.xml');
        if (file.existsSync()) {
          expect(file.readAsStringSync(), isNot(contains('permission.CAMERA')));
        }
      }
    });

    test('no other storage, location, or microphone permission slipped in', () {
      final main = read('android/app/src/main/AndroidManifest.xml');
      for (final bad in [
        'RECORD_AUDIO',
        'ACCESS_FINE_LOCATION',
        'READ_EXTERNAL_STORAGE',
        'WRITE_EXTERNAL_STORAGE',
      ]) {
        expect(main, isNot(contains(bad)), reason: bad);
      }
    });
  });
}
