---
name: criteria-patterns
description: Acceptance criteria patterns used in this project's backlog, meant to avoid rework (shared test definitions, barcode vectors, conditional upstream criteria, prose check rule, user tasks)
metadata:
  type: project
---

Patterns set up in the first backlog (T-001, 2026-10-11):

- A "Shared test definitions" section in docs/backlog.md holds window sizes (compact, medium, expanded, plus landscape 844 x 390 for named goldens), text scale 2.0 with the `text200` golden suffix, the four flutter_test accessibility guidelines, golden naming, and barcode vectors. UI tickets refer to it instead of repeating values.
- Barcode vectors with hand-verified check digits: UPC-A 036000291452 and 012345678905; EAN-13 4006381333931 and 0036000291452 (same product as 036000291452); EAN-8 96385074; bad check digit 036000291453. Server and app both normalize to GTIN-13.
- For upstream facts, cite fact ids from docs/api-research.md (BGG-21, EBAY-20, and so on), or write conditional criteria ("if api-research confirms X, then...; otherwise drop and note in the handoff"). Never put an upstream number or field name in a ticket unless it is in api-research.
- Prose check rule (T-016): exactly two hyphens with whitespace or line end on both sides, or a letter or digit on both sides, outside code spans and fences. Put literal dash examples in docs inside backticks, or the check flags our own docs.
- Use "manual" proof for CI and infra criteria that need a scratch branch (coverage gate, secret scan), and say the branch is deleted afterward.
- Work only the user can do (partner applications, accounts, emails) is a backlog ticket with owner "user" in a "User tasks" section, with a manual "answer recorded by PM" criterion.
- When adding ids in a later round, never renumber. Append new Q and T ids and cross-reference duplicates (for example "Q4 (U9, T-003 OQ4)").
- Answered questions move to an "Answered" list in PRD section 12 with the date and the same id. If a decision answers only part of a question, split it and keep the open part under a suffixed id (for example Q10b). Never drop an open part silently.
- When a confirmed [ASSUMPTION] loses its marker, cite the docs/decisions.md entry in its place.

Lesson from round 2 (2026-10-11): the PRD's 48-hour stale threshold was a PM guess, and UX built it into copy and specs before research showed eBay limits listings to 6 hours (EBAY-20). Mark numbers that depend on partner terms as "pending research", and check the research before UX specs rely on them.

Why: PM sign-off needs one named test per criterion. Vague or invented values cause rework rounds.

How to apply: reuse these when writing full criteria for the M3 to M5 stubs. Update this file if a pattern causes rework in sign-off. Related: [[reference-dependency-terms]], [[reference-research-access]].
