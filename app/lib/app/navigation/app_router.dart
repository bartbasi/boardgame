import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/collection/presentation/collection_item_placeholder_screen.dart';
import '../../features/collection/presentation/collection_screen.dart';
import '../../features/scanner/presentation/scan_screen.dart';
import '../../features/scanner/presentation/search_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../shell/app_shell.dart';
import 'app_destination.dart';

part 'app_router.g.dart';

/// Route of the placeholder item screen pushed on top of Collection.
String collectionItemPath(int number) =>
    '${AppDestination.collection.path}/item/$number';

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
    builder: (context, state) => const ScanScreen(),
  ),
  AppDestination.search => GoRoute(
    path: destination.path,
    builder: (context, state) => const SearchScreen(),
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
