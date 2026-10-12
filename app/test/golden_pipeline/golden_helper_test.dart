import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/goldens.dart';

/// Unit and widget tests for the golden pipeline (T-015 AC3, AC4, AC5).
/// They run on every platform; the goldens themselves run only on Linux.
void main() {
  group('AC3 goldenUpdateGuard', () {
    test('refuses an update on Windows or macOS', () {
      expect(
        goldenUpdateGuard(isLinux: false, updating: true),
        goldenUpdateRefusal,
      );
    });

    test('allows an update on Linux', () {
      expect(goldenUpdateGuard(isLinux: true, updating: true), isNull);
    });

    test('allows comparing on any platform', () {
      expect(goldenUpdateGuard(isLinux: false, updating: false), isNull);
      expect(goldenUpdateGuard(isLinux: true, updating: false), isNull);
    });

    test('the message points to the CI golden run', () {
      expect(goldenUpdateRefusal, contains(goldenUpdateCommand));
      expect(goldenUpdateRefusal, contains('gh run download'));
      expect(goldenUpdateRefusal, contains('No PNG was written'));
      expect(
        goldenUpdateCommand,
        'gh workflow run app.yml --ref <branch> -f update_goldens=true',
      );
    });
  });

  group('AC3 LinuxOnlyGoldenComparator', () {
    final golden = Uri.parse('app_shell_default_light_compact.png');
    final bytes = Uint8List.fromList([1, 2, 3]);

    test('off Linux, update throws and writes nothing', () async {
      final delegate = _RecordingComparator();
      final comparator = LinuxOnlyGoldenComparator(delegate, isLinux: false);

      await expectLater(
        comparator.update(golden, bytes),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            goldenUpdateRefusal,
          ),
        ),
      );
      expect(delegate.updates, isEmpty);
    });

    test('on Linux, update writes through the delegate', () async {
      final delegate = _RecordingComparator();
      final comparator = LinuxOnlyGoldenComparator(delegate, isLinux: true);

      await comparator.update(golden, bytes);

      expect(delegate.updates, [golden]);
    });

    test('compare and getTestUri delegate on every platform', () async {
      for (final isLinux in [true, false]) {
        final delegate = _RecordingComparator();
        final comparator = LinuxOnlyGoldenComparator(
          delegate,
          isLinux: isLinux,
        );

        expect(await comparator.compare(bytes, golden), isTrue);
        expect(
          comparator.getTestUri(golden, 2),
          Uri.parse('app_shell_default_light_compact.2.png'),
        );
        expect(delegate.compares, [golden]);
      }
    });
  });

  group('AC5 and AC6 goldenFileName', () {
    test('names the eight app shell goldens as the spec lists them', () {
      String name(
        String? state,
        GoldenTheme theme,
        GoldenSize size, [
        GoldenTextScale scale = GoldenTextScale.normal,
      ]) => goldenFileName(
        screen: 'app_shell',
        state: state,
        theme: theme,
        size: size,
        textScale: scale,
      );

      expect(
        [
          name('default', GoldenTheme.light, GoldenSize.compact),
          name('default', GoldenTheme.dark, GoldenSize.compact),
          name('default', GoldenTheme.light, GoldenSize.expanded),
          name('default', GoldenTheme.dark, GoldenSize.expanded),
          name('default', GoldenTheme.light, GoldenSize.medium),
          name('default', GoldenTheme.light, GoldenSize.landscape),
          name(null, GoldenTheme.light, GoldenSize.compact, .large),
          name(null, GoldenTheme.dark, GoldenSize.expanded, .large),
        ],
        [
          'app_shell_default_light_compact.png',
          'app_shell_default_dark_compact.png',
          'app_shell_default_light_expanded.png',
          'app_shell_default_dark_expanded.png',
          'app_shell_default_light_medium.png',
          'app_shell_default_light_landscape.png',
          'app_shell_text200_light_compact.png',
          'app_shell_text200_dark_expanded.png',
        ],
      );
    });

    test('adds text200 to a named state at large text', () {
      expect(
        goldenFileName(
          screen: 'game_detail',
          state: 'longtitle',
          theme: GoldenTheme.light,
          size: GoldenSize.compact,
          textScale: GoldenTextScale.large,
        ),
        'game_detail_longtitle_text200_light_compact.png',
      );
      expect(
        goldenFileName(
          screen: 'listings',
          state: 'success',
          theme: GoldenTheme.dark,
          size: GoldenSize.landscape,
          textScale: GoldenTextScale.large,
        ),
        'listings_success_text200_dark_landscape.png',
      );
    });

    test('every theme, size, and text scale gives a distinct name', () {
      final names = {
        for (final theme in GoldenTheme.values)
          for (final size in GoldenSize.values)
            for (final scale in GoldenTextScale.values)
              goldenFileName(
                screen: 'scanner',
                state: 'denied',
                theme: theme,
                size: size,
                textScale: scale,
              ),
      };
      expect(names, hasLength(16));
      for (final name in names) {
        expect(
          name,
          matches(
            RegExp(
              r'^scanner_denied(_text200)?_(light|dark)_'
              r'(compact|medium|expanded|landscape)\.png$',
            ),
          ),
        );
      }
    });

    test('a missing state is allowed only at large text', () {
      expect(
        () => goldenFileName(
          screen: 'app_shell',
          state: null,
          theme: GoldenTheme.light,
          size: GoldenSize.compact,
        ),
        throwsArgumentError,
      );
    });

    test('rejects names that are not lower_snake_case', () {
      for (final (screen, state) in [
        ('AppShell', 'default'),
        ('app-shell', 'default'),
        ('app_shell', 'Default'),
        ('app_shell', 'price success'),
        ('', 'default'),
        ('app_shell', ''),
      ]) {
        expect(
          () => goldenFileName(
            screen: screen,
            state: state,
            theme: GoldenTheme.light,
            size: GoldenSize.compact,
          ),
          throwsArgumentError,
          reason: '$screen / $state',
        );
      }
    });

    test('sizes, themes, and scales match the shared test definitions', () {
      expect(GoldenSize.compact.size, const Size(390, 844));
      expect(GoldenSize.medium.size, const Size(744, 1133));
      expect(GoldenSize.expanded.size, const Size(1280, 800));
      expect(GoldenSize.landscape.size, const Size(844, 390));
      expect(GoldenTheme.light.brightness, Brightness.light);
      expect(GoldenTheme.dark.brightness, Brightness.dark);
      expect(GoldenTextScale.normal.factor, 1.0);
      expect(GoldenTextScale.large.factor, 2.0);
    });
  });

  group('AC5 setGoldenWindow', () {
    for (final size in GoldenSize.values) {
      for (final theme in GoldenTheme.values) {
        for (final scale in GoldenTextScale.values) {
          testWidgets('${size.name} ${theme.name} ${scale.factor}', (
            tester,
          ) async {
            setGoldenWindow(tester, size: size, theme: theme, textScale: scale);
            late MediaQueryData data;
            await tester.pumpWidget(
              Builder(
                builder: (context) {
                  data = MediaQuery.of(context);
                  return const SizedBox();
                },
              ),
            );

            expect(data.size, size.size);
            expect(data.platformBrightness, theme.brightness);
            expect(data.textScaler.scale(10), 10 * scale.factor);
            expect(data.devicePixelRatio, 1);
          });
        }
      }
    }
  });

  group('AC4 and AC8 fonts', () {
    test('the committed Roboto files carry the Apache 2.0 notice', () {
      // Name table entry 13 (license description), stored as UTF-16BE.
      final notice = <int>[
        for (final unit
            in 'Licensed under the Apache License, Version 2.0'.codeUnits) ...[
          0,
          unit,
        ],
      ];
      for (final file in robotoFontFiles) {
        final bytes = File('$goldenFontDirectory/$file').readAsBytesSync();
        expect(_indexOf(bytes, notice), isNot(-1), reason: file);
      }
      expect(
        File('$goldenFontDirectory/LICENSE').readAsStringSync(),
        contains('Apache License'),
      );
    });

    testWidgets('the app bundles Material Icons, which goldens load', (
      tester,
    ) async {
      final assets = await tester.runAsync(bundledFontAssets);
      expect(assets!.keys, contains('MaterialIcons'));
      expect(assets['MaterialIcons'], isNotEmpty);
    });

    testWidgets('text renders in Roboto, not the square test font', (
      tester,
    ) async {
      // The test font draws every glyph as a square as wide as the font
      // size, so "il" at 20 is 40 wide. Roboto's i and l are narrow.
      double widthOf(String family) {
        final painter = TextPainter(
          text: TextSpan(
            text: 'il',
            style: TextStyle(fontFamily: family, fontSize: 20),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        addTearDown(painter.dispose);
        return painter.width;
      }

      expect(widthOf('Roboto'), 40);
      await tester.runAsync(loadGoldenFonts);
      await tester.runAsync(loadGoldenFonts); // A second call is a no-op.
      expect(widthOf('Roboto'), lessThan(20));
    });
  });
}

int _indexOf(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}

class _RecordingComparator extends GoldenFileComparator {
  final List<Uri> compares = [];
  final List<Uri> updates = [];

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    compares.add(golden);
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    updates.add(golden);
  }
}
