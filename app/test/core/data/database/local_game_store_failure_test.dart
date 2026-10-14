import 'package:board_game_collector/core/data/database/app_database.dart';
import 'package:board_game_collector/core/data/database/local_game_store.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

/// AC6: database errors reach the caller as a Failure, never as an
/// exception.
void main() {
  late FailingInterceptor interceptor;
  late AppDatabase db;
  late List<String> logged;
  late LocalGameStore store;

  setUp(() async {
    interceptor = FailingInterceptor();
    db = inMemoryDatabase(interceptor: interceptor);
    logged = [];
    store = LocalGameStore(db, log: logged.add);
    // Open and create the schema before the fake starts failing.
    await db.customSelect('SELECT 1').get();
    interceptor.failing = true;
  });
  tearDown(() => db.close());

  final operations = <String, Future<Result<Object?>> Function(LocalGameStore)>{
    'saveDetails': (s) => s.saveDetails(
      bggId: 13,
      detailsJson: '{}',
      fetchedAt: DateTime.utc(2026, 10, 13),
    ),
    'readDetails': (s) => s.readDetails(13),
    'markViewed': (s) => s.markViewed(13, DateTime.utc(2026, 10, 13)),
    'saveConfirmedMatch': (s) => s.saveConfirmedMatch(
      gtin13: '0036000291452',
      bggId: 13,
      confirmedAt: DateTime.utc(2026, 10, 13),
    ),
    'readConfirmedMatch': (s) => s.readConfirmedMatch('0036000291452'),
  };

  for (final MapEntry(key: name, value: run) in operations.entries) {
    test('$name returns StorageFailure when the database fails', () async {
      final result = await run(store);
      expect(result.failureOrNull, const StorageFailure());
      expect(interceptor.refused, greaterThan(0));
      // The log names the operation and error type, not data or messages.
      expect(logged, ['LocalGameStore.$name failed: SqliteException']);
    });
  }

  test('a constraint violation is a StorageFailure too', () async {
    interceptor.failing = false;
    final result = await store.saveConfirmedMatch(
      gtin13: '36000291452',
      bggId: 13,
      confirmedAt: DateTime.utc(2026, 10, 13),
    );
    expect(result.failureOrNull, const StorageFailure());
    // The transaction rolled back: no game row was left behind.
    expect(await db.select(db.games).get(), isEmpty);
  });

  test('a BGG id below 1 is a StorageFailure and stores nothing', () async {
    interceptor.failing = false;
    for (final bggId in [0, -1]) {
      final match = await store.saveConfirmedMatch(
        gtin13: '0036000291452',
        bggId: bggId,
        confirmedAt: DateTime.utc(2026, 10, 13),
      );
      expect(match.failureOrNull, const StorageFailure(), reason: '$bggId');
      final details = await store.saveDetails(
        bggId: bggId,
        detailsJson: '{}',
        fetchedAt: DateTime.utc(2026, 10, 13),
      );
      expect(details.failureOrNull, const StorageFailure(), reason: '$bggId');
    }
    expect(await db.select(db.games).get(), isEmpty);
    expect(await db.select(db.barcodeMatches).get(), isEmpty);
  });

  test('a closed database is a StorageFailure, not a thrown error', () async {
    interceptor.failing = false;
    await db.close();
    final result = await store.readDetails(13);
    expect(result.failureOrNull, const StorageFailure());
  });

  test('without a log callback failures are still returned', () async {
    final quiet = LocalGameStore(db);
    expect((await quiet.readDetails(13)).failureOrNull, const StorageFailure());
  });
}
