// T-099: coverage gate verdict line, ignore-start/end parity, the path-only
// scope helper, and hand-written part files.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/coverage_check.dart';

String _rec(String path, int hit, int total) {
  final b = StringBuffer()..writeln('SF:$path');
  for (var i = 1; i <= total; i++) {
    b.writeln('DA:$i,${i <= hit ? 1 : 0}');
  }
  b.writeln('end_of_record');
  return b.toString();
}

List<String> _failLines(String report) =>
    report.split('\n').where((l) => l.startsWith('FAIL')).toList();

List<String> _annotationLines(String report) =>
    annotations(report).split('\n').where((l) => l.isNotEmpty).toList();

String _lastLine(String report) => report.trimRight().split('\n').last;

const _core = 'lib/core/a.dart';
const _coreSrc = 'int a() => 1;\n';
const _domain = 'lib/features/x/domain/use_case.dart';
const _data = 'lib/features/x/data/source.dart';
const _ignoreFileSrc = '// coverage:ignore-file\nint run() => 1;\n';
const _rangeSrc =
    '// coverage:ignore-start\n'
    'int run() => 1;\n'
    'int other() => 2;\n'
    '// coverage:ignore-end\n';

/// Runs the real CLI in a temporary package, never against the app's lib/.
class _CliPackage {
  _CliPackage() : dir = Directory.systemTemp.createTempSync('t099_cli') {
    File('${dir.path}/pubspec.yaml').writeAsStringSync('name: fx\n');
  }

  final Directory dir;
  static final _tool = File('tool/coverage_check.dart').absolute.path;

  void write(String path, String source) => File('${dir.path}/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync(source);

  ProcessResult run(String lcov) {
    write('lcov.info', lcov);
    expect(syncImportsTest(write: true, root: dir.path), isNull);
    return Process.runSync(
      'dart',
      [_tool, '--lcov', 'lcov.info'],
      workingDirectory: dir.path,
      runInShell: true,
    );
  }

  void delete() => dir.deleteSync(recursive: true);
}

void main() {
  group('AC1 and AC2: verdict line and annotations (R3-S1, T-014-N1)', () {
    test('100% with one rule failure: one FAIL line, the rule', () {
      final gate = evaluateGate(_rec(_core, 18, 18), {
        _core: _coreSrc,
        _domain: _ignoreFileSrc,
      });
      expect(gate.passed, isFalse);
      final fails = _failLines(gate.report);
      expect(fails, hasLength(1));
      expect(
        fails.single,
        startsWith('FAIL: coverage:ignore-file marker in a domain or data'),
      );
      expect(
        _lastLine(gate.report),
        'Coverage 100.0% (18/18 lines), minimum 80% met; '
        'gate failed on 1 rule above.',
      );
      expect(_annotationLines(gate.report), ['::error::${fails.single}']);
    });

    test('below the minimum with no rule failure: the numbers line', () {
      final gate = evaluateGate(_rec(_core, 18, 28), {_core: _coreSrc});
      expect(gate.passed, isFalse);
      expect(gate.errors, isEmpty);
      const line = 'FAIL: 64.3% (18/28 lines), minimum 80%.';
      expect(_lastLine(gate.report), line);
      expect(_failLines(gate.report), [line]);
      expect(_annotationLines(gate.report), ['::error::$line']);
    });

    test('below the minimum and a rule failure: both, counted once each', () {
      final gate = evaluateGate(_rec(_core, 18, 28), {
        _core: _coreSrc,
        _domain: _ignoreFileSrc,
        _data: _ignoreFileSrc,
      });
      expect(
        _lastLine(gate.report),
        'FAIL: 64.3% (18/28 lines), minimum 80%; '
        'gate also failed on 2 rules above.',
      );
      expect(_failLines(gate.report), hasLength(3));
      expect(_annotationLines(gate.report), hasLength(3));
    });

    test('two rule failures at 100% use the plural', () {
      final gate = evaluateGate(_rec(_core, 18, 18), {
        _core: _coreSrc,
        _domain: _ignoreFileSrc,
        _data: _ignoreFileSrc,
      });
      expect(_lastLine(gate.report), endsWith('gate failed on 2 rules above.'));
      expect(_failLines(gate.report), hasLength(2));
    });

    test('a pass still prints PASS with no annotation', () {
      final gate = evaluateGate(_rec(_core, 18, 18), {_core: _coreSrc});
      expect(
        _lastLine(gate.report),
        'PASS: 100.0% (18/18 lines), minimum 80%.',
      );
      expect(annotations(gate.report), isEmpty);
    });

    test('nothing in scope plus a rule failure keeps the FAIL prefix', () {
      expect(
        verdictLine(CoverageResult(const [], 80), 1),
        'FAIL: no executable lines in scope; gate also failed on 1 rule above.',
      );
      expect(
        verdictLine(CoverageResult(const [], 80), 0),
        'FAIL: no executable lines in scope.',
      );
    });

    group('CLI', () {
      late _CliPackage pkg;
      setUp(() => pkg = _CliPackage()..write(_core, _coreSrc));
      tearDown(() => pkg.delete());

      test('rule failure only: exit 1, one ::error:: line', () {
        pkg.write(_domain, _ignoreFileSrc);
        final r = pkg.run(_rec(_core, 18, 18));
        expect(r.exitCode, 1);
        final out = (r.stdout as String).replaceAll('\r\n', '\n');
        expect(_failLines(out), hasLength(1));
        expect(out, contains('minimum 80% met; gate failed on 1 rule above.'));
        final errors = out
            .split('\n')
            .where((l) => l.startsWith('::error::'))
            .toList();
        expect(errors, hasLength(1));
        expect(errors.single, contains('coverage:ignore-file marker'));
      }, timeout: const Timeout(Duration(minutes: 2)));

      test('below the minimum only: exit 1, the numbers annotation', () {
        final r = pkg.run(_rec(_core, 18, 28));
        expect(r.exitCode, 1);
        final out = (r.stdout as String).replaceAll('\r\n', '\n');
        final errors = out
            .split('\n')
            .where((l) => l.startsWith('::error::'))
            .toList();
        expect(errors, ['::error::FAIL: 64.3% (18/28 lines), minimum 80%.']);
      }, timeout: const Timeout(Duration(minutes: 2)));
    });
  });

  group('AC3: ignore-start/end covering a whole file (R3-G1)', () {
    final full = _rec(_core, 2, 2);

    test('a 0/0 domain file fails and the message names file and markers', () {
      final gate = evaluateGate('$full${_rec(_domain, 0, 0)}', {
        _core: _coreSrc,
        _domain: _rangeSrc,
      });
      expect(gate.passed, isFalse);
      expect(gate.errors, hasLength(1));
      expect(gate.errors.single, contains(_domain));
      expect(gate.errors.single, contains('coverage:ignore-start/end'));
      expect(gate.errors.single, contains('ignoreFileAllowlist'));
      expect(gate.noExecutableLines, isEmpty);
      expect(
        _annotationLines(gate.report).single,
        startsWith('::error::FAIL: coverage:ignore-start/end'),
      );
    });

    test('a data file absent from lcov with such markers fails too', () {
      final gate = evaluateGate(full, {_core: _coreSrc, _data: _rangeSrc});
      expect(gate.passed, isFalse);
      expect(gate.errors.single, contains(_data));
      expect(gate.noExecutableLines, isEmpty);
    });

    test('R1-G3: absent from lcov reads as a stray marker, 0/0 as cover', () {
      // An interface with a stray ignore-line has no executable lines at
      // all, so lcov leaves it out; the message must not claim the markers
      // cover its lines.
      final stray = evaluateGate(full, {
        _core: _coreSrc,
        _domain:
            'abstract interface class Repo {\n'
            '  int count(); // coverage:ignore-line\n'
            '}\n',
      });
      expect(stray.passed, isFalse);
      expect(
        stray.errors.single,
        startsWith(
          'no executable lines remain in a domain or data file that has '
          'coverage:ignore-start/end or ignore-line markers: $_domain',
        ),
      );
      expect(stray.errors.single, contains('Remove the markers'));
      expect(stray.errors.single, isNot(contains('cover every')));

      final covered = evaluateGate('$full${_rec(_domain, 0, 0)}', {
        _core: _coreSrc,
        _domain: _rangeSrc,
      });
      expect(
        covered.errors.single,
        startsWith(
          'coverage:ignore-start/end (or ignore-line) markers cover every '
          'executable line of a domain or data file: $_domain',
        ),
      );

      final allowed = evaluateGate(
        full,
        {_core: _coreSrc, _data: _rangeSrc},
        allowlist: {_data: 'glue'},
      );
      expect(allowed.passed, isTrue);
      expect(
        allowed.report,
        contains(
          'no executable lines and coverage:ignore markers, allowlisted: '
          'glue: $_data',
        ),
      );
    });

    test('ignore-line on every line counts as the same thing', () {
      final gate = evaluateGate('$full${_rec(_domain, 0, 0)}', {
        _core: _coreSrc,
        _domain: 'int run() => 1; // coverage:ignore-line\n',
      });
      expect(gate.passed, isFalse);
      expect(gate.errors.single, contains(_domain));
    });

    test('allowlisted: passes and prints the reason', () {
      final gate = evaluateGate(
        '$full${_rec(_domain, 0, 0)}',
        {_core: _coreSrc, _domain: _rangeSrc},
        allowlist: {_domain: 'platform glue'},
      );
      expect(gate.passed, isTrue);
      expect(
        gate.report,
        contains(
          'coverage:ignore-start/end markers cover every line, allowlisted: '
          'platform glue: $_domain',
        ),
      );
    });

    test('in lib/core: passes and is listed with its marker count', () {
      const path = 'lib/core/glue.dart';
      final gate = evaluateGate('$full${_rec(path, 0, 0)}', {
        _core: _coreSrc,
        path: _rangeSrc,
      });
      expect(gate.passed, isTrue);
      expect(gate.errors, isEmpty);
      expect(gate.report, contains('2 marker line(s): $path'));
    });

    test('markers on part of a tested domain file are fine', () {
      final gate = evaluateGate('$full${_rec(_domain, 1, 1)}', {
        _core: _coreSrc,
        _domain: 'int a() => 1;\n$_rangeSrc',
      });
      expect(gate.passed, isTrue);
      expect(gate.markers, {_domain: 2});
    });

    test('a 0/0 domain file without markers is still only n/a', () {
      final gate = evaluateGate('$full${_rec(_domain, 0, 0)}', {
        _core: _coreSrc,
        _domain: 'typedef Id = int;\n',
      });
      expect(gate.passed, isTrue);
      expect(gate.report, contains('0/0  $_domain  (n/a'));
    });
  });

  group('AC4: the path-only scope rule is test-only (R3-G2)', () {
    final tool = File('tool/coverage_check.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n')
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    test('isInScope and checkCoverage are @visibleForTesting', () {
      expect(tool, contains('@visibleForTesting\nbool isInScope('));
      expect(
        tool,
        contains('@visibleForTesting\nCoverageResult checkCoverage('),
      );
    });

    test('only checkCoverage calls isInScope; the gate uses coverageOf', () {
      // Declaration plus the one call inside checkCoverage.
      expect(RegExp(r'\bisInScope\b').allMatches(tool), hasLength(2));
      // Declaration only: no production caller.
      expect(RegExp(r'\bcheckCoverage\(').allMatches(tool), hasLength(1));
      expect(tool, contains('final result = coverageOf('));
    });

    test('the gate scopes by header, not by name', () {
      const path = 'lib/features/x/data/repo_impl.g.dart';
      final gate = evaluateGate('${_rec(_core, 1, 1)}${_rec(path, 0, 2)}', {
        _core: _coreSrc,
        path: 'int r() => 1;\n',
      });
      expect(isInScope(path), isFalse);
      expect(gate.result.files.map((f) => f.path), contains(path));
      expect(gate.passed, isFalse);
    });
  });

  group('AC5: hand-written part files (R2-G3)', () {
    const owner = 'lib/core/owner.dart';
    const part = 'lib/core/owner_part.dart';

    test('partOwner resolves the library of a part file', () {
      expect(partOwner(part, "part of 'owner.dart';\n"), owner);
      expect(partOwner(part, 'part of "owner.dart";'), owner);
      expect(partOwner(part, "part of 'package:demo/core/owner.dart';"), owner);
      expect(partOwner(part, "part of '../app/x.dart';"), 'lib/app/x.dart');
      expect(
        partOwner(
          part,
          '\uFEFF// Copyright\n/* block\n comment */\n\n'
          "part of\n    'owner.dart';\n",
        ),
        owner,
      );
      expect(
        partOwner(r'lib\core\owner_part.dart', "part of 'owner.dart';"),
        owner,
      );
    });

    test('partOwner: not a part, or an unresolvable library', () {
      expect(
        partOwner(owner, "part 'owner_part.dart';\nint a() => 1;"),
        isNull,
      );
      expect(
        partOwner(owner, "import 'x.dart';\n// part of 'y.dart';"),
        isNull,
      );
      expect(partOwner(owner, ''), isNull);
      expect(partOwner(part, 'part of demo.owner;'), '');
      expect(partOwner(part, "part of '../../../x.dart';"), '');
      expect(partOwner(part, "part of 'dart:core';"), '');
    });

    test('importTargets imports the library instead of the part', () {
      expect(
        importTargets({
          owner: "part 'owner_part.dart';\n",
          part: "part of 'owner.dart';\n",
          'lib/features/x/data/view_part.dart':
              "part of '../presentation/view.dart';\n",
          'lib/features/x/data/broken.dart': 'part of some.name;\n',
        }),
        [owner, 'lib/features/x/presentation/view.dart'],
      );
    });

    test('the gate lists a part file and counts its lines', () {
      final gate = evaluateGate('${_rec(owner, 8, 8)}${_rec(part, 1, 2)}', {
        owner: "part 'owner_part.dart';\nint a() => 1;\n",
        part: "part of 'owner.dart';\nint b() => 2;\n",
      });
      expect(gate.passed, isTrue);
      expect(gate.parts, {part: owner});
      expect(gate.result.found, 10);
      expect(gate.result.hit, 9);
      expect(gate.report, contains('  part file: $part (part of $owner)'));
      expect(gate.report, contains('1/2  $part'));
    });

    test('a part that names its library by name fails the gate', () {
      final gate = evaluateGate(_rec(owner, 1, 1), {
        owner: 'library demo.owner;\npart "owner_part.dart";\n',
        part: 'part of demo.owner;\nint b() => 2;\n',
      });
      expect(gate.passed, isFalse);
      expect(gate.errors.single, contains('part file $part'));
      expect(gate.report, contains('part of an unresolved library'));
    });

    test('--write-imports output compiles with a part file in scope', () {
      final dir = Directory.systemTemp.createTempSync('t099_parts');
      addTearDown(() => dir.deleteSync(recursive: true));
      void write(String path, String source) => File('${dir.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(source);
      write('pubspec.yaml', 'name: fx\nenvironment:\n  sdk: ^3.0.0\n');
      write(owner, "part 'owner_part.dart';\n\nint a() => b();\n");
      write(part, "part of 'owner.dart';\n\nint b() => 2;\n");
      write('lib/core/plain.dart', 'int c() => 3;\n');

      expect(syncImportsTest(write: true, root: dir.path), isNull);
      expect(syncImportsTest(write: false, root: dir.path), isNull);
      final generated = File('${dir.path}/$importsTestPath').readAsStringSync();
      final imports = generated
          .split('\n')
          .where((l) => l.startsWith("import 'package:fx/"))
          .toList();
      expect(imports, [
        "import 'package:fx/core/owner.dart';",
        "import 'package:fx/core/plain.dart';",
      ]);

      // The generated test needs flutter_test, which this package lacks,
      // so compile its package imports in a plain Dart program instead.
      ProcessResult compile(List<String> lines) {
        write('bin/check.dart', '${lines.join('\n')}\n\nvoid main() {}\n');
        return Process.runSync(
          'dart',
          ['run', 'bin/check.dart'],
          workingDirectory: dir.path,
          runInShell: true,
        );
      }

      final ok = compile(imports);
      expect(ok.exitCode, 0, reason: '${ok.stdout}\n${ok.stderr}');
      // Control: importing the part itself, as before T-099, does not.
      final bad = compile([
        ...imports,
        "import 'package:fx/core/owner_part.dart';",
      ]);
      expect(bad.exitCode, isNot(0));
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
