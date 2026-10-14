#!/bin/sh
# Runs the server checks (analyze, format, tests with coverage) on Linux in
# the official Dart image. Use it on Windows to run the Linux-only tests,
# such as the real SIGTERM test (T-008 AC9).
#
# Usage, from the repo root:  sh server/tool/test_linux.sh
#
# The repo is mounted read-only; the container copies server/,
# packages/api_contract/, and the root analysis_options.yaml into a scratch
# folder with the same layout, so nothing on the host changes.
#
# The tests need PostgreSQL (T-019): the script starts a throwaway
# PostgreSQL container (same image and initdb settings as
# deploy/docker-compose.yml) on a private Docker network and removes both
# when it ends.
set -eu

# Same tag and digest as DART_IMAGE in server/Dockerfile; change them together.
IMAGE="dart:3.13.5@sha256:8604cbd137b6d67c24f49b916f2aa9b67d71b539576e0178bf161d831c9e344f"
# Same tag and digest as deploy/docker-compose.yml; change them together.
PG_IMAGE="postgres:18.6-alpine3.24@sha256:77f585114c32fbca283dc835b0596f4e52b51b4c6662d7810b2f4084f60a1873"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NAME="boardgame-test-linux-$$"
# A throwaway password for a database that lives only as long as this run.
PG_PASSWORD="test-linux-$$"

cleanup() {
  docker rm -f "$NAME-pg" >/dev/null 2>&1 || true
  docker network rm "$NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker network create "$NAME" >/dev/null
docker run -d --name "$NAME-pg" --network "$NAME" --network-alias postgres \
  -e POSTGRES_USER=boardgame_test \
  -e POSTGRES_PASSWORD="$PG_PASSWORD" \
  -e POSTGRES_DB=boardgame_test \
  -e "POSTGRES_INITDB_ARGS=--locale-provider=builtin --locale=C.UTF-8" \
  "$PG_IMAGE" >/dev/null

# Ready when it accepts TCP connections (see deploy/README.md: the image's
# init-time server listens on the socket only).
tries=0
until docker exec "$NAME-pg" pg_isready -q -h 127.0.0.1 -U boardgame_test -d boardgame_test; do
  tries=$((tries + 1))
  if [ "$tries" -gt 60 ]; then
    docker logs "$NAME-pg" >&2 || true
    echo "PostgreSQL did not become ready within 60 s" >&2
    exit 1
  fi
  sleep 1
done

# MSYS_NO_PATHCONV stops Git Bash on Windows from rewriting the /src paths.
MSYS_NO_PATHCONV=1 docker run --rm \
  --network "$NAME" \
  -e TEST_DATABASE_HOST=postgres \
  -e TEST_DATABASE_PORT=5432 \
  -e TEST_DATABASE_USER=boardgame_test \
  -e TEST_DATABASE_PASSWORD="$PG_PASSWORD" \
  -e TEST_DATABASE_NAME=boardgame_test \
  -v "$REPO_ROOT:/src:ro" \
  "$IMAGE" \
  sh -c '
    set -eu
    mkdir -p /w/packages
    cp /src/analysis_options.yaml /w/
    tar -C /src -cf - --exclude=.dart_tool --exclude=coverage --exclude=build \
      server packages/api_contract | tar -C /w -xf -
    cd /w/packages/api_contract && dart pub get --enforce-lockfile >/dev/null
    cd /w/server && dart pub get --enforce-lockfile >/dev/null
    dart analyze --fatal-infos
    dart format --output=none --set-exit-if-changed .
    dart run coverage:test_with_coverage
    awk -F"[:,]" "/^LF:/{lf+=\$2} /^LH:/{lh+=\$2} END{printf \"line coverage: %d/%d = %.1f%%\n\", lh, lf, lh*100/lf}" coverage/lcov.info
  '
