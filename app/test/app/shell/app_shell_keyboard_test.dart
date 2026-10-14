// T-031 AC8: on compact windows the NavigationBar hides while a text field
// has focus and returns when focus leaves; the rail never hides
// (docs/ux/screens/app-shell.md section 2 [ASSUMPTION], PRD Q32).
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
    testWidgets('the bar hides while the barcode field has focus and '
        'returns when focus leaves', (tester) async {
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
      expect(find.byType(NavigationRail), findsOne);
      expect(find.byType(NavigationBar), findsNothing);
    });
  }

  test('isTextFieldFocus is false without a focus node or context', () {
    expect(AppShell.isTextFieldFocus(null), isFalse);
    final node = FocusNode();
    addTearDown(node.dispose);
    expect(AppShell.isTextFieldFocus(node), isFalse);
  });
}
