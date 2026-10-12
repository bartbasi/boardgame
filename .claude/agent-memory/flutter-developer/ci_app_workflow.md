---
name: ci-app-workflow
description: How app.yml CI is built (T-014) and the Actions pitfalls found proving it on real runs; read before editing app.yml (T-015 goldens, release jobs)
metadata:
  type: project
---

Set up in T-014 (2026-10-12). Real runs happen on bartbasi/boardgame; the token has the workflow scope, the orchestrator allows pushing ticket branches (never main, no PRs).

- Flutter comes from `app/tool/ci/install_flutter.sh "$FLUTTER_VERSION"` (release index + SHA-256 + version check), not subosito/flutter-action: its composite steps use `actions/cache@v5` by tag, which breaks the "every action pinned to a SHA" rule.
- Flutter version lives only in app.yml `env.FLUTTER_VERSION`; coverage minimum in `env.COVERAGE_MIN`.
- A job-level `defaults.run` REPLACES the workflow-level one: jobs with `working-directory: app` lost `shell: bash` and ran `bash -e` without pipefail, so `cmd | tee` swallowed failures. actionlint does not catch it. Repeat `shell: bash` in every job's defaults.
- Prove failure paths with scratch branches (push, `gh run view`, then `git push origin --delete`); a gate that prints FAIL can still be green.
- Coverage gate is STRICT (decisions 2026-10-12): `app/tool/coverage_check.dart` + generated `test/coverage_imports_test.dart` (imports every lib/core and domain/data file). After adding or removing such a file run `dart run tool/coverage_check.dart --write-imports` and commit, or CI fails. Fails on: stale imports test, any in-scope file with executable lines and zero hits, total < 80%. Interface-only files are absent from lcov even when imported (verified on Linux CI) and count as "no executable lines".
- Workflow rules (decisions 2026-10-12): bash with pipefail in every job, `persist-credentials: false` on checkout, no `${{ }}` inside run scripts (pass via env).
- Root .gitignore ignores `coverage/` anywhere: lcov fixtures live in `app/test/fixtures/lcov/`.
- iOS job (macos-26) only on push to main or workflow_dispatch; a manual run took 2m19s. Use at most one manual run per ticket and report minutes.
- Typical durations: checks about 2.5 min, codegen about 3 min, android 4 to 7 min (cold Gradle cache is slower).
- Look up action SHAs with `gh api repos/<o>/<r>/git/ref/tags/<tag>`, one command per call (the Bash guard rejects loops with gh).

**Why:** each item cost a run or a retry during T-014.
**How to apply:** check this before changing app.yml or adding CI steps. Related: [[windows-toolchain-quirks]], [[app-conventions]].
