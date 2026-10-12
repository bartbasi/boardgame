import 'package:board_game_collector/core/theme/app_theme.dart';
import 'package:board_game_collector/core/theme/theme_mode_controller.dart';
import 'package:board_game_collector/features/scanner/presentation/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

ThemeData _themeOfScanScreen(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(ScanScreen)));

void main() {
  group('AppTheme', () {
    test('seed color is 0xFF1F6B5C (PRD Q31)', () {
      expect(AppTheme.seedColor, const Color(0xFF1F6B5C));
    });

    test('light theme is Material 3 from the seed, light brightness', () {
      final theme = AppTheme.light();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(
        theme.colorScheme,
        ColorScheme.fromSeed(seedColor: const Color(0xFF1F6B5C)),
      );
    });

    test('dark theme is Material 3 from the same seed, dark brightness', () {
      final theme = AppTheme.dark();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(
        theme.colorScheme,
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F6B5C),
          brightness: Brightness.dark,
        ),
      );
    });

    test('navigation bar always shows labels', () {
      expect(
        AppTheme.light().navigationBarTheme.labelBehavior,
        NavigationDestinationLabelBehavior.alwaysShow,
      );
    });
  });

  group('AC6 theme follows platform brightness', () {
    testWidgets('dark system theme gives the dark seeded scheme', (
      tester,
    ) async {
      await pumpApp(tester, brightness: Brightness.dark);
      await tester.pumpAndSettle();

      final theme = _themeOfScanScreen(tester);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme, AppTheme.dark().colorScheme);
    });

    testWidgets('light system theme gives the light seeded scheme', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();

      final theme = _themeOfScanScreen(tester);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme, AppTheme.light().colorScheme);
    });

    testWidgets('changing the system theme at runtime switches the scheme', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      expect(_themeOfScanScreen(tester).brightness, Brightness.light);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();

      expect(
        _themeOfScanScreen(tester).colorScheme,
        AppTheme.dark().colorScheme,
      );
    });

    testWidgets('MaterialApp uses only the seeded themes (no dynamic color)', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.system);
      expect(app.theme!.colorScheme, AppTheme.light().colorScheme);
      expect(app.darkTheme!.colorScheme, AppTheme.dark().colorScheme);
      expect(app.highContrastTheme, isNull);
      expect(app.highContrastDarkTheme, isNull);
    });
  });

  group('ThemeModeController', () {
    test('defaults to the system theme', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeControllerProvider), ThemeMode.system);
    });

    testWidgets('a forced dark mode wins over a light system theme', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ScanScreen)),
      );
      container
          .read(themeModeControllerProvider.notifier)
          .select(ThemeMode.dark);
      await tester.pumpAndSettle();

      expect(_themeOfScanScreen(tester).brightness, Brightness.dark);
    });
  });
}
