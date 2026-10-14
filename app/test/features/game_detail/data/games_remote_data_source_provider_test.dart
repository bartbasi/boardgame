// T-028: the data source provider uses the app's single API client.
import 'package:board_game_collector/core/data/network/api_client_provider.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:board_game_collector/features/game_detail/data/games_remote_data_source_provider.dart';
import 'package:board_game_collector/features/game_detail/domain/game_details.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http.dart';

void main() {
  test('without API_BASE_URL a call fails with a config failure', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final source = container.read(gamesRemoteDataSourceProvider);
    expect(container.read(gamesRemoteDataSourceProvider), same(source));
    expect(
      await source.fetchGame(13),
      const Err<GameDetails>(
        ConfigurationFailure(ConfigurationProblem.missingBaseUrl),
      ),
    );
  });

  test('it sends through the apiClientProvider client', () {
    final adapter = FakeHttpAdapter([
      respond(200, body: contractFixture('game_detail/full.json')),
    ]);
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(fakeClient(adapter))],
    );
    addTearDown(container.dispose);

    final t = runFake(
      () => container.read(gamesRemoteDataSourceProvider).fetchGame(13),
    );
    expect(t.result.valueOrNull?.name, 'Catan');
    expect(adapter.requests.single.uri.path, '/v1/games/13');
  });
}
