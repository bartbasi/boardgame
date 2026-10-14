import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database.dart';
import 'local_game_store.dart';
import 'open_app_database.dart';

part 'database_providers.g.dart';

/// The app's single database, opened lazily in a background isolate and
/// closed when the provider container is disposed. Tests override it with an
/// in-memory database.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = openAppDatabase();
  ref.onDispose(db.close);
  return db;
}

/// The store of cached game details and confirmed barcode matches.
@Riverpod(keepAlive: true)
LocalGameStore localGameStore(Ref ref) => LocalGameStore(
  ref.watch(appDatabaseProvider),
  log: kDebugMode ? debugPrint : null,
);
