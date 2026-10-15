import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database.dart';
import 'game_stores.dart';
import 'local_game_store.dart';
import 'open_app_database.dart';

part 'database_providers.g.dart';

/// The app's single database, opened lazily in a background isolate and
/// closed when the provider container is disposed. Tests override it with an
/// in-memory database.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = openAppDatabase();
  // onDispose cannot await, so the close is fire-and-forget on purpose
  // (T-027-B1); closeAppDatabase keeps a close error from going unhandled.
  ref.onDispose(
    () => unawaited(closeAppDatabase(db, log: kDebugMode ? debugPrint : null)),
  );
  return db;
}

/// Closes [db] and never fails: a close error is reported to [log] by type
/// only (T-027 R2-G1), because nothing can act on it during disposal.
Future<void> closeAppDatabase(
  AppDatabase db, {
  void Function(String message)? log,
}) async {
  try {
    await db.close();
  } on Object catch (error) {
    log?.call('AppDatabase.close failed: ${storageErrorType(error)}');
  }
}

/// The store of cached game details and confirmed barcode matches.
@Riverpod(keepAlive: true)
LocalGameStore localGameStore(Ref ref) => LocalGameStore(
  ref.watch(appDatabaseProvider),
  log: kDebugMode ? debugPrint : null,
);

/// The details cache the games repository uses. Today it is the same
/// [LocalGameStore]; T-102 re-points this provider to the separate cache
/// database file (PRD Q39).
@Riverpod(keepAlive: true)
GameDetailsCache gameDetailsCache(Ref ref) => ref.watch(localGameStoreProvider);

/// The store of confirmed barcode matches the games repository uses. It
/// stays on the main database file (user data).
@Riverpod(keepAlive: true)
BarcodeMatchStore barcodeMatchStore(Ref ref) =>
    ref.watch(localGameStoreProvider);
