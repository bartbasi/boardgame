import 'package:board_game_collector/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/goldens.dart';

/// Golden cases from docs/ux/screens/app-shell.md section 8 that T-015
/// delivers (T-015 AC6). The two offline cases come with T-032.
///
/// Render or update only on GitHub Actions, with the manual app.yml run
/// (input update_goldens; see test/helpers/goldens.dart). The list is also
/// read by test/golden_pipeline/golden_files_test.dart, which fails on PNGs
/// that no case declares.
const appShellGoldenCases = <GoldenCase>[
  GoldenCase('app_shell', 'default', .light, .compact),
  GoldenCase('app_shell', 'default', .dark, .compact),
  GoldenCase('app_shell', 'default', .light, .expanded),
  GoldenCase('app_shell', 'default', .dark, .expanded),
  GoldenCase('app_shell', 'default', .light, .medium),
  GoldenCase('app_shell', 'default', .light, .landscape),
  GoldenCase('app_shell', 'default', .light, .compact, .large),
  GoldenCase('app_shell', 'default', .dark, .expanded, .large),
];

void main() {
  goldenTests(
    appShellGoldenCases,
    build: () => const ProviderScope(child: BoardGameCollectorApp()),
  );
}
