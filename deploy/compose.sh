#!/bin/sh
# Runs Docker Compose for the local stack (deploy/docker-compose.yml) with the
# server image's build arguments set (T-010):
#   GIT_SHA      short commit hash of HEAD
#   APP_VERSION  <server/pubspec.yaml version>+<GIT_SHA>
# so GET /health reports the same version as server/tool/docker_build.sh.
#
# Usage, from anywhere in the repo:
#   sh deploy/compose.sh up -d --wait
#   sh deploy/compose.sh ps
#   sh deploy/compose.sh logs server
#   sh deploy/compose.sh down          # keeps volumes; add -v to delete data
#
# Like docker_build.sh, it refuses to build (up, build, create, run) while
# server/ or packages/api_contract/ has uncommitted changes, because the image
# would carry a commit hash that does not match its code. For a local
# experiment set ALLOW_DIRTY=1: the version then ends in -dirty.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPLOY_DIR="$REPO_ROOT/deploy"

if [ ! -f "$DEPLOY_DIR/.env" ]; then
  echo "error: deploy/.env is missing. Copy deploy/.env.example to deploy/.env and replace the placeholders." >&2
  exit 1
fi

GIT_SHA="$(git -C "$REPO_ROOT" rev-parse --short=7 HEAD)"

if [ -n "$(git -C "$REPO_ROOT" status --porcelain server packages/api_contract)" ]; then
  if [ "${ALLOW_DIRTY:-}" = "1" ]; then
    echo "warning: server/ or packages/api_contract/ has uncommitted changes; building as $GIT_SHA-dirty (ALLOW_DIRTY=1)" >&2
    GIT_SHA="$GIT_SHA-dirty"
  else
    case " $* " in
      *" up "* | *" build "* | *" --build "* | *" create "* | *" run "*)
        echo "error: server/ or packages/api_contract/ has uncommitted changes. Commit them, or set ALLOW_DIRTY=1 for a local build stamped -dirty." >&2
        exit 1
        ;;
    esac
  fi
fi

PUBSPEC_VERSION="$(sed -n 's/^version:[[:space:]]*//p' "$REPO_ROOT/server/pubspec.yaml" | tr -d '[:space:]')"
APP_VERSION="$PUBSPEC_VERSION+$GIT_SHA"
export GIT_SHA APP_VERSION

exec docker compose -f "$DEPLOY_DIR/docker-compose.yml" "$@"
