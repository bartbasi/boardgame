---
name: m2-contract-decisions
description: T-018 M2 contract choices (bad_request declined, no images per PRD Q5, bggUrl format evidence, BGG field names unconfirmed in research)
metadata:
  type: project
---

T-018 (2026-10-13) added GameSummary, SearchResponse, LookupResponse/LookupStatus, GameDetailResponse to packages/api_contract. Proposed (pending orchestrator record in docs/decisions.md):

- No `bad_request` ErrorCode; unparseable URLs keep 404 `not_found` (recorded 2026-10-13).
- No image URL fields at all (AC2 changed in e8c994d; R2-M1 removed thumbnailUrl in round 3). Removing a field later breaks /v1, so never add placeholder fields "for later"; add them additively when needed.
- `bggUrl` = `https://boardgamegeek.com/boardgame/{bggId}`, server-built. boardgamegeek.com returns 403 to WebFetch and curl from this machine; only evidence is Wikidata P2339 formatter URL (wbgetclaims API works).
- docs/api-research.md section 1.4 has no BGG response field names; detail fields were included as nullable pending T-021 fixtures (open question for PM).
- EAN-8 key rule confirmed 2026-10-13: UPC-A gets one leading zero, EAN-8 five (decisions.md). bad_request declined and the app exhaustive ErrorCode switch is intentional (decisions.md 2026-10-13).

**Why:** server endpoints T-022, T-023, T-025 decode their 200s with these DTOs, and the app's T-028 reuses the fixtures.

**How to apply:** when implementing T-022/T-023/T-025, send explicit nulls (never 0 or ""), `[]` for lists, UTC `fetchedAt`, and a games count that fits the lookup status (the decoder enforces it). Re-check the handoff docs/handoffs/T-018.md for PM answers first.

Related: [[api-contract-codegen]]
