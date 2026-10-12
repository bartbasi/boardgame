import 'package:flutter/material.dart';

/// Builds the Material 3 light and dark themes.
///
/// Both schemes come from one seed color (docs/ux/screens/app-shell.md,
/// PRD Q31, docs/decisions.md 2026-10-12). Dynamic (wallpaper) color is off
/// in v1, so no other color source is used anywhere in the app.
abstract final class AppTheme {
  /// Brand seed color: a deep green-teal.
  static const Color seedColor = Color(0xFF1F6B5C);

  /// The light theme.
  static ThemeData light() => _build(Brightness.light);

  /// The dark theme.
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
