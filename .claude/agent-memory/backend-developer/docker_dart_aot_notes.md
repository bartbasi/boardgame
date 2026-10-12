---
name: docker-dart-aot-notes
description: Dart AOT server in Docker (cross-compile multi-arch pattern, scratch image, measured sizes/RSS) and Windows/agent tooling quirks for Docker builds and cleanup
metadata:
  type: project
---

Dart 3.13.5 AOT server on `FROM scratch` + official image `/runtime/`: about 8.6 MB VmRSS idle, 7.4 MB executable, ~5 MB compressed image per platform (measured T-005 and T-009, 2026-10-12). `dart:3.13.5` index digest sha256:8604cbd1...344f has amd64 and arm64.

**Why:** PRD memory targets and the OCI idle-reclaim rule (B8) depend on real numbers; disk on the dev machine is tight (under 10 GB free).

**How to apply:**
- Multi-arch without QEMU (T-009, server/Dockerfile): build stage `FROM --platform=$BUILDPLATFORM`, `dart compile exe --target-os=linux --target-arch=$arch` (amd64->x64, arm64->arm64; officially supported since Dart 3.8; downloads cross tools, ~13 s). Runtime files from a target-platform `FROM dart` stage with no RUN. Both platforms built in ~20 s.
- But that runtime stage pulls the whole arm64 dart image (~1.2 GB) locally. Cleanup: `docker image rm --force --platform linux/arm64 dart:3.13.5` (dart:stable shares the index, hence --force), then prune only own cache records: `docker builder prune -f --filter id=<id>` one id at a time (the filter takes one value), repeat passes because parents free up after children. List with `docker buildx du --verbose` and filter by "Created at". Docker Desktop's VHDX does not shrink, so Windows free space still drops.
- Docker Desktop uses the containerd store: `--load` works for multi-platform images; `docker image inspect --platform linux/arm64` inspects one variant; `docker run --platform linux/arm64` runs it under QEMU.
- Docker gives non-root containers ports below 1024 (PORT=80 bound fine as 65532), so do not claim otherwise.
- Dockerfile-specific ignore: `server/Dockerfile.dockerignore` next to server/Dockerfile overrides a root .dockerignore. Verify the context with a throwaway `COPY . /ctx` + `find` Dockerfile under server/build/ with a copy of the ignore file.
- Scratch image has no shell: read RSS with `docker run --rm --pid=container:<name> busybox:1.37 grep VmRSS /proc/1/status`; Compose health checks need an in-binary probe (open in T-009 handoff).
- The worktree guard refuses Bash commands that mix `{{...}}` Go templates with pipes or loops (thinks it might be git); run `docker inspect -f '{{...}}'` as its own plain command.
- If the Docker engine pipe is missing, `docker desktop start` works.
- `dart analyze` in a worktree under C:\bart\boardgame picks up the main checkout's analysis_options.yaml; add a local one in standalone packages.

Related: [[backend-framework-choice]], [[worktree-shell-limits]], [[server-skeleton-patterns]]
