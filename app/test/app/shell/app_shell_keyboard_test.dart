// T-031 AC8: on compact windows the NavigationBar hides while the keyboard
// is open for a focused text field, and returns when focus leaves or the
// keyboard closes; the rail never hides (PRD Q32 [ASSUMPTION]; round 2
// follows Q32's "while the keyboard is open", review R1-S1).
//
// pumpApp installs a fake on-screen keyboard (installFakeKeyboard): the
// view gets a bottom inset while the text input is shown.
import 'package:board_game_collector/app/app.dart';
import 'package:board_game_collector/app/navigation/app_router.dart';
import 'package:board_game_collector/app/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

Finder get _field => find.byType(TextField);

Future<void> _openManualEntry(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(OutlinedButton, 'Enter barcode'));
  await tester.pumpAndSettle();
}

void _unfocus(WidgetTester tester) =>
    tester.binding.focusManager.primaryFocus?.unfocus();

void main() {
  group('compact', () {
    testWidgets('the bar hides while the barcode field has focus with the '
        'keyboard open and returns when focus leaves', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOne);

      await _openManualEntry(tester);
      // The field takes focus on arrival.
      expect(find.byType(NavigationBar), findsNothing);

      _unfocus(tester);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOne);

      await tester.tap(_field);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('the bar returns when the keyboard closes while focus stays '
        '(Android Back), and hides again when it reopens', (tester) async {
      await pumpApp(tester);
      await _openManualEntry(tester);
      expect(tester.view.viewInsets.bottom, greaterThan(0));
      expect(find.byType(NavigationBar), findsNothing);

      // Android Back with the keyboard up closes only the keyboard.
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(_field);
      expect(field.focusNode!.hasPrimaryFocus, isTrue);
      expect(find.byType(NavigationBar), findsOne);

      // Tapping the focused field shows the keyboard again.
      await tester.tap(_field);
      await tester.pumpAndSettle();
      expect(tester.view.viewInsets.bottom, greaterThan(0));
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('a resize with the keyboard open keeps it open at the new '
        'size (fake keyboard, review R2-G2)', (tester) async {
      await pumpApp(tester);
      await _openManualEntry(tester);
      expect(
        tester.view.viewInsets.bottom,
        fakeKeyboardHeight(WindowSizes.compact),
      );

      // Same compact class, shorter window: the inset follows the size.
      const shorter = Size(390, 600);
      setTestWindow(tester, size: shorter);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      expect(tester.view.viewInsets.bottom, fakeKeyboardHeight(shorter));
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('focus without a keyboard keeps the bar (for example a '
        'hardware keyboard, or the iOS number pad dismissed)', (tester) async {
      await pumpApp(tester, keyboard: false);
      await _openManualEntry(tester);

      expect(
        tester.widget<TextField>(_field).focusNode!.hasPrimaryFocus,
        isTrue,
      );
      expect(tester.view.viewInsets.bottom, 0);
      expect(find.byType(NavigationBar), findsOne);
    });

    testWidgets('a keyboard inset without a focused text field keeps the '
        'bar', (tester) async {
      await pumpApp(tester, keyboard: false);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOne);
    });

    testWidgets('the bar stays hidden after an error, because focus stays', (
      tester,
    ) async {
      await pumpApp(tester);
      await _openManualEntry(tester);
      await tester.enterText(_field, '12345');
      await tester.tap(find.widgetWithText(FilledButton, 'Look up'));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('the bar returns on Back and on the lookup result', (
      tester,
    ) async {
      await pumpApp(tester);
      await _openManualEntry(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOne);

      await _openManualEntry(tester);
      await tester.enterText(_field, '036000291452');
      await tester.tap(find.widgetWithText(FilledButton, 'Look up'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOne);
    });

    testWidgets('focus on something that is not a text field keeps the bar', (
      tester,
    ) async {
      await pumpApp(tester);
      await _openManualEntry(tester);
      final button = Focus.of(
        tester.element(
          find.descendant(
            of: find.widgetWithText(TextButton, 'Scan instead'),
            matching: find.text('Scan instead'),
          ),
        ),
      );
      button.requestFocus();
      await tester.pumpAndSettle();

      expect(AppShell.isTextFieldFocus(button), isFalse);
      expect(find.byType(NavigationBar), findsOne);
    });

    testWidgets('a field left focused in another destination does not hide '
        'the bar', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      // Search is built once, so switching back later pushes no new route
      // there that would take focus.
      await tapDestination(tester, 'Search');
      await tapDestination(tester, 'Scan');
      await _openManualEntry(tester);
      expect(find.byType(NavigationBar), findsNothing);

      // Switch destination through the router while the field has focus,
      // leaving manual entry mounted (offstage) on Scan's stack. go_router
      // gives focus to the new destination's top route (its navigators use
      // requestFocus), so the hidden field loses focus and the bar returns.
      ProviderScope.containerOf(
        tester.element(find.byType(BoardGameCollectorApp)),
      ).read(appRouterProvider).go('/search');
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOne);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );

      // Back on Scan, manual entry is still there; tapping the field hides
      // the bar again.
      await tapDestination(tester, 'Scan');
      expect(find.byType(NavigationBar), findsOne);
      await tester.tap(_field);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  for (final entry in {
    'medium': WindowSizes.medium,
    'expanded': WindowSizes.expanded,
    'landscape': WindowSizes.landscape,
  }.entries) {
    testWidgets('${entry.key}: the rail stays while the field has focus', (
      tester,
    ) async {
      await pumpApp(tester, size: entry.value);
      await _openManualEntry(tester);

      expect(
        tester.widget<TextField>(_field).focusNode!.hasPrimaryFocus,
        isTrue,
      );
      expect(tester.view.viewInsets.bottom, greaterThan(0));
      expect(find.byType(NavigationRail), findsOne);
      expect(find.byType(NavigationBar), findsNothing);

      // The shell's Scaffold already makes room for the keyboard, so the
      // screen's own Scaffold must not see the inset again (round 2 fix:
      // the rail layout used to put it back, shrinking the screen twice).
      final screen = find.byType(Scaffold).last;
      expect(MediaQuery.viewInsetsOf(tester.element(screen)).bottom, 0);
      expect(
        tester.getRect(screen).bottom,
        entry.value.height - fakeKeyboardHeight(entry.value),
      );
    });
  }

  test('isTextFieldFocus is false without a focus node or context', () {
    expect(AppShell.isTextFieldFocus(null), isFalse);
    final node = FocusNode();
    addTearDown(node.dispose);
    expect(AppShell.isTextFieldFocus(node), isFalse);
  });
}
