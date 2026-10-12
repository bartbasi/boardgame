import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/coverage_check.dart';

String _record(String path, Map<int, int> hits) {
  final b = StringBuffer()..writeln('SF:$path');
  hits.forEach((line, count) => b.writeln('DA:$line,$count'));
  b.writeln('end_of_record');
  return b.toString();
}

Map<int, int> _hits(int hit, int total) => {
  for (var i = 1; i <= total; i++) i: i <= hit ? 1 : 0,
};

void main() {
  group('QA edge cases', () {
    test('empty lcov fails: nothing in scope', () {
      final r = checkCoverage('');
      expect(r.passed, isFalse);
      expect(r.percent, isNull);
      expect(formatReport(r, const []), contains('FAIL: no executable lines'));
    });

    test('whitespace-only lcov fails', () {
      expect(checkCoverage('\r\n\r\n  \n').passed, isFalse);
    });

    test('record with SF but no DA lines adds nothing and does not divide', () {
      final r = checkCoverage(
        _record('lib/core/a.dart', {}) +
            _record('lib/core/b.dart', _hits(8, 10)),
      );
      expect(r.found, 10);
      expect(r.percent, 80.0);
      expect(r.passed, isTrue);
      expect(formatReport(r, const []), contains('100.0%  0/0'));
    });

    test('exactly 80.0% across several files passes, 79.9% fails', () {
      final at = checkCoverage(
        _record('lib/core/a.dart', _hits(3, 5)) +
            _record('lib/features/x/data/b.dart', _hits(5, 5)),
      );
      expect(at.percent, 80.0);
      expect(at.passed, isTrue);
      final below = checkCoverage(_record('lib/core/a.dart', _hits(799, 1000)));
      expect(below.passed, isFalse);
      expect(formatReport(below, const []), contains('FAIL: 79.9%'));
    });

    test('record without end_of_record is dropped, not counted', () {
      final r = checkCoverage(
        'SF:lib/core/a.dart\nDA:1,1\n${_record('lib/core/b.dart', _hits(1, 2))}',
      );
      // The unterminated record is replaced by the next SF line.
      expect(r.files.map((f) => f.path), ['lib/core/b.dart']);
    });

    test('Windows absolute paths with drive letter and CRLF are in scope', () {
      final lcov = _record(
        r'C:\bart\app\lib\features\games\domain\game.dart',
        _hits(10, 10),
      ).replaceAll('\n', '\r\n');
      final r = checkCoverage(lcov);
      expect(r.files.single.path, 'lib/features/games/domain/game.dart');
      expect(r.passed, isTrue);
    });

    test('generated and non-dart files are out of scope', () {
      expect(isInScope('lib/core/a.g.dart'), isFalse);
      expect(isInScope('lib/features/x/data/a.freezed.dart'), isFalse);
      expect(isInScope('lib/core/readme.md'), isFalse);
      expect(isInScope('lib/features/x/presentation/a.dart'), isFalse);
      expect(isInScope('lib/features/x/domain.dart'), isFalse);
      expect(isInScope('lib/features/domain/a.dart'), isFalse);
      expect(isInScope('test/core/a.dart'), isFalse);
    });

    test(
      'a data file whose path contains a nested lib/ folder stays in scope',
      () {
        // normalizePath cuts at the LAST /lib/, so an absolute path with a
        // nested lib folder loses its layer prefix (see QA bug T-014-B1).
        expect(
          isInScope('/home/runner/app/lib/features/x/data/lib/y.dart'),
          isTrue,
        );
      },
    );
  });

  group('CLI exit codes (hermetic fixture package)', () {
    late Directory dir;
    final tool = File('tool/coverage_check.dart').absolute.path;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('covcheck');
      File('${dir.path}/pubspec.yaml').writeAsStringSync('name: fx\n');
      File('${dir.path}/lib/core/a.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('int a() => 1;\n');
      File('${dir.path}/$importsTestPath')
        ..createSync(recursive: true)
        ..writeAsStringSync(importsTestSource('fx', ['lib/core/a.dart']));
    });
    tearDown(() => dir.deleteSync(recursive: true));

    // Runs the tool inside the fixture package, never the real lib/.
    ProcessResult run(List<String> args, {Map<String, String>? env}) =>
        Process.runSync(
          'dart',
          [tool, ...args],
          workingDirectory: dir.path,
          runInShell: true,
          environment: env,
        );

    test(
      'a violating fixture file fails the CLI with ::error:: and summary',
      () {
        File('${dir.path}/lib/features/c/domain/u.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync('// coverage:ignore-file\nint u() => 1;\n');
        File('${dir.path}/$importsTestPath').writeAsStringSync(
          importsTestSource('fx', [
            'lib/core/a.dart',
            'lib/features/c/domain/u.dart',
          ]),
        );
        final info = File('${dir.path}/ok.info')
          ..writeAsStringSync(_record('lib/core/a.dart', _hits(10, 10)));
        final summary = File('${dir.path}/summary.md');
        final r = run(
          ['--lcov', info.path],
          env: {'GITHUB_STEP_SUMMARY': summary.path},
        );
        expect(r.exitCode, 1);
        final out = r.stdout as String;
        expect(out, contains('::error::FAIL: coverage:ignore-file marker'));
        expect(out, isNot(contains('no executable lines: lib/features/c')));
        expect(summary.readAsStringSync(), contains('### App coverage gate'));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('exit 0 on pass, 1 on fail, 2 on missing file and bad args', () {
      final pass = File('${dir.path}/pass.info')
        ..writeAsStringSync(_record('lib/core/a.dart', _hits(10, 10)));
      final fail = File('${dir.path}/fail.info')
        ..writeAsStringSync(_record('lib/core/a.dart', _hits(5, 10)));
      final empty = File('${dir.path}/empty.info')..writeAsStringSync('');
      expect(run(['--lcov', pass.path]).exitCode, 0);
      expect(run(['--lcov', fail.path]).exitCode, 1);
      expect(run(['--lcov', fail.path, '--min', '50']).exitCode, 0);
      expect(run(['--lcov', empty.path]).exitCode, 1);
      expect(run(['--lcov', '${dir.path}/missing.info']).exitCode, 2);
      expect(run(['--lcov']).exitCode, 2);
      expect(run(['--min', 'abc']).exitCode, 2);
      expect(run(['--bogus']).exitCode, 2);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
