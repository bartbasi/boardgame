# Product Requirements: Board Game Collector App

- Status: Draft for user review (ticket T-001)
- Date: 2026-10-11
- Owner: product-manager
- Inputs: docs/brief.md (original brief), docs/decisions.md. Upstream API and store facts live in docs/api-research.md (ticket T-002, in progress). This PRD does not restate those facts; tickets point to them.

Items marked [ASSUMPTION] are unconfirmed. They stay marked until you confirm them and the orchestrator records the answer in docs/decisions.md. Numbers the brief did not give are proposals and are marked the same way.

## 1. Summary

A free iOS and Android app for serious US board game collectors. A collector scans a game box barcode or searches by title. The app identifies the game, shows what it currently goes for used on eBay US along with price history, and lets the collector file it as Owned, Wanted, or Evaluating. The collection lives only on the phone. A small backend that we run is the only thing that talks to BoardGameGeek (BGG), eBay, and GameUPC.

## 2. Goals

1. **Identify a game in seconds.** Scan, type a barcode, or search by title. When the match is unclear, the user picks from candidates, and the app remembers the choice.
2. **Show trustworthy used-market value.** Every price says where it came from, whether it is an asking or a sold price, how many listings it is based on, and how old it is.
3. **Keep the collection private and usable offline.** No accounts, no cloud sync, no tracking. Export and import let users back it up themselves.
4. **Respect our partners.** Stay inside BGG, eBay, and GameUPC terms and both app stores' policies.
5. **Run cheaply.** The backend fits on one Oracle Cloud Always Free VM. The only revenue is eBay Partner Network (EPN) commission.

Success measures [ASSUMPTION]. The app has no analytics, so these come from aggregate backend counters (no identifiers) and the store consoles:

- At least 80% of valid barcode lookups return a match or candidates.
- Crash-free users of at least 99.5% (App Store Connect and Play Console).
- Average store rating of 4.5 or higher.
- EPN clicks and earnings, read from the EPN dashboard only. The app does not track clicks itself.

## 3. Users

**Primary user:** a serious board game collector in the US. Owns 100 or more games [ASSUMPTION], knows BGG, and buys and sells used games on eBay, at conventions, thrift stores, and game store sales.

Three jobs this user hires the app for:

- **Cataloging:** "I want a reliable list of what I own, with its value, for insurance and for deciding what to sell."
- **Hunting:** "I'm holding a box in a store. Is this price a good deal? If I pass, remind me what I'm willing to pay."
- **Trimming:** "I'm deciding what to sell or trade, and I want to see what it's worth before I decide."

Casual players with a few games can use the app, but we do not design for them. Sellers who want to list items are not served (out of scope).

## 4. Core user stories

| Id | As a collector, I want to... | Milestone |
|---|---|---|
| US-1 | scan a box barcode and see which game it is | M2 |
| US-2 | type the barcode when the camera cannot read it | M2 |
| US-3 | search by title when there is no barcode or no match | M2 |
| US-4 | pick the right game when a barcode matches several games or none, and have the app remember my pick | M2 |
| US-5 | see game details, including when I am offline, using the last data I saw | M2 |
| US-6 | file a game as Owned, Wanted, or Evaluating, and move it between lists later | M3 |
| US-7 | record condition, purchase price and date, edition, expansions owned, notes, and photos for games I own | M3 |
| US-8 | record a target price and priority for Wanted games, and notes and date added for Evaluating games | M3 |
| US-9 | sort, filter, and search each list | M3 |
| US-10 | export to CSV, import from CSV, and save and restore a full backup file | M3 |
| US-11 | see the current used-market price: median, low, high, and number of listings, with source and age | M4 |
| US-12 | see a price history chart, with a text summary for screen readers | M4 |
| US-13 | open an eBay listing in my browser or the eBay app | M4 |
| US-14 | see the total estimated value of my Owned games | M4 |
| US-15 | use my collection and last known prices with no connection | M3 to M5 |
| US-16 | do all of the above with a screen reader, large text, or either theme | all |

## 5. Features by milestone

Ticket ids refer to docs/backlog.md.

### M1 Foundations (T-004 to T-017)

Repository tooling and strict lints, a decision on a Dart pub workspace, CI on GitHub Actions [ASSUMPTION] (app.yml, server.yml, repo.yml with secret scanning, a prose style check, and dependency license checks), the Linux golden image pipeline, the app skeleton (navigation, light and dark themes, feature folders, Result and Failure types, HTTP client with retries), the backend skeleton (GET /health, fail-fast config, minimal structured logs), a multi-arch Dockerfile, local Docker Compose with PostgreSQL and Caddy, a shelf or dart_frog decision [ASSUMPTION: Dart backend], and the api_contract package skeleton.

Done when: CI is green on main for app, server, and repo checks; the app runs on an Android emulator and the iOS build compiles in CI; https://localhost/health answers through local Compose; a golden rendered with the Linux command passes in CI.

### M2 Identify a game (T-018 to T-036)

Barcode scanning (UPC-A, EAN-13, EAN-8) with torch, haptics, and duplicate debounce; manual barcode entry; title search; candidate selection when a barcode has zero or several matches; on-device cache of confirmed barcode matches and viewed games; the game detail screen with BGG attribution. Backend: PostgreSQL access, per-IP rate limits, BGG client with a shared request queue, GameUPC client, and the barcode, search, and game detail endpoints.

Done when: on a real Android phone (and an iPhone through TestFlight, once accounts exist), a user scans a box and reaches the right game's detail screen through the backend, and every M2 ticket is signed off.

### M3 Collection (T-037 to T-049)

Local database, the three lists with type-specific fields, manual entry, edit, move, sort, filter, search, photos, CSV export and import, full backup and restore, and the scan to add-to-collection integration test. Fully offline.

### M4 Pricing (T-050 to T-065)

eBay current value from the Browse API, daily price snapshots, history charts, listings with "View on eBay", affiliate disclosure, collection total value, and Marketplace Insights (sold prices) behind a feature flag that stays off until eBay approves access.

### M5 Hardening and store readiness (T-066 to T-083)

App Attest and Play Integrity, offline and error handling audits, accessibility audit, performance check against section 8.3, privacy policy, terms, store listings, privacy label and Data Safety answers, release builds, production deployment runbook, and tested backups. Deployment happens only with your approval.

## 6. Pricing rules

These rules apply to every screen and endpoint that shows a price.

1. **Source:** eBay US marketplace only, used condition, board game category, prices in USD.
2. **Asking versus sold:** Browse API results are current listings, so their prices are asking prices. They are always labeled as asking prices. Sold prices come only from Marketplace Insights, behind a feature flag that is off by default, and are labeled as sold. Asking and sold prices are never combined into one number, and an asking price is never called a sold price, a value, or a sale.
3. **Every price display shows:** the amount, the label (asking or sold), the source (eBay), the sample size ("from 23 listings"), and the data age ("updated 5 hours ago").
4. **Statistics:** median, low, high, and number of listings, computed after removing lots, bundles, and obvious outliers. The filter rules are documented and each one has a test (M4).
5. **Low data:** with zero listings, show "No current listings", never $0. With fewer than 3 listings [ASSUMPTION], show the numbers with a "few listings" note.
6. **Stale data:** price data older than 48 hours [ASSUMPTION] gets a visible stale marker.
7. **Shipping:** prices are item prices without shipping [ASSUMPTION], and the label says so.
8. **Collection total:** the sum of median asking prices for Owned games that have price data. Labeled as an estimate from eBay asking prices, with the count of games that have no price data.
9. **History:** built only from our own daily snapshots. It starts the first day anyone looks up the game. No backfill.

## 7. Monetization constraints

- Free. No ads, no in-app purchases, no subscriptions.
- The only revenue is EPN commission on "View on eBay" links.
- The EPN campaign id is a backend setting. The app never holds it and never builds affiliate URLs. The backend sends the campaign id with Browse API requests in the way docs/api-research.md documents, returns itemAffiliateWebUrl when eBay provides it, and falls back to the plain item URL when it does not.
- A short affiliate disclosure appears as inline text near the listings and in Settings. It is never a modal and never needs to be acknowledged. Wording comes from docs/legal/ (T-050).
- **Nothing blocks, delays, or requires a tap to keep using the app.** That means no interstitials, no onboarding wall, no rating prompts [ASSUMPTION], no confirmation dialog before opening eBay, no forced update screens, and no countdowns. The camera permission prompt appears only when the user opens the scanner, and denying it never blocks search or the collection.

## 8. Non-functional requirements

### 8.1 Platforms

- iOS 15 or later and Android API 24 or later [ASSUMPTION].
- Phones and tablets, portrait and landscape, with compact, medium, and expanded layouts.
- Latest stable Flutter and Dart 3 (versions recorded in docs/decisions.md).

### 8.2 Offline

- The collection, games the user has viewed, and their last known prices work with no connection.
- When data cannot be refreshed, show the cached data with a "Last updated" label instead of an error screen.
- Scanning a barcode that already has a confirmed match on the device opens the game offline.
- Errors use plain language and a Retry button. Users never see raw exceptions or status codes.
- Network calls retry with exponential backoff and jitter, and honor Retry-After.

### 8.3 Performance targets [ASSUMPTION: all numbers in this table]

Measured on reference devices still to be chosen (Q7), on a good network, in release builds.

| Measure | Target |
|---|---|
| Cold start to first usable screen | 2.0 s or less (p90) |
| Camera preview after opening Scan, permission already granted | 1.0 s or less |
| Barcode read to result, backend cache hit | 1.5 s or less (p95) |
| Barcode read to result, backend cache miss | 6 s or less (p95); see risk R6 |
| Title search results, backend cache hit / miss | 1.0 s / 5 s or less (p95) |
| Game detail from the device cache | 300 ms or less |
| Collection with 2,000 games: search, sort, or filter | updates in 300 ms or less, scrolling without visible jank |
| CSV export of 2,000 games | 5 s or less |
| App download size | 50 MB or less per platform |
| Backend server time for a cache hit | 100 ms or less (p95) |
| Whole backend Compose stack memory | 512 MB or less idle, 1 GB or less at peak |

### 8.4 Accessibility

- WCAG 2.2 AA contrast: 4.5:1 for text, 3:1 for large text and UI parts. Information is never shown by color alone.
- Touch targets at least 48 by 48 dp.
- Dynamic type up to 200% with no clipping or overlap.
- Semantic labels on every icon, image, and chart. Charts also have a text summary.
- Complete flows with TalkBack and VoiceOver. Motion respects the system reduce-motion setting.

### 8.5 Privacy

- No accounts, no user ids, no device ids, no advertising ids, no analytics or ad SDKs [ASSUMPTION], and no cross-app tracking.
- The collection and its photos never leave the phone, except in files the user exports.
- The backend stores only: cached game data, barcode-to-game mappings, cached searches, price snapshots, and which games were looked up and when (no identifiers). It stores no IP addresses.
- Request logs hold method, route template, status, and duration only, and are kept 7 days [ASSUMPTION].
- Known third-party processing that must be disclosed: Google ML Kit usage metrics on Android if approved (Q4), image hosts if images load directly (Q5), and eBay when the user opens a listing. The privacy policy and store forms list all of it (M5).

### 8.6 Security

- The backend serves only our app. Every /v1 route checks App Attest (iOS) or Play Integrity (Android), plus per-IP rate limits. It must not work as an open API to BGG or eBay data. No public deployment happens before attestation is in place.
- HTTPS only, through Caddy.
- Every input is validated (barcode digits, length, and check digit; query length; bggId). Errors are typed JSON with no stack traces and no upstream error bodies.
- XML is parsed with external entities disabled.
- CSV export guards against formula injection.
- Secrets live in git-ignored .env files. CI scans for secrets. The app binary contains no third-party API keys and no campaign id.
- Dependencies must be MIT, BSD, or Apache 2.0, checked in CI. Anything else needs your approval.

### 8.7 Backend and operations

- One Oracle Cloud Always Free VM, running Docker Compose with Caddy in front. Images built for linux/arm64 and linux/amd64 until the VM's architecture is confirmed (Q20).
- BGG requests go through one queue, no more than one every 2 seconds unless docs/api-research.md says otherwise. Game data is cached for at least 7 days.
- The daily snapshot job covers every game looked up in the last 90 days [ASSUMPTION]. It stays inside eBay's daily call budget, logs the budget used each day, and logs a warning at 80% [ASSUMPTION].
- Daily PostgreSQL backups kept 14 days [ASSUMPTION], with a restore procedure that has been tested.
- API versioning: /v1 stays backward compatible. Breaking changes go to a new version while /v1 keeps working, so there is never a forced app update.
- If the backend is down, the app keeps working from cached data.

### 8.8 Quality

- Unit tests for every repository, use case, parser, and price calculation, using recorded fixtures. No live third-party calls in tests.
- Widget tests for every screen: loading, empty, error, and offline states.
- Golden tests for key screens, rendered on Linux only.
- An integration test for scan to add-to-collection with the scanner mocked.
- Backend tests for every endpoint, the rate limiter, the snapshot job, and failure of each upstream API.
- At least 80% line coverage on the app's domain and data layers and on the server. Zero analyzer warnings under strict lints. CI runs all of it on every push.

### 8.9 Language and region

US English only, USD, US date and number formats ($1,234.56; Oct 11, 2026).

## 9. External dependencies and risks

Facts and sources for these live in docs/api-research.md (T-002).

| Id | Risk | Impact | Status |
|---|---|---|---|
| R1 | BGG may deny a commercial license to an app it sees as competing with its business. BGG runs its own marketplace, and we show eBay prices with affiliate links. | Without BGG data the app cannot identify or describe games. No fallback has been identified yet. | Being researched in T-002, including a draft license application. |
| R2 | eBay production access, API License Agreement terms, and EPN approval. Browse API daily call limits cap how many games get daily snapshots. | Pricing (M4) and revenue. | T-002 |
| R3 | Marketplace Insights (sold prices) is limited release and may never be approved. | v1 may show asking prices only. Already planned for: feature flag, off by default. | T-002 |
| R4 | GameUPC commercial terms, limits, and availability. | Barcode matching (M2). Title search is the fallback. | T-002 |
| R5 | App Store and Google Play review of affiliate links, third-party prices, and camera use. | Release (M5). | T-002 |
| R6 | BGG allows about one request every 2 seconds. Under load, cold lookups wait in our queue. | Slow first lookups. Mitigated by caching. | Monitor in M2 and M5 |
| R7 | mobile_scanner (BSD-3-Clause) uses a bundled Google ML Kit on Android. ML Kit is governed by the Google APIs Terms of Service, not an open source license, and sends usage metrics to Google that we must disclose. | Needs your approval under the license rule (Q4) and a disclosure in the privacy policy and Data Safety form. | Checked 2026-10-11; details in docs/handoffs/T-001.md for T-002 to record |
| R8 | One free VM is a single point of failure. Oracle's rules for idle Always Free instances are UNVERIFIED. | Backend downtime; the app falls back to cached data. | To check before M5 |

## 10. Out of scope for v1

- User accounts, cloud sync, and social features.
- Buying or selling inside the app.
- Importing a BGG collection.
- Marketplaces other than eBay US, and currencies other than USD.
- Sold prices, until eBay approves Marketplace Insights (the code exists behind a flag).
- New or sealed-condition prices [ASSUMPTION].
- Price alerts and push notifications [ASSUMPTION].
- Languages other than US English [ASSUMPTION].
- Web and desktop versions.
- Ads, in-app purchases, subscriptions, analytics, and crash reporting SDKs [ASSUMPTION].

## 11. Assumptions to confirm

From the brief: CI on GitHub Actions; Android API 24 and iOS 15 minimums; a Dart backend on dart_frog or shelf (T-005); snapshots for games looked up in the last 90 days.

Proposed in this PRD: the success measures (section 2), collector size of 100+ games, every number in section 8.3, the few-listings threshold of 3, the stale threshold of 48 hours, prices without shipping, no rating prompts, no analytics or crash SDKs, a 7-day log retention, 14-day backups, the 80% budget warning, and the out-of-scope items marked above. Ticket-level proposals are marked in docs/backlog.md.

## 12. Open questions

Grouped by when we need the answer.

**Before M1 work starts**

- Q1. What are the app's display name, Android application id, and iOS bundle id? Until you answer, M1 uses the placeholder name "Board Game Collector" and the id com.example.boardgamecollector [ASSUMPTION]. That id must change before any store upload.
- Q2. Is the GitHub repository private or public? For private repositories, GitHub Actions minutes are limited, and macOS runners (needed for iOS builds) use them faster. Current pricing is UNVERIFIED. To limit macOS use, the proposal is to build iOS only on main and on manual runs.
- Q3. Please confirm the brief's assumptions in section 11. The backend framework is decided separately in T-005.

**Before M2**

- Q4. On Android, mobile_scanner bundles Google ML Kit. ML Kit is governed by the Google APIs Terms of Service, not MIT, BSD, or Apache 2.0, and it sends usage metrics to Google. Do you approve it? The alternative is a different scanning library, which would change the brief's stack.
- Q5. Can the app load cover images (BGG) and listing photos (eBay) directly from their image hosts? A strict reading of "the app talks only to our backend" says no, which means the backend must proxy images. Proxying costs VM bandwidth and may conflict with provider terms. The proposal is to allow direct image loading and disclose it in the privacy policy [ASSUMPTION].
- Q6. Do you have Apple Developer Program and Google Play Console accounts (both are paid)? Is the publisher you as an individual, or a company? iPhone testing through TestFlight (T-036) needs the Apple account.
- Q7. Which iPhone and Android phone models can you test on? We will use them as the reference devices for section 8.3 and for manual checks.
- Q8. For iPhone testing in M2, the backend has to be reachable from the internet. Do you want a staging deployment on the VM before M5? If so, attestation (T-066 to T-069) moves ahead of it, and Caddy needs a domain name, which may be a paid item.
- Q9. Should a match the user confirms stay only on the device (proposed default), or also go to our backend so other users get better matches?
- Q10. Who registers for the BGG API token and GameUPC access, and when? M2 backend work needs both to record test fixtures. T-002 documents how to apply.

**Before M3**

- Q11. Does "manual entry" mean adding a game that has no BGG match by typing its details? Those games would have no metadata refresh and no prices.
- Q12. Should the full backup file include photos? It could reach hundreds of MB.
- Q13. Should the operating system's own backups (iCloud device backup, Android Auto Backup) include the collection? The proposal is yes, because they are under the user's control and protect against a lost phone [ASSUMPTION]. The privacy policy would mention it.
- Q14. Is 2,000 games per device the right size to design and test for [ASSUMPTION]?

**Before M4**

- Q15. Do you have an EPN account and a campaign id?
- Q16. Should prices exclude shipping (proposed), and should we stay used-only, with new and sealed prices out of scope (proposed)?
- Q17. If more games need snapshots than eBay's daily budget allows, which come first? The proposal is the most recently looked-up games first, keeping 20% of the budget for on-demand lookups [ASSUMPTION].
- Q18. Are the thresholds in section 6 (fewer than 3 listings, older than 48 hours) right?

**Before M5**

- Q19. Is it right to ship no crash reporting or analytics, relying on store console crash reports only (proposed)?
- Q20. Which Oracle VM shape will we use (Ampere arm64 or AMD amd64), and which domain name?
- Q21. Are 7-day request log retention and 14-day backup retention right?
- Q22. Where will the privacy policy and support page be hosted (the stores need public URLs), and what support email should the listings show?
