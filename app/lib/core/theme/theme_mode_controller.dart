import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_mode_controller.g.dart';

/// The theme the user picked. Follows the system by default
/// (docs/ux/screens/app-shell.md, decision 4).
///
/// Settings (a later ticket) lets the user force light or dark and persists
/// the choice; until then the value lives only in memory.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.system;

  /// Sets the theme mode for the running app.
  void select(ThemeMode mode) => state = mode;
}
