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

api_contract and server (from T-007):
- Commands (api_contract): PATH=/c/dev/flutter/bin/cache/dart-sdk/bin; `dart test`; `dart run coverage:test_with_coverage`; freezed files are not instrumented in lcov.
- Docker check from Git Bash: `MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/repo" -w /repo/packages/api_contract dart:stable sh -c '...'`.
- api_contract decoding: json_serializable checked mode; null/missing required -> CheckedFromJsonException with key; unknown enum -> ErrorCode.unknown.
- Git Bash /tmp is not visible to Windows python; do file edits with bash tools.
server (from T-008):
- Windows: PATH=/c/dev/flutter/bin/cache/dart-sdk/bin; from server/: `dart analyze`, `dart test`. Linux: from repo root `sh server/tool/test_linux.sh` (prints coverage).
- Real-process tests: spawn `Platform.resolvedExecutable bin/server.dart` with PORT env, wait for "server started" line, use `rawHttp`/`rawBody`/`freePort` from test/support/harness.dart. Test-only child: test/support/guard_server.dart (throwing /v1 guards).
- Use "secret" as the marker in client values and assert it never appears in logs; do not reuse the word in your own thrown messages or the check false-fails.
- Heredocs with many quotes/escapes can break the Bash tool; use the Write tool for Dart test files.

Server and more (from T-008):
- Commands (server): PATH=/c/dev/flutter/bin/cache/dart-sdk/bin; in server/: `dart analyze`, `dart format --output=none --set-exit-if-changed .`, `dart test`, `dart run coverage:test_with_coverage` (lcov at coverage/lcov.info). Linux: `sh server/tool/test_linux.sh` from repo root.
- Server test harness: server/test/support/harness.dart (TestApp, LogCapture, freePort); runServer takes an injected signal stream, so shutdown tests run in-process on real sockets.
- Docker Desktop's WSL engine can fail to start (seen 2026-10-12); report the Linux run as NOT RUN, never claim it.
- Bash tool: big heredocs with quotes can hang or fail to parse; use the Write tool for test files. Never put a bare `python3 -` in a command (waits on stdin).

Docker (from T-009):
- Dockerfile QA: `sh server/tool/docker_build.sh --platform linux/arm64,linux/amd64 --load -t <tag>` works (containerd store, arm64 cross-compiled, no QEMU to build). Run arm64 with `--platform linux/arm64` (QEMU). Use `MSYS_NO_PATHCONV=1`.
- Host C: can be at 100% full while Docker's own disk has space; builds still worked. Cleanup: `docker image rm`, `docker image rm --force --platform linux/arm64 dart:3.13.5`, then prune cache records by id (`docker buildx du --verbose`, filter by Created at; ~60 MB shared records stay).
Compose (from T-010):
- Do NOT set MSYS_NO_PATHCONV when running `sh deploy/compose.sh` (native git gets /c/ paths and fails). DO set it for `docker exec ... /app/server` and `docker run --entrypoint /app/...`, or the path becomes C:/Program Files/Git/app.
- Build context size: warm cache says 1.94kB, cold says 92.44kB (real sources). Reproduce with `docker buildx prune -f --filter type=source.local`. Never treat "about 2 kB" as a pass/fail number.
- Plain `docker compose up` without the wrapper fails (no GIT_SHA) and leaves killed containers down.
- Windows closed-port connects can hang until the timeout; assert only the exit code.
- Build context check: throwaway `Ctx.Dockerfile` + copy named `Ctx.Dockerfile.dockerignore` in scratchpad, `-f` it with repo root context, `find /ctx`.
CI workflow QA (from T-014):
- Verify runs with `gh run view <id> --repo bartbasi/boardgame --json jobs --jq ...` and `--log > file`; confirm action tags with `gh api repos/<r>/git/ref/tags/<tag>`.
- In flutter_test, `Platform.resolvedExecutable` is flutter_tester, not dart: spawning it with `run` hangs forever (kill with `taskkill //F //IM flutter_tester.exe`). Use `Process.runSync('dart', ..., runInShell: true)` on Windows.
- `flutter test` has no `-n`; use `--plain-name`. Job-level `defaults.run` replaces workflow-level, losing `shell: bash` (pipefail); check every job.
