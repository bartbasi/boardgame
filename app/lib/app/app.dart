import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_controller.dart';
import '../l10n/app_localizations.dart';
import 'navigation/app_router.dart';

/// Root widget: router, light and dark themes, and localizations.
///
/// There is no splash, onboarding, or interstitial: the first frame shows
/// the Scan destination (docs/ux/screens/app-shell.md, section 1).
class BoardGameCollectorApp extends ConsumerWidget {
  const BoardGameCollectorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).shellAppName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeControllerProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(appRouterProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
