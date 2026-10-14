// T-030: the scanner screen, with a fake camera and a fake permission
// service (test/helpers/fake_scanner.dart). Test names start with the
// acceptance criterion they prove.
import 'dart:async';
import 'dart:io';

import 'package:board_game_collector/app/app.dart';
import 'package:board_game_collector/core/data/network/api_client_provider.dart';
import 'package:board_game_collector/features/scanner/domain/barcode.dart';
import 'package:board_game_collector/features/scanner/domain/barcode_detection.dart';
import 'package:board_game_collector/features/scanner/domain/camera_permission.dart';
import 'package:board_game_collector/features/scanner/presentation/lookup_result_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/manual_entry_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/permission_panel.dart';
import 'package:board_game_collector/features/scanner/presentation/scan_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/scan_session.dart';
import 'package:board_game_collector/features/scanner/presentation/scanner_camera.dart';
import 'package:board_game_collector/features/scanner/presentation/scanner_viewfinder.dart';
import 'package:board_game_collector/features/scanner/presentation/search_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/torch_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_scanner.dart';
import '../../../helpers/pump_app.dart';

const _ean13 = '4006381333931';
const _manual = 'Enter barcode';
const _search = 'Search by title';
const _hint = 'Point the camera at the barcode on the box.';
const _hintSlow =
    'Hold steady and fill the frame with the barcode. Try the torch in low '
    'light.';
const _success = 'Barcode 4006381333931 read. Looking up the game.';

/// Records haptic feedback calls on the platform channel.
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

/// The scanner screen's current phase.
ScanPhase _phase(WidgetTester tester) => tester
    .widgetList<ListenableBuilder>(find.byType(ListenableBuilder))
    .map((w) => w.listenable)
    .whereType<ScanSession>()
    .single
    .phase;

/// Pumps the app on Scan and lets the scanner settle.
Future<ScannerFakes> _open(
  WidgetTester tester, {
  ScannerFakes? scanner,
  Size size = WindowSizes.compact,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  final fakes = await pumpApp(
    tester,
    scanner: scanner,
    size: size,
    textScale: textScale,
    brightness: brightness,
  );
  await tester.pumpAndSettle();
  return fakes;
}

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

/// Emits [code] and lets the success step open the lookup result.
Future<void> _scan(
  WidgetTester tester,
  ScannerFakes fakes, [
  String code = _ean13,
]) async {
  fakes.camera.emit(code);
  await tester.pump();
  await tester.pump(ScanSession.successDelay);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
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

void main() {
  group('AC1 the permission prompt', () {
    testWidgets('AC1 first open of Scan asks, behind the requesting panel', (
      tester,
    ) async {
      final fakes = _fakes(current: CameraPermission.denied, answer: null);
      await pumpApp(tester, scanner: fakes);
      // The first frame shows the scanner itself; the check and the prompt
      // start after it, from the scanner.
      expect(find.byType(ScanScreen), findsOne);
      await tester.pumpAndSettle();

      expect(fakes.permissions.requestCount, 1);
      expect(_phase(tester), ScanPhase.requesting);
      expect(find.text('Camera access'), findsOne);
      expect(
        find.text(
          'The camera reads barcodes on game boxes. Photos and video are '
          'never saved or sent anywhere.',
        ),
        findsOne,
      );
      expect(find.byType(Dialog), findsNothing);

      fakes.permissions.completeRequest(CameraPermission.granted);
      await tester.pumpAndSettle();
      expect(_phase(tester), ScanPhase.scanning);
      expect(fakes.camera.running, isTrue);
    });

    testWidgets('AC1 the prompt shows once per app run, not on other '
        'destinations or on return', (tester) async {
      final fakes = _fakes(
        current: CameraPermission.denied,
        answer: CameraPermission.denied,
      );
      await _open(tester, scanner: fakes);
      expect(fakes.permissions.requestCount, 1);
      expect(_phase(tester), ScanPhase.denied);

      for (final label in ['Search', 'Collection', 'Settings', 'Scan']) {
        await tapDestination(tester, label);
      }
      await _lifecycle(tester, _toBackground);
      await _lifecycle(tester, _toForeground);
      expect(fakes.permissions.requestCount, 1);
      expect(_phase(tester), ScanPhase.denied);
    });

    testWidgets('AC1 a granted permission is never requested', (tester) async {
      final fakes = await _open(tester);
      expect(fakes.permissions.requestCount, 0);
      expect(fakes.permissions.statusCount, 1);
    });
  });

  group('AC2 a valid scan', () {
    testWidgets('AC2 EAN-13 gives one haptic, the success step, then the '
        'lookup result', (tester) async {
      final haptics = _recordHaptics(tester);
      final fakes = await _open(tester);
      tester.takeAnnouncements();

      fakes.camera.emit(_ean13);
      await tester.pump();
      expect(_phase(tester), ScanPhase.detected);
      expect(find.byIcon(Icons.check), findsOne);
      expect(find.byType(LookupResultScreen), findsNothing);
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(
          _success,
          assertiveness: Assertiveness.polite,
          textDirection: TextDirection.ltr,
        ),
      ]);

      await tester.pump(ScanSession.successDelay);
      await tester.pumpAndSettle();
      expect(find.byType(LookupResultScreen), findsOne);
      expect(find.text('Barcode $_ean13'), findsOne);
      expect(
        tester
            .widget<LookupResultScreen>(find.byType(LookupResultScreen))
            .barcode
            .digits,
        _ean13,
      );
      expect(haptics, hasLength(1));
    });

    testWidgets('AC2 UPC-A opens with its own 12 digits', (tester) async {
      final fakes = await _open(tester);
      fakes.camera.emit('036000291452', format: BarcodeFormat.upcA);
      await tester.pump();
      await tester.pump(ScanSession.successDelay);
      await tester.pumpAndSettle();
      expect(find.text('Barcode 036000291452'), findsOne);
    });

    testWidgets('AC2 with reduce motion the check shows without the flash', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final fakes = await _open(tester);
      fakes.camera.emit(_ean13);
      await tester.pump();
      expect(find.byIcon(Icons.check), findsOne);
      await tester.pump(ScanSession.successDelay);
      await tester.pumpAndSettle();
      expect(find.byType(LookupResultScreen), findsOne);
    });
  });

  group('AC4 and AC5 ignored detections', () {
    final cases = <String, (String, BarcodeFormat?)>{
      'QR': ('https://example.com/game', null),
      'Code 128': ('ABC-12345', null),
      // GS1-11: an 8-digit UPC-E whose digits pass the EAN-8 check digit.
      'UPC-E 96385074 (EAN-8 valid digits)': ('96385074', null),
      'UPC-E with EAN-13 valid digits': (_ean13, null),
      'AC5 bad check digit 036000291453': ('036000291453', BarcodeFormat.upcA),
      'wrong length': ('12345', BarcodeFormat.ean13),
    };
    for (final MapEntry(key: name, value: (raw, format)) in cases.entries) {
      testWidgets('AC4 $name: no haptic, no feedback, no navigation', (
        tester,
      ) async {
        final haptics = _recordHaptics(tester);
        final fakes = await _open(tester);
        tester.takeAnnouncements();
        fakes.camera.emit(raw, format: format);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(haptics, isEmpty);
        expect(tester.takeAnnouncements(), isEmpty);
        expect(find.byIcon(Icons.check), findsNothing);
        expect(find.byType(LookupResultScreen), findsNothing);
        expect(_phase(tester), ScanPhase.scanning);
      });
    }

    testWidgets('AC4 a frame with an ignored code and a valid one opens the '
        'valid one', (tester) async {
      final fakes = await _open(tester);
      fakes.camera.emitAll(const [
        BarcodeDetection(rawValue: '96385074', format: null),
        BarcodeDetection(rawValue: _ean13, format: BarcodeFormat.ean13),
      ]);
      await tester.pump();
      await tester.pump(ScanSession.successDelay);
      await tester.pumpAndSettle();
      expect(find.text('Barcode $_ean13'), findsOne);
    });
  });

  group('AC6 debounce', () {
    testWidgets('AC6 5 reads in 500 ms open one lookup; after Back the same '
        'code opens again', (tester) async {
      final haptics = _recordHaptics(tester);
      final fakes = await _open(tester);
      for (var i = 0; i < 5; i++) {
        fakes.camera.emit(_ean13);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(find.byType(LookupResultScreen), findsOne);
      expect(haptics, hasLength(1));

      await _back(tester);
      expect(find.byType(LookupResultScreen), findsNothing);
      expect(_phase(tester), ScanPhase.scanning);

      // Well inside the 2 s window, but the user came back.
      await _scan(tester, fakes);
      expect(find.byType(LookupResultScreen), findsOne);
      expect(haptics, hasLength(2));
    });
  });

  group('AC7 torch', () {
    testWidgets('AC7 the toggle switches the torch, its labels follow, and '
        'the state is announced', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final fakes = await _open(tester);
        tester.takeAnnouncements();
        expect(find.byType(TorchToggle), findsOne);
        expect(find.byTooltip('Turn torch on'), findsOne);
        expect(
          tester.getSemantics(find.byType(TorchToggle)),
          matchesSemantics(
            label: 'Turn torch on',
            hasToggledState: true,
            isToggled: false,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );

        await tester.tap(find.byType(TorchToggle));
        await tester.pumpAndSettle();
        expect(fakes.camera.torchOn, isTrue);
        expect(find.byTooltip('Turn torch off'), findsOne);
        expect(
          tester.getSemantics(find.byType(TorchToggle)),
          matchesSemantics(
            label: 'Turn torch off',
            hasToggledState: true,
            isToggled: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        expect(tester.takeAnnouncements(), [
          isAccessibilityAnnouncement(
            'Torch is on',
            textDirection: TextDirection.ltr,
          ),
        ]);

        await tester.tap(find.byType(TorchToggle));
        await tester.pumpAndSettle();
        expect(fakes.camera.torchOn, isFalse);
        expect(tester.takeAnnouncements(), [
          isAccessibilityAnnouncement(
            'Torch is off',
            textDirection: TextDirection.ltr,
          ),
        ]);
        final size = tester.getSize(find.byType(IconButton).first);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('AC7 no torch: no toggle', (tester) async {
      await _open(tester, scanner: _fakes(hasTorch: false));
      expect(_phase(tester), ScanPhase.scanning);
      expect(find.byType(TorchToggle), findsNothing);
    });

    testWidgets('AC7 while the camera restarts the toggle shows disabled', (
      tester,
    ) async {
      final fakes = await _open(tester);
      fakes.camera.startGate = Completer<void>();
      await tapDestination(tester, 'Search');
      await tester.tap(find.text('Scan').last);
      await tester.pump();
      await tester.pump();
      expect(_phase(tester), ScanPhase.starting);
      final toggle = tester.widget<TorchToggle>(find.byType(TorchToggle));
      expect(toggle.onPressed, isNull);
      fakes.camera.startGate!.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TorchToggle>(find.byType(TorchToggle)).onPressed,
        isNotNull,
      );
    });
  });

  group('AC8 permission panels', () {
    testWidgets('AC8 denied: explanation and Allow camera, which asks again', (
      tester,
    ) async {
      final fakes = _fakes(
        current: CameraPermission.denied,
        answer: CameraPermission.denied,
      );
      await _open(tester, scanner: fakes);
      expect(find.text('Camera access is off'), findsOne);
      expect(
        find.text(
          'Without the camera we cannot scan. You can still enter the barcode '
          'or search by title.',
        ),
        findsOne,
      );
      fakes.permissions.answer = CameraPermission.granted;
      await tester.tap(find.widgetWithText(FilledButton, 'Allow camera'));
      await tester.pumpAndSettle();
      expect(fakes.permissions.requestCount, 2);
      expect(_phase(tester), ScanPhase.scanning);
    });

    testWidgets('AC8 Allow camera after "don\'t ask again" shows the blocked '
        'panel', (tester) async {
      final fakes = _fakes(
        current: CameraPermission.denied,
        answer: CameraPermission.denied,
      );
      await _open(tester, scanner: fakes);
      fakes.permissions.answer = CameraPermission.permanentlyDenied;
      await tester.tap(find.widgetWithText(FilledButton, 'Allow camera'));
      await tester.pumpAndSettle();
      expect(_phase(tester), ScanPhase.permanentlyDenied);
    });

    testWidgets('AC8 permanently denied: Open settings, and the camera '
        'starts on return when it was turned on', (tester) async {
      final fakes = _fakes(current: CameraPermission.permanentlyDenied);
      await _open(tester, scanner: fakes);
      expect(find.text('Camera access is blocked'), findsOne);
      expect(
        find.text(
          'To scan, turn on the camera for this app in system settings. You '
          'can still enter the barcode or search by title.',
        ),
        findsOne,
      );
      expect(fakes.permissions.requestCount, 0);

      await tester.tap(find.widgetWithText(FilledButton, 'Open settings'));
      await tester.pumpAndSettle();
      expect(fakes.permissions.openSettingsCount, 1);

      await _lifecycle(tester, _toBackground);
      fakes.permissions.current = CameraPermission.granted;
      await _lifecycle(tester, _toForeground);
      expect(_phase(tester), ScanPhase.scanning);
      expect(fakes.camera.running, isTrue);
    });

    testWidgets('AC8 permanently denied stays when settings did not change '
        'it', (tester) async {
      final fakes = _fakes(current: CameraPermission.permanentlyDenied);
      await _open(tester, scanner: fakes);
      await _lifecycle(tester, _toBackground);
      await _lifecycle(tester, _toForeground);
      expect(_phase(tester), ScanPhase.permanentlyDenied);
      expect(fakes.camera.startCount, 0);
    });

    testWidgets('AC8 restricted: restricted text, no settings button', (
      tester,
    ) async {
      final fakes = _fakes(current: CameraPermission.restricted);
      await _open(tester, scanner: fakes);
      expect(find.text('Camera access is off'), findsOne);
      expect(
        find.text(
          'Camera access is restricted on this device, so scanning is not '
          'available. You can still enter the barcode or search by title.',
        ),
        findsOne,
      );
      expect(
        find.descendant(
          of: find.byType(PermissionPanel),
          matching: find.byType(FilledButton),
        ),
        findsNothing,
      );
      expect(find.text('Open settings'), findsNothing);
      expect(fakes.permissions.requestCount, 0);
    });

    testWidgets('AC8 the panel title is a heading in a live region', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await _open(
          tester,
          scanner: _fakes(current: CameraPermission.permanentlyDenied),
        );
        expect(
          tester.getSemantics(find.text('Camera access is blocked')),
          matchesSemantics(label: 'Camera access is blocked', isHeader: true),
        );
        final panel = tester.getSemantics(find.byType(PermissionPanel));
        expect(panel.flagsCollection.isLiveRegion, isTrue);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('camera unavailable: Retry starts the camera again', (
      tester,
    ) async {
      final fakes = _fakes(start: CameraStartResult.failed);
      await _open(tester, scanner: fakes);
      expect(find.text('Camera not available'), findsOne);
      fakes.camera.startResult = CameraStartResult.started;
      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(_phase(tester), ScanPhase.scanning);
      expect(fakes.camera.startCount, 2);
    });

    testWidgets('a permission check that fails shows camera unavailable', (
      tester,
    ) async {
      await _open(tester, scanner: _fakes(statusFails: true));
      expect(_phase(tester), ScanPhase.unavailable);
    });

    testWidgets('a permission revoked in the background shows its panel', (
      tester,
    ) async {
      final fakes = await _open(tester);
      await _lifecycle(tester, _toBackground);
      // The status check still says granted (a race), then the camera
      // refuses; the next check sees the revoked permission.
      fakes.camera.startResult = CameraStartResult.permissionDenied;
      final permissions = fakes.permissions;
      permissions.onStatus = () {
        if (permissions.statusCount == 3) {
          permissions.current = CameraPermission.permanentlyDenied;
        }
      };
      await _lifecycle(tester, _toForeground);
      expect(_phase(tester), ScanPhase.permanentlyDenied);
    });
  });

  group('AC9 manual entry and search in every state', () {
    final states = <String, ScannerFakes Function()>{
      'starting': () {
        final fakes = _fakes();
        fakes.camera.startGate = Completer<void>();
        return fakes;
      },
      'requesting': () =>
          _fakes(current: CameraPermission.denied, answer: null),
      'scanning': _fakes,
      'denied': () => _fakes(
        current: CameraPermission.denied,
        answer: CameraPermission.denied,
      ),
      'permanently denied': () =>
          _fakes(current: CameraPermission.permanentlyDenied),
      'restricted': () => _fakes(current: CameraPermission.restricted),
      'camera unavailable': () => _fakes(start: CameraStartResult.failed),
    };
    final expected = <String, ScanPhase>{
      'starting': ScanPhase.starting,
      'requesting': ScanPhase.requesting,
      'scanning': ScanPhase.scanning,
      'denied': ScanPhase.denied,
      'permanently denied': ScanPhase.permanentlyDenied,
      'restricted': ScanPhase.restricted,
      'camera unavailable': ScanPhase.unavailable,
    };
    for (final MapEntry(key: name, value: make) in states.entries) {
      for (final size in ['compact', 'landscape', 'expanded']) {
        testWidgets('AC9 $name ($size): both actions visible, one tap away', (
          tester,
        ) async {
          await pumpApp(tester, scanner: make(), size: WindowSizes.all[size]!);
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          expect(_phase(tester), expected[name]);
          final manual = find.widgetWithText(FilledButton, _manual);
          final search = find.widgetWithText(FilledButton, _search);
          expect(manual.hitTestable(), findsOne);
          expect(search.hitTestable(), findsOne);
          expect(tester.getSize(manual).height, greaterThanOrEqualTo(48));

          await tester.tap(manual);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(ManualEntryScreen), findsOne);
        });
      }
    }

    testWidgets('AC9 Search by title switches to Search', (tester) async {
      await _open(tester);
      tester.takeAnnouncements();
      await tester.tap(find.widgetWithText(FilledButton, _search));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen).hitTestable(), findsOne);
      expect(find.byType(ScanScreen).hitTestable(), findsNothing);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement('Search', textDirection: TextDirection.ltr),
      ]);
    });

    testWidgets('AC9 a double tap on Enter barcode opens one manual entry', (
      tester,
    ) async {
      await _open(tester);
      final manual = find.widgetWithText(FilledButton, _manual);
      await tester.tap(manual);
      await tester.tap(manual, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(ManualEntryScreen), findsOne);
      await _back(tester);
      expect(find.byType(ManualEntryScreen), findsNothing);
    });
  });

  group('AC10 the camera runs only while the scanner is visible', () {
    testWidgets('AC10 switching tabs stops it; coming back restarts it', (
      tester,
    ) async {
      final fakes = await _open(tester);
      expect(fakes.camera.running, isTrue);
      await tapDestination(tester, 'Collection');
      expect(fakes.camera.running, isFalse);
      expect(fakes.camera.stopCount, 1);
      await tapDestination(tester, 'Scan');
      expect(fakes.camera.running, isTrue);
      expect(fakes.camera.startCount, 2);
      expect(_phase(tester), ScanPhase.scanning);
    });

    testWidgets('AC10 background stops it; foreground restarts it', (
      tester,
    ) async {
      final fakes = await _open(tester);
      await _lifecycle(tester, _toBackground);
      expect(fakes.camera.running, isFalse);
      await _lifecycle(tester, _toForeground);
      expect(fakes.camera.running, isTrue);
      expect(fakes.camera.startCount, 2);
    });

    testWidgets('AC10 a screen pushed on Scan stops it; Back restarts it', (
      tester,
    ) async {
      final fakes = await _open(tester);
      await tester.tap(find.widgetWithText(FilledButton, _manual));
      await tester.pumpAndSettle();
      expect(fakes.camera.running, isFalse);
      await _back(tester);
      expect(fakes.camera.running, isTrue);
    });

    testWidgets('AC10 the camera never starts while Scan is hidden', (
      tester,
    ) async {
      final fakes = _fakes();
      fakes.camera.startGate = Completer<void>();
      await pumpApp(tester, scanner: fakes);
      await tester.pump();
      await tester.pump();
      // Leave while the camera is still starting.
      await tester.tap(find.text('Settings').last);
      await tester.pump();
      await tester.pump();
      fakes.camera.startGate!.complete();
      await tester.pumpAndSettle();
      expect(fakes.camera.running, isFalse);
    });

    testWidgets('slow hint after 8 s with no valid detection', (tester) async {
      await _open(tester);
      expect(find.text(_hint), findsOne);
      await tester.pump(const Duration(seconds: 7));
      expect(find.text(_hint), findsOne);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(_hintSlow), findsOne);
    });

    testWidgets('the screen and its camera are released on dispose', (
      tester,
    ) async {
      final fakes = await _open(tester);
      await tester.pumpWidget(const SizedBox());
      expect(fakes.camera.disposed, isTrue);
    });
  });

  testWidgets('AC11 offline: scanning still opens the lookup result', (
    tester,
  ) async {
    var networkReads = 0;
    final fakes = ScannerFakes();
    setTestWindow(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...fakes.overrides,
          apiClientProvider.overrideWith((ref) {
            networkReads++;
            throw StateError('offline');
          }),
        ],
        child: const BoardGameCollectorApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _scan(tester, fakes);
    expect(find.byType(LookupResultScreen), findsOne);
    expect(networkReads, 0);
    expect(tester.takeException(), isNull);
  });

  group('AC13 large text, themes, sizes', () {
    for (final brightness in Brightness.values) {
      for (final size in ['compact', 'expanded']) {
        for (final state in ['scanning', 'permanently denied']) {
          testWidgets('AC13 $state at 2.0 (${brightness.name}, $size): no '
              'overflow, guidelines pass', (tester) async {
            final semantics = tester.ensureSemantics();
            try {
              await _open(
                tester,
                scanner: state == 'scanning'
                    ? _fakes()
                    : _fakes(current: CameraPermission.permanentlyDenied),
                size: WindowSizes.all[size]!,
                textScale: largeTextScale,
                brightness: brightness,
              );
              expect(tester.takeException(), isNull);
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              await expectLater(tester, meetsGuideline(textContrastGuideline));
            } finally {
              semantics.dispose();
            }
          });
        }
      }
    }

    for (final size in ['medium', 'landscape']) {
      testWidgets('AC13 no overflow at 2.0 in $size', (tester) async {
        await _open(
          tester,
          scanner: _fakes(current: CameraPermission.permanentlyDenied),
          size: WindowSizes.all[size]!,
          textScale: largeTextScale,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('AC13 at 2.0 on compact the actions stack', (tester) async {
      await _open(tester, textScale: largeTextScale);
      final manual = tester.getRect(find.widgetWithText(FilledButton, _manual));
      final search = tester.getRect(find.widgetWithText(FilledButton, _search));
      expect(search.top, greaterThanOrEqualTo(manual.bottom));
    });

    // The test font draws every glyph as a square, wider than Roboto, so
    // at 1.0 the labels already wrap past 2 lines on compact; medium gives
    // each button 280 dp.
    testWidgets('at 1.0 on medium the actions sit side by side, equal width, '
        'at most 280 dp', (tester) async {
      await _open(tester, size: WindowSizes.medium);
      final manual = tester.getRect(find.widgetWithText(FilledButton, _manual));
      final search = tester.getRect(find.widgetWithText(FilledButton, _search));
      expect(manual.top, search.top);
      expect(manual.width, search.width);
      expect(manual.width, lessThanOrEqualTo(280));
    });

    testWidgets('phone landscape: preview on the left 60%, actions stacked '
        'on the right', (tester) async {
      await _open(tester, size: WindowSizes.landscape);
      final body = tester.getRect(
        find.descendant(
          of: find.byType(ScanScreen),
          matching: find.byType(ScannerViewfinder),
        ),
      );
      final manual = tester.getRect(find.widgetWithText(FilledButton, _manual));
      final search = tester.getRect(find.widgetWithText(FilledButton, _search));
      expect(manual.left, greaterThanOrEqualTo(body.right));
      expect(search.top, greaterThanOrEqualTo(manual.bottom));
      expect(find.text(_hint), findsOne);
    });

    testWidgets('expanded: the preview is at most 720 dp wide', (tester) async {
      await _open(tester, size: WindowSizes.expanded);
      expect(
        tester.getSize(find.byType(ScannerViewfinder)).width,
        lessThanOrEqualTo(720),
      );
    });

    testWidgets('scanning: the viewfinder has its label and the torch comes '
        'before it, the actions after', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _open(tester);
        expect(
          find.semantics.byLabel('Camera view. Barcode scanning is active.'),
          findsOne,
        );
        final order = <String>[];
        void visit(SemanticsNode node) {
          if (node.label.isNotEmpty) order.add(node.label);
          for (final child in node.debugListChildrenInOrder(
            DebugSemanticsDumpOrder.traversalOrder,
          )) {
            visit(child);
          }
        }

        visit(
          tester
              .renderObject(find.byType(ScanScreen))
              .owner!
              .semanticsOwner!
              .rootSemanticsNode!,
        );
        int at(String label) => order.indexWhere((l) => l.contains(label));
        expect(at('Turn torch on'), lessThan(at('Camera view')));
        expect(at('Camera view'), lessThan(at(_manual)));
        expect(at(_manual), lessThan(at(_search)));
      } finally {
        semantics.dispose();
      }
    });
  });

  group('AC17 destination changes announce the screen title', () {
    for (final size in ['compact', 'expanded']) {
      testWidgets('AC17 all four destinations ($size)', (tester) async {
        await _open(tester, size: WindowSizes.all[size]!);
        final titles = {
          'Search': 'Search',
          'Collection': 'Collection',
          'Settings': 'Settings',
          'Scan': 'Scan a barcode',
        };
        for (final MapEntry(key: label, value: title) in titles.entries) {
          tester.takeAnnouncements();
          await tapDestination(tester, label);
          expect(tester.takeAnnouncements(), [
            isAccessibilityAnnouncement(
              title,
              textDirection: TextDirection.ltr,
            ),
          ], reason: label);
        }
      });
    }

    testWidgets('AC17 tapping the selected destination announces nothing', (
      tester,
    ) async {
      await _open(tester);
      tester.takeAnnouncements();
      await tapDestination(tester, 'Scan');
      expect(tester.takeAnnouncements(), isEmpty);
    });
  });

  test('AC18 the scanner uses no dev* placeholder string', () {
    for (final file in [
      'lib/features/scanner/presentation/scan_screen.dart',
      'lib/features/scanner/presentation/scanner_viewfinder.dart',
      'lib/features/scanner/presentation/scan_action_bar.dart',
      'lib/features/scanner/presentation/permission_panel.dart',
      'lib/features/scanner/presentation/torch_toggle.dart',
    ]) {
      final source = File(file).readAsStringSync();
      expect(source, isNot(contains('devPlaceholder')), reason: file);
      expect(source, isNot(contains('PlaceholderBody')), reason: file);
    }
  });
}
