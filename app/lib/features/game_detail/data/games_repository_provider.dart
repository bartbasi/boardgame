import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/data/database/database_providers.dart';
import '../domain/games_repository.dart';
import 'games_remote_data_source_provider.dart';
import 'games_repository_impl.dart';

part 'games_repository_provider.g.dart';

/// The app's [GamesRepository]: the backend plus the on-device stores.
/// Screens read this provider; tests override it with a fake.
@Riverpod(keepAlive: true)
GamesRepository gamesRepository(Ref ref) => GamesRepositoryImpl(
  remote: ref.watch(gamesRemoteDataSourceProvider),
  detailsCache: ref.watch(gameDetailsCacheProvider),
  matchStore: ref.watch(barcodeMatchStoreProvider),
  log: kDebugMode ? debugPrint : null,
);
