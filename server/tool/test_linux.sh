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
set -eu

IMAGE="dart:3.13.5"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# MSYS_NO_PATHCONV stops Git Bash on Windows from rewriting the /src paths.
MSYS_NO_PATHCONV=1 docker run --rm \
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
