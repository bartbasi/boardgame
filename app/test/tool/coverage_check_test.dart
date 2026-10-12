import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/coverage_check.dart';

String _record(String path, Map<int, int> hits) {
  final b = StringBuffer()..writeln('SF:$path');
  hits.forEach((line, count) => b.writeln('DA:$line,$count'));
  b
    ..writeln('LF:${hits.length}')
    ..writeln('LH:${hits.values.where((c) => c > 0).length}')
    ..writeln('end_of_record');
  return b.toString();
}

void main() {
  group('isInScope', () {
    test('counts lib/core and feature domain and data layers', () {
      expect(isInScope('lib/core/theme/app_theme.dart'), isTrue);
      expect(isInScope('lib/features/pricing/domain/price.dart'), isTrue);
      expect(isInScope('lib/features/pricing/data/dto_mapper.dart'), isTrue);
      expect(isInScope(r'lib\features\scanner\data\a.dart'), isTrue);
    });

    test('leaves out presentation, app, l10n and generated files', () {
      expect(isInScope('lib/features/pricing/presentation/x.dart'), isFalse);
      expect(isInScope('lib/app/app.dart'), isFalse);
      expect(isInScope('lib/l10n/app_localizations.dart'), isFalse);
      expect(isInScope('lib/core/theme/theme_mode_controller.g.dart'), isFalse);
      expect(isInScope('lib/features/a/domain/game.freezed.dart'), isFalse);
      expect(isInScope('lib/core/README.md'), isFalse);
    });
  });

  group('normalizePath', () {
    test('accepts Windows, relative and absolute paths', () {
      expect(normalizePath(r'lib\core\a.dart'), 'lib/core/a.dart');
      expect(
        normalizePath('/home/runner/work/app/lib/core/a.dart'),
        'lib/core/a.dart',
      );
      expect(normalizePath(r'C:\x\app\lib\core\a.dart'), 'lib/core/a.dart');
      expect(normalizePath('test/a.dart'), 'test/a.dart');
    });
  });

  group('parseLcov', () {
    test('counts DA lines per file and merges duplicate lines', () {
      final files = parseLcov(
        '${_record('lib/core/a.dart', {1: 1, 2: 0, 3: 4})}'
        'SF:lib/core/b.dart\nDA:1,0\nDA:1,2\nDA:2,0\nend_of_record\n',
      );
      expect(files.map((f) => f.path), ['lib/core/a.dart', 'lib/core/b.dart']);
      expect([files[0].hit, files[0].found], [2, 3]);
      expect([files[1].hit, files[1].found], [1, 2]);
    });

    test('ignores malformed DA records and CRLF line ends', () {
      final files = parseLcov(
        'SF:lib/core/a.dart\r\nDA:x,1\r\nDA:3\r\nDA:4,1,abc\r\nend_of_record\r\n',
      );
      expect([files.single.hit, files.single.found], [1, 1]);
    });
  });

  group('checkCoverage', () {
    test('passes at exactly the minimum', () {
      final result = checkCoverage(
        _record('lib/core/a.dart', {1: 1, 2: 1, 3: 1, 4: 1, 5: 0}),
      );
      expect(result.percent, 80);
      expect(result.passed, isTrue);
    });

    test('fails just below the minimum', () {
      final hits = {for (var i = 1; i <= 100; i++) i: i <= 79 ? 1 : 0};
      final result = checkCoverage(_record('lib/core/a.dart', hits));
      expect(result.percent, 79);
      expect(result.passed, isFalse);
      expect(formatReport(result, const []), contains('FAIL: 79.0%'));
    });

    test('totals across files and ignores files out of scope', () {
      final result = checkCoverage(
        _record('lib/features/a/domain/x.dart', {1: 1, 2: 1}) +
            _record('lib/features/a/data/y.dart', {1: 0, 2: 1}) +
            _record('lib/features/a/presentation/z.dart', {1: 0, 2: 0}) +
            _record('lib/core/c.g.dart', {1: 0}),
      );
      expect(result.files.map((f) => f.path), [
        'lib/features/a/data/y.dart',
        'lib/features/a/domain/x.dart',
      ]);
      expect([result.hit, result.found], [3, 4]);
      expect(result.passed, isFalse);
    });

    test('honors a custom minimum', () {
      final result = checkCoverage(
        _record('lib/core/a.dart', {1: 1, 2: 0}),
        minPercent: 50,
      );
      expect(result.passed, isTrue);
    });

    test('fails when nothing is in scope', () {
      final result = checkCoverage(_record('lib/app/app.dart', {1: 1}));
      expect(result.percent, isNull);
      expect(result.passed, isFalse);
      expect(formatReport(result, const []), contains('FAIL: no executable'));
    });

    test('recorded Windows report from T-012 passes with core files only', () {
      final lcov = File('test/fixtures/lcov/lcov_windows_t012.info')
          .readAsStringSync();
      final result = checkCoverage(lcov);
      expect(result.files.map((f) => f.path), [
        'lib/core/layout/window_size_class.dart',
        'lib/core/theme/app_theme.dart',
        'lib/core/theme/theme_mode_controller.dart',
        'lib/core/widgets/placeholder_body.dart',
      ]);
      expect(result.passed, isTrue);
    });
  });

  group('unloadedFiles', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('coverage_check'));
    tearDown(() => temp.deleteSync(recursive: true));

    test('lists in-scope files that no test loaded', () {
      for (final path in [
        'lib/core/a.dart',
        'lib/core/b.dart',
        'lib/core/b.g.dart',
        'lib/features/x/domain/repo.dart',
        'lib/features/x/presentation/screen.dart',
      ]) {
        File('${temp.path}/$path').createSync(recursive: true);
      }
      final result = checkCoverage(_record('lib/core/a.dart', {1: 1}));
      final missing = unloadedFiles(Directory('${temp.path}/lib'), result);
      expect(missing, ['lib/core/b.dart', 'lib/features/x/domain/repo.dart']);
      expect(
        formatReport(result, missing),
        contains('no executable lines: lib/core/b.dart'),
      );
    });

    test('returns nothing when the folder is missing', () {
      final result = checkCoverage('');
      expect(unloadedFiles(Directory('${temp.path}/nope'), result), isEmpty);
    });
  });

  group('round 2: strict gate', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('coverage_strict'));
    tearDown(() => temp.deleteSync(recursive: true));

    void writeFiles(List<String> paths) {
      File('${temp.path}/pubspec.yaml').writeAsStringSync('name: demo_app\n');
      for (final path in paths) {
        File('${temp.path}/$path').createSync(recursive: true);
      }
    }

    test('normalizePath cuts at the first /lib/ (T-014-B1)', () {
      expect(
        normalizePath('/home/runner/app/lib/features/x/data/lib/y.dart'),
        'lib/features/x/data/lib/y.dart',
      );
    });

    test('a file in scope with executable lines but no hits fails', () {
      final result = checkCoverage(
        _record('lib/core/a.dart', {for (var i = 1; i <= 20; i++) i: 1}) +
            _record('lib/features/x/data/untested.dart', {1: 0, 2: 0}),
      );
      expect(result.percent, closeTo(90.9, 0.1));
      expect(result.untested, ['lib/features/x/data/untested.dart']);
      expect(result.passed, isFalse);
      final report = formatReport(result, const []);
      expect(
        report,
        contains(
          'FAIL: no test runs any line of '
          'lib/features/x/data/untested.dart',
        ),
      );
      expect(report, contains('1 untested file(s)'));
    });

    test('a file with no executable lines missing from lcov passes', () {
      // An interface-only file is absent from lcov.info even when the
      // imports test loads it (checked with a probe file, T-014 round 1).
      writeFiles(['lib/core/a.dart', 'lib/features/x/domain/repo.dart']);
      final result = checkCoverage(_record('lib/core/a.dart', {1: 1}));
      final unloaded = unloadedFiles(Directory('${temp.path}/lib'), result);
      expect(unloaded, ['lib/features/x/domain/repo.dart']);
      expect(result.passed, isTrue);
      expect(
        formatReport(result, unloaded),
        contains('no executable lines: lib/features/x/domain/repo.dart'),
      );
    });

    test('filesInScope ignores folders above lib, even ones named lib', () {
      final nested = Directory('${temp.path}/lib/app')
        ..createSync(recursive: true);
      File('${nested.path}/lib/core/a.dart').createSync(recursive: true);
      File('${nested.path}/lib/features/x/presentation/s.dart')
          .createSync(recursive: true);
      expect(filesInScope(Directory('${nested.path}/lib')), [
        'lib/core/a.dart',
      ]);
    });

    test('packageName reads the pubspec name', () {
      expect(
        packageName('# c\nname: board_game_collector\n'),
        'board_game_collector',
      );
      expect(packageName('description: x\n'), isNull);
    });

    test('importsTestSource imports every file and has one test', () {
      final source = importsTestSource('demo_app', [
        'lib/core/a.dart',
        'lib/features/x/data/b.dart',
      ]);
      expect(source, contains("import 'package:demo_app/core/a.dart';"));
      expect(
        source,
        contains("import 'package:demo_app/features/x/data/b.dart';"),
      );
      expect(source, contains('// ignore_for_file: unused_import'));
      expect(source, contains("test('every file in the coverage gate loads'"));
      expect(sameSource(source.replaceAll('\n', '\r\n'), source), isTrue);
    });

    test('syncImportsTest fails when a new file in scope is not imported', () {
      writeFiles(['lib/core/a.dart']);
      expect(syncImportsTest(write: false, root: temp.path), contains('FAIL'));
      expect(syncImportsTest(write: true, root: temp.path), isNull);
      expect(syncImportsTest(write: false, root: temp.path), isNull);
      File('${temp.path}/lib/features/x/data/new.dart')
          .createSync(recursive: true);
      expect(
        syncImportsTest(write: false, root: temp.path),
        contains('--write-imports'),
      );
    });

    test('syncImportsTest reports a missing package name', () {
      expect(
        syncImportsTest(write: false, root: temp.path),
        contains('No package name'),
      );
    });

    test('the committed imports test is up to date', () {
      expect(syncImportsTest(write: false), isNull);
    });
  });
}
