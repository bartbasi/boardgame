// QA edge cases for T-099 (coverage gate). Pure functions, in-memory sources.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/coverage_check.dart';

const _lcov =
    'SF:lib/core/a.dart\nDA:1,1\nDA:2,1\nend_of_record\n'
    'SF:lib/features/x/domain/ok.dart\nDA:1,1\nend_of_record\n';
const _range =
    '// coverage:ignore-start\nint f() => 1;\n// coverage:ignore-end\n';

String _report(Map<String, String> sources, {Map<String, String>? allow}) {
  final out = evaluateGate(_lcov, sources, allowlist: allow ?? const {});
  return formatReport(
    out.result,
    out.noExecutableLines,
    exempt: out.exempt,
    markers: out.markers,
    errors: out.errors,
    parts: out.parts,
  );
}

void main() {
  final base = {
    'lib/core/a.dart': 'int a() => 1;\n',
    'lib/features/x/domain/ok.dart': 'int b() => 1;\n',
  };

  test('two all-ignored domain files give two FAIL lines and two errors', () {
    final report = _report({
      ...base,
      'lib/features/x/domain/r1.dart': _range,
      'lib/features/x/data/r2.dart': _range,
    });
    final fails = report.split('\n').where((l) => l.startsWith('FAIL'));
    expect(fails, hasLength(2));
    expect(annotations(report).trim().split('\n'), hasLength(2));
    expect(report, contains('failed on 2 rules'));
  });

  test('ignore-file plus ranges in a domain file fails once, not twice', () {
    final report = _report({
      ...base,
      'lib/features/x/domain/both.dart': '// coverage:ignore-file\n$_range',
    });
    expect(report.split('\n').where((l) => l.startsWith('FAIL')), hasLength(1));
  });

  // Rewritten by flutter-developer in T-099 round 2 (review R1-S2): the
  // presentation version could never fail, because presentation files are
  // never in scope. A lib/core file is in scope, so this fails if the rule
  // stops being limited to domain and data.
  test('a lib/core file fully covered by a range (0/0) is not a rule', () {
    const path = 'lib/core/r.dart';
    final out = evaluateGate('${_lcov}SF:$path\nend_of_record\n', {
      ...base,
      path: _range,
    }, allowlist: const {});
    expect(out.errors, isEmpty);
    expect(out.passed, isTrue);
    expect(out.markers, {path: 2});
    expect(out.report, contains('2 marker line(s): $path'));
  });

  test('a part file with a BOM and a leading doc comment is detected', () {
    expect(
      partOwner(
        'lib/core/o_part.dart',
        "\uFEFF/// doc\n// c\n/* b */ part of 'o.dart';",
      ),
      'lib/core/o.dart',
    );
  });

  test('two parts of one library import the library once', () {
    final targets = importTargets({
      'lib/core/o.dart': "part 'p1.dart';\npart 'p2.dart';\n",
      'lib/core/p1.dart': "part of 'o.dart';\n",
      'lib/core/p2.dart': "part of 'o.dart';\n",
    });
    expect(targets, ['lib/core/o.dart']);
  });

  test('PASS verdict never starts a line with FAIL', () {
    final report = _report(base);
    expect(report.split('\n').where((l) => l.startsWith('FAIL')), isEmpty);
    expect(annotations(report).trim(), isEmpty);
  });
}
