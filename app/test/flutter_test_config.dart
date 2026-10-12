import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/goldens.dart';

/// Runs before every test file under test/ (T-015).
///
/// Golden images are rendered only on Linux (docs/decisions.md). When
/// `flutter test --update-goldens` runs on Windows or macOS, no test runs:
/// each file reports one failing test that points to the Docker command, so
/// no PNG can be written. Otherwise the comparator is wrapped so that a
/// golden update off Linux still fails.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final refusal = goldenUpdateGuard(
    isLinux: Platform.isLinux,
    updating: autoUpdateGoldenFiles,
  );
  if (refusal != null) {
    test('golden update guard', () => fail(refusal));
    return;
  }
  goldenFileComparator = LinuxOnlyGoldenComparator(
    goldenFileComparator,
    isLinux: Platform.isLinux,
  );
  await testMain();
}
