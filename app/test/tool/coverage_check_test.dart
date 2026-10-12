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
        contains('warning: no test loads lib/core/b.dart'),
      );
    });

    test('returns nothing when the folder is missing', () {
      final result = checkCoverage('');
      expect(unloadedFiles(Directory('${temp.path}/nope'), result), isEmpty);
    });
  });
}
