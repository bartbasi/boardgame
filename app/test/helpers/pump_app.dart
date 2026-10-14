import 'dart:math' as math;

import 'package:board_game_collector/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
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

/// Height of the fake on-screen keyboard for a window of [size]: 40% of the
/// window height, at most 300 dp (about a phone keyboard).
double fakeKeyboardHeight(Size size) => math.min(300, size.height * 0.4);

/// Makes the test window act like a phone with an on-screen keyboard: the
/// bottom view inset is [height] dp while the text input is shown
/// (`TextInput.show`) and 0 once it is hidden or its client is cleared
/// (for example when the field loses focus).
///
/// flutter_test only records whether the keyboard is visible and never sets
/// a view inset, so without this a focused field never "opens" a keyboard.
/// The shell hides the compact NavigationBar only while a text field has
/// focus and the keyboard is open (T-031 round 2, review R1-S1). To close
/// the keyboard while focus stays (Android Back), set
/// `tester.view.viewInsets = FakeViewPadding.zero`.
void installFakeKeyboard(WidgetTester tester, {required double height}) {
  final messenger = tester.binding.defaultBinaryMessenger;
  var active = true;
  void apply() {
    if (!active) return;
    final inset = tester.testTextInput.isVisible
        ? height * tester.view.devicePixelRatio
        : 0.0;
    if (tester.view.viewInsets.bottom != inset) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
    }
  }

  messenger.allMessagesHandler = (channel, handler, message) {
    // The same routing the messenger uses without this handler.
    final result = handler != null
        ? handler(message)
        : messenger.delegate.send(channel, message);
    if (channel == SystemChannels.textInput.name) {
      // A field that closes its input while the tree is being built or
      // unmounted cannot change the window metrics then; wait for the frame
      // to end, as a real keyboard would.
      if (tester.binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
        tester.binding.addPostFrameCallback((_) => apply());
      } else {
        apply();
      }
    }
    return result;
  };
  addTearDown(() {
    active = false;
    messenger.allMessagesHandler = null;
  });
}

/// Pumps the whole app in a fresh [ProviderScope] and renders one frame.
///
/// Does not settle, so callers can check what the very first frame shows.
/// With [keyboard] (the default), focusing a text field opens a fake
/// on-screen keyboard; see [installFakeKeyboard].
Future<void> pumpApp(
  WidgetTester tester, {
  Size size = WindowSizes.compact,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  bool keyboard = true,
}) async {
  setTestWindow(
    tester,
    size: size,
    textScale: textScale,
    brightness: brightness,
  );
  if (keyboard) {
    installFakeKeyboard(tester, height: fakeKeyboardHeight(size));
  }
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
