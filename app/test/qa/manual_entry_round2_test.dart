// T-031 QA round 2: OpenOnce guard, keyboard-aware nav bar, double inset fix,
// and the fake keyboard in pumpApp.
import 'package:board_game_collector/app/app.dart';
import 'package:board_game_collector/app/navigation/app_router.dart';
import 'package:board_game_collector/features/scanner/presentation/lookup_result_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/manual_entry_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/scan_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/pump_app.dart';

Finder get _field => find.byType(TextField);
Finder get _submit => find.widgetWithText(FilledButton, 'Look up');
Finder get _enterBarcode =>
    find.widgetWithText(OutlinedButton, 'Enter barcode');

FocusNode _focus(WidgetTester tester) =>
    tester.widget<TextField>(_field).focusNode!;

Future<void> _open(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(_enterBarcode);
  await tester.pumpAndSettle();
}

/// Taps [finder] [times] times with no frame between taps.
Future<void> _tapFast(WidgetTester tester, Finder finder, int times) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(finder, warnIfMissed: false);
  }
  await tester.pumpAndSettle();
}

Future<void> _submitValid(WidgetTester tester, {int taps = 1}) async {
  await tester.enterText(_field, '036000291452');
  await tester.pump();
  await tester.ensureVisible(_submit);
  await tester.pump();
  await _tapFast(tester, _submit, taps);
}

GoRouter _router(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(BoardGameCollectorApp)),
).read(appRouterProvider);

void _pauseResume(WidgetTester tester) {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

int _count(Finder f) => f.evaluate().length;

void main() {
  group('OpenOnce guard', () {
    testWidgets('three taps on Enter barcode open one manual entry', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      await _tapFast(tester, _enterBarcode, 3);
      expect(find.byType(ManualEntryScreen), findsOne);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ManualEntryScreen), findsNothing);
      expect(find.byType(ScanScreen), findsOne);
    });

    testWidgets('three taps on Look up open one result', (tester) async {
      await pumpApp(tester);
      await _open(tester);
      await _submitValid(tester, taps: 3);
      expect(find.byType(LookupResultScreen), findsOne);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(LookupResultScreen), findsNothing);
      expect(find.byType(ManualEntryScreen), findsOne);
    });

    testWidgets('three keyboard actions open one result', (tester) async {
      await pumpApp(tester);
      await _open(tester);
      await tester.enterText(_field, '96385074');
      for (var i = 0; i < 3; i++) {
        await tester.testTextInput.receiveAction(TextInputAction.search);
      }
      await tester.pumpAndSettle();
      expect(find.byType(LookupResultScreen), findsOne);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.byType(LookupResultScreen, skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('system back unlocks: submit, system back, submit again', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester);
      await _submitValid(tester);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(ManualEntryScreen), findsOne);
      // The text is still there; submit again opens exactly one result.
      await tester.ensureVisible(_submit);
      await _tapFast(tester, _submit, 2);
      expect(find.byType(LookupResultScreen), findsOne);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LookupResultScreen), findsNothing);
    });

    testWidgets('app pause and resume while a result is open change nothing', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester);
      await _submitValid(tester);
      _pauseResume(tester);
      await tester.pumpAndSettle();
      expect(find.byType(LookupResultScreen), findsOne);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(_submit);
      await _tapFast(tester, _submit, 2);
      expect(find.byType(LookupResultScreen), findsOne);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.byType(LookupResultScreen, skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('pause and resume on manual entry keep the screen usable', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester);
      _pauseResume(tester);
      await tester.pumpAndSettle();
      await _submitValid(tester);
      expect(find.byType(LookupResultScreen), findsOne);
    });

    testWidgets('tab re-tap drops the pushed routes and unlocks Scan', (
      tester,
    ) async {
      await pumpApp(tester, size: WindowSizes.expanded);
      await _open(tester);
      await _submitValid(tester);
      expect(find.byType(LookupResultScreen), findsOne);

      await tapDestination(tester, 'Scan');
      expect(find.byType(ScanScreen), findsOne);
      expect(find.byType(ManualEntryScreen), findsNothing);
      expect(find.byType(LookupResultScreen), findsNothing);

      await _tapFast(tester, _enterBarcode, 2);
      expect(find.byType(ManualEntryScreen), findsOne);
      // A fresh manual entry is not locked.
      await _submitValid(tester, taps: 2);
      expect(find.byType(LookupResultScreen), findsOne);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ManualEntryScreen), findsOne);
    });

    testWidgets('tab re-tap from manual entry (no result) unlocks Scan', (
      tester,
    ) async {
      await pumpApp(tester, size: WindowSizes.expanded);
      await _open(tester);
      await tapDestination(tester, 'Scan');
      expect(find.byType(ManualEntryScreen), findsNothing);
      await _tapFast(tester, _enterBarcode, 1);
      expect(find.byType(ManualEntryScreen), findsOne);
    });

    testWidgets('Search tab: re-tap unlocks the Search entry point', (
      tester,
    ) async {
      await pumpApp(tester, size: WindowSizes.expanded);
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Search');
      final action = find.byTooltip('Enter barcode');
      await _tapFast(tester, action, 3);
      expect(find.byType(ManualEntryScreen), findsOne);
      await tapDestination(tester, 'Search');
      expect(find.byType(SearchScreen), findsOne);
      await _tapFast(tester, action, 2);
      expect(find.byType(ManualEntryScreen), findsOne);
    });

    testWidgets('route replacement: Scan instead, then Enter barcode again', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester);
      await tester.ensureVisible(find.text('Scan instead'));
      await tester.tap(find.text('Scan instead'));
      await tester.pumpAndSettle();
      expect(find.byType(ScanScreen), findsOne);
      await _tapFast(tester, _enterBarcode, 2);
      expect(find.byType(ManualEntryScreen), findsOne);
    });

    testWidgets('route replacement: Search by title instead, then the Search '
        'action opens one entry and the Scan entry still works', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester);
      await tester.ensureVisible(find.text('Search by title instead'));
      await tester.tap(find.text('Search by title instead'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOne);
      await _tapFast(tester, find.byTooltip('Enter barcode'), 2);
      expect(find.byType(ManualEntryScreen), findsOne);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Scan');
      await _tapFast(tester, _enterBarcode, 2);
      expect(find.byType(ManualEntryScreen), findsOne);
    });

    testWidgets('router.go away and back: a locked screen unlocks', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester);
      await _submitValid(tester);
      expect(find.byType(LookupResultScreen), findsOne);
      // Leave via a router go that drops the result without a pop.
      _router(tester).go('/scan/manual');
      await tester.pumpAndSettle();
      expect(find.byType(LookupResultScreen), findsNothing);
      expect(find.byType(ManualEntryScreen), findsOne);
      await _submitValid(tester, taps: 2);
      expect(find.byType(LookupResultScreen), findsOne);
    });

    testWidgets('an invalid submit never locks the screen', (tester) async {
      await pumpApp(tester);
      await _open(tester);
      await tester.enterText(_field, '12345');
      await _tapFast(tester, _submit, 3);
      expect(find.byType(LookupResultScreen), findsNothing);
      await tester.enterText(_field, '');
      await _tapFast(tester, _submit, 2);
      expect(find.byType(LookupResultScreen), findsNothing);
      await _submitValid(tester);
      expect(find.byType(LookupResultScreen), findsOne);
    });

    testWidgets('invalid after a valid round trip still shows the error', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester);
      await _submitValid(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.enterText(_field, '036000291453');
      await tester.ensureVisible(_submit);
      await _tapFast(tester, _submit, 1);
      expect(find.byType(LookupResultScreen), findsNothing);
      expect(find.byIcon(Icons.error), findsOne);
    });

    testWidgets('ten open and Back cycles never leave a dead button', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester);
      for (var i = 0; i < 10; i++) {
        await tester.enterText(_field, '96385074');
        await tester.ensureVisible(_submit);
        await _tapFast(tester, _submit, 2);
        expect(_count(find.byType(LookupResultScreen)), 1, reason: 'cycle $i');
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      expect(find.byType(ManualEntryScreen), findsOne);
    });
  });

  group('nav bar follows focus AND keyboard', () {
    testWidgets(
      'keyboard closes with focus kept: bar returns; reopens: hides',
      (tester) async {
        await pumpApp(tester);
        await _open(tester);
        expect(find.byType(NavigationBar), findsNothing);
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        expect(_focus(tester).hasPrimaryFocus, isTrue);
        expect(find.byType(NavigationBar), findsOne);
        await tester.tap(_field);
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar), findsNothing);
      },
    );

    testWidgets('focus lost: inset goes to 0 and the bar returns', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester);
      tester.binding.focusManager.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(tester.view.viewInsets.bottom, 0);
      expect(find.byType(NavigationBar), findsOne);
    });

    testWidgets('focus lost with an inset left over: the bar returns at once '
        '(a keyboard without a focused text field never hides it)', (
      tester,
    ) async {
      await pumpApp(tester, keyboard: false);
      await _open(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      tester.binding.focusManager.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOne);
    });

    testWidgets('inset toggling quickly ends in the right state', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester);
      for (var i = 0; i < 5; i++) {
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pump();
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOne);
    });

    testWidgets('rotation with the keyboard open: rail appears, then the bar '
        'rules apply again when rotated back', (tester) async {
      await pumpApp(tester);
      await _open(tester);
      setTestWindow(tester, size: WindowSizes.landscape);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOne);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
      setTestWindow(tester);
      await tester.pumpAndSettle();
      expect(find.byType(ManualEntryScreen), findsOne);
      expect(find.byType(NavigationRail), findsNothing);
      // The fake keyboard drops its inset on rotation (harness only), so set
      // it again as a real phone keeps it: focus kept, keyboard open.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOne);
    });

    testWidgets('tab switch through the router with the keyboard open shows '
        'the bar on the new tab, and the old field is not revived', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester);
      _router(tester).go('/search');
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOne);
      expect(tester.view.viewInsets.bottom, 0);
    });

    testWidgets('Back with the keyboard open returns the bar on Scan', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.view.viewInsets.bottom, 0);
      expect(find.byType(NavigationBar), findsOne);
    });
  });

  group('no double keyboard inset', () {
    for (final entry in WindowSizes.all.entries) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${entry.key} at $scale: the screen ends at the keyboard '
            'top and the field stays visible', (tester) async {
          final size = entry.value;
          await pumpApp(tester, size: size, textScale: scale);
          await _open(tester);
          final kb = fakeKeyboardHeight(size);
          expect(tester.view.viewInsets.bottom, kb);

          final screen = find.byType(Scaffold).last;
          expect(MediaQuery.viewInsetsOf(tester.element(screen)).bottom, 0);
          expect(tester.getRect(screen).bottom, size.height - kb);

          // The input line starts above the keyboard. Its helper and counter
          // may be under it in landscape at 2.0 (known gap, scrolls).
          expect(tester.getRect(_field).top, lessThan(size.height - kb));
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('on the Search tab with its own field-less screen, no inset is '
        'applied without a keyboard', (tester) async {
      await pumpApp(tester, size: WindowSizes.expanded);
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Search');
      expect(tester.view.viewInsets.bottom, 0);
      expect(
        tester.getRect(find.byType(Scaffold).last).bottom,
        WindowSizes.expanded.height,
      );
    });

    testWidgets('after the keyboard closes the screen grows back to the full '
        'window height on every layout', (tester) async {
      for (final size in WindowSizes.all.values) {
        await pumpApp(tester, size: size);
        await _open(tester);
        tester.binding.focusManager.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final bottom = tester.getRect(find.byType(Scaffold).last).bottom;
        // Compact has the nav bar under the body.
        final navBarHeight = find.byType(NavigationBar).evaluate().isEmpty
            ? 0
            : tester.getSize(find.byType(NavigationBar)).height;
        expect(bottom, size.height - navBarHeight, reason: '$size');
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('the fake keyboard in pumpApp', () {
    testWidgets('keyboard: true gives an inset only while text input is '
        'shown', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      expect(tester.view.viewInsets.bottom, 0);
      await tester.tap(_enterBarcode);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      expect(tester.view.viewInsets.bottom, 300);
      tester.binding.focusManager.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(tester.view.viewInsets.bottom, 0);
    });

    testWidgets('keyboard: false never sets an inset, even with focus and a '
        'visible text input', (tester) async {
      await pumpApp(tester, keyboard: false);
      await _open(tester);
      expect(_focus(tester).hasPrimaryFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(tester.view.viewInsets.bottom, 0);
      expect(find.byType(NavigationBar), findsOne);
      await tester.enterText(_field, '1234');
      await tester.pumpAndSettle();
      expect(tester.view.viewInsets.bottom, 0);
    });

    testWidgets('keyboard: false and a manual inset still behaves like a '
        'phone: the screen shrinks once', (tester) async {
      await pumpApp(tester, keyboard: false);
      await _open(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(Scaffold).last).bottom,
        WindowSizes.compact.height - 250,
      );
    });
  });

  group('Look up is never covered by the keyboard (spec section 7)', () {
    // Phone landscape is the known exception (open question 4).
    final cases = <String, (Size, double)>{
      'compact 1.0': (WindowSizes.compact, 1),
      'compact 2.0': (WindowSizes.compact, 2),
      'medium 1.0': (WindowSizes.medium, 1),
    };
    for (final entry in cases.entries) {
      testWidgets('${entry.key}: on arrival the whole button is above the '
          'keyboard and a plain tap opens the result', (tester) async {
        final (size, scale) = entry.value;
        await pumpApp(tester, size: size, textScale: scale);
        await _open(tester);
        final top = size.height - fakeKeyboardHeight(size);
        expect(tester.view.viewInsets.bottom, fakeKeyboardHeight(size));

        // No scrolling: the button is fully visible above the keyboard.
        final rect = tester.getRect(_submit);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(top));

        await tester.enterText(_field, '036000291452');
        await tester.pump();
        // Typing must not push it under the keyboard either.
        expect(tester.getRect(_submit).bottom, lessThanOrEqualTo(top));
        await tester.tap(_submit);
        await tester.pumpAndSettle();
        expect(find.byType(LookupResultScreen), findsOne);
      });

      testWidgets('${entry.key}: with an error showing the button is still '
          'above the keyboard', (tester) async {
        final (size, scale) = entry.value;
        await pumpApp(tester, size: size, textScale: scale);
        await _open(tester);
        final top = size.height - fakeKeyboardHeight(size);
        await tester.tap(_submit);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.error), findsOne);
        expect(tester.getRect(_submit).bottom, lessThanOrEqualTo(top));
      });
    }
  });
}
