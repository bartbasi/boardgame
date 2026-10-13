import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/collection/presentation/collection_item_placeholder_screen.dart';
import '../../features/collection/presentation/collection_screen.dart';
import '../../features/scanner/domain/barcode.dart';
import '../../features/scanner/presentation/lookup_result_screen.dart';
import '../../features/scanner/presentation/manual_entry_screen.dart';
import '../../features/scanner/presentation/scan_screen.dart';
import '../../features/scanner/presentation/search_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../shell/app_shell.dart';
import 'app_destination.dart';

part 'app_router.g.dart';

/// Route of the placeholder item screen pushed on top of Collection.
String collectionItemPath(int number) =>
    '${AppDestination.collection.path}/item/$number';

/// Route of manual barcode entry, pushed on top of [from] (Scan or Search),
/// so the bar or rail stays visible (app-shell.md decision 7).
String manualEntryPath(AppDestination from) => '${from.path}/manual';

/// Route of the lookup result for [barcode], pushed on top of [from]. The
/// path carries the digits as typed or scanned, so the screen shows them.
String lookupResultPath(AppDestination from, Barcode barcode) =>
    '${from.path}/lookup/${barcode.digits}';

/// The app's router: one branch per destination, each with its own navigator,
/// so every destination keeps its back stack and scroll position
/// (docs/ux/screens/app-shell.md, decision 7).
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final router = GoRouter(
    initialLocation: AppDestination.start.path,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          for (final destination in AppDestination.values)
            StatefulShellBranch(routes: [_rootRoute(destination)]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}

GoRoute _rootRoute(AppDestination destination) => switch (destination) {
  AppDestination.scan => GoRoute(
    path: destination.path,
    builder: (context, state) => ScanScreen(
      onManualEntry: () => context.push(manualEntryPath(destination)),
    ),
    routes: _lookupRoutes(destination),
  ),
  AppDestination.search => GoRoute(
    path: destination.path,
    builder: (context, state) => SearchScreen(
      onManualEntry: () => context.push(manualEntryPath(destination)),
    ),
    routes: _lookupRoutes(destination),
  ),
  AppDestination.collection => GoRoute(
    path: destination.path,
    builder: (context, state) => CollectionScreen(
      onOpenItem: (number) => context.push(collectionItemPath(number)),
    ),
    routes: [
      GoRoute(
        path: 'item/:number',
        builder: (context, state) => CollectionItemPlaceholderScreen(
          number: int.tryParse(state.pathParameters['number'] ?? '') ?? 0,
        ),
      ),
    ],
  ),
  AppDestination.settings => GoRoute(
    path: destination.path,
    builder: (context, state) => const SettingsScreen(),
  ),
};

/// Manual entry and lookup result, pushed inside [from] (Scan or Search).
List<RouteBase> _lookupRoutes(AppDestination from) => [
  GoRoute(
    path: 'manual',
    builder: (context, state) => ManualEntryScreen(
      onSubmit: (barcode) => context.push(lookupResultPath(from, barcode)),
      onScanInstead: () => _leaveManualEntry(context, AppDestination.scan),
      onSearchInstead: () => _leaveManualEntry(context, AppDestination.search),
    ),
  ),
  GoRoute(
    path: 'lookup/:code',
    // Only manual entry and the scanner build these paths, from a valid
    // Barcode; anything else goes back to the destination root.
    redirect: (context, state) =>
        Barcode.parse(state.pathParameters['code'] ?? '').isOk
        ? null
        : from.path,
    builder: (context, state) => LookupResultScreen(
      barcode: Barcode.parse(state.pathParameters['code']!).valueOrNull!,
    ),
  ),
];

/// Closes manual entry and shows [to]. Manual entry is popped first, so it
/// is not left on its destination's stack (and its field does not keep
/// focus in a hidden branch). Going to [to]'s root then either reveals it
/// (manual entry was pushed on [to]) or switches destination.
void _leaveManualEntry(BuildContext context, AppDestination to) {
  final router = GoRouter.of(context);
  router.pop();
  router.go(to.path);
}
