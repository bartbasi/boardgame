---
name: criteria-patterns
description: Acceptance criteria patterns used in this project's backlog, meant to avoid rework (shared test definitions, barcode vectors, conditional upstream criteria, prose check rule)
metadata:
  type: project
---

Patterns set up in the first backlog (T-001, 2026-10-11):

- A "Shared test definitions" section in docs/backlog.md holds window sizes, text scale 2.0, the four flutter_test accessibility guidelines, golden naming, and barcode vectors. UI tickets refer to it instead of repeating values.
- Barcode vectors with hand-verified check digits: UPC-A 036000291452 and 012345678905; EAN-13 4006381333931 and 0036000291452 (same product as 036000291452); EAN-8 96385074; bad check digit 036000291453. Server and app both normalize to GTIN-13.
- For upstream facts, write criteria as "per docs/api-research.md" or as conditional criteria ("if api-research confirms X, then...; otherwise drop and note in the handoff"). Never put an upstream number or field name in a ticket unless it is in api-research.
- Prose check rule (T-016): exactly two hyphens with whitespace or line end on both sides, or a letter or digit on both sides, outside code spans and fences. Put literal dash examples in docs inside backticks, or the check flags our own docs.
- Use "manual" proof for CI and infra criteria that need a scratch branch (coverage gate, secret scan), and say the branch is deleted afterward.

Why: PM sign-off needs one named test per criterion. Vague or invented values cause rework rounds.

How to apply: reuse these when writing the full criteria for M3 to M5 stubs. Update this file if a pattern causes rework in sign-off. Related: [[reference-dependency-terms]].
