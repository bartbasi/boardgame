// AC3 (T-012): domain code is pure Dart. This test reads source files, so it
// runs from the app/ folder (flutter test sets the working directory there).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'domain_purity.dart';

const String _package = 'board_game_collector';
const String _fixtures = 'test/fixtures/architecture';

List<PurityViolation> _checkFixture(String name) => checkDomainPurity(
  libDir: Directory('$_fixtures/$name/lib'),
  packageName: _package,
);

void main() {
  group('the app', () {
    test('every domain file in lib/ is pure Dart', () {
      final violations = checkDomainPurity(
        libDir: Directory('lib'),
        packageName: _package,
      );
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('each feature has data, domain, and presentation folders (AC2)', () {
      const features = [
        'scanner',
        'game_detail',
        'pricing',
        'collection',
        'settings',
      ];
      for (final feature in features) {
        for (final layer in ['data', 'domain', 'presentation']) {
          expect(
            Directory('lib/features/$feature/$layer').existsSync(),
            isTrue,
            reason: 'lib/features/$feature/$layer',
          );
        }
      }
      expect(Directory('lib/core').existsSync(), isTrue);
    });
  });

  group('the checker proves itself on fixtures', () {
    test('a clean domain passes (comments, dart:, allowlist, own files)', () {
      final violations = _checkFixture('clean');
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    final badCases = <String, (String, String)>{
      'flutter_import': ('package:flutter/foundation.dart', 'Flutter'),
      'dart_ui': ('dart:ui', 'platform or UI bound'),
      'plugin': ('package:mobile_scanner/mobile_scanner.dart', 'allowlist'),
      'transitive': ('package:flutter/material.dart', 'Flutter'),
      'layer': (
        'package:board_game_collector/features/collection/data/item_dto.dart',
        'data layer',
      ),
      'conditional': ('package:flutter/widgets.dart', 'Flutter'),
      'export': ('package:flutter/widgets.dart', 'Flutter'),
      // T-013: lib/core/domain is domain code too.
      'core_domain': ('package:dio/dio.dart', 'allowlist'),
      'core_data': ('../data/client.dart', 'core data layer'),
    };

    for (final entry in badCases.entries) {
      test('fails on ${entry.key}', () {
        final violations = _checkFixture(entry.key);
        final (uri, reason) = entry.value;
        expect(
          violations.where((v) => v.uri == uri && v.reason.contains(reason)),
          isNotEmpty,
          reason: 'got: ${violations.join('\n')}',
        );
      });
    }

    test('a transitive violation names both files', () {
      // core/domain/colors.dart is also checked on its own, so pick the
      // violation reached from the feature's domain file.
      final violation = _checkFixture('transitive').singleWhere(
        (v) => v.domainFile == 'features/settings/domain/settings.dart',
      );
      expect(violation.file, 'core/domain/colors.dart');
      expect(violation.uri, 'package:flutter/material.dart');
    });

    test('own files outside the domain allowlist are refused (R1-G5)', () {
      final violations = _checkFixture('outside_domain');
      expect(violations.map((v) => v.uri).toSet(), {
        'package:board_game_collector/app/routes.dart',
        '../../../core/ui/spacing.dart',
      });
      expect(
        violations.every((v) => v.reason.contains('may only import domain')),
        isTrue,
        reason: violations.join('\n'),
      );
    });

    test('isDomainPath allows only feature domain and core domain', () {
      expect(isDomainPath(['features', 'pricing', 'domain', 'p.dart']), isTrue);
      expect(isDomainPath(['core', 'domain', 'result.dart']), isTrue);
      expect(isDomainPath(['core', 'domain', 'sub', 'x.dart']), isTrue);
      expect(isDomainPath(['features', 'pricing', 'data', 'p.dart']), isFalse);
      expect(isDomainPath(['core', 'ui', 'x.dart']), isFalse);
      expect(isDomainPath(['core', 'presentation', 'x.dart']), isFalse);
      expect(isDomainPath(['app', 'app.dart']), isFalse);
      expect(isDomainPath(['main.dart']), isFalse);
      expect(isDomainPath(['features', 'domain']), isFalse);
      expect(isDomainPath(const []), isFalse);
    });

    test('a conditional import checks every alternative', () {
      final uris = _checkFixture('conditional').map((v) => v.uri).toSet();
      expect(uris, {'package:flutter/widgets.dart', 'dart:io'});
    });
  });

  group('directiveUris', () {
    test('reads single, double, multi-line, and conditional directives', () {
      const source = '''
library;
import 'a.dart';
import "package:b/b.dart" as b show C;
export 'c.dart' hide D;
import 'e.dart'
    if (dart.library.io) 'f.dart';
// import 'commented.dart';
/* import 'blocked.dart'; */
part 'g.g.dart';
''';
      expect(directiveUris(source), [
        'a.dart',
        'package:b/b.dart',
        'c.dart',
        'e.dart',
        'f.dart',
      ]);
    });

    test('a library without directives has none', () {
      expect(directiveUris('class A {}\n'), isEmpty);
    });
  });

  test('a missing features folder has nothing to check', () {
    expect(
      checkDomainPurity(
        libDir: Directory('$_fixtures/does_not_exist/lib'),
        packageName: _package,
      ),
      isEmpty,
    );
  });
}
