# Third-party components outside the lockfiles

`tool/license-check.mjs` (run by repo.yml) checks the license of every Dart and Flutter package in every tracked `pubspec.lock`. This list covers what that check cannot see: container images, SDKs, native libraries pulled in by plugins, bundled fonts, and CI tools. Update it in the same commit that adds or changes such a component.

Status values: **allowed** (MIT, BSD, or Apache 2.0), **approved** (the user approved an exception, see the decision), **pending** (needs the user's approval before it ships), **CI only** (runs inside CI or on a developer machine, is never shipped or deployed, and is not a dependency of the app or server).

Repository license fields below were read with `gh api repos/<owner>/<repo>` on 2026-10-12, unless another source is named.

## Shipped in the app

| Component | Where it comes from | License | Status |
|---|---|---|---|
| Flutter SDK and engine, including the SDK packages in the lockfiles (flutter, flutter_localizations, flutter_test, flutter_web_plugins, sky_engine) | Flutter 3.47.7 (docs/decisions.md 2026-10-11) | BSD-3-Clause (flutter/flutter). The engine bundles further third-party code under its own notices; Flutter generates them into the app's license page. | allowed |
| Material Icons font (`uses-material-design: true` in app/pubspec.yaml) | Bundled by the Flutter SDK | Apache-2.0 [ASSUMPTION: confirm against the font's notice in the Flutter SDK in T-081] | allowed |
| Google ML Kit barcode scanning (Android only, through mobile_scanner, from M2) | Google | ML Kit terms, subject to the Google APIs Terms of Service (MLKIT-01 in docs/api-research.md) | approved: docs/decisions.md 2026-10-11 (ML Kit with disclosure) |
| AndroidX and other Gradle dependencies of the Flutter Android embedding | Google Maven | Not checked by the lockfile check [ASSUMPTION: Apache-2.0 for AndroidX; a Gradle license report is added in T-082 before the first store upload] | pending check (T-082) |

## Run on our servers (not distributed)

| Component | Where it comes from | License | Status |
|---|---|---|---|
| Dart SDK runtime files in the server image (`dart:3.13.5` pinned by digest, server/Dockerfile) | Official dart image | BSD-3-Clause (dart-lang/sdk) | allowed |
| glibc and the Mozilla CA bundle copied into the server image | Official dart image | LGPL-2.1-or-later; MPL-2.0 | approved: docs/decisions.md 2026-10-12 (runtime image license exception) |
| PostgreSQL image (`postgres:18.6-alpine3.24`, pinned by digest) | Official postgres image (docker-library/postgres, MIT packaging) | PostgreSQL License; Alpine base includes GPL and LGPL system packages | approved: docs/decisions.md 2026-10-12 (postgres and caddy images) |
| Caddy image (`caddy:2.11.7-alpine`, pinned by digest) | Official caddy image | Apache-2.0 (caddyserver/caddy); Alpine base includes GPL and LGPL system packages | approved: docs/decisions.md 2026-10-12 (postgres and caddy images) |

## CI and development tools (not distributed)

| Component | Used by | License | Status |
|---|---|---|---|
| gitleaks 8.30.1 binary | repo.yml secret scan | MIT (gitleaks/gitleaks) | allowed |
| Node.js on GitHub runners | repo.yml prose and license checks | MIT [ASSUMPTION: preinstalled runner tool, not pinned] | allowed |
| GitHub Actions: actions/checkout, actions/cache, actions/upload-artifact, actions/setup-java, dart-lang/setup-dart, docker/setup-buildx-action, docker/build-push-action, docker/setup-qemu-action | workflows, pinned by SHA | MIT, BSD-3-Clause, or Apache-2.0 as recorded in docs/handoffs/T-011.md and T-014.md | allowed |
| BuildKit image (moby/buildkit v0.34.0, pinned by digest) | server.yml image builds | Apache-2.0 (moby/buildkit) | allowed |
| QEMU binfmt image (tonistiigi/binfmt, pinned by digest) | server.yml arm64 checks | MIT for the repository (tonistiigi/binfmt); the QEMU binaries inside are GPL-2.0. Used only inside CI runners. | CI only |
| Android SDK, emulator, and system images | local development only | Android Software Development Kit License Agreement | CI only (local development) |
