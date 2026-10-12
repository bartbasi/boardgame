import 'package:board_game_collector/app/navigation/app_destination.dart';
import 'package:board_game_collector/app/navigation/app_router.dart';
import 'package:board_game_collector/app/shell/app_shell.dart';
import 'package:board_game_collector/l10n/app_localizations_en.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('AC10 generated appRouterProvider', () {
    test('starts on the Scan destination', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      expect(router.routeInformationProvider.value.uri.path, '/scan');
    });

    test('is kept alive, so the same router is returned each time', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final first = container.read(appRouterProvider);
      final second = container.read(appRouterProvider);

      expect(identical(first, second), isTrue);
    });

    testWidgets('the shell is built from the generated provider', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
      );
      final router = container.read(appRouterProvider);
      final routerConfig = tester
          .widget<Router<Object>>(find.byType(Router<Object>))
          .routerDelegate;
      expect(identical(routerConfig, router.routerDelegate), isTrue);
    });
  });

  group('AppDestination', () {
    test('order is Scan, Search, Collection, Settings', () {
      expect(AppDestination.values, [
        AppDestination.scan,
        AppDestination.search,
        AppDestination.collection,
        AppDestination.settings,
      ]);
      expect(AppDestination.start, AppDestination.scan);
    });

    test('labels and semantic labels come from copy.md keys', () {
      final l10n = AppLocalizationsEn();
      expect(
        [for (final d in AppDestination.values) d.label(l10n)],
        ['Scan', 'Search', 'Collection', 'Settings'],
      );
      expect(
        [for (final d in AppDestination.values) d.semanticLabel(l10n)],
        ['Scan a barcode', 'Search by title', 'Your collection', 'Settings'],
      );
    });

    test('paths are unique', () {
      final paths = {for (final d in AppDestination.values) d.path};
      expect(paths, hasLength(AppDestination.values.length));
    });

    test('collection item path is nested under Collection', () {
      expect(collectionItemPath(7), '/collection/item/7');
    });
  });

  testWidgets('an unknown item number still opens a screen', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
    );
    container.read(appRouterProvider).go('/collection/item/abc');
    await tester.pumpAndSettle();
    expect(find.text('Placeholder item 0'), findsWidgets);
  });
}
