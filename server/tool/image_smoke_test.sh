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
#      the unpacked image is 100 MB or less.
#   2. With PORT and LOG_LEVEL set, GET /health returns 200 with status "ok"
#      and EXPECTED_VERSION within 5 seconds of `docker run`.
#   3. `docker stop` (SIGTERM) makes it exit 0.
#   4. With no environment, it exits 78.
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
  docker rm -f "$NAME" "$NAME-noenv" >/dev/null 2>&1 || true
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
size="$(docker image inspect -f '{{.Size}}' "$IMAGE")"
[ "$size" -le "$MAX_BYTES" ] || fail "image size is $size bytes, limit $MAX_BYTES"
echo "ok ($PLATFORM): platform $arch, user $user, size $size bytes (limit $MAX_BYTES)"

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

# 3. SIGTERM: clean exit.
docker stop "$NAME" >/dev/null
stop_code="$(docker inspect -f '{{.State.ExitCode}}' "$NAME")"
[ "$stop_code" = "0" ] || {
  docker logs "$NAME" >&2 || true
  fail "exit code after docker stop is $stop_code, want 0"
}
docker rm "$NAME" >/dev/null
echo "ok ($PLATFORM): docker stop exited 0"

# 4. No environment: config error, exit 78.
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
