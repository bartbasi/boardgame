---
name: ci-server-workflow
description: server.yml facts learned on GitHub Actions (T-011 build context size truth, gha cache, QEMU vs arm64 runners, guard quirks, minutes; T-098 Ubuntu 26 containerd store and image size)
metadata:
  type: project
---

Learned on T-011 (2026-10-12), repo bartbasi/boardgame (private):

- BuildKit "transferring context" is incremental: a warm builder sends only unseen files (1.84 kB), a fresh one sends everything (86.86 kB = the allowlisted files). Check context size on a builder that has never seen it (`--builder default`, the engine's own builder, after setup-buildx made another the default).
- build-push-action with `type=gha,mode=max`: on the next run the arm64 `runtime-files` stage only resolves (no pull) and the cross-compiler warm-up layer is CACHED. The compile step always reruns because GIT_SHA changes per commit, so the amd64 dart build-stage image (~240 MB layer) is pulled from cache each run; unavoidable.
- `push: false` with several platforms prints "No output specified ... remain in the build cache"; load each platform separately with `load: true` (cache hits) for smoke tests. `DOCKER_BUILD_RECORD_UPLOAD: false` keeps runs at 0 artifacts.
- arm64 hosted runners are billed for private repos; use docker/setup-qemu-action with the binfmt image pinned by digest. arm64 /health under QEMU answers in ~0.4 s.
- `coverage:test_with_coverage` (1.15.1) reports ONLY libraries the tests loaded; an unimported lib file is silently absent (my round 1 claim otherwise was wrong: the barrel export made everything load). server/tool/coverage_gate.dart (orchestrator decision, T-011 R1-S3) fails if any lib file is missing from lcov SF lines, except *.g.dart, *.freezed.dart, `// coverage:ignore-file`, and directive-only barrels. Const-only files (lib/src/version.dart) never appear in lcov even when loaded, so they need the ignore marker. Round 3: the marker is matched per line with coverage's own regex (`//\s*coverage:ignore-file[\w\d\s]*$`, coverage lib/src/util.dart), generated files need the GENERATED CODE header, and every exemption is printed with its reason and written to the step summary.
- Workflows: `defaults.run.shell: bash` for pipefail (repeat in job defaults, which replace workflow ones); pass step outputs to scripts via `env:`; `persist-credentials: false`; BuildKit pinned via setup-buildx `driver-opts: image=moby/buildkit:<v>@sha256:...`; don't cancel runs on main.
- Heredocs or Bash commands whose text contains the word "git" (even in a comment) get refused by the worktree guard; use the Edit tool.
- Run cost: server.yml ~2 min wall, ~5 billed minutes per run (3 jobs rounded up). The `/timing` API returns 0 billable; estimate from job durations.
- Worktree guard: `for` loops over gh/git and `git ls-files | xargs` pipelines get refused; run plain separate commands. GitHub API shares a 5,000/h limit across agents; check `gh api rate_limit` after a warning.


Learned on T-098 (2026-10-12):

- Ubuntu 26.04 runners (label `ubuntu-26.04` usable now; ubuntu-latest moves 2026-10-19 to 11-19) run Docker 29 with the containerd image store: `docker image inspect .Size` becomes the COMPRESSED size (5.1 MB vs 11.6 MB unpacked on 24.04's overlay2). Docker Desktop locally is containerd too. Measure unpacked size with `docker create` + `docker export -o file` + `wc -c` (same 11.85 MB on both). Compose is v5.1.3 there; `config -q` behaves the same.
- To pre-test a runner image, push a scratch branch with `runs-on` swapped; the "Runner and Docker" step in server.yml prints ImageOS/ImageVersion and the storage driver.
- `docker exec -e PORT=<unused> <c> /app/server --healthcheck` is a clean "nothing listening" case (exit 1, reason "connection failed") inside the real container, also under QEMU.
- Compose `config -q` fails on unknown service keys (schema), not only YAML syntax; `--env-file /dev/null` proves the `${VAR:?}` guards.

**Why:** these cost a round to find; later CI tickets (T-014 app.yml, T-017 licenses) will hit the same.
**How to apply:** reuse the smoke script and the fresh-builder context check; keep arm64 on QEMU while private; prove gates with a scratch branch and delete it.

Related: [[docker-dart-aot-notes]], [[worktree-shell-limits]]
