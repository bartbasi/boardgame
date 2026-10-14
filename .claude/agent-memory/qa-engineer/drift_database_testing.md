---
name: drift-database-testing
description: Patterns for testing the Drift/SQLite store (T-027): in-memory and file DBs, lock and corrupt file tests, import clashes
metadata:
  type: reference
---

- In tests import `package:drift/drift.dart' hide isNotNull, isNull` or the matchers clash. `SchemaVerifier` needs `package:drift_dev/api/migrations_native.dart`.
- Helpers: app/test/helpers/test_database.dart (`inMemoryDatabase`, `FailingInterceptor`). Subclass `QueryInterceptor` to fail one statement type (for example runUpdate) to test rollback.
- File tests: `Directory.systemTemp.createTempSync`, `AppDatabase(NativeDatabase(file))`. Lock test: a second AppDatabase on the same file runs `BEGIN EXCLUSIVE` (default busy timeout 0 gives SQLITE_BUSY). Corrupt: write random bytes. Newer user_version: store gives StorageFailure forever; reopening with AppDatabase rethrows, so compare file bytes instead.
- Whole app suite ~70 s, 704 tests at T-027. Run build_runner + `drift_dev schema dump` and compare to drift_schemas/ for the generated-files check.
