import 'package:board_game_collector/core/data/database/app_database.dart';
import 'package:board_game_collector/core/data/database/database_providers.dart';
import 'package:board_game_collector/core/data/database/local_game_store.dart';
import 'package:board_game_collector/core/domain/result.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

/// A database whose close fails, as a damaged connection might.
class _FailingCloseDatabase extends AppDatabase {
  _FailingCloseDatabase() : super(NativeDatabase.memory());

  int closeCalls = 0;

  @override
  Future<void> close() async {
    closeCalls++;
    await super.close();
    throw SqliteException(
      extendedResultCode: 5,
      message: 'database is locked: /private/path/board_game_collector.sqlite',
    );
  }
}

/// T-027 R2-G1: the provider's fire-and-forget close never leaves an
/// unhandled error, and logs only the error type.
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('a close error is caught and logged by type only', () async {
    final db = _FailingCloseDatabase();
    final logged = <String>[];
    // An uncaught async error would fail this test.
    await closeAppDatabase(db, log: logged.add);
    expect(db.closeCalls, 1);
    expect(logged, ['AppDatabase.close failed: SqliteException']);
    expect(logged.single, isNot(contains('/private/path')));
  });

  test('a close error without a log callback is still caught', () async {
    final db = _FailingCloseDatabase();
    await expectLater(closeAppDatabase(db), completes);
    expect(db.closeCalls, 1);
  });

  test('a normal close logs nothing and closes the database', () async {
    final db = inMemoryDatabase();
    await db.customSelect('SELECT 1').get();
    final logged = <String>[];
    await closeAppDatabase(db, log: logged.add);
    expect(logged, isEmpty);
    final result = await LocalGameStore(db).readDetails(13);
    expect(result.failureOrNull, const StorageFailure());
  });

  test('storageErrorType names the error type, not the wrapper', () {
    expect(storageErrorType(StateError('x')), StateError);
    expect(
      storageErrorType(SqliteException(extendedResultCode: 13, message: 'm')),
      SqliteException,
    );
  });
}
