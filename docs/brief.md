# Original Brief

The user's kickoff brief, received 2026-10-11, kept word for word. docs/PRD.md turns it into requirements; when they differ, the PRD wins once the user approves it, and docs/decisions.md records why.

---

# Board Game Collector App: Claude Code Kickoff Prompt

## ROLE

You are the tech lead and orchestrator for a commercial mobile app for serious board game collectors. You plan the work, delegate to a team of specialist subagents, integrate their output, and keep the project moving. You do not write most of the product code yourself.

Ground rules for you and every agent:
- Do not invent API endpoints, fields, limits, or terms. Check current official docs and record the URL in docs/api-research.md.
- If something in this prompt is unclear or conflicts with what an API or store policy allows, stop and ask me.
- No secrets in the repo. Use .env files that are git-ignored, plus a committed .env.example.
- No em dashes or double hyphens in user-facing copy or docs.
- Items marked [ASSUMPTION] are my best guess. Confirm or challenge them during planning.

## PRODUCT SUMMARY

- A collector scans a game box barcode (or searches by title), the app identifies the game, shows current used-market value and price history, and lets them file it as Owned, Wanted, or Evaluating.
- Commercial release on the Apple App Store and Google Play.
- US only. eBay US marketplace only. All prices in USD.
- No user accounts or cloud sync in version 1. Each user's collection lives only on their own phone, with export and import for backup.
- Monetization: the app is free with no ads. The only revenue is eBay Partner Network affiliate commission on "View on eBay" links. Nothing in the app may block, delay, or require a tap to keep using it. BGG license is being applied for as Commercial.

## PHASE 0: BUILD THE TEAM (before any product code)

Create these project subagents in .claude/agents/. Each file needs name, description, tools, model, and `memory: project`. Show me all the files and wait for my approval.

| Agent | Owns | Tools | Notes |
|---|---|---|---|
| product-manager | docs/PRD.md, docs/backlog.md, docs/api-research.md, acceptance criteria, final sign-off on each ticket | Read, Write, Edit, Grep, Glob, WebSearch, WebFetch | No Bash. Researches API terms and app store policies. |
| ux-designer | docs/ux/ (user flows, screen specs, component inventory, copy, accessibility checklist) | Read, Write, Edit, Grep, Glob, Bash | Reviews built screens against spec using golden test images. Does not edit lib/. |
| flutter-developer | app code in app/lib and app/test | Read, Write, Edit, Grep, Glob, Bash | `isolation: worktree` |
| backend-developer | server/ and deploy/ | Read, Write, Edit, Grep, Glob, Bash, WebFetch | `isolation: worktree` |
| qa-engineer | test plans, integration tests, bug reports | Read, Write, Edit, Grep, Glob, Bash | May only edit test directories. Reports bugs, does not fix production code. |
| code-reviewer | review of every diff, including security | Read, Grep, Glob, Bash | Read-only. Checks architecture rules, lints, secrets, input validation, test coverage. |

Write each agent's system prompt so it knows: its role, which files it owns, which files it must read before starting (see shared state below), what "done" means for its part, and that it must update its memory with decisions and patterns it learns.

### Shared state

Subagents start with a fresh context and do not see our conversation. All handoffs go through files:
- docs/PRD.md: product requirements
- docs/backlog.md: tickets with id, title, owner, status, acceptance criteria, linked files
- docs/ux/: screen specs and flows
- docs/api-research.md: verified facts about every external API and policy, with source URLs and dates checked
- docs/decisions.md: a short log of architecture and product decisions (date, decision, reason, who decided)
- docs/handoffs/<ticket-id>.md: notes passed between agents on a ticket (findings, open questions, review results)

Every delegation prompt you write must name the ticket id and list the files the agent must read first.

## THE WORK LOOP (every ticket)

1. product-manager writes the ticket with testable acceptance criteria.
2. ux-designer writes or updates the screen spec if the ticket touches UI.
3. The developer implements it with tests in its worktree.
4. qa-engineer runs the full test suite, adds edge case tests, and writes findings to the handoff file.
5. code-reviewer reviews the diff and writes findings as must fix, should fix, or suggestion.
6. If there are must-fix findings or failing tests, send them back to the same developer agent by resuming it with SendMessage so it keeps its context. Repeat steps 3 to 5.
7. For UI tickets, ux-designer checks the result against the spec. product-manager checks the acceptance criteria. The ticket is done only when tests pass, review has no must-fix items, and PM signs off.

Rules for the loop:
- Maximum 3 rounds per ticket. If it still is not done, stop and send me a short summary of what is stuck and the options.
- Run independent tickets in parallel (app and backend are usually independent), but never let two agents edit the same files at once.
- You merge worktree branches, resolve conflicts, and keep main green.
- Small commits that reference the ticket id.

### Checkpoints where you stop and wait for me
- After Phase 0 (agent files)
- After PRD, API research, and UX specs are drafted
- At the end of each milestone, with a demo summary and known issues
- Before any deployment to the server
- Before adding any paid service, or any dependency whose license is not MIT, BSD, or Apache 2.0
- Any time API terms or store policy appear to block a feature

## MILESTONES

- M1 Foundations: repo structure, lints, CI [ASSUMPTION: GitHub Actions], app skeleton with navigation and theming, backend skeleton with a health endpoint, Docker setup.
- M2 Identify a game: barcode scanning, barcode lookup, title search, game detail screen, all through the backend.
- M3 Collection: local database, Owned / Wanted / Evaluating lists, manual entry, edit, move, sort, filter, export and import.
- M4 Pricing: eBay current value, daily price snapshots, history charts, collection total value.
- M5 Hardening and store readiness: offline behavior, error handling, accessibility audit, performance, privacy policy, store listings, release builds.

## RESEARCH FIRST (product-manager, before M2 code)

Write docs/api-research.md covering, with source URLs:
- BoardGameGeek XML API: commercial license process and current terms, token use, rate limits, caching expectations, "Powered by BGG" logo rules. Note that BGG can deny apps it sees as competing with its business, and it runs its own marketplace. Draft an honest description of our app for the license application and flag this risk to me.
- eBay: Developer Program production access, API License Agreement terms for commercial apps, Browse API daily call limits, rules on caching or storing listing data, required attribution, and whether eBay Partner Network affiliate links are allowed in a listing view. Marketplace Insights (sold data) is limited release; document how to apply.
- GameUPC (barcode to BGG id): terms for commercial use, rate limits, and what happens if it is unavailable.
- Apple App Store and Google Play: camera permission text, privacy policy requirement, Data Safety form and privacy labels, any rules about showing third-party prices.

## MOBILE APP

Stack:
- Latest stable Flutter and Dart 3, Material 3, null safety.
- Minimum targets: [ASSUMPTION: Android API 24, iOS 15].
- State management: Riverpod with code generation.
- Local database: Drift (SQLite).
- Networking: dio, talking only to our backend, never directly to BGG or eBay.
- Models: freezed and json_serializable.
- Charts: fl_chart.

Architecture:
- Feature-first clean architecture: each feature has data, domain, and presentation layers.
- Features: scanner, game_detail, pricing, collection, settings.
- Domain layer is pure Dart with no Flutter imports. Repositories are interfaces in domain, implemented in data.
- Errors are typed failures (sealed classes), not exceptions thrown across layers.

Barcode scanning:
- mobile_scanner, supporting UPC-A, EAN-13, and EAN-8.
- Clear handling of camera permission denial, with a link to settings.
- Torch toggle, haptic feedback on scan, debounce of duplicate reads.
- Manual barcode entry and title search always available.
- If the barcode has no match or several, show candidates and let the user choose or search. Cache confirmed barcode to game matches on the device.

Collection (device only):
- Three lists: Owned, Wanted, Evaluating. One list per game at a time, movable.
- Owned: condition, purchase price, purchase date, edition, expansions owned, notes, photos.
- Wanted: target price, priority. Evaluating: notes, date added.
- Sort, filter, and search in each list. Total estimated value of Owned.
- Works fully offline. Metadata and prices refresh when online.
- CSV export and import, plus a full backup file the user can save and restore.

Pricing display:
- Show median, low, high, and number of listings.
- Every price shows its source, whether it is an asking price or a sold price, sample size, and how old the data is. Never label asking prices as sold prices.
- History chart built from our daily snapshots, with a text summary for screen readers.
- Each eBay listing has a "View on eBay" button that opens the listing outside the app. The backend sends our eBay Partner Network campaign ID with Browse API requests and returns itemAffiliateWebUrl when eBay provides it, falling back to the plain item URL when it does not. Show a short affiliate disclosure near the listings and in Settings. The campaign ID is a backend setting, not hard-coded in the app.

Errors and offline:
- Show cached data with a "last updated" label instead of an error screen.
- Retries with exponential backoff and jitter. Honor Retry-After.
- Plain-language error messages with a retry button. No raw exceptions shown to users.

UI and accessibility:
- Light and dark themes, dynamic type, minimum 48dp touch targets, WCAG AA contrast.
- Semantic labels on all icons, images, and charts.
- Layouts that adapt to phones and tablets, portrait and landscape.
- Skeleton loaders, pull to refresh, and empty states that tell the user what to do next.

## BACKEND

Hosting:
- Oracle Cloud Always Free VM. First confirm the VM's CPU architecture (likely ARM64) and build Docker images for it.
- Docker Compose, with Caddy in front for automatic HTTPS.
- Design to run comfortably on a small free-tier VM. Document memory and disk use.
- Daily database backups, with a documented restore procedure that has actually been tested.

Stack:
- [ASSUMPTION: Dart with dart_frog or shelf, so models can be shared with the app]. Propose an alternative in docs/decisions.md if you think it is clearly better.
- PostgreSQL for the API response cache, barcode to game mappings, and price snapshots.

Endpoints (versioned under /v1):
- GET /lookup/barcode/{code}
- GET /games/search?q=
- GET /games/{bggId}
- GET /prices/{bggId}
- GET /prices/{bggId}/history
- GET /health

Third-party calls:
- BGG: XML API2 with the Bearer token, sent to boardgamegeek.com without "www". Queue requests to stay within BGG's limits (no more than one every 2 seconds unless docs/api-research.md says otherwise). Handle HTTP 202 and 429. Cache game data for at least 7 days.
- eBay: Browse API, search by GTIN first and keywords as fallback, used condition, board game category. Remove obvious outliers, lots, and bundles before computing stats.
- Marketplace Insights (sold prices) built behind a feature flag, off by default, until eBay approves access.
- GameUPC for barcode lookup, with BGG title search as fallback.

Price snapshots:
- A scheduled daily job records a snapshot for every game any device has looked up in the last [ASSUMPTION: 90] days.
- Stay inside eBay's daily call budget. Log the budget used each day and alert in the logs before running out.

Protection and privacy:
- The backend serves only our app. It must not work as an open API to BGG or eBay data. Use Play Integrity on Android and App Attest on iOS to verify requests, plus per-IP rate limits.
- Store no personal data. No user ids. Keep request logs minimal and short-lived.
- All secrets in a git-ignored .env file on the server.

## TESTING AND QUALITY

- Unit tests for every repository, use case, parser, and price calculation, using recorded fixture responses from each API.
- Widget tests for every screen covering loading, empty, error, and offline states.
- Golden tests for key screens so ux-designer can review them.
- An integration test for scan to add-to-collection, with the scanner mocked.
- Backend tests for every endpoint, the rate limiter, the snapshot job, and failure of each upstream API.
- At least 80% line coverage on domain and data layers. flutter analyze and dart analyze with strict lints, zero warnings.
- CI runs all of the above on every push.

## DELIVERABLES

- Full source for the app and the backend.
- README covering local setup, registering for BGG, eBay, and GameUPC access, environment variables, running tests, building releases, and deploying to the Oracle VM.
- docs/ folder as described above, kept current.
- A final list of assumptions, known limitations, and open risks.

## OUT OF SCOPE FOR VERSION 1

User accounts, cloud sync, social features, buying or selling inside the app, importing a user's BGG collection.

## START

Begin with Phase 0. Enter plan mode, propose the agent files and the repository layout, and wait for my approval.
