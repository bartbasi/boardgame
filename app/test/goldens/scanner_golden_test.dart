import 'package:board_game_collector/features/scanner/domain/camera_permission.dart';

import '../helpers/fake_scanner.dart';
import '../helpers/goldens.dart';
import '../helpers/pump_app.dart';

/// Golden cases from docs/ux/screens/scanner.md section 8 (T-030 AC14).
/// The camera preview is the fake camera's neutral placeholder.
///
/// Render or update only on GitHub Actions, with the manual app.yml run
/// (input update_goldens; see test/helpers/goldens.dart). Listed in
/// test/golden_pipeline/golden_files_test.dart.
const scannerGoldenCases = <GoldenCase>[
  GoldenCase('scanner', 'scanning', .light, .compact),
  GoldenCase('scanner', 'scanning', .dark, .compact),
  GoldenCase('scanner', 'scanning', .light, .landscape),
  GoldenCase('scanner', 'requesting', .light, .compact),
  GoldenCase('scanner', 'detected', .light, .compact),
  GoldenCase('scanner', 'permanentlydenied', .light, .compact),
  GoldenCase('scanner', 'denied', .dark, .compact),
  GoldenCase('scanner', 'permanentlydenied', .dark, .compact, .large),
];

/// The scanner fakes for a golden [state].
ScannerFakes _fakesFor(String state) => switch (state) {
  'scanning' || 'detected' => ScannerFakes(),
  // The system prompt stays open.
  'requesting' => ScannerFakes(
    permissions: FakeCameraPermissions(
      current: CameraPermission.denied,
      answer: null,
    ),
  ),
  'denied' => ScannerFakes(
    permissions: FakeCameraPermissions(
      current: CameraPermission.denied,
      answer: CameraPermission.denied,
    ),
  ),
  'permanentlydenied' => ScannerFakes(
    permissions: FakeCameraPermissions(
      current: CameraPermission.permanentlyDenied,
    ),
  ),
  _ => throw ArgumentError.value(state, 'state'),
};

void main() {
  for (final c in scannerGoldenCases) {
    late ScannerFakes fakes;
    goldenTest(
      screen: c.screen,
      state: c.state,
      theme: c.theme,
      size: c.size,
      textScale: c.textScale,
      build: () => testApp(fakes = _fakesFor(c.state)),
      arrange: c.state == 'detected'
          ? (tester) async {
              // The capture happens inside the 300 ms success step.
              fakes.camera.emit('4006381333931');
              await tester.pump();
            }
          : null,
    );
  }
}
