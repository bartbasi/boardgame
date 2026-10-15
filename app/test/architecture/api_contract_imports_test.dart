// T-028 AC5: package:api_contract is imported only under lib/**/data/,
// never in domain or presentation. Reads source files, so it runs from the
// app/ folder (flutter test sets the working directory there).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'api_contract_imports.dart';

void main() {
  test('the app imports api_contract only in the data layer', () {
    final violations = checkContractImports(Directory('lib'));
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('the app does import it in the data layer (the check is live)', () {
    // Guards against a check that passes because it reads nothing.
    final dataSource = File(
      'lib/features/game_detail/data/games_remote_data_source.dart',
    ).readAsStringSync();
    expect(dataSource, contains("import 'package:api_contract/"));
  });

  group('the checker proves itself on fixtures', () {
    final violations = checkContractImports(
      Directory('test/fixtures/architecture/contract_imports/lib'),
    );

    test('finds exactly the files outside the data layer and the export', () {
      expect(
        {for (final v in violations) v.file: v.reason},
        {
          'app/app.dart': contains('only be imported under lib/**/data/'),
          'core/domain/result.dart': contains('only be imported'),
          'features/game_detail/domain/game.dart': contains('only be imported'),
          'features/pricing/datasource/source.dart': contains(
            'only be imported',
          ),
          'features/scanner/presentation/screen.dart': contains(
            'only be imported',
          ),
          'features/game_detail/data/leak.dart': contains('re-exported'),
        },
      );
    });

    test('names the directive URI, including src/ imports', () {
      final screen = violations.singleWhere(
        (v) => v.file == 'features/scanner/presentation/screen.dart',
      );
      expect(screen.uri, 'package:api_contract/src/game_summary.dart');
      expect(screen.toString(), contains(screen.file));
    });

    test('data files and commented-out directives pass', () {
      final files = violations.map((v) => v.file).toSet();
      expect(files, isNot(contains('main.dart')));
      expect(files, isNot(contains('core/data/network/mapper.dart')));
      expect(
        files,
        isNot(contains('features/game_detail/data/games_source.dart')),
      );
    });
  });

  test('isDataPath allows only feature data and core data', () {
    expect(isDataPath(['features', 'pricing', 'data', 'p.dart']), isTrue);
    expect(isDataPath(['features', 'pricing', 'data', 'a', 'p.dart']), isTrue);
    expect(isDataPath(['core', 'data', 'x.dart']), isTrue);
    expect(isDataPath(['features', 'pricing', 'domain', 'p.dart']), isFalse);
    expect(isDataPath(['features', 'data', 'p.dart']), isFalse);
    expect(isDataPath(['core', 'domain', 'x.dart']), isFalse);
    expect(isDataPath(['data', 'x.dart']), isFalse);
    expect(isDataPath(const []), isFalse);
  });

  test('a missing lib folder has nothing to check', () {
    expect(checkContractImports(Directory('does_not_exist/lib')), isEmpty);
  });
}
