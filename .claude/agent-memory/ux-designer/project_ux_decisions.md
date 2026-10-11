---
name: ux-decisions
description: Core UX decisions from T-003 (seed color, nav, sizes, copy and golden conventions) for consistency in later specs and reviews
metadata:
  type: project
---

T-003 drafted 2026-10-11 (pending user review). Decisions:

- Seed color 0xFF1F6B5C, M3, dynamic color off. Destinations: Scan, Search, Collection, Settings. NavigationBar under 600 dp, NavigationRail from 600 dp, TwoPane at 840 dp wide and 600 dp tall.
- Test sizes: compact 390x844, medium 744x1133, expanded 1280x800, plus proposed `landscape` 844x390. Golden state suffix `text200` for 2.0 text scale.
- No confirmation dialogs: add, move, remove, import, restore use Undo snackbars. Edit screen autosaves.
- Copy keys are dotted groups (scanner.denied.title) mapping to camelCase in app_en.arb. Placeholders for BGG attribution, eBay statement, affiliate text, ML Kit note are marked PLACEHOLDER with ticket ref.
- Pricing wording: always "asking", source eBay US, count, age; "No current listings" never $0; "estimated" only on collection total.

**Why:** keeps later specs and UX checks consistent with the draft.
**How to apply:** read docs/ux/ first; check the user's review changes before reusing these.
