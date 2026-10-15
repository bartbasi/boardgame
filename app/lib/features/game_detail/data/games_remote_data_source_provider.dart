import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/data/network/api_client_provider.dart';
import 'games_remote_data_source.dart';

part 'games_remote_data_source_provider.g.dart';

/// The app's [GamesRemoteDataSource], on the shared API client.
@Riverpod(keepAlive: true)
GamesRemoteDataSource gamesRemoteDataSource(Ref ref) =>
    GamesRemoteDataSource(ref.watch(apiClientProvider));
