import 'package:board_game_collector/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Window sizes from "Shared test definitions" in docs/backlog.md.
abstract final class WindowSizes {
  static const Size compact = Size(390, 844);
  static const Size medium = Size(744, 1133);
  static const Size expanded = Size(1280, 800);
  static const Size landscape = Size(844, 390);

  /// Every size the shell supports, by name, for table-driven tests.
  static const Map<String, Size> all = {
    'compact': compact,
    'medium': medium,
    'expanded': expanded,
    'landscape': landscape,
  };
}

/// Large text from "Shared test definitions".
const double largeTextScale = 2;

/// Sets the test window to [size] in dp, with [textScale] and the platform
/// [brightness]. Everything is reset when the test ends.
void setTestWindow(
  WidgetTester tester, {
  Size size = WindowSizes.compact,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  tester.platformDispatcher
    ..textScaleFactorTestValue = textScale
    ..platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

/// Pumps the whole app in a fresh [ProviderScope] and renders one frame.
///
/// Does not settle, so callers can check what the very first frame shows.
Future<void> pumpApp(
  WidgetTester tester, {
  Size size = WindowSizes.compact,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  setTestWindow(
    tester,
    size: size,
    textScale: textScale,
    brightness: brightness,
  );
  await tester.pumpWidget(const ProviderScope(child: BoardGameCollectorApp()));
}

/// Taps the destination with the visible [label] in the NavigationBar or
/// NavigationRail, whichever is shown, and settles.
Future<void> tapDestination(WidgetTester tester, String label) async {
  final inBar = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
  final inRail = find.descendant(
    of: find.byType(NavigationRail),
    matching: find.text(label),
  );
  await tester.tap(inBar.evaluate().isNotEmpty ? inBar : inRail);
  await tester.pumpAndSettle();
}
