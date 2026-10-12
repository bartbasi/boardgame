import 'package:board_game_collector/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/goldens.dart';

/// Golden cases from docs/ux/screens/app-shell.md section 8 that T-015
/// delivers (T-015 AC6). The two offline cases come with T-032.
///
/// Render or update with app/tool/golden/goldens.sh update (Linux only).
void main() {
  const cases = <(String?, GoldenTheme, GoldenSize, GoldenTextScale)>[
    ('default', GoldenTheme.light, GoldenSize.compact, GoldenTextScale.normal),
    ('default', GoldenTheme.dark, GoldenSize.compact, GoldenTextScale.normal),
    ('default', GoldenTheme.light, GoldenSize.expanded, GoldenTextScale.normal),
    ('default', GoldenTheme.dark, GoldenSize.expanded, GoldenTextScale.normal),
    ('default', GoldenTheme.light, GoldenSize.medium, GoldenTextScale.normal),
    (
      'default',
      GoldenTheme.light,
      GoldenSize.landscape,
      GoldenTextScale.normal,
    ),
    (null, GoldenTheme.light, GoldenSize.compact, GoldenTextScale.large),
    (null, GoldenTheme.dark, GoldenSize.expanded, GoldenTextScale.large),
  ];

  for (final (state, theme, size, textScale) in cases) {
    goldenTest(
      screen: 'app_shell',
      state: state,
      theme: theme,
      size: size,
      textScale: textScale,
      build: () => const ProviderScope(child: BoardGameCollectorApp()),
    );
  }
}
