# Server image for linux/arm64 (Oracle Cloud Ampere VM) and linux/amd64 (local
# use, or an AMD VM shape). T-009.
#
# Build from the repo root; the build context is the whole repo, filtered by
# server/Dockerfile.dockerignore (docs/decisions.md, T-004):
#
#   sh server/tool/docker_build.sh --platform linux/arm64,linux/amd64
#
# or by hand:
#
#   sha=$(git rev-parse --short=7 HEAD)
#   docker buildx build -f server/Dockerfile \
#     --build-arg GIT_SHA=$sha --build-arg APP_VERSION=0.1.0+$sha \
#     --platform linux/arm64,linux/amd64 .
#
# GIT_SHA is 7 to 40 lowercase hex characters, optionally followed by -dirty.
# APP_VERSION must equal `<server/pubspec.yaml version>+<GIT_SHA>`; the build
# checks it and fails otherwise. It is passed in only so the image can carry
# it as a label.
#
# How it works:
# - The build stage always runs on the build machine's own platform and
#   cross-compiles with `dart compile exe --target-os=linux --target-arch=...`
#   (supported for Linux arm64 and x64 since Dart 3.8,
#   https://dart.dev/tools/dart-compile). No CPU emulation is needed.
# - The final stage is `scratch` with only the AOT executable and the
#   official image's /runtime/ folder (glibc loader and libraries, CA
#   certificates, nsswitch.conf) for the target platform (decisions.md, T-005).
#   No shell, no Dart SDK, no source.
# - The build version is `<server/pubspec.yaml version>+<GIT_SHA>`, compiled in
#   with -DAPP_VERSION and reported by GET /health (decisions.md, T-008).

# dart:3.13.5, multi-platform index digest (checked 2026-10-12 with
# `docker buildx imagetools inspect dart:3.13.5`). Base image: Debian trixie-slim.
ARG DART_IMAGE=dart:3.13.5@sha256:8604cbd137b6d67c24f49b916f2aa9b67d71b539576e0178bf161d831c9e344f

# ---------------------------------------------------------------------------
# Build stage: runs natively on the build machine, emits a target-arch binary.
FROM --platform=$BUILDPLATFORM ${DART_IMAGE} AS build

WORKDIR /src

# Resolve dependencies first so the layer is reused while only code changes.
# The server depends on ../packages/api_contract by path, so keep the layout.
COPY packages/api_contract/pubspec.yaml packages/api_contract/pubspec.lock packages/api_contract/
COPY server/pubspec.yaml server/pubspec.lock server/
RUN cd server && dart pub get --enforce-lockfile

COPY packages/api_contract/lib packages/api_contract/lib
COPY server/bin server/bin
COPY server/lib server/lib

ARG TARGETARCH
ARG GIT_SHA
ARG APP_VERSION
RUN set -eu; \
    case "${TARGETARCH}" in \
      amd64) dart_arch=x64 ;; \
      arm64) dart_arch=arm64 ;; \
      *) echo "T-009: unsupported target architecture '${TARGETARCH}' (use linux/amd64 or linux/arm64)" >&2; exit 1 ;; \
    esac; \
    if ! printf '%s' "${GIT_SHA:-}" | grep -Eqx '[0-9a-f]{7,40}(-dirty)?'; then \
      echo "T-009: build arg GIT_SHA is required: the short git commit hash, for example --build-arg GIT_SHA=\$(git rev-parse --short=7 HEAD)" >&2; \
      exit 1; \
    fi; \
    pubspec_version="$(sed -n 's/^version:[[:space:]]*//p' server/pubspec.yaml | tr -d '[:space:]')"; \
    if ! printf '%s' "${pubspec_version}" | grep -Eqx '[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?'; then \
      echo "T-009: server/pubspec.yaml version '${pubspec_version}' must be MAJOR.MINOR.PATCH with no +build part" >&2; \
      exit 1; \
    fi; \
    app_version="${pubspec_version}+${GIT_SHA}"; \
    if [ "${APP_VERSION:-}" != "${app_version}" ]; then \
      echo "T-009: build arg APP_VERSION must be '${app_version}' (server/pubspec.yaml version + GIT_SHA), got '${APP_VERSION:-}'" >&2; \
      exit 1; \
    fi; \
    echo "T-009: compiling server ${app_version} for linux/${dart_arch}"; \
    mkdir -p /out; \
    cd server; \
    dart compile exe \
      --target-os=linux \
      --target-arch="${dart_arch}" \
      "-DAPP_VERSION=${app_version}" \
      -o /out/server \
      bin/server.dart

# ---------------------------------------------------------------------------
# Runtime files for the target platform. Nothing runs in this stage (no RUN),
# so building the other platform needs no emulation.
FROM ${DART_IMAGE} AS runtime-files

# ---------------------------------------------------------------------------
# Final image.
FROM scratch

# Both values were checked in the build stage (APP_VERSION is pubspec version
# plus GIT_SHA), so the labels match what GET /health reports.
ARG GIT_SHA
ARG APP_VERSION
LABEL org.opencontainers.image.title="boardgame-server" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.version="${APP_VERSION}"

COPY --from=runtime-files /runtime/ /
COPY --from=build /out/server /app/server

# Unprivileged numeric user and group (scratch has no /etc/passwd). The server
# listens on PORT from the environment; Compose (T-010) uses 8080.
USER 65532:65532

EXPOSE 8080

# Exec form: the server is PID 1 and receives SIGTERM from `docker stop`
# directly. It drains for up to 10 s, so Compose sets stop_grace_period: 15s
# (T-010).
ENTRYPOINT ["/app/server"]
