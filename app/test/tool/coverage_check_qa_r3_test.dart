import 'package:flutter_test/flutter_test.dart';

import '../../tool/coverage_check.dart';

const _header = '// GENERATED CODE - DO NOT MODIFY BY HAND\n';

String _rec(String path, int hit, int total) {
  final b = StringBuffer()..writeln('SF:$path');
  for (var i = 1; i <= total; i++) {
    b.writeln('DA:$i,${i <= hit ? 1 : 0}');
  }
  b.writeln('end_of_record');
  return b.toString();
}

void main() {
  group('QA round 3: exemptions', () {
    final good = _rec('lib/core/a.dart', 10, 10);
    const coreSrc = 'int a() => 1;\n';

    test('ignore-file in domain fails, not labelled no executable lines', () {
      final o = evaluateGate(good, {
        'lib/core/a.dart': coreSrc,
        'lib/features/c/domain/u.dart': '// coverage:ignore-file\nint u()=>1;',
      });
      expect(o.passed, isFalse);
      expect(o.noExecutableLines, isEmpty);
      expect(o.report, contains('FAIL: coverage:ignore-file marker'));
      expect(annotations(o.report), contains('::error::FAIL: coverage:'));
    });

    test('ignore-file in data fails too', () {
      final o = evaluateGate(good, {
        'lib/core/a.dart': coreSrc,
        'lib/features/c/data/u.dart': '// coverage:ignore-file reason\nx',
      });
      expect(o.passed, isFalse);
      expect(o.errors, hasLength(1));
    });

    test('ignore-file in lib/core is exempt and listed', () {
      final o = evaluateGate(good, {
        'lib/core/a.dart': coreSrc,
        'lib/core/z.dart': '// coverage:ignore-file\nint z()=>1;',
      });
      expect(o.passed, isTrue);
      expect(o.exempt['lib/core/z.dart'], 'coverage:ignore-file marker');
      expect(
        o.report,
        contains('coverage:ignore-file marker: lib/core/z.dart'),
      );
      expect(o.noExecutableLines, isEmpty);
    });

    test('prose mention of the marker is not an exemption', () {
      final o = evaluateGate(good, {
        'lib/core/a.dart': coreSrc,
        'lib/features/c/domain/u.dart':
            '// we never use coverage:ignore-file here\nint u()=>1;',
      });
      expect(o.errors, isEmpty);
      expect(o.noExecutableLines, ['lib/features/c/domain/u.dart']);
    });

    test('allowlisted data file passes with its reason shown', () {
      final o = evaluateGate(
        good,
        {
          'lib/core/a.dart': coreSrc,
          'lib/features/c/data/u.dart': '// coverage:ignore-file\nx',
        },
        allowlist: {'lib/features/c/data/u.dart': 'platform glue'},
      );
      expect(o.passed, isTrue);
      expect(o.report, contains('allowlisted: platform glue'));
    });

    test('generated needs name AND header in the first five lines', () {
      expect(isGenerated('lib/core/a.g.dart', '${_header}x'), isTrue);
      expect(
        isGenerated('lib/core/a.freezed.dart', '\n\n\n\n$_header'),
        isTrue,
      );
      expect(isGenerated('lib/core/a.g.dart', 'int a()=>1;'), isFalse);
      expect(isGenerated('lib/core/a.dart', '${_header}x'), isFalse);
      expect(isGenerated('lib/core/a.g.dart', '\n\n\n\n\n$_header'), isFalse);
    });

    test('headerless .g.dart is in scope and fails when untested', () {
      final o = evaluateGate(
        '$good${_rec('lib/features/c/data/r.g.dart', 0, 2)}',
        {
          'lib/core/a.dart': coreSrc,
          'lib/features/c/data/r.g.dart': 'int r()=>1;',
        },
      );
      expect(o.passed, isFalse);
      expect(
        o.report,
        contains('FAIL: no test runs any line of lib/features/c/data/r.g.dart'),
      );
    });

    test('real generated file is exempt, printed, and not counted', () {
      final o = evaluateGate('$good${_rec('lib/core/t.g.dart', 0, 5)}', {
        'lib/core/a.dart': coreSrc,
        'lib/core/t.g.dart': '${_header}x',
      });
      expect(o.passed, isTrue);
      expect(o.result.found, 10);
      expect(o.report, contains('Exempt files: 1'));
      expect(
        o.report,
        contains('generated (GENERATED CODE header): lib/core/t.g.dart'),
      );
    });

    test('every exemption kind is counted and printed together', () {
      final o = evaluateGate(good, {
        'lib/core/a.dart': coreSrc,
        'lib/core/g.g.dart': '${_header}x',
        'lib/core/i.dart': '// coverage:ignore-file\nx',
        'lib/features/c/domain/iface.dart': 'abstract interface class I {}',
      });
      expect(o.report, contains('Exempt files: 3'));
      expect(o.report, contains('no executable lines: lib/features/c/domain/'));
    });

    test('0/0 file is shown as n/a', () {
      final o = evaluateGate('$good${_rec('lib/core/b.dart', 0, 0)}', {
        'lib/core/a.dart': coreSrc,
        'lib/core/b.dart': 'x',
      });
      expect(o.report, contains('lib/core/b.dart  (n/a, no executable lines'));
      expect(o.passed, isTrue);
    });

    test('ignore-start, end and line are counted and listed', () {
      final o = evaluateGate(good, {
        'lib/core/a.dart':
            'a(); // coverage:ignore-line\n// coverage:ignore-start\nb();\n'
            '// coverage:ignore-end\n// prose coverage:ignore-start here\n',
      });
      expect(o.markers['lib/core/a.dart'], 3);
      expect(o.report, contains('3 marker line(s): lib/core/a.dart'));
    });

    test('step summary and annotations', () {
      const report = 'ok line\nFAIL: boom\nPASS: no\n';
      expect(annotations(report), '::error::FAIL: boom\n');
      expect(stepSummary(report), startsWith('### App coverage gate'));
      expect(stepSummary(report), contains('FAIL: boom'));
    });
  });
}
