import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

/// The documented way to render goldens (docs/decisions.md 2026-10-12):
/// the manual app.yml run on GitHub Actions, then download its artifact and
/// commit the PNGs. Steps in docs/handoffs/T-015.md.
const String goldenUpdateCommand =
    'gh workflow run app.yml --ref <branch> -f update_goldens=true';

/// Why `--update-goldens` is refused off Linux.
const String goldenUpdateRefusal =
    'Golden images are rendered only on GitHub Actions (Linux), so they '
    'match CI exactly (docs/decisions.md). Do not run flutter test '
    '--update-goldens on Windows or macOS. Run $goldenUpdateCommand, then '
    'download the "goldens" artifact with gh run download and commit the '
    'PNGs. No PNG was written.';

/// Why golden tests are skipped off Linux.
const String goldenSkipReason =
    'Goldens are compared only on Linux (the app.yml checks job on GitHub '
    'Actions).';

/// Returns the refusal message when golden files would be written on a
/// platform other than Linux, otherwise null.
String? goldenUpdateGuard({required bool isLinux, required bool updating}) =>
    updating && !isLinux ? goldenUpdateRefusal : null;

/// A comparator that refuses to write golden files off Linux and otherwise
/// delegates to [delegate] (normally the [LocalFileComparator] that
/// flutter_test creates for each test file).
///
/// flutter_test_config.dart installs it as a second line of defense: it also
/// catches code that sets [autoUpdateGoldenFiles] by hand.
class LinuxOnlyGoldenComparator extends GoldenFileComparator {
  LinuxOnlyGoldenComparator(this.delegate, {required this.isLinux});

  final GoldenFileComparator delegate;
  final bool isLinux;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) =>
      delegate.compare(imageBytes, golden);

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    if (!isLinux) throw StateError(goldenUpdateRefusal);
    await delegate.update(golden, imageBytes);
  }

  @override
  Uri getTestUri(Uri key, int? version) => delegate.getTestUri(key, version);
}

/// Golden themes; the app follows the platform brightness.
enum GoldenTheme {
  light(Brightness.light),
  dark(Brightness.dark);

  const GoldenTheme(this.brightness);

  final Brightness brightness;
}

/// The four shared window sizes ("Shared test definitions", docs/backlog.md).
enum GoldenSize {
  compact(WindowSizes.compact),
  medium(WindowSizes.medium),
  expanded(WindowSizes.expanded),
  landscape(WindowSizes.landscape);

  const GoldenSize(this.size);

  final Size size;
}

/// Text scales used by goldens: 1.0, and 2.0 for large text.
enum GoldenTextScale {
  normal(1),
  large(largeTextScale);

  const GoldenTextScale(this.factor);

  final double factor;
}

/// File name `<screen>_<state>_<theme>_<size>.png`.
///
/// At [GoldenTextScale.large] the state always gets the `text200` suffix,
/// the default state included (`app_shell_default_text200_light_compact.png`,
/// UX decision in T-015 round 3). There is no bare `text200` form.
String goldenFileName({
  required String screen,
  required String state,
  required GoldenTheme theme,
  required GoldenSize size,
  GoldenTextScale textScale = GoldenTextScale.normal,
}) {
  final namePart = RegExp(r'^[a-z0-9]+(_[a-z0-9]+)*$');
  if (!namePart.hasMatch(screen)) {
    throw ArgumentError.value(screen, 'screen', 'use lower_snake_case');
  }
  if (!namePart.hasMatch(state)) {
    throw ArgumentError.value(state, 'state', 'use lower_snake_case');
  }
  if (state.split('_').contains('text200')) {
    throw ArgumentError.value(
      state,
      'state',
      'text200 is added from the text scale, not written in the state',
    );
  }
  final stateLabel = switch (textScale) {
    GoldenTextScale.normal => state,
    GoldenTextScale.large => '${state}_text200',
  };
  return '${screen}_${stateLabel}_${theme.name}_${size.name}.png';
}

/// Roboto, committed for tests only (Apache 2.0; see
/// test/fonts/roboto/README.md and docs/handoffs/T-015.md). Roboto is the
/// Material type scale's family on Android, the platform widget tests use.
/// The Linux Flutter SDK archive has no Roboto, so the SDK cannot supply it.
///
/// Relative to app/, the working directory of `flutter test`.
const String goldenFontDirectory = 'test/fonts/roboto';

/// Roboto weights the Material 3 type scale uses (400 and 500) plus bold.
const List<String> robotoFontFiles = [
  'Roboto-Regular.ttf',
  'Roboto-Medium.ttf',
  'Roboto-Bold.ttf',
];

bool _fontsLoaded = false;

/// Loads real fonts into the test engine, once per test file: Roboto from
/// [goldenFontDirectory], and every font the app itself bundles (today only
/// Material Icons, from `uses-material-design: true`) from the test asset
/// bundle. Without this, text renders as boxes.
///
/// Inside testWidgets, call it through `tester.runAsync`.
Future<void> loadGoldenFonts() async {
  if (_fontsLoaded) return;
  final roboto = FontLoader('Roboto');
  for (final file in robotoFontFiles) {
    final bytes = File('$goldenFontDirectory/$file').readAsBytesSync();
    roboto.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await roboto.load();

  final bundled = await bundledFontAssets();
  for (final MapEntry(key: family, value: assets) in bundled.entries) {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
  _fontsLoaded = true;
}

/// Font families and their asset keys from the app's FontManifest.json.
Future<Map<String, List<String>>> bundledFontAssets() async {
  final json = jsonDecode(await rootBundle.loadString('FontManifest.json'));
  final families = (json as List<Object?>).cast<Map<String, Object?>>();
  return {
    for (final family in families)
      family['family']! as String: [
        for (final font
            in (family['fonts']! as List<Object?>).cast<Map<String, Object?>>())
          font['asset']! as String,
      ],
  };
}

/// Sets the test window for a golden: [size], [theme] as the platform
/// brightness, and [textScale]. Reset when the test ends.
void setGoldenWindow(
  WidgetTester tester, {
  required GoldenSize size,
  required GoldenTheme theme,
  required GoldenTextScale textScale,
}) {
  setTestWindow(
    tester,
    size: size.size,
    textScale: textScale.factor,
    brightness: theme.brightness,
  );
}

/// One golden: a screen state in a theme, window size, and text scale.
class GoldenCase {
  const GoldenCase(
    this.screen,
    this.state,
    this.theme,
    this.size, [
    this.textScale = GoldenTextScale.normal,
  ]);

  final String screen;
  final String state;
  final GoldenTheme theme;
  final GoldenSize size;
  final GoldenTextScale textScale;

  /// See [goldenFileName].
  String get fileName => goldenFileName(
    screen: screen,
    state: state,
    theme: theme,
    size: size,
    textScale: textScale,
  );
}

/// The folder every golden test file and PNG lives in, relative to app/.
/// Flat: the render job (app.yml goldens-update) runs only this folder, and
/// its artifact is downloaded straight into it.
const String goldenDirectory = 'test/goldens';

/// Returns why golden tests may not be declared in the test file whose
/// folder is [testFileDirectory], or null when it is [goldenDirectory]
/// itself (not a subfolder).
String? goldenLocationError(Uri testFileDirectory) {
  final segments = testFileDirectory.pathSegments
      .where((s) => s.isNotEmpty)
      .toList();
  final n = segments.length;
  if (n >= 2 && segments[n - 2] == 'test' && segments[n - 1] == 'goldens') {
    return null;
  }
  return 'Golden tests must live directly in app/$goldenDirectory/ (found '
      'one in ${testFileDirectory.toFilePath()}). The app.yml render job '
      'runs only that folder, so a golden anywhere else could never be '
      'rendered.';
}

/// The folder of the running test file, read from the golden comparator
/// flutter_test creates for it, or null when it is not known.
Uri? currentTestFileDirectory([GoldenFileComparator? comparator]) {
  final c = comparator ?? goldenFileComparator;
  return switch (c) {
    LinuxOnlyGoldenComparator(:final delegate) => currentTestFileDirectory(
      delegate,
    ),
    LocalFileComparator(:final basedir) => basedir,
    _ => null,
  };
}

/// Declares one [goldenTest] per case in [cases].
void goldenTests(List<GoldenCase> cases, {required Widget Function() build}) {
  for (final c in cases) {
    goldenTest(
      screen: c.screen,
      state: c.state,
      theme: c.theme,
      size: c.size,
      textScale: c.textScale,
      build: build,
    );
  }
}

final Key _goldenBoundary = UniqueKey();

/// Declares one golden test that renders [build] full window and compares it
/// with `<screen>_<state>_<theme>_<size>.png` next to the calling test file
/// (which lives in app/test/goldens/).
///
/// [build] returns the whole widget to pump (for example the app in a
/// ProviderScope, or a screen inside a themed MaterialApp). [arrange] runs
/// after the first settle, for taps or scrolling before the capture.
///
/// Skipped off Linux, with [goldenSkipReason] in the output. Throws a
/// [StateError] on every platform when the calling test file is not directly
/// in [goldenDirectory] (see [goldenLocationError]), so the test file fails
/// to load.
void goldenTest({
  required String screen,
  required String state,
  required GoldenTheme theme,
  required GoldenSize size,
  GoldenTextScale textScale = GoldenTextScale.normal,
  required Widget Function() build,
  Future<void> Function(WidgetTester tester)? arrange,
}) {
  final fileName = goldenFileName(
    screen: screen,
    state: state,
    theme: theme,
    size: size,
    textScale: textScale,
  );
  final directory = currentTestFileDirectory();
  final locationError = directory == null
      ? null
      : goldenLocationError(directory);
  if (locationError != null) throw StateError(locationError);
  testWidgets(fileName, (tester) async {
    if (!Platform.isLinux) {
      markTestSkipped(goldenSkipReason);
      return;
    }
    await tester.runAsync(loadGoldenFonts);
    setGoldenWindow(tester, size: size, theme: theme, textScale: textScale);
    await tester.pumpWidget(
      RepaintBoundary(key: _goldenBoundary, child: build()),
    );
    await tester.pumpAndSettle();
    if (arrange != null) {
      await arrange(tester);
      await tester.pumpAndSettle();
    }
    await expectLater(find.byKey(_goldenBoundary), matchesGoldenFile(fileName));
  });
}
