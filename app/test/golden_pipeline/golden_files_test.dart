import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../goldens/app_shell_golden_test.dart' as app_shell;
import '../goldens/manual_entry_golden_test.dart' as manual_entry;
import '../goldens/scanner_golden_test.dart' as scanner;
import '../helpers/goldens.dart';

/// Every golden test file in test/goldens/ and its declared cases. Add a
/// line here with each new golden test file.
///
/// This file lives outside test/goldens/ on purpose: the render job runs only
/// that folder, and a renamed case leaves its old PNG behind until it is
/// deleted, which must not stop the render.
final Map<String, List<GoldenCase>> declaredGoldens = {
  'app_shell_golden_test.dart': app_shell.appShellGoldenCases,
  'manual_entry_golden_test.dart': manual_entry.manualEntryGoldenCases,
  'scanner_golden_test.dart': scanner.scannerGoldenCases,
};

/// T-015 review R1-G1 and R1-G2: goldens stay flat in test/goldens/, and
/// every committed PNG belongs to a declared case. Runs on every platform.
void main() {
  final goldens = Directory(goldenDirectory);

  Set<String> namesIn(Directory dir, bool Function(String) keep) => {
    for (final entity in dir.listSync())
      if (entity is File && keep(_basename(entity.path)))
        _basename(entity.path),
  };

  test('every golden test file is listed in declaredGoldens', () {
    expect(
      namesIn(goldens, (n) => n.endsWith('_golden_test.dart')),
      declaredGoldens.keys.toSet(),
    );
  });

  test('no orphaned PNG: each one in test/goldens has a declared case', () {
    final declared = {
      for (final cases in declaredGoldens.values)
        for (final c in cases) c.fileName,
    };
    final committed = namesIn(goldens, (n) => n.endsWith('.png'));
    expect(
      committed.difference(declared),
      isEmpty,
      reason:
          'Delete PNGs whose golden case was renamed or removed, or declare '
          'the case.',
    );
    expect(
      declared.difference(committed),
      isEmpty,
      reason:
          'Render missing goldens with the app.yml update_goldens run '
          '(docs/handoffs/T-015.md).',
    );
  });

  test('declared golden names are unique', () {
    final names = [
      for (final cases in declaredGoldens.values)
        for (final c in cases) c.fileName,
    ];
    expect(names.toSet(), hasLength(names.length));
  });

  test('goldens are flat: no PNG elsewhere under test/', () {
    final stray = [
      for (final entity in Directory('test').listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.png') &&
            _slashes(entity.parent.path) != goldenDirectory &&
            !_slashes(entity.path).contains('/failures/'))
          entity.path,
    ];
    expect(stray, isEmpty);
  });

  test('the folder holds only golden tests and PNGs', () {
    final other = [
      for (final entity in goldens.listSync())
        if (!(entity is Directory && _basename(entity.path) == 'failures') &&
            !(entity is File &&
                (entity.path.endsWith('_golden_test.dart') ||
                    entity.path.endsWith('.png'))))
          entity.path,
    ];
    expect(other, isEmpty);
  });
}

String _slashes(String path) => path.replaceAll(r'\', '/');

String _basename(String path) => _slashes(path).split('/').last;
