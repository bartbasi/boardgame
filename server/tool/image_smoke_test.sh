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
#   2. With PORT and LOG_LEVEL set, GET /health returns 200 with status "ok"
#      and EXPECTED_VERSION within 5 seconds of `docker run`.
#   3. `docker exec <container> /app/server --healthcheck` exits 0 while the
#      server is up, 1 when nothing listens on PORT, and an unknown argument
#      exits 64 (T-098 AC1).
#   4. `docker stop` (SIGTERM) makes it exit 0.
#   5. With no environment, it exits 78.
#
# Needs docker, curl, and jq (all present on GitHub's ubuntu runners).
# HOST_PORT (default 18080) is the local port mapped to the container.
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
NAME="boardgame-smoke-$$"
WORK="$(mktemp -d)"

cleanup() {
  docker rm -f "$NAME" "$NAME-noenv" "$NAME-fs" >/dev/null 2>&1 || true
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

# 2. GET /health within 5 s.
start="$(now_ms)"
docker run -d --name "$NAME" --platform "$PLATFORM" \
  -e PORT=8080 -e LOG_LEVEL=info \
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
[ "$status" = "ok" ] || fail "health status is '$status'"
[ "$version" = "$EXPECTED_VERSION" ] ||
  fail "health version is '$version', want '$EXPECTED_VERSION'"
echo "ok ($PLATFORM): GET /health 200 in $elapsed ms, version $version"

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

# 4. SIGTERM: clean exit.
docker stop "$NAME" >/dev/null
stop_code="$(docker inspect -f '{{.State.ExitCode}}' "$NAME")"
[ "$stop_code" = "0" ] || {
  docker logs "$NAME" >&2 || true
  fail "exit code after docker stop is $stop_code, want 0"
}
docker rm "$NAME" >/dev/null
echo "ok ($PLATFORM): docker stop exited 0"

# 5. No environment: config error, exit 78.
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
