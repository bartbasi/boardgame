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
      // A generated file needs the header as well as the name (round 3).
      File('${temp.path}/lib/core/b.g.dart')
          .writeAsStringSync("$generatedHeader\n\npart of 'b.dart';\n");
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
      expect(
        syncImportsTest(write: false, root: temp.path),
        contains('out of date'),
      );
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

  group('round 3: exemptions match the server gate', () {
    const header = '$generatedHeader\n\n';
    final full = _record('lib/core/a.dart', {1: 1, 2: 1});

    test('ignore-file marker matches coverage, prose mentions do not', () {
      expect(hasIgnoreFile('// coverage:ignore-file\nclass A {}\n'), isTrue);
      expect(
        hasIgnoreFile('class A {} //coverage:ignore-file reason\n'),
        isTrue,
      );
      expect(
        hasIgnoreFile('// coverage:ignore-file\r\nclass A {}\r\n'),
        isTrue,
      );
      expect(
        hasIgnoreFile('// We never use // coverage:ignore-file, see docs.\n'),
        isFalse,
      );
    });

    test('ignore-file in a domain file fails and is not "no lines"', () {
      final gate = evaluateGate(full, {
        'lib/core/a.dart': 'int a() => 1;',
        'lib/features/x/domain/use_case.dart':
            '// coverage:ignore-file\nint run() => 1;\n',
      });
      expect(gate.passed, isFalse);
      expect(gate.noExecutableLines, isEmpty);
      expect(
        gate.report,
        contains(
          'FAIL: coverage:ignore-file marker in a domain or data file: '
          'lib/features/x/domain/use_case.dart',
        ),
      );
      expect(gate.report, isNot(contains('no executable lines: lib/features')));
    });

    test('ignore-file in a data file passes only when allowlisted', () {
      final sources = {
        'lib/core/a.dart': 'int a() => 1;',
        'lib/features/x/data/source.dart': '// coverage:ignore-file\n',
      };
      expect(evaluateGate(full, sources).passed, isFalse);
      final allowed = evaluateGate(
        full,
        sources,
        allowlist: {'lib/features/x/data/source.dart': 'platform glue'},
      );
      expect(allowed.passed, isTrue);
      expect(
        allowed.report,
        contains(
          'coverage:ignore-file marker, allowlisted: platform glue: '
          'lib/features/x/data/source.dart',
        ),
      );
    });

    test('ignore-file in lib/core is exempt and printed with its reason', () {
      final gate = evaluateGate(full, {
        'lib/core/a.dart': 'int a() => 1;',
        'lib/core/glue.dart': '// coverage:ignore-file\nint g() => 1;\n',
      });
      expect(gate.passed, isTrue);
      expect(
        gate.report,
        contains('coverage:ignore-file marker: lib/core/glue.dart'),
      );
    });

    test(
      'a file absent from lcov without a marker has no executable lines',
      () {
        final gate = evaluateGate(full, {
          'lib/core/a.dart': 'int a() => 1;',
          'lib/features/x/domain/repo.dart':
              'abstract interface class Repo {\n  int count();\n}\n',
        });
        expect(gate.passed, isTrue);
        expect(gate.noExecutableLines, ['lib/features/x/domain/repo.dart']);
        expect(
          gate.report,
          contains('no executable lines: lib/features/x/domain/repo.dart'),
        );
      },
    );

    test('a real generated file is exempt and listed', () {
      final gate = evaluateGate(
        full + _record('lib/core/a.g.dart', {1: 0, 2: 0}),
        {
          'lib/core/a.dart': 'int a() => 1;',
          'lib/core/a.g.dart': "${header}part of 'a.dart';\n",
        },
      );
      expect(gate.passed, isTrue);
      expect(gate.result.found, 2);
      expect(
        gate.report,
        contains('generated (GENERATED CODE header): lib/core/a.g.dart'),
      );
      expect(gate.report, contains('Exempt files: 1'));
    });

    test('a renamed .g.dart without the header is in scope and fails', () {
      const path = 'lib/features/x/data/repo_impl.g.dart';
      final gate = evaluateGate(full + _record(path, {1: 0, 2: 0, 3: 0}), {
        'lib/core/a.dart': 'int a() => 1;',
        path: 'class RepoImpl {\n  int count() => 1;\n}\n',
      });
      expect(isGenerated(path, 'class RepoImpl {}'), isFalse);
      expect(gate.result.untested, [path]);
      expect(gate.passed, isFalse);
      expect(gate.report, contains('FAIL: no test runs any line of $path'));
      expect(scopeFiles({path: 'class RepoImpl {}'}), [path]);
    });

    test('the header must be in the first five lines', () {
      const path = 'lib/core/x.g.dart';
      expect(isGenerated(path, '$header// x'), isTrue);
      expect(isGenerated(path, '\n\n\n\n\n$generatedHeader'), isFalse);
      expect(isGenerated('lib/core/x.dart', header), isFalse);
    });

    test(
      'files with ignore-start/end/line markers are listed with a count',
      () {
        const source =
            'int a() {\n'
            '  return 1; // coverage:ignore-line\n'
            '}\n'
            '// coverage:ignore-start\n'
            'int b() => 2;\n'
            '// coverage:ignore-end\n'
            '// mentions // coverage:ignore-line in prose.\n';
        expect(ignoreMarkerCount(source), 3);
        final gate = evaluateGate(_record('lib/core/a.dart', {1: 1}), {
          'lib/core/a.dart': source,
        });
        expect(gate.markers, {'lib/core/a.dart': 3});
        expect(gate.report, contains('3 marker line(s): lib/core/a.dart'));
      },
    );

    test('a 0/0 file shows as n/a', () {
      final gate = evaluateGate(full + _record('lib/core/empty.dart', {}), {
        'lib/core/a.dart': 'int a() => 1;',
        'lib/core/empty.dart': '',
      });
      expect(gate.report, contains('0/0  lib/core/empty.dart  (n/a'));
    });

    test('failure lines become annotations and the summary is markdown', () {
      final gate = evaluateGate(_record('lib/core/a.dart', {1: 0, 2: 1}), {
        'lib/core/a.dart': 'int a() => 1;',
      });
      final notes = annotations(gate.report);
      expect(notes, contains('::error::FAIL: 50.0% (1/2 lines)'));
      expect(notes.split('\n').where((l) => l.isNotEmpty), hasLength(1));
      final summary = stepSummary(gate.report);
      expect(summary, startsWith('### App coverage gate\n\n```\n'));
      expect(summary, contains('FAIL: 50.0%'));
      expect(summary, endsWith('```\n'));
    });

    test('layerSources reads only layer files, relative to lib', () {
      final temp = Directory.systemTemp.createTempSync('coverage_sources');
      addTearDown(() => temp.deleteSync(recursive: true));
      File('${temp.path}/lib/core/a.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('int a() => 1;');
      File('${temp.path}/lib/features/x/presentation/s.dart')
          .createSync(recursive: true);
      expect(layerSources(Directory('${temp.path}/lib')), {
        'lib/core/a.dart': 'int a() => 1;',
      });
    });
  });
}
