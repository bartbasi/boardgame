---
name: app-conventions
description: Conventions set in T-012 for app/ that later tickets must follow (composition root, generated files, test helpers, arb keys, domain allowlist)
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
- Do not depend on packages/api_contract until T-013 (T-007 builds it in parallel).

**Why:** the reviewer and the strings and architecture tests enforce these, and later tickets (T-013, T-032, T-039) build on them.
**How to apply:** follow these when adding screens, providers, strings, or domain code. Related: [[windows-toolchain-quirks]].
