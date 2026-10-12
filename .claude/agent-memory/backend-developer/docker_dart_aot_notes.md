---
name: docker-dart-aot-notes
description: Measured Dart AOT server footprint in Docker, scratch-image pattern, and Windows/agent tooling quirks for running Docker and scripts
metadata:
  type: project
---

Dart 3.13.5 AOT `/health` server (shelf or dart_frog) on `FROM scratch` + official image `/runtime/`: about 8.2 to 8.4 MB VmRSS idle, 7.4 MB executable, ~5 MB image (amd64, measured 2026-10-12 in T-005). `dart:3.13.5` manifest has amd64 and arm64.

**Why:** PRD memory targets (512 MB idle stack) and the OCI idle-reclaim rule (B8) depend on real numbers; the Dart process is negligible, PostgreSQL and Caddy dominate.

**How to apply:**
- Scratch image has no shell: read RSS with `docker run --rm --pid=container:<name> busybox:1.37 grep VmRSS /proc/1/status`.
- `docker stats` (cgroup) reads lower than RSS because binary file pages are not charged to the container.
- If the Docker engine pipe is missing, `docker desktop start` works; launching the .exe, cmd, or powershell is blocked by the worktree guard.
- The worktree guard also blocks commands containing "github" URLs and `$var` in option position: put helper scripts under the ticket's spike folder, not the OS temp dir (guard-paths blocks writes outside the repo).
- The worktree sits under C:\bart\boardgame, so `dart analyze` picks up the main checkout's analysis_options.yaml; add a local one in standalone packages.

Related: [[backend-framework-choice]]
