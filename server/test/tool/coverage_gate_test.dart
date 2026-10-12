import 'dart:io';

import 'package:test/test.dart';

import '../../tool/coverage_gate.dart';

void main() {
  group('parseLcov (T-011 coverage gate)', () {
    test('sums LF and LH and makes SF paths relative to the package', () {
      const lcov =
          'SF:/w/server/lib/a.dart\nDA:1,1\nLF:10\nLH:8\nend_of_record\n'
          'SF:/w/server/lib/src/b.dart\nLF:5\nLH:1\nend_of_record\n';
      final summary = parseLcov(lcov, '/w/server');
      expect(summary.linesFound, 15);
      expect(summary.linesHit, 9);
      expect(summary.percent, closeTo(60, 0.01));
      expect(summary.files, {'lib/a.dart', 'lib/src/b.dart'});
    });

    test('accepts Windows separators and CRLF line ends', () {
      const lcov = 'SF:C:\\w\\server\\lib\\a.dart\r\nLF:2\r\nLH:2\r\n';
      final summary = parseLcov(lcov, 'C:\\w\\server');
      expect(summary.files, {'lib/a.dart'});
      expect(summary.linesFound, 2);
    });

    test('no lines gives 0 percent instead of dividing by zero', () {
      expect(parseLcov('', '/w').percent, 0);
    });
  });

  group('which lib files must appear in lcov', () {
    test('generated files are exempt', () {
      expect(isGenerated('lib/src/x.g.dart'), isTrue);
      expect(isGenerated('lib/src/x.freezed.dart'), isTrue);
      expect(isGenerated('lib/src/x.dart'), isFalse);
    });

    test('a coverage:ignore-file marker is exempt', () {
      expect(hasIgnoreFile('// coverage:ignore-file\nint f() => 1;'), isTrue);
      expect(hasIgnoreFile('int f() => 1;'), isFalse);
    });

    test('a barrel with only directives and comments is exempt', () {
      const barrel = '''
/// Docs.
library;

/* block */
export 'package:json_annotation/json_annotation.dart'
    show CheckedFromJsonException;
export 'src/a.dart' show A, B;
import 'dart:io';
part 'x.g.dart';
''';
      expect(isDirectiveOnly(barrel), isTrue);
    });

    test('a file with code is not directive-only', () {
      expect(isDirectiveOnly("export 'a.dart';\nint f() => 1;"), isFalse);
      expect(isDirectiveOnly('const url = "http://x"; // export;'), isFalse);
    });

    test('missingFromLcov lists only unexempted files that are absent', () {
      final missing = missingFromLcov(
        {
          'lib/covered.dart': 'int a() => 1;',
          'lib/untested.dart': 'int b() => 2;',
          'lib/src/z_untested.dart': 'int c() => 3;',
          'lib/gen.g.dart': 'int d() => 4;',
          'lib/barrel.dart': "export 'covered.dart';",
          'lib/ignored.dart': '// coverage:ignore-file\nint e() => 5;',
        },
        {'lib/covered.dart'},
      );
      expect(missing, ['lib/src/z_untested.dart', 'lib/untested.dart']);
    });
  });

  group('runGate', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('coverage_gate'));
    tearDown(() => dir.deleteSync(recursive: true));

    void write(String path, String content) => File('${dir.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(content);

    String lcovFor(String file, int found, int hit) =>
        'SF:${dir.absolute.path}/$file\nLF:$found\nLH:$hit\nend_of_record\n';

    test('passes at the minimum with every lib file reported', () {
      write('lib/a.dart', 'int a() => 1;');
      write('lib/pkg.dart', "library;\nexport 'a.dart';\n");
      write('coverage/lcov.info', lcovFor('lib/a.dart', 10, 8));
      final out = StringBuffer();
      expect(runGate(dir.path, 80, out), 0);
      expect(out.toString(), contains('line coverage: 8/10 = 80.0%'));
      expect(out.toString(), isNot(contains('::error::')));
    });

    test('fails below the minimum', () {
      write('lib/a.dart', 'int a() => 1;');
      write('coverage/lcov.info', lcovFor('lib/a.dart', 10, 7));
      final out = StringBuffer();
      expect(runGate(dir.path, 80, out), 1);
      expect(out.toString(), contains('::error::line coverage: 7/10 = 70.0%'));
    });

    test('fails when a lib file is missing from lcov, even at 100%', () {
      write('lib/a.dart', 'int a() => 1;');
      write('lib/src/untested.dart', 'int b() => 2;');
      write('coverage/lcov.info', lcovFor('lib/a.dart', 10, 10));
      final out = StringBuffer();
      expect(runGate(dir.path, 80, out), 1);
      expect(
        out.toString(),
        contains('::error::1 lib file(s) are not in the coverage report'),
      );
      expect(out.toString(), contains('lib/src/untested.dart'));
    });

    test('a package dir with . segments still matches SF paths', () {
      write('lib/a.dart', 'int a() => 1;');
      write('coverage/lcov.info', lcovFor('lib/a.dart', 10, 10));
      final out = StringBuffer();
      expect(runGate('${dir.path}/./lib/..', 80, out), 0, reason: '$out');
    });

    test('fails when lcov.info is missing', () {
      final out = StringBuffer();
      expect(runGate(dir.path, 80, out), 1);
      expect(out.toString(), contains('lcov.info not found'));
    });

    test('fails when lcov.info has no coverable lines', () {
      write('coverage/lcov.info', '');
      final out = StringBuffer();
      expect(runGate(dir.path, 80, out), 1);
      expect(out.toString(), contains('no coverable lines'));
    });
  });
}
