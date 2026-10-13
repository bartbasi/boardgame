---
name: m2-contract-decisions
description: T-018 M2 contract choices (bad_request declined, no images per PRD Q5, bggUrl format evidence, BGG field names unconfirmed in research)
metadata:
  type: project
---

T-018 (2026-10-13) added GameSummary, SearchResponse, LookupResponse/LookupStatus, GameDetailResponse to packages/api_contract. Proposed (pending orchestrator record in docs/decisions.md):

- No `bad_request` ErrorCode; unparseable URLs keep 404 `not_found`.
- `thumbnailUrl` nullable on summaries only, always null until PRD Q5 (BGG image use) is answered; no image field on detail.
- `bggUrl` = `https://boardgamegeek.com/boardgame/{bggId}`, server-built. boardgamegeek.com returns 403 to WebFetch and curl from this machine; only evidence is Wikidata P2339 formatter URL (wbgetclaims API works).
- docs/api-research.md section 1.4 has no BGG response field names; detail fields were included as nullable pending T-021 fixtures (open question for PM).
- EAN-8 normalization to GTIN-13 (left-pad to 13) is unspecified in T-025; contract requires 13 digits.

**Why:** server endpoints T-022, T-023, T-025 decode their 200s with these DTOs, and the app's T-028 reuses the fixtures.

**How to apply:** when implementing T-022/T-023/T-025, send explicit nulls (never 0 or ""), `[]` for lists, UTC `fetchedAt`, and a games count that fits the lookup status (the decoder enforces it). Re-check the handoff docs/handoffs/T-018.md for PM answers first.

Related: [[api-contract-codegen]]
