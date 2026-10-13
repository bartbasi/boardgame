#!/bin/sh
# Smoke-tests one platform of a loaded server image (T-011 AC9 b to d, the
# checks listed in docs/handoffs/T-009.md "What CI (T-011) must verify").
# CI runs it for linux/amd64 and, under QEMU, for linux/arm64.
#
# Usage, from anywhere:
#   sh server/tool/image_smoke_test.sh IMAGE PLATFORM EXPECTED_VERSION
#
#   IMAGE             a loaded image, for example boardgame-server:ci-amd64
#   PLATFORM          linux/amd64 or linux/arm64 (arm64 on an x64 host needs
#                     QEMU binfmt handlers)
#   EXPECTED_VERSION  the version GET /health must report:
#                     <server/pubspec.yaml version>+<GIT_SHA>
#
# Checks, in order:
#   1. The image architecture matches PLATFORM, the user is 65532:65532, and
#      the unpacked file system (`docker export` size) is 100 MB or less.
#   2. With PORT, LOG_LEVEL, and the DATABASE_* settings of a throwaway
#      PostgreSQL container (same image and initdb settings as
#      deploy/docker-compose.yml, on a private network), GET /health returns
#      200 with status and database "ok" and EXPECTED_VERSION within 5
#      seconds of `docker run`, and the migrations were recorded (T-019).
#   3. `docker exec <container> /app/server --healthcheck` exits 0 while the
#      server is up, 1 when nothing listens on PORT, and an unknown argument
#      exits 64 (T-098 AC1).
#   4. PostgreSQL stopped: GET /health answers 503 with database
#      "unavailable" within 2 s, --healthcheck exits 1, and the server keeps
#      running; PostgreSQL started again: /health is 200 again (T-019 AC6).
#   5. `docker stop` (SIGTERM) makes it exit 0.
#   6. With no environment, it exits 78.
#
# Needs docker, curl, and jq (all present on GitHub's ubuntu runners).
# HOST_PORT (default 18080) is the local port mapped to the container.
# The PostgreSQL container runs on the host's own platform (no QEMU).
set -eu

if [ "$#" -ne 3 ]; then
  echo "usage: sh server/tool/image_smoke_test.sh IMAGE PLATFORM EXPECTED_VERSION" >&2
  exit 2
fi

IMAGE="$1"
PLATFORM="$2"
EXPECTED_VERSION="$3"
HOST_PORT="${HOST_PORT:-18080}"
MAX_BYTES=100000000
HEALTH_DEADLINE_MS=5000
# T-019 AC6: /health must answer within 2 s while the database is down.
DB_DOWN_DEADLINE_MS=2000
NAME="boardgame-smoke-$$"
WORK="$(mktemp -d)"
# Same tag and digest as deploy/docker-compose.yml; change them together.
PG_IMAGE="postgres:18.6-alpine3.24@sha256:77f585114c32fbca283dc835b0596f4e52b51b4c6662d7810b2f4084f60a1873"
# A throwaway password for a database that lives only as long as this run.
PG_PASSWORD="smoke-$$"

cleanup() {
  docker rm -f "$NAME" "$NAME-noenv" "$NAME-fs" "$NAME-pg" >/dev/null 2>&1 || true
  docker network rm "$NAME" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

fail() {
  echo "FAIL ($PLATFORM): $*" >&2
  exit 1
}

now_ms() {
  echo $(($(date +%s%N) / 1000000))
}

# Waits up to 60 s until PostgreSQL accepts TCP connections (deploy/README.md
# explains why the check uses TCP and not the socket).
wait_for_postgres() {
  tries=0
  until docker exec "$NAME-pg" pg_isready -q -h 127.0.0.1 -U smoke -d smoke; do
    tries=$((tries + 1))
    if [ "$tries" -gt 60 ]; then
      docker logs "$NAME-pg" >&2 || true
      fail "PostgreSQL did not become ready within 60 s"
    fi
    sleep 1
  done
}

# GET /health once: prints the status code; the body goes to $WORK/body.
health() {
  curl -s -o "$WORK/body" -w '%{http_code}' --max-time 5 \
    "http://127.0.0.1:$HOST_PORT/health" || true
}

# 1. Image metadata.
arch="$(docker image inspect -f '{{.Os}}/{{.Architecture}}' "$IMAGE")"
[ "$arch" = "$PLATFORM" ] || fail "image platform is $arch"
user="$(docker image inspect -f '{{.Config.User}}' "$IMAGE")"
[ "$user" = "65532:65532" ] || fail "image user is '$user', want 65532:65532"
# The limit applies to the unpacked file system, measured as the size of
# `docker export` of a created (never started) container: a tar of every
# file, so it means the same on every Docker image store. `docker image
# inspect` .Size does not: the classic overlay2 store reports the unpacked
# size, the containerd image store (the default on Ubuntu 26.04 runners,
# Docker 29) reports the compressed content size, about half (T-098 AC3).
# It is printed for the record only.
store_size="$(docker image inspect -f '{{.Size}}' "$IMAGE")"
docker create --pull never --name "$NAME-fs" --platform "$PLATFORM" "$IMAGE" >/dev/null
docker export -o "$WORK/rootfs.tar" "$NAME-fs"
docker rm "$NAME-fs" >/dev/null
unpacked="$(wc -c <"$WORK/rootfs.tar" | tr -d '[:space:]')"
rm -f "$WORK/rootfs.tar"
[ "$unpacked" -le "$MAX_BYTES" ] ||
  fail "unpacked file system is $unpacked bytes, limit $MAX_BYTES"
echo "ok ($PLATFORM): platform $arch, user $user, unpacked file system $unpacked bytes (limit $MAX_BYTES); docker image inspect .Size $store_size bytes"

# 2. GET /health within 5 s, with a real PostgreSQL behind it.
docker network create "$NAME" >/dev/null
docker run -d --name "$NAME-pg" --network "$NAME" --network-alias postgres \
  -e POSTGRES_USER=smoke -e POSTGRES_PASSWORD="$PG_PASSWORD" -e POSTGRES_DB=smoke \
  -e "POSTGRES_INITDB_ARGS=--locale-provider=builtin --locale=C.UTF-8" \
  "$PG_IMAGE" >/dev/null
wait_for_postgres

start="$(now_ms)"
docker run -d --name "$NAME" --platform "$PLATFORM" --network "$NAME" \
  -e PORT=8080 -e LOG_LEVEL=info \
  -e DATABASE_HOST=postgres -e DATABASE_NAME=smoke -e DATABASE_USER=smoke \
  -e DATABASE_PASSWORD="$PG_PASSWORD" \
  -p "127.0.0.1:$HOST_PORT:8080" "$IMAGE" >/dev/null
code=""
while :; do
  code="$(curl -s -o "$WORK/body" -w '%{http_code}' --max-time 1 \
    "http://127.0.0.1:$HOST_PORT/health" || true)"
  [ "$code" = "200" ] && break
  if [ $(($(now_ms) - start)) -gt "$HEALTH_DEADLINE_MS" ]; then
    docker logs "$NAME" >&2 || true
    fail "GET /health did not return 200 within ${HEALTH_DEADLINE_MS} ms (last status '$code')"
  fi
  sleep 0.1
done
elapsed=$(($(now_ms) - start))
[ "$elapsed" -le "$HEALTH_DEADLINE_MS" ] || fail "GET /health took $elapsed ms"
status="$(jq -er '.status' "$WORK/body")" || fail "health body has no status"
version="$(jq -er '.version' "$WORK/body")" || fail "health body has no version"
database="$(jq -er '.database' "$WORK/body")" || fail "health body has no database"
[ "$status" = "ok" ] || fail "health status is '$status'"
[ "$database" = "ok" ] || fail "health database is '$database'"
[ "$version" = "$EXPECTED_VERSION" ] ||
  fail "health version is '$version', want '$EXPECTED_VERSION'"
echo "ok ($PLATFORM): GET /health 200 in $elapsed ms, version $version, database ok"
migrated="$(docker exec "$NAME-pg" psql -At -U smoke -d smoke -c 'SELECT count(*) FROM schema_migrations')" ||
  fail "schema_migrations is missing"
[ "$migrated" -ge 1 ] || fail "no migration was recorded"
docker logs "$NAME" 2>&1 | grep -q '"msg":"database schema up to date"' ||
  fail "no 'database schema up to date' log line"
echo "ok ($PLATFORM): $migrated migration(s) recorded in schema_migrations"

# 3. The Compose health check (`/app/server --healthcheck`, T-010 AC12,
# T-098 AC1) inside the running container: exit 0 while the server answers;
# exit 1 with reason "connection failed" when nothing listens on PORT (the
# same container with PORT pointed at a port no process uses); exit 64 for
# an unknown argument. Any other exit code fails the step. Each run is
# limited to 30 s so a hang fails instead of stalling the job.
set +e
timeout 30 docker exec "$NAME" /app/server --healthcheck >"$WORK/hc.log" 2>&1
hc_code=$?
set -e
[ "$hc_code" -eq 0 ] || {
  cat "$WORK/hc.log" >&2
  docker logs "$NAME" >&2 || true
  fail "--healthcheck with the server up exited $hc_code, want 0"
}
echo "ok ($PLATFORM): --healthcheck with the server up exited 0"

set +e
timeout 30 docker exec -e PORT=8099 "$NAME" /app/server --healthcheck >"$WORK/hc-down.log" 2>&1
hc_down_code=$?
set -e
[ "$hc_down_code" -eq 1 ] || {
  cat "$WORK/hc-down.log" >&2
  docker logs "$NAME" >&2 || true
  fail "--healthcheck with nothing listening exited $hc_down_code, want 1"
}
reason="$(jq -er '.reason' "$WORK/hc-down.log")" ||
  fail "--healthcheck output is not one JSON line with a reason: $(cat "$WORK/hc-down.log")"
[ "$reason" = "connection failed" ] ||
  fail "--healthcheck with nothing listening gave reason '$reason', want 'connection failed'"
echo "ok ($PLATFORM): --healthcheck with nothing listening exited 1: $(cat "$WORK/hc-down.log")"

set +e
timeout 30 docker exec "$NAME" /app/server --no-such-flag >"$WORK/hc-usage.log" 2>&1
usage_code=$?
set -e
[ "$usage_code" -eq 64 ] || {
  cat "$WORK/hc-usage.log" >&2
  docker logs "$NAME" >&2 || true
  fail "an unknown argument exited $usage_code, want 64"
}
echo "ok ($PLATFORM): an unknown argument exited 64"

# 4. PostgreSQL down: 503 within 2 s, the server keeps running; back up: 200.
docker stop "$NAME-pg" >/dev/null
# The last good result is reused for 1 s; poll until the server notices.
deadline=$(($(now_ms) + 10000))
code=""
while [ "$(now_ms)" -lt "$deadline" ]; do
  code="$(health)"
  [ "$code" = "503" ] && break
  sleep 0.2
done
[ "$code" = "503" ] || fail "GET /health with PostgreSQL stopped returned '$code', want 503"
start="$(now_ms)"
code="$(health)"
elapsed=$(($(now_ms) - start))
[ "$code" = "503" ] || fail "GET /health with PostgreSQL stopped returned '$code', want 503"
[ "$elapsed" -le "$DB_DOWN_DEADLINE_MS" ] ||
  fail "GET /health with PostgreSQL stopped took $elapsed ms, limit $DB_DOWN_DEADLINE_MS ms"
database="$(jq -er '.database' "$WORK/body")" || fail "503 body has no database"
[ "$database" = "unavailable" ] || fail "503 body database is '$database'"
running="$(docker inspect -f '{{.State.Running}}' "$NAME")"
[ "$running" = "true" ] || fail "the server stopped when PostgreSQL went away"
set +e
timeout 30 docker exec "$NAME" /app/server --healthcheck >"$WORK/hc-db.log" 2>&1
hc_db_code=$?
set -e
[ "$hc_db_code" -eq 1 ] || {
  cat "$WORK/hc-db.log" >&2
  fail "--healthcheck with PostgreSQL stopped exited $hc_db_code, want 1"
}
echo "ok ($PLATFORM): PostgreSQL stopped: GET /health 503 in $elapsed ms, database unavailable, --healthcheck exited 1: $(cat "$WORK/hc-db.log")"

docker start "$NAME-pg" >/dev/null
wait_for_postgres
deadline=$(($(now_ms) + 30000))
code=""
while [ "$(now_ms)" -lt "$deadline" ]; do
  code="$(health)"
  [ "$code" = "200" ] && break
  sleep 0.5
done
[ "$code" = "200" ] || {
  docker logs "$NAME" >&2 || true
  fail "GET /health after PostgreSQL restarted returned '$code', want 200"
}
echo "ok ($PLATFORM): PostgreSQL back: GET /health 200 again"

# 5. SIGTERM: clean exit.
docker stop "$NAME" >/dev/null
stop_code="$(docker inspect -f '{{.State.ExitCode}}' "$NAME")"
[ "$stop_code" = "0" ] || {
  docker logs "$NAME" >&2 || true
  fail "exit code after docker stop is $stop_code, want 0"
}
docker rm "$NAME" >/dev/null
echo "ok ($PLATFORM): docker stop exited 0"

# 6. No environment: config error, exit 78.
# Named so the EXIT trap removes it, and limited to 30 s so a server that
# wrongly starts without config fails the step instead of hanging the job
# (timeout then exits 124).
set +e
timeout 30 docker run --rm --name "$NAME-noenv" --platform "$PLATFORM" "$IMAGE" >"$WORK/noenv.log" 2>&1
noenv_code=$?
set -e
[ "$noenv_code" -eq 78 ] || {
  cat "$WORK/noenv.log" >&2
  fail "exit code with no environment is $noenv_code, want 78"
}
echo "ok ($PLATFORM): no environment exited 78: $(cat "$WORK/noenv.log")"
