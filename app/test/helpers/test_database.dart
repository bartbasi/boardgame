import 'package:board_game_collector/core/data/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// A fresh in-memory database on the test isolate (T-027). Close it in a
/// tear-down.
AppDatabase inMemoryDatabase({QueryInterceptor? interceptor}) {
  // Tests open many databases of the same class; drift warns about that in
  // debug builds because it is usually a bug in apps.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final QueryExecutor executor = NativeDatabase.memory();
  return AppDatabase(
    interceptor == null ? executor : executor.interceptWith(interceptor),
  );
}

/// A failing fake: once [failing] is true, every statement throws the
/// [SqliteException] SQLite gives for a full disk (SQLITE_FULL, code 13).
class FailingInterceptor extends QueryInterceptor {
  bool failing = false;

  /// How many statements were refused.
  int refused = 0;

  T _check<T>(T Function() run) {
    if (failing) {
      refused++;
      throw SqliteException(
        extendedResultCode: 13,
        message: 'database or disk is full',
      );
    }
    return run();
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _check(() => super.runSelect(executor, statement, args));

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _check(() => super.runInsert(executor, statement, args));

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _check(() => super.runUpdate(executor, statement, args));

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _check(() => super.runDelete(executor, statement, args));

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) =>
      _check(() => super.beginTransaction(parent));
}
