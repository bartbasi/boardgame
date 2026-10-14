import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_scanner.dart';
import '../helpers/goldens.dart';
import '../helpers/pump_app.dart';

/// Golden cases from docs/ux/screens/manual-entry.md section 8 (T-031 AC7).
///
/// Render or update only on GitHub Actions, with the manual app.yml run
/// (input update_goldens; see test/helpers/goldens.dart). Listed in
/// test/golden_pipeline/golden_files_test.dart.
const manualEntryGoldenCases = <GoldenCase>[
  GoldenCase('manual_entry', 'initial', .light, .compact),
  GoldenCase('manual_entry', 'initial', .dark, .compact),
  GoldenCase('manual_entry', 'initial', .light, .expanded),
  GoldenCase('manual_entry', 'error_checkdigit', .light, .compact),
  GoldenCase('manual_entry', 'error_checkdigit', .dark, .compact),
  GoldenCase('manual_entry', 'initial', .light, .compact, .large),
];

/// Opens manual entry the way a user does, from the Scan destination. The
/// field takes focus, but goldens draw no keyboard (no view inset), so the
/// compact NavigationBar shows: it hides only while the keyboard is open
/// (T-031 round 2, R1-S1).
Future<void> _openManualEntry(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Enter barcode'));
  await tester.pumpAndSettle();
}

/// The bad check digit example from the spec.
Future<void> _submitBadCheckDigit(WidgetTester tester) async {
  await _openManualEntry(tester);
  await tester.enterText(find.byType(TextField), '036000291453');
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Look up'));
}

void main() {
  // A focused field blinks its cursor; draw it steadily so the capture does
  // not depend on timing.
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  for (final c in manualEntryGoldenCases) {
    goldenTest(
      screen: c.screen,
      state: c.state,
      theme: c.theme,
      size: c.size,
      textScale: c.textScale,
      build: () => testApp(ScannerFakes()),
      arrange: switch (c.state) {
        'initial' => _openManualEntry,
        'error_checkdigit' => _submitBadCheckDigit,
        _ => throw ArgumentError.value(c.state, 'state'),
      },
    );
  }
}
