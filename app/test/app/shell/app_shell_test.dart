import 'dart:ui' show Tristate;

import 'package:board_game_collector/features/collection/presentation/collection_item_placeholder_screen.dart';
import 'package:board_game_collector/features/collection/presentation/collection_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/scan_screen.dart';
import 'package:board_game_collector/features/scanner/presentation/search_screen.dart';
import 'package:board_game_collector/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// Destination labels in display order (copy.md nav.*).
const List<String> _labels = ['Scan', 'Search', 'Collection', 'Settings'];

/// Semantic labels in display order (copy.md nav.*Label).
const List<String> _semanticLabels = [
  'Scan a barcode',
  'Search by title',
  'Your collection',
  'Settings',
];

/// Left edge of each finder's first match, to check order along an axis.
List<double> _xs(WidgetTester tester, List<Finder> finders) => [
  for (final f in finders) tester.getCenter(f).dx,
];

List<double> _ys(WidgetTester tester, List<Finder> finders) => [
  for (final f in finders) tester.getCenter(f).dy,
];

bool _isIncreasing(List<double> values) {
  for (var i = 1; i < values.length; i++) {
    if (values[i] <= values[i - 1]) return false;
  }
  return true;
}

void main() {
  group('AC4 navigation by window size', () {
    testWidgets('compact uses a bottom NavigationBar in order', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      final bar = find.byType(NavigationBar);
      final labels = [
        for (final label in _labels)
          find.descendant(of: bar, matching: find.text(label)),
      ];
      for (final label in labels) {
        expect(label, findsOneWidget);
      }
      expect(_isIncreasing(_xs(tester, labels)), isTrue);
      // The bar sits at the bottom of the window.
      expect(tester.getBottomLeft(bar).dy, WindowSizes.compact.height);
    });

    for (final entry in {
      'medium': WindowSizes.medium,
      'expanded': WindowSizes.expanded,
      'landscape': WindowSizes.landscape,
    }.entries) {
      testWidgets('${entry.key} uses a NavigationRail in order', (
        tester,
      ) async {
        await pumpApp(tester, size: entry.value);
        await tester.pumpAndSettle();

        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        final rail = find.byType(NavigationRail);
        final labels = [
          for (final label in _labels)
            find.descendant(of: rail, matching: find.text(label)),
        ];
        for (final label in labels) {
          expect(label, findsOneWidget);
        }
        expect(_isIncreasing(_ys(tester, labels)), isTrue);
        // The rail is on the leading edge.
        expect(tester.getTopLeft(rail).dx, 0);
        final rail0 = tester.widget<NavigationRail>(rail);
        expect(rail0.labelType, NavigationRailLabelType.all);
      });
    }

    testWidgets('the bar changes to a rail at 600 dp wide', (tester) async {
      await pumpApp(tester, size: const Size(599, 900));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);

      setTestWindow(tester, size: const Size(600, 900));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('the first frame already shows Scan, with nothing before it', (
      tester,
    ) async {
      // pumpApp renders exactly one frame and does not settle.
      await pumpApp(tester);

      expect(find.byType(ScanScreen), findsOneWidget);
      expect(find.text('Scan a barcode'), findsOneWidget);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 0);
    });
  });

  group('AC5 state per destination', () {
    testWidgets('Collection keeps its scroll position across a switch', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Collection');

      final list = find.byType(Scrollable).last;
      await tester.drag(list, const Offset(0, -600));
      await tester.pumpAndSettle();
      final before = tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position
          .pixels;
      expect(before, greaterThan(0));
      expect(find.text('Placeholder item 1'), findsNothing);

      await tapDestination(tester, 'Settings');
      expect(find.byType(SettingsScreen), findsOneWidget);

      await tapDestination(tester, 'Collection');
      final after = tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position
          .pixels;
      expect(after, before);
      expect(find.text('Placeholder item 1'), findsNothing);
    });

    testWidgets('a pushed screen is kept when switching away and back', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Collection');
      await tester.tap(find.text('Placeholder item 2'));
      await tester.pumpAndSettle();
      expect(find.byType(CollectionItemPlaceholderScreen), findsOneWidget);
      // The bar stays visible on pushed screens.
      expect(find.byType(NavigationBar), findsOneWidget);

      await tapDestination(tester, 'Scan');
      expect(find.byType(ScanScreen), findsOneWidget);
      await tapDestination(tester, 'Collection');
      expect(find.byType(CollectionItemPlaceholderScreen), findsOneWidget);
    });

    for (final entry in {
      'compact': WindowSizes.compact,
      'expanded': WindowSizes.expanded,
    }.entries) {
      testWidgets(
        'tapping the selected destination returns to its root (${entry.key})',
        (tester) async {
          await pumpApp(tester, size: entry.value);
          await tester.pumpAndSettle();
          await tapDestination(tester, 'Collection');
          await tester.tap(find.text('Placeholder item 3'));
          await tester.pumpAndSettle();
          expect(find.byType(CollectionItemPlaceholderScreen), findsOneWidget);

          await tapDestination(tester, 'Collection');

          expect(find.byType(CollectionItemPlaceholderScreen), findsNothing);
          expect(find.byType(CollectionScreen), findsOneWidget);
        },
      );
    }
  });

  group('System Back (app-shell.md section 5)', () {
    testWidgets('pops inside the destination first', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Collection');
      await tester.tap(find.text('Placeholder item 1'));
      await tester.pumpAndSettle();

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.byType(CollectionScreen), findsOneWidget);
      expect(find.byType(CollectionItemPlaceholderScreen), findsNothing);
    });

    testWidgets('at a destination root goes to Scan', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      await tapDestination(tester, 'Search');
      expect(find.byType(SearchScreen), findsOneWidget);

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.byType(ScanScreen), findsOneWidget);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 0);
    });
  });

  group('Safe areas with the rail (app-shell.md section 2)', () {
    testWidgets('a landscape cutout pads the rail once, not the content', (
      tester,
    ) async {
      setTestWindow(tester, size: WindowSizes.landscape);
      tester.view.padding = const FakeViewPadding(left: 48, right: 30);
      await pumpApp(tester, size: WindowSizes.landscape);
      await tester.pumpAndSettle();

      // The rail keeps its destinations clear of the leading cutout.
      final scanIcon = find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byIcon(Icons.qr_code_scanner),
      );
      expect(tester.getTopLeft(scanIcon).dx, greaterThanOrEqualTo(48));

      // The content no longer sees the leading inset, but keeps the trailing.
      final padding = MediaQuery.paddingOf(
        tester.element(find.byType(ScanScreen)),
      );
      expect(padding.left, 0);
      expect(padding.right, 30);
      final viewPadding = MediaQuery.viewPaddingOf(
        tester.element(find.byType(ScanScreen)),
      );
      expect(viewPadding.left, 0);
    });

    testWidgets('the compact bar layout keeps the side insets', (tester) async {
      setTestWindow(tester);
      tester.view.padding = const FakeViewPadding(left: 20, right: 20);
      await pumpApp(tester);
      await tester.pumpAndSettle();

      final padding = MediaQuery.paddingOf(
        tester.element(find.byType(ScanScreen)),
      );
      expect(padding.left, 20);
      expect(padding.right, 20);
    });
  });

  group('AC7 large text', () {
    for (final entry in {
      'compact': WindowSizes.compact,
      'expanded': WindowSizes.expanded,
      'landscape': WindowSizes.landscape,
    }.entries) {
      testWidgets('no overflow at text scale 2.0 (${entry.key})', (
        tester,
      ) async {
        await pumpApp(tester, size: entry.value, textScale: largeTextScale);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        for (final label in _labels) {
          await tapDestination(tester, label);
          expect(tester.takeException(), isNull, reason: label);
        }
        await tapDestination(tester, 'Collection');
        await tester.tap(find.text('Placeholder item 1'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('AC8 semantics and accessibility guidelines', () {
    for (final brightness in Brightness.values) {
      for (final entry in {
        'compact': WindowSizes.compact,
        'expanded': WindowSizes.expanded,
      }.entries) {
        testWidgets(
          'labels and guidelines pass (${brightness.name}, ${entry.key})',
          (tester) async {
            final semantics = tester.ensureSemantics();
            // flutter_test checks for live handles before tear-downs run, so
            // addTearDown is too late; finally disposes even when an expect fails.
            try {
              await pumpApp(tester, size: entry.value, brightness: brightness);
              await tester.pumpAndSettle();

              for (var i = 0; i < _semanticLabels.length; i++) {
                final node = find.semantics.byPredicate(
                  (node) =>
                      node.label.contains(_semanticLabels[i]) &&
                      node.label.contains('Tab ${i + 1} of 4'),
                  describeMatch: (_) => _semanticLabels[i],
                );
                expect(node, findsOne, reason: _semanticLabels[i]);
                expect(
                  node
                      .evaluate()
                      .single
                      .getSemanticsData()
                      .flagsCollection
                      .isSelected,
                  i == 0 ? Tristate.isTrue : Tristate.isFalse,
                );
              }

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
          },
        );
      }
    }
  });
}
