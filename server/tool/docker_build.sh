#!/bin/sh
# Builds the server image with server/Dockerfile, passing the short git commit
# hash and the build version so GET /health reports `<pubspec version>+<sha>`
# (T-009).
#
# Usage, from anywhere in the repo:
#   sh server/tool/docker_build.sh [docker buildx build options]
#
# Examples:
#   sh server/tool/docker_build.sh --platform linux/amd64 --load -t boardgame-server:local
#   sh server/tool/docker_build.sh --platform linux/arm64,linux/amd64
#
# Extra options go straight to `docker buildx build`. The build context is the
# repo root, filtered by server/Dockerfile.dockerignore.
#
# The build stops if server/ or packages/api_contract/ has uncommitted
# changes, because the image would carry a commit hash that does not match its
# code. For a local experiment, set ALLOW_DIRTY=1: the version then ends in
# -dirty (for example 0.1.0+abc1234-dirty). Never deploy a -dirty image.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GIT_SHA="$(git -C "$REPO_ROOT" rev-parse --short=7 HEAD)"

if [ -n "$(git -C "$REPO_ROOT" status --porcelain -- server packages/api_contract)" ]; then
  if [ "${ALLOW_DIRTY:-}" = "1" ]; then
    echo "warning: server/ or packages/api_contract/ has uncommitted changes; building as $GIT_SHA-dirty (ALLOW_DIRTY=1)" >&2
    GIT_SHA="$GIT_SHA-dirty"
  else
    echo "error: server/ or packages/api_contract/ has uncommitted changes. Commit them, or set ALLOW_DIRTY=1 for a local build stamped -dirty." >&2
    exit 1
  fi
fi

PUBSPEC_VERSION="$(sed -n 's/^version:[[:space:]]*//p' "$REPO_ROOT/server/pubspec.yaml" | tr -d '[:space:]')"
APP_VERSION="$PUBSPEC_VERSION+$GIT_SHA"

exec docker buildx build \
  -f "$REPO_ROOT/server/Dockerfile" \
  --build-arg "GIT_SHA=$GIT_SHA" \
  --build-arg "APP_VERSION=$APP_VERSION" \
  "$@" \
  "$REPO_ROOT"
