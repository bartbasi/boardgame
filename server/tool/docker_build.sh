#!/bin/sh
# Builds the server image with server/Dockerfile, passing the short git commit
# hash so GET /health reports `<pubspec version>+<sha>` (T-009).
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
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GIT_SHA="$(git -C "$REPO_ROOT" rev-parse --short=7 HEAD)"

if [ -n "$(git -C "$REPO_ROOT" status --porcelain -- server packages/api_contract)" ]; then
  echo "warning: server/ or packages/api_contract/ has uncommitted changes; the image is labeled $GIT_SHA but does not match that commit" >&2
fi

exec docker buildx build \
  -f "$REPO_ROOT/server/Dockerfile" \
  --build-arg "GIT_SHA=$GIT_SHA" \
  "$@" \
  "$REPO_ROOT"
