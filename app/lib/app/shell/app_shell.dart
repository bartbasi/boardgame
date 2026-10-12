import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/window_size_class.dart';
import '../../l10n/app_localizations.dart';
import '../navigation/app_destination.dart';

/// The frame around every screen (AdaptiveScaffold and AppNavigation in
/// docs/ux/components.md).
///
/// Compact windows get a bottom NavigationBar; medium and expanded windows
/// (including phone landscape) get a NavigationRail on the leading edge.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  /// Holds one navigator per destination; see `appRouter`.
  final StatefulNavigationShell navigationShell;

  void _select(int index) {
    // Tapping the selected destination again pops it to its root.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  /// The semantic label to add to the bar icon, or null when it would just
  /// repeat the visible label (Settings).
  static String? _extraSemanticLabel(
    AppDestination destination,
    AppLocalizations l10n,
  ) {
    final semanticLabel = destination.semanticLabel(l10n);
    return semanticLabel == destination.label(l10n) ? null : semanticLabel;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedIndex = navigationShell.currentIndex;
    final sizeClass = WindowSizeClass.fromWidth(
      MediaQuery.sizeOf(context).width,
    );
    final startIndex = AppDestination.start.index;

    // System Back at a destination root goes to Scan; at Scan root it exits.
    // Back inside a destination pops that destination's own stack first.
    final content = PopScope(
      canPop: selectedIndex == startIndex,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _select(startIndex);
      },
      child: navigationShell,
    );

    if (sizeClass == WindowSizeClass.compact) {
      return Scaffold(
        body: content,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: _select,
          destinations: [
            for (final destination in AppDestination.values)
              NavigationDestination(
                // The bar takes its label as a String, so the semantic label
                // (nav.*Label) goes on the icon. Screen readers then read,
                // for example, "Scan a barcode, Scan, Tab 1 of 4".
                icon: Icon(
                  destination.icon,
                  semanticLabel: _extraSemanticLabel(destination, l10n),
                ),
                selectedIcon: Icon(
                  destination.selectedIcon,
                  semanticLabel: _extraSemanticLabel(destination, l10n),
                ),
                label: destination.label(l10n),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          _ScrollableRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: _select,
            destinations: [
              for (final destination in AppDestination.values)
                NavigationRailDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: Text(
                    destination.label(l10n),
                    semanticsLabel: destination.semanticLabel(l10n),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: content),
        ],
      ),
    );
  }
}

/// A NavigationRail that scrolls when its destinations do not fit, for
/// example phone landscape with large text (app-shell.md, section 7).
class _ScrollableRail extends StatelessWidget {
  const _ScrollableRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationRailDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              groupAlignment: -1,
              destinations: destinations,
            ),
          ),
        ),
      ),
    );
  }
}
