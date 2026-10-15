// T-029: the repository provider wires the remote data source and the
// stores from their providers, so overriding them reaches the repository.
import 'package:board_game_collector/core/data/database/app_database.dart';
import 'package:board_game_collector/core/data/database/database_providers.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:board_game_collector/features/game_detail/data/games_remote_data_source_provider.dart';
import 'package:board_game_collector/features/game_detail/data/games_repository_impl.dart';
import 'package:board_game_collector/features/game_detail/data/games_repository_provider.dart';
import 'package:board_game_collector/features/game_detail/domain/game_lookup_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_games.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FakeGamesRemote remote;
  late ProviderContainer container;

  setUp(() {
    db = inMemoryDatabase();
    remote = FakeGamesRemote();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        gamesRemoteDataSourceProvider.overrideWithValue(remote),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('gamesRepositoryProvider is one GamesRepositoryImpl', () {
    final repository = container.read(gamesRepositoryProvider);
    expect(repository, isA<GamesRepositoryImpl>());
    expect(container.read(gamesRepositoryProvider), same(repository));
  });

  test('a backend match is stored in the app database', () async {
    remote.lookupResult = Ok(lookupFixture('lookup/matched.json'));
    final repository = container.read(gamesRepositoryProvider);

    await repository.lookupBarcode(barcodeOf('036000291452'));
    final again = await repository.lookupBarcode(barcodeOf('036000291452'));

    expect(again.valueOrNull, isA<ConfirmedOnDevice>());
    expect(remote.calls, 1);
    final store = container.read(localGameStoreProvider);
    expect(
      (await store.readConfirmedMatch('0036000291452')).valueOrNull?.bggId,
      13,
    );
  });
}
