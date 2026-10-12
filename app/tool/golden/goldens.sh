#!/usr/bin/env bash
# Renders (update) or checks (check) the app's golden images in a Linux
# container with the same Flutter version as CI (T-015).
#
# Usage, from the repository root in Git Bash (Windows) or bash (Linux):
#   app/tool/golden/goldens.sh update   # render and replace app/test/goldens/*.png
#   app/tool/golden/goldens.sh check    # compare only, like CI
#
# Needs Docker (Docker Desktop on Windows). The image is built on first use
# and tagged bgc-goldens:<flutter version>-<hash of its inputs>, so editing
# the Dockerfile, its scripts, or the Flutter version in app.yml
# builds a new image. Pub packages are kept in the Docker volume
# bgc-goldens-pub-cache between runs.
set -euo pipefail

mode="${1:-update}"
case "$mode" in
  update | check) ;;
  *) echo "Usage: app/tool/golden/goldens.sh update|check" >&2; exit 64 ;;
esac

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool="$(cd "$here/.." && pwd)"
root="$(cd "$here/../../.." && pwd)"

# The Flutter version has one home: env.FLUTTER_VERSION in app.yml.
version="$(sed -n 's/^  FLUTTER_VERSION: *\([0-9][0-9.]*\) *$/\1/p' "$root/.github/workflows/app.yml")"
if [ -z "$version" ]; then
  echo "Could not read FLUTTER_VERSION from .github/workflows/app.yml." >&2
  exit 1
fi

inputs_hash="$(cat "$here/Dockerfile" "$here/warm_up.sh" "$here/in_container.sh" \
  "$tool/ci/install_flutter.sh" | sha256sum | cut -c1-12)"
image="bgc-goldens:$version-$inputs_hash"

if ! docker image inspect "$image" > /dev/null 2>&1; then
  echo "Building $image (first run takes a few minutes)."
  docker build --platform linux/amd64 \
    --build-arg "FLUTTER_VERSION=$version" \
    -t "$image" -f "$here/Dockerfile" "$tool"
fi

# Git Bash rewrites arguments that look like paths; give Docker a Windows
# path (C:/...) there and turn the rewriting off for the docker call.
mount="$root"
if pwd -W > /dev/null 2>&1; then
  mount="$(cd "$root" && pwd -W)"
fi

MSYS_NO_PATHCONV=1 docker run --rm --platform linux/amd64 \
  -v "$mount:/src" \
  -v bgc-goldens-pub-cache:/root/.pub-cache \
  "$image" "$mode"
