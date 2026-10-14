---
name: app-conventions
description: Conventions set in T-012 and T-013 for app/ that later tickets must follow (composition root, generated files, test helpers, arb keys, domain allowlist)
metadata:
  type: project
---

Set in T-012 (2026-10-12), proposed as decisions in docs/handoffs/T-012.md; check docs/decisions.md for whether the orchestrator accepted them.

- `lib/app/` is the composition root (root widget, go_router `StatefulShellRoute.indexedStack`, adaptive shell). `lib/core/` is shared code and must not import features.
- Title search lives in `features/scanner/presentation/` with the rest of the lookup flow.
- Generated files are committed (`*.g.dart`, `lib/l10n/app_localizations*.dart`). After changing providers or app_en.arb run `flutter gen-l10n` and `dart run build_runner build` (first run about 3 minutes, later about 15 s) and commit the output.
- arb keys = copy.md keys in camelCase; `test/l10n/strings_test.dart` checks key AND string match copy.md. Skeleton-only keys start with `dev` and must be deleted when the real screen lands.
- `test/l10n/strings_test.dart` also fails on literal strings passed to `Text(`, `label:`, `title:`, `tooltip:` and similar in lib/.
- Domain purity test: `test/architecture/domain_purity.dart` has the package allowlist (collection, equatable, freezed_annotation, json_annotation, meta). freezed or json in domain needs nothing extra; anything else needs an allowlist edit.
- Test helpers in `test/helpers/pump_app.dart`: `WindowSizes` (not `TestWindow`, which clashes with flutter_test), `largeTextScale`, `setTestWindow`, `pumpApp` (renders one frame, no settle).
- `tapDestination(tester, label)` lives in `test/helpers/pump_app.dart`; QA's tests use it too.
- Dispose `tester.ensureSemantics()` handles with try/finally, NOT addTearDown: flutter_test (3.47.7) checks for live handles before tear-downs run, so addTearDown fails every test.
- Rail layout removes the leading MediaQuery padding from content (rail's SafeArea already uses it); tests use `tester.view.padding = FakeViewPadding(...)`.
- T-013 (2026-10-12) added `lib/core/domain/` (Result with Ok/Err, sealed Failure) and `lib/core/data/network/` (ApiClient, ApiConfig, RetryPolicy, failure mapper, log interceptor, `apiClientProvider`). Repositories call `ApiClient.get(path, decode: Dto.fromJson)`, which returns `Result<T>` and never throws. The purity test now also checks lib/core/domain. api_contract is a path dependency.
- Timing tests use `runFake` from `test/helpers/fake_http.dart` (fakeAsync plus package:clock) with `FakeHttpAdapter`, `respond`, `failWith`, `hang`, `FixedRandom`. Production code must use `clock.now()`, not DateTime.now(), for fake time to apply; for durations and deadlines use a monotonic Stopwatch injected as a factory (tests pass `clock.stopwatch`), per T-013 review R1-G1.
- Failure is sealed, so any new failure type (for example T-026's `InvalidBarcodeFailure`) must go in `lib/core/domain/failure.dart`, and adding one breaks two exhaustive switches you must extend: `isRetryable` in failure_mapper.dart and `_copyKey` in test/core/domain/failure_test.dart.
- T-026 (2026-10-13): `features/scanner/domain/barcode.dart` `Barcode.parse` is the one barcode validator; key is `gtin13` (left zero-pad to 13; decisions.md 2026-10-13, GS1-03 to GS1-08; UPC-E not supported in v1). Empty input = wrongLength with length 0 (UI maps to `manualEntry.errorEmpty`). Reuse it in T-027, T-030, T-031 instead of re-validating.
- Domain purity (since T-013 round 2) is an allowlist of own-package paths: domain may import only `features/<f>/domain/` and `core/domain/`.
- Reviewer expects exact assertions (failure type, request count, elapsed) in timing tests, using `FixedRandom`, not loose bounds.
- Gotcha: anything with a Completer (for example a dio CancelToken) must be created INSIDE the fakeAsync callback; one created outside completes on the real microtask queue and never fires in fake time.
- App tests read api_contract JSON fixtures via `contractFixture('error/not_found.json')` (path ../packages/api_contract/test/fixtures). Note `variants/error_extra_field.json` has code not_found.
- T-027 (2026-10-14): Drift database in `lib/core/data/database/` (AppDatabase schema v1, `LocalGameStore` returning Result with `StorageFailure`, `appDatabaseProvider`/`localGameStoreProvider`). Tests use `inMemoryDatabase()` and `FailingInterceptor` from `test/helpers/test_database.dart`. Schema change = bump version, `build_runner build`, `dart run drift_dev make-migrations` (export in drift_schemas/, helpers in test/drift/), extend migration_test (app/README.md). Table DSL getters never run, so app_database.dart sits near 44% line coverage; do not add ignore markers. Changing an unreleased schema version in place: `drift_dev schema dump <db.dart> drift_schemas/app_database/drift_schema_vN.json` plus `drift_dev schema generate --data-classes --companions drift_schemas/app_database/ test/drift/app_database/generated/` (make-migrations alone does not overwrite). Background-isolate errors arrive as `DriftRemoteException` (in-memory tests show the raw SqliteException), so test error paths through `openAppDatabase` too. Import it as `package:drift/isolate.dart` show DriftRemoteException (remote.dart is experimental); log error types via `storageErrorType`. Riverpod onDispose cannot await: wrap closes in `unawaited(...)` with a catch (`closeAppDatabase`).

**Why:** the reviewer and the strings and architecture tests enforce these, and later tickets (T-013, T-032, T-039) build on them.
**How to apply:** follow these when adding screens, providers, strings, network calls, or domain code. Related: [[windows-toolchain-quirks]].
