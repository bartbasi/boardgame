---
name: backend-framework-choice
description: T-005 proposal (shelf + shelf_router over dart_frog), status pending user confirmation, and the switch triggers
metadata:
  type: project
---

T-005 (2026-10-12) proposed shelf 1.4.2 + shelf_router 1.1.4, AOT on scratch. Confirmed by the user and recorded in docs/decisions.md (2026-10-12); T-008 built server/ on it.

**Why:** equal memory to dart_frog; smaller all-Dart-team dependency tree; no CLI/codegen; tests can call the full Handler pipeline with real Request objects; dart_frog runtime unreleased since 2025-11-03 and its repo moved from VGV to dart-frog-dev with no maintainer statement. dart_frog `[param].dart` route names trip the `file_names` lint, and its generated server rebuilds nested pipelines per request.

**How to apply:** if confirmed, T-008 uses one router per feature mounted under /v1, attestation as a mounted Pipeline middleware, /health on the outer router, clock injected into the rate limiter. Switch triggers: shelf discontinued/archived or unreleased security fix (then look at relic, serverpod.dev). Spike code lives only on the T-005 branch under server/spike/.

Related: [[docker-dart-aot-notes]]
