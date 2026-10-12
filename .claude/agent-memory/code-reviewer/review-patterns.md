---
name: review-patterns
description: Recurring review findings by agent, confirmed conventions, and useful commands for this repo (Dart SDK path, dash grep, SDK constraint check)
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
