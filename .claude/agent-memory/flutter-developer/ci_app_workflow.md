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
- Coverage gate is STRICT and mirrors server/tool/coverage_gate.dart (decisions 2026-10-12, reviewer compares them): `app/tool/coverage_check.dart` + generated `test/coverage_imports_test.dart`. After adding/removing a lib/core or domain/data file run `dart run tool/coverage_check.dart --write-imports` and commit. Fails on: stale imports test, in-scope file with lines but zero hits, `coverage:ignore-file` in domain/data (unless in `ignoreFileAllowlist`), total < 80%. Generated = name AND `// GENERATED CODE - DO NOT MODIFY BY HAND` header. Every exemption printed. package:coverage drops ignore-file files from lcov entirely.
- Merge pitfall (2026-10-12, run 38292884766): T-013 and T-014 merged separately, each green, but main went red because the generated imports test did not list T-013's lib/core/data/network files. Any ticket that adds lib/core or domain/data files must regenerate after rebasing on or merging main; flag it in the handoff when two app tickets merge close together.
- QA's CLI test in coverage_check_qa_test.dart runs the gate against the real lib/, so a red gate on a scratch branch also fails that test.
- Workflow rules (decisions 2026-10-12): bash with pipefail in every job, `persist-credentials: false` on checkout, no `${{ }}` inside run scripts (pass via env).
- Root .gitignore ignores `coverage/` anywhere: lcov fixtures live in `app/test/fixtures/lcov/`.
- iOS job (macos-26) only on push to main or workflow_dispatch; a manual run took 2m19s. Use at most one manual run per ticket and report minutes.
- Typical durations: checks about 2.5 min, codegen about 3 min, android 4 to 7 min (cold Gradle cache is slower).
- Look up action SHAs with `gh api repos/<o>/<r>/git/ref/tags/<tag>`, one command per call (the Bash guard rejects loops with gh).
- Goldens (user decision 2026-10-12): render ONLY on Actions, never locally or with Docker. Use `gh workflow run app.yml --ref <branch> -f update_goldens=true` (runs only the goldens-update job), then `rm -f app/test/goldens/*.png` (gh run download refuses to overwrite: "file exists"), then `gh run download <id> --name goldens --dir app/test/goldens`, then commit. Golden names always keep the state segment (`app_shell_default_text200_...`, UX decision T-015 round 3). All golden tests must live directly in app/test/goldens/ (goldenTest throws otherwise), and each golden test file exports a `List<GoldenCase>` registered in test/golden_pipeline/golden_files_test.dart `declaredGoldens` (orphan PNG check). A mismatch uploads the `golden-failures` artifact. Prove a failure with a scratch branch pushed via `git push origin HEAD:refs/heads/<scratch>`, then reset locally and delete the remote branch. Format the scratch edit or the Format step stops the job before Test runs.
- The Bash guard rejects gh with jq `--jq` filters, `cd ..` before git, and python heredocs whose text mentions git. Use plain `gh run view <id>` and the Grep tool on a saved log.

**Why:** each item cost a run or a retry during T-014 and T-015.
**How to apply:** check this before changing app.yml or adding CI steps. Related: [[windows-toolchain-quirks]], [[app-conventions]].
