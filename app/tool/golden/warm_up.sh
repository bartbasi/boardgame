#!/usr/bin/env bash
# Image build step (T-015): runs one empty test so the Flutter tool fetches
# anything `flutter test` downloads lazily, checks the Material Icons font the
# app bundles is present, then removes the throwaway package and its pub
# cache. Roboto is not in the Linux SDK; the goldens load the copy committed
# in app/test/fonts/roboto/.
set -euo pipefail

warm=/tmp/warm
mkdir -p "$warm/test"
cat > "$warm/pubspec.yaml" << 'EOF'
name: warm
publish_to: none
environment:
  sdk: ^3.0.0
dev_dependencies:
  flutter_test:
    sdk: flutter
EOF
cat > "$warm/test/warm_test.dart" << 'EOF'
import 'package:flutter_test/flutter_test.dart';

void main() => test('warm', () {});
EOF

(cd "$warm" && flutter test)

icons=/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf
if [ ! -f "$icons" ]; then
  echo "Missing $icons." >&2
  exit 1
fi

rm -rf "$warm" /root/.pub-cache
