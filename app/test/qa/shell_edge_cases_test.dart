// QA edge cases for T-012 (app skeleton), added in QA round 1.
import 'package:board_game_collector/core/theme/theme_mode_controller.dart';
import 'package:board_game_collector/features/collection/presentation/collection_item_placeholder_screen.dart';
import 'package:board_game_collector/features/collection/presentation/collection_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/scan_screen.dart';
import 'package:board_game_collector/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../architecture/domain_purity.dart';
import '../helpers/pump_app.dart';

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first)).colorScheme;

int _railIndex(WidgetTester tester) =>
    tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex!;

int _barIndex(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

void main() {
  group('resize across the 600 dp breakpoint', () {
    testWidgets('a pushed screen on Collection survives bar to rail and back', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Collection');
      await tester.tap(find.text('Placeholder item 4'));
      await tester.pumpAndSettle();
      expect(find.byType(CollectionItemPlaceholderScreen), findsOneWidget);

      setTestWindow(tester, size: WindowSizes.expanded);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(CollectionItemPlaceholderScreen), findsOneWidget);
      expect(_railIndex(tester), 2);

      setTestWindow(tester);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(CollectionItemPlaceholderScreen), findsOneWidget);
      expect(_barIndex(tester), 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the selected destination is kept on rotation', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Settings');

      setTestWindow(tester, size: WindowSizes.landscape);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(_railIndex(tester), 3);
    });

    testWidgets('Collection scroll position is kept across a resize', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Collection');
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      final before = tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position
          .pixels;
      expect(before, greaterThan(0));

      setTestWindow(tester, size: WindowSizes.medium);
      await tester.pumpAndSettle();

      final after = tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position
          .pixels;
      expect(after, greaterThan(0));
      expect(find.byType(CollectionScreen), findsOneWidget);
    });

    testWidgets('599.9 dp wide is still a bar', (tester) async {
      await pumpApp(tester, size: const Size(599.9, 900));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  group('theme at runtime', () {
    testWidgets('system brightness change keeps the destination and state', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Collection');
      await tester.tap(find.text('Placeholder item 2'));
      await tester.pumpAndSettle();

      setTestWindow(tester, brightness: Brightness.dark);
      await tester.pumpAndSettle();

      expect(_scheme(tester).brightness, Brightness.dark);
      expect(find.byType(CollectionItemPlaceholderScreen), findsOneWidget);
    });

    testWidgets('forcing light then system follows the platform again', (
      tester,
    ) async {
      await pumpApp(tester, brightness: Brightness.dark);
      await tester.pumpAndSettle();
      expect(_scheme(tester).brightness, Brightness.dark);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ScanScreen)),
      );
      final controller = container.read(themeModeControllerProvider.notifier)
        ..select(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(_scheme(tester).brightness, Brightness.light);

      controller.select(ThemeMode.system);
      await tester.pumpAndSettle();
      expect(_scheme(tester).brightness, Brightness.dark);
    });
  });

  group('back navigation', () {
    testWidgets('Back at Scan root is not handled by the app (it exits)', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isFalse);
    });

    testWidgets('Back twice from a pushed Collection item: root, then Scan', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Collection');
      await tester.tap(find.text('Placeholder item 1'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CollectionScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ScanScreen), findsOneWidget);
    });

    testWidgets('Back from Settings goes to Scan and Collection keeps its '
        'pushed item', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Collection');
      await tester.tap(find.text('Placeholder item 1'));
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Settings');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ScanScreen), findsOneWidget);

      await tapDestination(tester, 'Collection');
      expect(find.byType(CollectionItemPlaceholderScreen), findsOneWidget);
    });

    testWidgets('two quick taps on the selected destination do not throw', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Collection');
      await tester.tap(find.text('Placeholder item 1'));
      await tester.pumpAndSettle();

      final label = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Collection'),
      );
      await tester.tap(label);
      await tester.tap(label);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(CollectionScreen), findsOneWidget);
    });
  });

  group('text scale extremes', () {
    for (final scale in [0.5, 1.5, 3.0]) {
      for (final entry in WindowSizes.all.entries) {
        testWidgets('no overflow at ${scale}x (${entry.key})', (tester) async {
          await pumpApp(tester, size: entry.value, textScale: scale);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final label in ['Search', 'Collection', 'Settings', 'Scan']) {
            await tapDestination(tester, label);
            expect(tester.takeException(), isNull, reason: label);
          }
        });
      }
    }

    testWidgets('at 3.0x on phone landscape the rail can reach Settings', (
      tester,
    ) async {
      await pumpApp(tester, size: WindowSizes.landscape, textScale: 3);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('Settings'),
        ),
      );
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Settings');
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  group('domain purity checker edge cases', () {
    test('deferred and prefixed imports are read', () {
      expect(directiveUris("import 'dart:io' deferred as io;\n"), ['dart:io']);
    });

    test('a URI inside a string literal is not a directive', () {
      expect(directiveUris('const s = "import \'x.dart\';";\n'), isEmpty);
    });
  });
}
