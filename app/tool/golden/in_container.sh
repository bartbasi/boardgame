#!/usr/bin/env bash
# Runs inside the golden image (T-015). Called by app/tool/golden/goldens.sh.
#
# Usage: bgc-goldens update|check
#
# The repository is mounted at /src. The app and api_contract are copied to
# /work first, so the Linux run never touches the host's .dart_tool or build
# folders. Only PNG files under app/test/goldens/ are copied back:
#   update: renders every golden, then replaces the committed PNGs with the
#           new set (stale PNGs of removed cases are deleted).
#   check:  compares against the committed PNGs; on a mismatch the diff
#           images are copied to app/test/goldens/failures/ (git-ignored).
set -euo pipefail

mode="${1:-update}"
src=/src
work=/work
goldens=test/goldens

case "$mode" in
  update | check) ;;
  *) echo "Usage: bgc-goldens update|check" >&2; exit 64 ;;
esac

if [ ! -f "$src/app/pubspec.yaml" ]; then
  echo "The repository root must be mounted at $src." >&2
  exit 1
fi

flutter --version

mkdir -p "$work"
tar -C "$src" \
  --exclude='app/build' \
  --exclude='app/.dart_tool' \
  --exclude='app/coverage' \
  --exclude='app/android/.gradle' \
  --exclude='app/ios/Pods' \
  --exclude='app/test/goldens/failures' \
  --exclude='packages/api_contract/.dart_tool' \
  -cf - app packages/api_contract | tar -C "$work" -xf -

cd "$work/app"
flutter pub get --enforce-lockfile

# Files copied back to the host get the owner of the mounted app folder
# (matters on Linux hosts; Docker Desktop ignores it).
owner="$(stat -c %u:%g "$src/app")"

if [ "$mode" = update ]; then
  find "$goldens" -name '*.png' -not -path '*/failures/*' -delete
  flutter test --update-goldens "$goldens"
  # Replace the committed set only after every test passed.
  find "$src/app/$goldens" -name '*.png' -not -path '*/failures/*' -delete
  count=0
  while IFS= read -r -d '' png; do
    mkdir -p "$src/app/$(dirname "$png")"
    cp "$png" "$src/app/$png"
    chown "$owner" "$src/app/$png" 2> /dev/null || true
    count=$((count + 1))
  done < <(find "$goldens" -name '*.png' -not -path '*/failures/*' -print0)
  echo "Wrote $count golden PNG files to app/$goldens/."
else
  status=0
  flutter test "$goldens" || status=$?
  if [ "$status" -ne 0 ] && [ -d "$goldens/failures" ]; then
    rm -rf "$src/app/$goldens/failures"
    cp -r "$goldens/failures" "$src/app/$goldens/failures"
    chown -R "$owner" "$src/app/$goldens/failures" 2> /dev/null || true
    echo "Diff images: app/$goldens/failures/"
  fi
  exit "$status"
fi
