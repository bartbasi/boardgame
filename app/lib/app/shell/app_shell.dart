import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/window_size_class.dart';
import '../../l10n/app_localizations.dart';
import '../navigation/app_destination.dart';

/// The frame around every screen (AdaptiveScaffold and AppNavigation in
/// docs/ux/components.md).
///
/// Compact windows get a bottom NavigationBar; medium and expanded windows
/// (including phone landscape) get a NavigationRail on the leading edge.
///
/// On compact windows the NavigationBar hides while the keyboard is open
/// for a text field (a text field has focus AND the view has a bottom
/// inset), so the keyboard does not squeeze the content. It returns when
/// focus leaves or when the keyboard closes while focus stays (Android
/// Back, the iOS number pad that has no action key). PRD Q32 [ASSUMPTION];
/// built in T-031, narrowed to "keyboard open" in round 2 (review R1-S1).
/// The rail never hides.
class AppShell extends StatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  /// Holds one navigator per destination; see `appRouter`.
  final StatefulNavigationShell navigationShell;

  /// Whether [node] is the focus node of a text field.
  ///
  /// A text field's EditableText builds a Focus widget for its node, so the
  /// node's context sits below that EditableText.
  static bool isTextFieldFocus(FocusNode? node) {
    final context = node?.context;
    if (context == null) return false;
    final editable = context.findAncestorWidgetOfExactType<EditableText>();
    return editable != null && identical(editable.focusNode, node);
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _textFieldFocused = false;

  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
    _textFieldFocused = AppShell.isTextFieldFocus(
      FocusManager.instance.primaryFocus,
    );
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = navigationShell.currentIndex;
    if (index != oldWidget.navigationShell.currentIndex) {
      _announceDestination(AppDestination.values[index]);
    }
  }

  /// Announces the screen title of the destination the user switched to,
  /// however they switched: bar, rail, a button such as "Search by title",
  /// or Back to Scan (app-shell.md section 7; T-030 AC17).
  void _announceDestination(AppDestination destination) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      destination.screenTitle(AppLocalizations.of(context)),
      Directionality.of(context),
    );
  }

  void _onFocusChanged() {
    final focused = AppShell.isTextFieldFocus(
      FocusManager.instance.primaryFocus,
    );
    if (focused != _textFieldFocused && mounted) {
      setState(() => _textFieldFocused = focused);
    }
  }

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
      final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
      return Scaffold(
        body: content,
        bottomNavigationBar: _textFieldFocused && keyboardOpen
            ? null
            : NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: _select,
                destinations: [
                  for (final destination in AppDestination.values)
                    NavigationDestination(
                      // The bar takes its label as a String, so the semantic
                      // label (nav.*Label) goes on the icon. Screen readers
                      // then read, for example, "Scan a barcode, Scan, Tab 1
                      // of 4".
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
          Expanded(
            // The rail already keeps clear of the leading inset (cutout,
            // system bar), so the content must not pad that side again.
            // The other edges keep their insets. The Builder reads the
            // MediaQuery inside this Scaffold, which has already removed the
            // keyboard inset; the shell's own context would add it back and
            // the screen would shrink by the keyboard height twice.
            child: Builder(
              builder: (bodyContext) => MediaQuery.removePadding(
                context: bodyContext,
                removeLeft: Directionality.of(context) == TextDirection.ltr,
                removeRight: Directionality.of(context) == TextDirection.rtl,
                child: content,
              ),
            ),
          ),
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
