import 'package:board_game_collector/core/layout/window_size_class.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WindowSizeClass.fromWidth', () {
    const cases = <(double, WindowSizeClass)>[
      (0, WindowSizeClass.compact),
      (390, WindowSizeClass.compact),
      (599.9, WindowSizeClass.compact),
      (600, WindowSizeClass.medium),
      (744, WindowSizeClass.medium),
      (839.9, WindowSizeClass.medium),
      (840, WindowSizeClass.expanded),
      (844, WindowSizeClass.expanded),
      (1280, WindowSizeClass.expanded),
    ];
    for (final (width, expected) in cases) {
      test('$width dp is ${expected.name}', () {
        expect(WindowSizeClass.fromWidth(width), expected);
      });
    }
  });
}
