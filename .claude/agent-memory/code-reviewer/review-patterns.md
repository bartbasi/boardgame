---
name: review-patterns
description: Recurring review findings by agent, confirmed conventions, forward checks, and useful commands for this repo (Dart and Flutter)
metadata:
  type: project
---

Recurring problems (who makes them):
- backend-developer (T-007): SDK lower bound set below what was tested (`^3.9.0` while the lockfile and freezed 4 need 3.13). Check pubspec `sdk:` against `sdks:` in pubspec.lock and the dev deps.
- qa-engineer (T-007): occasional tautological assertions in edge-case tests (e.g. `contains(cond ? '' : 'm')`). Read QA test bodies, not just counts.

Conventions confirmed in review:
- api_contract generated *.freezed.dart / *.g.dart are committed; root analysis_options excludes them, so analyze says nothing about generated code.
- Decoding errors surface as CheckedFromJsonException (json_serializable `checked: true`), re-exported by api_contract.
- QA commits may also touch docs/handoffs and QA memory, not only test paths; that is accepted.

Commands:
- Dart SDK binary (not Flutter wrapper): /c/dev/flutter/bin/cache/dart-sdk/bin/dart.exe
- Pub cache in Git Bash: "$LOCALAPPDATA/Pub/Cache/hosted/pub.dev" (quote it, the user path has a space).
- Dash check: `git diff main...HEAD -- . ':!*.freezed.dart' ':!*.g.dart' ':!*.lock' | grep -n $'\xe2\x80\x94\|\xe2\x80\x93'` (grep -P with \x{2014} fails here).
- Ownership: `for c in $(git log --format=%h main..HEAD); do git show --stat --format= $c; done`
- `dart run coverage:test_with_coverage` writes coverage/ (git-ignored); mention it in the commands list.

Recurring problems, app (first seen T-012, 2026-10-12):
- flutter-developer: tests guard rules with line-by-line regexes (strings_test hard-coded check) that miss dart-format-wrapped code. Check multi-line forms.
- flutter-developer and qa-engineer: duplicate test helpers (tap destination) instead of putting them in app/test/helpers/.
- Semantics handles disposed at end of test body instead of addTearDown.
- Safe-area handling in the adaptive shell (rail layout) is easy to get half right; check MediaQuery padding passed to content.

Conventions confirmed, app (T-012):
- lib/app/ is the composition root; lib/core/ shared; generated *.g.dart and gen-l10n output are committed.
- Domain purity enforced by app/test/architecture/domain_purity.dart (allowlist; adding a package is a reviewed change).
- Strings test maps copy.md dotted keys to camelCase arb keys; `dev*` keys are skeleton-only.

Forward items to check in later tickets: INTERNET permission in main AndroidManifest (T-013), release signing not debug key (T-014+), allowBackup decision before collection DB.

Flutter commands (Flutter not on PATH): `export PATH="/c/dev/flutter/bin:$PATH"` then from app/: `flutter pub get --enforce-lockfile`, `flutter analyze`, `dart format --output=none --set-exit-if-changed .`, `flutter test`.
Process note: edit the handoff only with the Edit tool, never sed -i (shell writes are not allowed for the reviewer).
