---
name: review-patterns
description: Recurring review findings by agent, confirmed conventions, forward checks, and useful commands for this repo (Dart and Flutter)
metadata:
  type: project
---

Recurring problems (who makes them):
- backend-developer (T-007): SDK lower bound set below what was tested (`^3.9.0` while the lockfile and freezed 4 need 3.13). Check pubspec `sdk:` against `sdks:` in pubspec.lock and the dev deps.
- qa-engineer (T-007): occasional tautological assertions in edge-case tests (e.g. `contains(cond ? '' : 'm')`). Read QA test bodies, not just counts.

- backend-developer (T-008): responsive to findings and often improves on the suggested fix (error boundary outside /v1 guards was better than my order). Judge alternatives on merit.

Server conventions confirmed (T-008):
- Server never uses shelf_io.serve/serveRequests (they print raw URL to stderr); bindAndServe in server/lib/src/http/serve.dart. Grep `shelf_io.serve` in server/lib on every server ticket.
- Order: requestLog > errorBoundary > root router > /v1 mount behind buildApp(v1Middleware). Guards go in v1Middleware.
- Logger.error uses describeError; it does NOT redact URL paths or ArgumentError values (R2-S1 carry-over). Check this on T-020, T-066, and the first /v1 data endpoint.
- Compose must set stop_grace_period 15s (T-010 check); Caddy upstream keep-alive < 65 s.
- backend-developer (T-008): privacy tests drive the handler in-process only; shelf_io's own error printer (stderr, plain text, includes path?query) is reachable via bad X-Forwarded-Host/Proto because dart:io builds requestedUri with Uri.parse. Check real-socket paths and anything that escapes the pipeline.
- backend-developer (T-008): errorBoundary logs error.toString(); watch later tickets for FormatException/dio text carrying input, queries, or keys.
- Forward: T-010 must set Compose stop_grace_period above the 10 s drain (docker default SIGKILL at 10 s). T-066/T-020: /v1 middleware must also cover unmatched /v1 paths.

Conventions confirmed in review:
- server (T-008): shelf + shelf_router; pipeline requestLog (outer) > errorBoundary > router; Routes registrar records route templates; config exit 78, bind exit 1; server reads only Platform.environment (bin/server.dart).
- api_contract generated *.freezed.dart / *.g.dart are committed; root analysis_options excludes them, so analyze says nothing about generated code.
- Decoding errors surface as CheckedFromJsonException (json_serializable `checked: true`), re-exported by api_contract.
- QA commits may also touch docs/handoffs and QA memory, not only test paths; that is accepted.

Commands:
- Dart SDK binary (not Flutter wrapper): /c/dev/flutter/bin/cache/dart-sdk/bin/dart.exe
- Pub cache in Git Bash: "$LOCALAPPDATA/Pub/Cache/hosted/pub.dev" (quote it, the user path has a space).
- Dash check: `git diff main...HEAD -- . ':!*.freezed.dart' ':!*.g.dart' ':!*.lock' | grep -n $'\xe2\x80\x94\|\xe2\x80\x93'` (grep -P with \x{2014} fails here).
- Ownership: `for c in $(git log --format=%h main..HEAD); do git show --stat --format= $c; done`
- `dart run coverage:test_with_coverage` writes coverage/ (git-ignored); mention it in the commands list. Sum: awk -F: '/^LF:/{lf+=$2} /^LH:/{lh+=$2} END{print lh"/"lf}' coverage/lcov.info (SF paths contain C:, so do not split SF on ':').
- shelf source to verify adapter behavior: "$LOCALAPPDATA/Pub/Cache/hosted/pub.dev/shelf-1.4.2/lib/shelf_io.dart".
- Server Linux run: `sh server/tool/test_linux.sh` from repo root (Docker, read-only mount). Library source to check: dart-sdk lib/_http/http_impl.dart, pub cache shelf-*/lib/shelf_io.dart.
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

Docker (T-009, 2026-10-12): server image is scratch + dart /runtime/, cross-compiled via --platform=$BUILDPLATFORM; ignore rules in server/Dockerfile.dockerignore (applies only when -f server/Dockerfile with repo-root context: check T-010 Compose build block). License exception (glibc/MPL) holds only while the image is never pushed to a public registry: check T-011 for push steps. Scratch has no /tmp. Reviewed without docker builds (C: nearly full); rely on dev+QA runtime evidence.
- backend-developer (T-009): handoff open questions get decided on main but README keeps pointing at the handoff; check docs for stale "open question" pointers after decisions land.

App networking (T-013, 2026-10-12): ApiClient in lib/core/data/network; only GET retried; per-attempt Timer enforces 20 s deadline; followRedirects false; log interceptor only in kDebugMode, logs uri.path only. Server must answer upstream_unavailable with 503 + Retry-After (T-022/T-023/T-025), not 500.
- flutter-developer and qa-engineer (T-013): "sanity" tests with loose bounds (<=, isErr, lessThan) that pass on wrong behavior, e.g. int overflow in pow() backoff wrapping to 0. Check edge tests assert exact values; check `pow(...).toInt()` multiplications for 64-bit wrap.
- Forward: T-068/T-069 app attestation: 401 refresh once, POST too, inside the 20 s deadline. T-028: JsonDecoder typedef clashes with dart:convert.
- Backlog line to ticket id: `awk '/^### T-/{t=$0} NR==585{print t}' docs/backlog.md`.

Compose/deploy (T-010, 2026-10-12): local stack in deploy/, built via deploy/compose.sh (sets GIT_SHA/APP_VERSION). Forward for T-071: port binding (local should be 127.0.0.1, R1-S1), memswap_limit, POSTGRES_PASSWORD_FILE, journald retention, Caddy request_body/timeouts/-Server.
- qa-engineer (T-010): "env ignored" tests that pass a map to a function whose dependency reads Platform.environment (tautological). Dart HttpClient default findProxy = findProxyFromEnvironment (Platform.environment, no loopback bypass): proxy tests must be process tests.
- backend-developer (T-010): docs again pointed at handoff open questions already decided on main; check README pointers against main's decisions.md (`git show main:docs/decisions.md`).
- Merge-conflict check between ticket branches: `git merge-tree --write-tree --name-only <a> <b>` (read-only).

CI workflows (T-011 server.yml, T-014 app.yml, T-016 repo.yml; 2026-10-12):
- Default `run` shell without `shell:` is `bash -e` (no pipefail). T-014 convention: `defaults.run.shell: bash`, repeated in job defaults. Check every workflow for pipelines and awk without an END/NR==0 guard.
- Values from repo files or step outputs go through `env:`, not `${{ }}` inside `run:` (T-016 convention). backend-developer slipped on this in T-011.
- Dart coverage (coverage 1.15.1) counts only loaded libraries. Since T-011 round 2, server/tool/coverage_gate.dart (used by both packages) fails on lib files missing from lcov; exemptions: *.g.dart/*.freezed.dart, `// coverage:ignore-file`, directive-only. test_with_coverage passes --check-ignore, so the marker removes a file from the percentage too. On every ticket: `git diff main...HEAD | grep -n "coverage:ignore"` and question each marker (files with no executable lines, e.g. abstract interfaces, also never appear in lcov).
- Trial merge of two branches without checkout: `git merge-tree --write-tree --name-only --no-messages A B`.
- Run logs: `gh run view <id> --log | grep -E "line coverage|transferring context|ok \("`.
- App gate (T-014, app/tool/coverage_check.dart): generated imports test loads every in-scope file; files absent from lcov are inferred "no executable lines". flutter test --coverage ALSO honors coverage:ignore-file (flutter_tools coverage_collector checkIgnoredLines: true; coverage hitmap.dart:225 skips the file), so absence != no lines. flutter-developer (T-014) exempted generated files by name only; server gate needs name + GENERATED CODE header. Check both gates stay aligned (exemptions listed with reason, ::error::, step summary).
- T-014 round 3 (approved): app gate copies server's isGenerated/ignoreFilePattern; ignore-file FAILS in domain/data unless in ignoreFileAllowlist, exempt+listed in lib/core. Open: verdict line says "FAIL: 100.0%" when only a rule fails (R3-S1); 0/0 files via ignore-start/end pass in domain/data (R3-G1). Recheck when domain/data code lands.
- Gate tools: any report line starting with FAIL becomes an ::error:: annotation, so check that every FAIL line is a real reason.
- Pin check: `gh api repos/<r>/git/ref/tags/<tag> --jq '.object.type+" "+.object.sha'` (type must be commit, else follow the tag object).

CI script checks (T-098, 2026-10-12, approved round 1):
- Negative self-checks often prove only one case: Compose `${VAR:?}` stops at the FIRST missing variable, so a no-values run proves one guard only (R1-S1). Ask for one run per variable.
- Verify red-proof claims: `gh api repos/{owner}/{repo}/compare/<branch sha>...<scratch sha> --jq '.files[]|.filename+" "+.patch'` shows the scratch commit changed only the intended line (works after the scratch branch is deleted).
- Ubuntu 26.04 runners use the containerd image store: `docker image inspect` .Size is compressed size there; the smoke test measures `docker export` instead. ubuntu-latest moves from 2026-10-19.
- Log grep for step output without timestamps: `gh run view <id> --log | grep -E "ok \(|FAIL" | sed -E 's/^.*Z //'`.

Goldens (T-015, 2026-10-12, approved round 1):
- Rendered only by app.yml workflow_dispatch input update_goldens (job goldens-update, runs test/goldens only); checks job compares and uploads golden-failures. Guard in app/test/flutter_test_config.dart; helper goldenTest in app/test/helpers/goldens.dart skips off Linux only.
- Proof a golden ran on CI: CI "N passed" equals Windows passed + skipped. Proof PNGs are CI-rendered: commit after the render run, and the next push run's comparisons pass.
- flutter-developer (T-015): unanchored .gitignore patterns (`failures/` would hide lib/**/failures/). Check every new ignore rule for over-matching.
- New committed assets (fonts, images) also belong in docs/third-party-components.md (orchestrator-owned); developers record them only in the handoff.
- Flutter source facts: flutter_platform.dart sets comparator and autoUpdateGoldenFiles before testExecutable; runAsync reports errors via FlutterError.reportError (test fails, no hang).

Forward items to check in later tickets: release signing not debug key (T-014+), allowBackup decision before collection DB.

Flutter commands (Flutter not on PATH): `export PATH="/c/dev/flutter/bin:$PATH"` then from app/: `flutter pub get --enforce-lockfile`, `flutter analyze`, `dart format --output=none --set-exit-if-changed .`, `flutter test`.
Process note: edit the handoff only with the Edit tool, never sed -i (shell writes are not allowed for the reviewer).
