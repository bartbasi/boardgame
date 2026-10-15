// T-029 AC8: repository interfaces live in a domain folder and their
// implementations in a data folder. Reads source files, so it runs from the
// app/ folder (flutter test sets the working directory there).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'repository_layers.dart';

void main() {
  test('every repository in lib/ is in the right layer', () {
    final violations = checkRepositoryLayers(Directory('lib'));
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('the games repository interface is in domain, its implementation '
      'in data (the check is live)', () {
    final found = {
      for (final repo in findRepositories(Directory('lib')))
        repo.name: (repo.file, repo.isInterface),
    };
    expect(found['GamesRepository'], (
      'features/game_detail/domain/games_repository.dart',
      true,
    ));
    expect(found['GamesRepositoryImpl'], (
      'features/game_detail/data/games_repository_impl.dart',
      false,
    ));
  });

  test('the checker proves itself on fixtures', () {
    final violations = checkRepositoryLayers(
      Directory('test/fixtures/architecture/repository_layers/lib'),
    );
    expect(
      {for (final v in violations) v.name: v.file},
      {
        'ScreenRepository':
            'features/scanner/presentation/screen_repository.dart',
        'DomainRepositoryImpl':
            'features/scanner/domain/domain_repository_impl.dart',
        'CoreRepository': 'core/data/core_repository.dart',
        'MultiLineRepositoryImpl': 'app/multi_line.dart',
        // Round 2 (R1-S2, QA T-029-B1): sealed, mixin, and plain interface
        // classes are interfaces; extending a repository or a repository
        // implementation makes an implementation.
        'SealedRepository':
            'features/scanner/presentation/sealed_repository.dart',
        'MixinRepository': 'features/scanner/data/mixin_repository.dart',
        'PlainInterfaceRepository': 'core/data/plain_interface_repository.dart',
        'FakeRepo': 'features/scanner/presentation/fake_repo.dart',
        'ExtendsImpl': 'features/scanner/domain/extends_impl.dart',
      },
    );
    final found = {
      for (final repo in findRepositories(
        Directory('test/fixtures/architecture/repository_layers/lib'),
      ))
        repo.name: repo.isInterface,
    };
    expect(found['SubclassImpl'], isFalse, reason: 'found, and in data');
    // A concrete class named ...Repository counts as an implementation (it
    // is in data here, so it passes); commented-out classes do not count.
    expect(found['UsesRepository'], isFalse);
    expect(found, isNot(contains('CommentedRepository')));
    expect(found, isNot(contains('CommentedImpl')));
    expect(found, isNot(contains('Other')), reason: 'type arguments ignored');
    expect(
      violations.firstWhere((v) => v.name == 'ScreenRepository').reason,
      contains('interfaces belong in features/<feature>/domain/'),
    );
    expect(
      violations.firstWhere((v) => v.name == 'DomainRepositoryImpl').reason,
      contains('implementations belong in features/<feature>/data/'),
    );
  });
}
