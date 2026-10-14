import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// The four top-level destinations, in display order
/// (docs/ux/screens/app-shell.md, decision 1). Scan is the start destination.
enum AppDestination {
  scan(
    path: '/scan',
    icon: Icons.qr_code_scanner_outlined,
    selectedIcon: Icons.qr_code_scanner,
  ),
  search(
    path: '/search',
    icon: Icons.search_outlined,
    selectedIcon: Icons.search,
  ),
  collection(
    path: '/collection',
    icon: Icons.collections_bookmark_outlined,
    selectedIcon: Icons.collections_bookmark,
  ),
  settings(
    path: '/settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  );

  const AppDestination({
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });

  /// Root route of the destination.
  final String path;

  /// Icon when not selected.
  final IconData icon;

  /// Icon when selected.
  final IconData selectedIcon;

  /// The destination the app starts on.
  static const AppDestination start = AppDestination.scan;

  /// Visible label (copy.md `nav.*`).
  String label(AppLocalizations l10n) => switch (this) {
    AppDestination.scan => l10n.navScan,
    AppDestination.search => l10n.navSearch,
    AppDestination.collection => l10n.navCollection,
    AppDestination.settings => l10n.navSettings,
  };

  /// Title of the destination's root screen, announced when the user
  /// switches to it (app-shell.md section 7; T-030 AC17).
  String screenTitle(AppLocalizations l10n) => switch (this) {
    AppDestination.scan => l10n.scannerTitle,
    AppDestination.search => l10n.searchTitle,
    AppDestination.collection => l10n.collectionTitle,
    AppDestination.settings => l10n.settingsTitle,
  };

  /// Label read by screen readers (copy.md `nav.*Label`).
  String semanticLabel(AppLocalizations l10n) => switch (this) {
    AppDestination.scan => l10n.navScanLabel,
    AppDestination.search => l10n.navSearchLabel,
    AppDestination.collection => l10n.navCollectionLabel,
    AppDestination.settings => l10n.navSettingsLabel,
  };
}
