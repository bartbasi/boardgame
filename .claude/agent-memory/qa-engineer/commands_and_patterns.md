---
name: commands-and-patterns
description: How to run each suite on this Windows/Git Bash setup, widget test helpers, and gotchas
metadata:
  type: reference
---

- Flutter is at C:\dev\flutter. In Bash: `export PATH="/c/dev/flutter/bin:$PATH"`, then from `<worktree>/app`: `flutter analyze`, `dart format --output=none --set-exit-if-changed .`, `flutter test --coverage`.
- lcov.info has CRLF line endings. Strip with `tr -d '\r'` before awk, or sums come out 0/0.
- `python` heredocs hang in this shell. Use sed or the Write tool for edits.
- Test helpers in app/test/helpers/pump_app.dart: `pumpApp`, `setTestWindow` (call again mid-test to resize or change brightness), `WindowSizes.all`, `largeTextScale`.
- Widget tests use the test font (square glyphs), so rail widths differ from real.
- Back navigation test: `tester.binding.handlePopRoute()` returns false when the app would exit.
- Edge-case tests live in app/test/qa/.
- Domain purity checker (app/test/architecture/domain_purity.dart) reads one directive per line; fine because dart format enforces it (T-012-B1).
