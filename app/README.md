# Board Game Collector app

Flutter app (Android and iOS). The name and ids are placeholders until PRD Q1 is answered: "Board Game Collector", `com.example.boardgamecollector`.

## Layout

- `lib/app/`: composition root: the root widget, router, and adaptive shell.
- `lib/core/`: shared code (theme, layout breakpoints, shared widgets).
- `lib/features/<feature>/{data,domain,presentation}`: scanner, game_detail, pricing, collection, settings. Domain code is pure Dart; `test/architecture/` enforces it.
- `lib/l10n/app_en.arb`: every user-facing string, keyed as in docs/ux/copy.md.

## Generated code

Generated files are committed: Riverpod providers (`*.g.dart`) and localizations (`lib/l10n/app_localizations*.dart`). After changing a provider or the arb file, regenerate and commit the output:

```
flutter gen-l10n
dart run build_runner build
```

CI should run both and fail if `git diff --exit-code` shows changes.

## On-device database

`lib/core/data/database/` holds the Drift database (T-027). After changing a table:

1. Bump `schemaVersion` in `app_database.dart` and add the step to `migration`.
2. Run `dart run build_runner build`, then `dart run drift_dev make-migrations`. It exports the new version to `drift_schemas/app_database/` and regenerates the helpers in `test/drift/app_database/generated/`.
3. Extend `test/drift/app_database/migration_test.dart` with a data test for the new step, and commit the export, the helpers, and the test.

The migration test fails when the tables change but the export was not regenerated.

## Checks

```
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test --coverage
```

Golden images are rendered only on Linux (docs/decisions.md). Never commit goldens rendered on Windows.
