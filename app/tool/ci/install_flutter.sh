#!/usr/bin/env bash
# Installs one exact Flutter stable release on a GitHub Actions runner (T-014).
#
# Usage: app/tool/ci/install_flutter.sh <version> [install-dir]
#
# Reads the official release index on storage.googleapis.com, downloads the
# archive for this OS and CPU, checks its SHA-256 against the index, unpacks
# it, checks `flutter --version` reports the requested version, and adds
# flutter/bin to GITHUB_PATH when that variable is set. Works on the Linux
# (x64) and macOS (arm64 or x64) runners. Needs curl, jq, and tar or unzip.
set -euo pipefail

version="${1:?usage: install_flutter.sh <version> [install-dir]}"
dest="${2:-${RUNNER_TEMP:-/tmp}}"
base="https://storage.googleapis.com/flutter_infra_release/releases"

case "$(uname -s)" in
  Linux) os=linux ;;
  Darwin) os=macos ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64 | amd64) arch=x64 ;;
  arm64 | aarch64) arch=arm64 ;;
  *) echo "Unsupported CPU: $(uname -m)" >&2; exit 1 ;;
esac

index="$(curl -sSfL --retry 3 "$base/releases_${os}.json")"
entry="$(echo "$index" | jq -c --arg v "$version" --arg a "$arch" \
  '[.releases[] | select(.version == $v and .channel == "stable" and .dart_sdk_arch == $a)] | first // empty')"
if [ -z "$entry" ]; then
  echo "Flutter $version (stable, $os, $arch) is not in the release index." >&2
  exit 1
fi
archive="$(echo "$entry" | jq -r .archive)"
sha256="$(echo "$entry" | jq -r .sha256)"
file="$dest/$(basename "$archive")"

echo "Downloading $base/$archive"
mkdir -p "$dest"
curl -sSfL --retry 3 -o "$file" "$base/$archive"
if command -v sha256sum > /dev/null; then
  echo "$sha256  $file" | sha256sum -c -
else
  echo "$sha256  $file" | shasum -a 256 -c -
fi

rm -rf "$dest/flutter"
case "$file" in
  *.tar.xz) tar -xJf "$file" -C "$dest" ;;
  *.zip) unzip -q "$file" -d "$dest" ;;
  *) echo "Unknown archive type: $file" >&2; exit 1 ;;
esac
rm -f "$file"

# The archive is a git checkout; the runner user owns it, but git refuses to
# read it under some setups unless it is marked safe.
git config --global --add safe.directory "$dest/flutter"

flutter="$dest/flutter/bin/flutter"
"$flutter" config --no-analytics > /dev/null
"$flutter" --disable-analytics > /dev/null 2>&1 || true
actual="$("$flutter" --version --machine | jq -r .frameworkVersion)"
if [ "$actual" != "$version" ]; then
  echo "Expected Flutter $version but found $actual." >&2
  exit 1
fi
"$flutter" --version

if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$dest/flutter/bin" >> "$GITHUB_PATH"
  echo "$dest/flutter/bin/cache/dart-sdk/bin" >> "$GITHUB_PATH"
fi
