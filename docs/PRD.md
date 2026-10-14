# Product Requirements: Board Game Collector App

- Status: Draft for user review (ticket T-001, round 3: research from T-002 and your checkpoint 2 decisions folded in)
- Date: 2026-10-11
- Owner: product-manager
- Inputs: docs/brief.md (original brief), docs/decisions.md, docs/api-research.md (T-002, all facts checked 2026-10-11). Fact ids in parentheses, such as (EBAY-20), point to docs/api-research.md, which is the source of record for upstream facts. Blocking risk ids such as B2 refer to the "Blocking risks" table in that file.

Items marked [ASSUMPTION] are unconfirmed. They stay marked until you confirm them and the orchestrator records the answer in docs/decisions.md. Numbers the brief did not give are proposals and are marked the same way.

## 1. Summary

A free iOS and Android app for serious US board game collectors. A collector scans a game box barcode or searches by title. The app identifies the game, shows current used-market asking prices from eBay US listings, and lets the collector file it as Owned, Wanted, or Evaluating. A price history chart is planned, but whether we may keep daily eBay price statistics depends on eBay's answer (Q24). The collection lives only on the phone. A small backend that we run is the only thing that talks to BoardGameGeek (BGG), eBay, and GameUPC.

## 2. Goals

1. **Identify a game in seconds.** Scan, type a barcode, or search by title. When the match is unclear, the user picks from candidates, and the app remembers the choice.
2. **Show trustworthy used-market prices.** Every price says where it came from, that it is an asking price, how many listings it is based on, and how old it is. v1 has asking prices only, because eBay's sold-price API is closed to new users (EBAY-100).
3. **Keep the collection private and usable offline.** No accounts, no cloud sync, no tracking. Export and import let users back it up themselves.
4. **Respect our partners.** Launch only with a written BGG commercial license (BGG-11) and GameUPC's permission (GUPC-07). Follow eBay's API License Agreement, EPN's rules, and both app stores' policies (section 8.10).
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
| US-11 | see current used-market asking prices: median, low, high, and number of listings, with source and age | M4 |
| US-12 | see a price history chart, with a text summary for screen readers, if eBay allows us to keep the data (Q24) | M4 |
| US-13 | open an eBay listing in my browser or the eBay app | M4 |
| US-14 | see the total estimated value of my Owned games | M4 |
| US-15 | use my collection with no connection, and see recent prices within the age limits eBay allows (section 6) | M3 to M5 |
| US-16 | do all of the above with a screen reader, large text, or either theme | all |

## 5. Features by milestone

Ticket ids refer to docs/backlog.md. Tasks only you can do (applications, accounts, partner emails) are user tasks T-087 to T-095 (except T-093) in the backlog.

### M1 Foundations (T-004 to T-017)

Repository tooling and strict lints, a decision on a Dart pub workspace, CI on GitHub Actions in the private repository bartbasi/boardgame (confirmed, docs/decisions.md 2026-10-11; iOS builds on macOS runners only on main and manual runs) (app.yml, server.yml, repo.yml with secret scanning, a prose style check, and dependency license checks), the Linux golden image pipeline, the app skeleton (navigation, light and dark themes, feature folders, Result and Failure types, HTTP client with retries), the backend skeleton (GET /health, fail-fast config, minimal structured logs), a multi-arch Dockerfile, local Docker Compose with PostgreSQL and Caddy, the backend framework decision (shelf with shelf_router, confirmed, docs/decisions.md 2026-10-12), and the api_contract package skeleton.

Done when: CI is green on main for app, server, and repo checks; the app runs on an Android emulator and the iOS build compiles in CI; https://localhost/health answers through local Compose; a golden rendered with the Linux command passes in CI.

### M2 Identify a game (T-018 to T-036)

Barcode scanning (UPC-A, EAN-13, EAN-8) with torch, haptics, and duplicate debounce; manual barcode entry; title search; candidate selection when a barcode has zero or several matches; on-device cache of confirmed barcode matches and viewed games; the game detail screen with BGG attribution. Backend: PostgreSQL access, per-IP rate limits, BGG client with a shared request queue, GameUPC client, and the barcode, search, and game detail endpoints.

Started, because they gate M2 backend work: you submitted the BGG app registration and license application on 2026-10-13 and are waiting for BGG's answer (T-087; approval can take a week or more after submission, BGG-04), and PM has researched fallback game data sources in case BGG refuses (T-097, done). None keeps the product as specified; the best is a reduced product (docs/api-research.md section 10, B11; Q33 to Q36). Still to start: the email to GameUPC (T-088).

Done when: on a real Android phone (and an iPhone through TestFlight, once accounts exist), a user scans a box and reaches the right game's detail screen through the backend, and every M2 ticket is signed off.

### M3 Collection (T-037 to T-049)

Local database, the three lists with type-specific fields, manual entry, edit, move, sort, filter, search, photos, CSV export and import, full backup and restore, and the scan to add-to-collection integration test. Fully offline.

### M4 Pricing (T-050 to T-065, T-084 to T-086)

Current asking prices from the eBay Browse API, listings with "View on eBay", the EPN disclosure, and collection total value. eBay compliance work: the account deletion notification endpoint (T-084), a category id check (T-085), and daily usage logging (T-086). Daily price snapshots and history charts are built behind a backend flag, because storing eBay-derived statistics needs eBay's answer (B2, Q24). Sold prices are not in v1: Marketplace Insights is closed to new users (EBAY-100), and its ticket (T-059) is on hold (Q27).

Before M4 starts: your eBay developer account, production keyset, and EPN account (T-090), and the question to eBay Developer Support (T-089).

### M5 Hardening and store readiness (T-066 to T-083, T-093)

App Attest and Play Integrity, offline and error handling audits, accessibility audit, performance check against section 8.3, privacy policy, terms, store listings, privacy label and Data Safety answers, the iOS privacy manifest check, release builds, production deployment runbook, and tested backups. Deployment happens only with your approval. At launch: the EPN mobile app application (T-092) and permission proof for App Review (T-094).

## 6. Pricing rules

These rules apply to every screen and endpoint that shows a price.

1. **Source:** eBay US marketplace (EBAY-49), used condition (`conditions:{USED}`, EBAY-47), the board games category (likely 2550 "Board & Traditional Games", EBAY-60, confirmed in T-085), prices in USD. Fixed-price (Buy It Now) listings only, which is the Browse API default (EBAY-45). Auctions are left out because a current bid is not an asking price [ASSUMPTION].
2. **Asking prices only in v1:** Browse API results are current listings, so their prices are asking prices, and they are always labeled as asking prices. Marketplace Insights, the only sold-price source, is closed to new users and cannot be requested (EBAY-100, EBAY-102). If sold prices ever arrive, they are labeled as sold and never combined with asking prices into one number. An asking price is never called a sold price, a value, or a sale.
3. **Every price display shows:** the amount, the asking label, the source (eBay), the sample size ("from 23 listings"), and the data age ("updated 2 hours ago"). eBay requires showing the age of listing data that is not current (EBAY-20).
4. **Statistics:** median, low, high, and number of listings, computed after removing lots, bundles, and obvious outliers. The filter rules are documented and each one has a test (M4). We never compute category-wide or site-wide statistics (EBAY-23).
5. **Low data:** with zero listings, show "No current listings", never $0. With fewer than 3 listings [ASSUMPTION], show the numbers with a "few listings" note.
6. **Age limits (EBAY-20):**
   - Listings are shown only if they were fetched in the last 6 hours. This applies on the server and in the app, including offline. Older listings are hidden, not shown with a "Last updated" label.
   - A price summary (median, low, high, count) is computed from listings fetched in the last 6 hours. After 6 hours it carries a visible stale marker [ASSUMPTION]. Once it is older than 24 hours it is not shown [ASSUMPTION: a cautious reading of EBAY-20's 24-hour limit for other eBay content, until eBay answers Q24].
7. **Shipping:** the Browse API price excludes shipping (EBAY-53). We show item prices without shipping, and the label says so [ASSUMPTION, Q16].
8. **Collection total:** the sum of median asking prices for Owned games whose price summary is within the age limit in rule 6. Labeled as an estimate from eBay asking prices, with the count of games that have no current price data.
9. **History:** built only from our own daily snapshots of the four statistics. It starts the first day anyone looks up the game, with no backfill. The eBay API License Agreement neither clearly allows nor forbids keeping these (EBAY-20, EBAY-21, EBAY-23, B2). Snapshots and history are built behind a backend flag. Whether the flag is on at launch depends on eBay's answer (Q24). If it stays off, the app hides history, and current prices still work.

## 7. Monetization constraints

- Free. No ads, no in-app purchases, no subscriptions.
- The only revenue is EPN commission on "View on eBay" links.
- EPN must approve the app before it pays for app traffic, and the application needs a live store link and test access (EBAY-90, EBAY-91). Expect no commission from launch until EPN approves (Q15, T-092).
- The EPN campaign id is a backend setting. The app never holds it and never builds affiliate URLs. The backend sends it as `affiliateCampaignId` in the `X-EBAY-C-ENDUSERCTX` header (EBAY-50). eBay returns itemAffiliateWebUrl only when that header is sent (EBAY-51), and partners must use it (EBAY-52). The backend returns itemAffiliateWebUrl when present and itemWebUrl otherwise.
- **Disclosure:** a short disclosure sits next to the listings, visible without scrolling (EBAY-92). A disclosure only in Settings, behind a link, or in small print is not enough. It must use an EPN-approved phrase; "Affiliate link" is not approved (EBAY-93). You choose the wording (Q25). Settings also carries the full disclosure. The disclosure is inline text, never a modal, and never needs to be acknowledged. Wording lives in docs/legal/ (T-050).
- No rewards or incentives for tapping links (EBAY-94).
- eBay logos, if used, must be exactly the files EPN provides. "eBay" may appear in the app name only with EPN's written approval and only descriptively (EBAY-82; see Q1b).
- **Nothing blocks, delays, or requires a tap to keep using the app.** That means no interstitials, no onboarding wall, no rating prompts [ASSUMPTION], no confirmation dialog before opening eBay, no forced update screens, and no countdowns. The camera permission prompt appears only when the user opens the scanner, and denying it never blocks search or the collection.

## 8. Non-functional requirements

### 8.1 Platforms

- iOS 15 or later and Android API 24 or later (confirmed, docs/decisions.md 2026-10-11). These minimums fit App Attest (iOS 14 and later, APPLE-11), Play Integrity (Android 6.0 and later, GPLAY-07), and ML Kit barcode scanning (API 23 and later, MLKIT-08).
- Phones and tablets, portrait and landscape, with compact, medium, and expanded layouts.
- Latest stable Flutter and Dart 3 (versions recorded in docs/decisions.md).

### 8.2 Offline

- The collection and games the user has viewed work with no connection. When they cannot be refreshed, show the cached data with a "Last updated" label instead of an error screen.
- eBay data follows the age limits in section 6 rule 6. Listings older than 6 hours are hidden, and price summaries older than the limit are not shown. In their place, a plain message says prices need a connection.
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
| Barcode read to result, backend cache miss, BGG queue empty | 6 s or less (p95). Each request already waiting in the BGG queue adds about 5 s (section 8.7, R6). |
| Title search results, backend cache hit / miss with BGG queue empty | 1.0 s / 6 s or less (p95) |
| Game detail from the device cache | 300 ms or less |
| Collection with 2,000 games: search, sort, or filter | updates in 300 ms or less, scrolling without visible jank |
| CSV export of 2,000 games | 5 s or less |
| App download size | 50 MB or less per platform |
| Backend server time for a cache hit | 100 ms or less (p95) |
| Whole backend Compose stack memory | 512 MB or less idle, 1 GB or less at peak. These are efficiency targets. The VM is sized separately so Oracle does not reclaim it as idle (section 8.7, Q20). |

### 8.4 Accessibility

- WCAG 2.2 AA contrast: 4.5:1 for text, 3:1 for large text and UI parts. Information is never shown by color alone.
- Touch targets at least 48 by 48 dp.
- Dynamic type up to 200% with no clipping or overlap.
- Semantic labels on every icon, image, and chart. Charts also have a text summary.
- Complete flows with TalkBack and VoiceOver. Motion respects the system reduce-motion setting.

### 8.5 Privacy

- No accounts, no user ids, no advertising ids, no analytics or ad SDKs [ASSUMPTION], and no cross-app tracking.
- **Device ids: none, with one open exception.** App Attest requires our server to store a public key and a counter for each app install (APPLE-13). That is a pseudonymous per-install record. You either accept it, and we disclose it, or protection uses a design without it (Q26).
- The collection and its photos never leave the phone, except in files the user exports. Whether the operating system's own backups (Android Auto Backup, iCloud Backup) include them is Q38.
- The backend stores only: cached game data, barcode-to-game mappings, cached searches (normalized query text, no identifiers), eBay data within the age limits in section 6 (plus daily statistics if Q24 allows), and which games were looked up and when. It stores no IP addresses. The eBay listing cache keeps no seller or buyer identifiers [ASSUMPTION], so eBay's account deletion notifications need no data changes (EBAY-10, T-084).
- Request logs hold method, route template, status, and duration only, and are kept 7 days [ASSUMPTION].
- Third-party processing we must disclose: Google ML Kit on Android, which you approved with disclosure (docs/decisions.md 2026-10-11). It processes camera images on the device and sends usage and performance metrics to Google (MLKIT-02 to MLKIT-04). It must appear in the privacy policy (T-078) and the Google Play Data safety answers (T-079). iOS uses Apple's scanner, not ML Kit (MLKIT-05). Also: image hosts, if images load directly (Q5); eBay, when the user opens a listing. Our server sends GameUPC barcodes only, never a device or user identifier (GUPC-02).
- Store requirements: both stores need a privacy policy link in the store listing and inside the app (APPLE-02, APPLE-05, GPLAY-03). Google Play's Data safety form is required even if we collect nothing (GPLAY-06). Apple's privacy details cover third-party SDK practices (APPLE-04). The iOS build needs accurate privacy manifests (APPLE-15).

### 8.6 Security

- The backend serves only our app. It must not work as an open API to BGG or eBay data. Every /v1 request must carry proof that it comes from a genuine install of our app, and per-IP rate limits apply. No public deployment happens before this protection is in place.
- How the proof works: Play Integrity's default quota is 10,000 token requests and 10,000 decodes a day across all installs (GPLAY-07, GPLAY-08), so checking it on every request does not scale. Proposed design: verify App Attest or Play Integrity when a session starts, then issue a short-lived signed server token for later requests [ASSUMPTION; depends on Q26 and the orchestrator's decision]. What happens for installs that cannot attest (Apple says to skip App Attest gracefully where unsupported, APPLE-11) is decided in T-066 to T-069.
- HTTPS only, through Caddy.
- Every input is validated (barcode digits, length, and check digit; query length; bggId). Errors are typed JSON with no stack traces and no upstream error bodies.
- XML is parsed with external entities disabled.
- CSV export guards against formula injection.
- Secrets live in git-ignored .env files on the server, and CI scans for secrets. The BGG token, eBay credentials, GameUPC key, and EPN campaign id stay on the server (BGG-05). The app binary contains none of them.
- Dependencies must be MIT, BSD, or Apache 2.0, checked in CI. Anything else needs your approval.

### 8.7 Backend and operations

- **Hosting:** one Oracle Cloud Always Free VM, running Docker Compose with Caddy in front. Ampere A1 (linux/arm64) is the realistic shape: 2 OCPUs and 12 GB of memory in total (OCI-02). The AMD micro shape has 1 GB (OCI-01), which is likely too small [ASSUMPTION]. Images are built for linux/arm64, and for linux/amd64 for local use.
- **Idle reclamation:** Oracle may reclaim an Always Free VM that looks idle over 7 days, meaning CPU (95th percentile), network, and memory are all under 20% (OCI-07). Either the VM is sized so normal use stays above that line, or the account is upgraded to Pay As You Go (a paid account; whether that stops reclamation is UNVERIFIED, OCI-10). You choose (Q20).
- **BGG:** requests go through one queue at one request every 5 seconds [ASSUMPTION], configurable. BGG publishes no limit, and its wiki says a 5-second wait seems to suffice (BGG-20, BGG-21). This replaces the brief's 2 seconds, as the brief allows. Thing requests batch up to 20 ids (BGG-33). The queue backs off with jitter on 202, 429, 500, and 503. Game data is cached for at least 7 days (BGG has no cache rule we could find, BGG-24).
- **eBay:** the default Browse limit is 5,000 calls a day (EBAY-70). Raising it needs the free Application Growth Check (EBAY-72, EBAY-73), which expects at most two retries on infrastructure errors. Application tokens last 2 hours and are reused (EBAY-32). Daily usage is read with getRateLimits (EBAY-74) and logged, with a warning at 80% [ASSUMPTION].
- **Snapshots:** the daily job covers every game looked up in the last 90 days (confirmed, docs/decisions.md 2026-10-11), stays inside the eBay budget, and runs only when the history flag is on (section 6 rule 9).
- **Backups:** daily PostgreSQL backups, kept 14 days [ASSUMPTION], copied off the VM [ASSUMPTION], with a restore procedure that has been tested.
- **Storage keys:** the server database and the on-device Drift database give each game an internal surrogate id. The BGG id is a unique external id column next to the game's barcodes (and a future Wikidata id). The /v1 API paths and the api_contract keep `bggId`, as the brief specifies. Reason: if BGG refuses or ends the license, a fallback catalog fits without a schema change (B11; docs/decisions.md 2026-10-11, "Storage keys").
- **API versioning:** /v1 stays backward compatible. Breaking changes go to a new version while /v1 keeps working, so there is never a forced app update.
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

### 8.10 Partner and store compliance

- **BGG:** a written commercial license before launch (BGG-11, BGG-12; T-087). Every screen that shows BGG data credits BoardGameGeek by name and shows the "Powered by BGG" logo, linked to BGG, at a legible size (BGG-40, BGG-41). BGG data is not modified (BGG-15). XML API2 only, never BGG's JSON API (BGG-17). Cover images only as BGG allows (BGG-42). Until BGG answers, the app shows no cover images or listing photos at all (Q5, answered 2026-10-12), and every screen must work without them.
- **eBay:** the account deletion notification endpoint is live before the first production eBay API call (EBAY-10, EBAY-11; T-084). Content age limits apply (section 6 rule 6). Cached eBay content is deleted when no longer needed (EBAY-21), and all of it within 10 days if the agreement ends (EBAY-26). No category-wide or site-wide statistics (EBAY-23).
- **EPN:** app approval, disclosure placement, and approved wording (section 7).
- **GameUPC:** written permission for commercial use and a production key before launch (GUPC-01, GUPC-07; T-088).
- **App Review:** Apple can ask for proof that we may show BGG and eBay content (APPLE-08), so the BGG license and EPN approval must be ready (T-094). Neither store forbids linking out to buy physical goods (APPLE-06, GPLAY-11). We found no store rule about showing third-party prices (APPLE-10, GPLAY-13), but prices must not mislead (APPLE-09).
- **Permissions:** the camera is requested only when the user opens the scanner (GPLAY-02), with a purpose string that clearly describes the use (APPLE-01, APPLE-03).

## 9. External dependencies and risks

The research ids (B1 to B11) refer to the "Blocking risks" table in docs/api-research.md.

| Id | Risk | Impact | Research | Next step |
|---|---|---|---|---|
| R1 | BGG may refuse or charge for a commercial license. It may decline apps that compete with any part of its business, it runs GeekMarket, and its free tiers do not cover affiliate revenue (BGG-12, BGG-13, BGG-14). | Without BGG data the app cannot identify or describe games. T-097 found no fallback that keeps the product as specified. The best is a reduced product: our own catalog seeded from Wikidata (about 5% of BGG's games, sparse details), a paid barcode database, and games users add by hand (docs/api-research.md section 10). | B1, B11 | You plan to submit the application (T-087, in progress; not yet submitted as of 2026-10-12). Storage uses internal ids with the BGG id as an external column (section 8.7). If BGG refuses, answer Q33 to Q36. |
| R2 | Keeping eBay-derived price history is a gray area in the eBay API License Agreement (EBAY-20, EBAY-21, EBAY-23). | History chart, snapshots, offline prices, collection total. | B2 | Ask eBay (T-089, Q24). Build history behind a flag. |
| R3 | No sold prices: Marketplace Insights is closed to new users (EBAY-100, EBAY-102). | v1 shows asking prices only. | B3 | Accepted. T-059 on hold (Q27). |
| R4 | GameUPC publishes no terms, limits, or availability promise, and documents only a test endpoint (GUPC-01 to GUPC-07). | Barcode lookup. Title search is the fallback. | B6 | Email the operator (T-088). |
| R5 | Apple can ask for proof that we may show BGG and eBay content (APPLE-08). | Release. | APPLE-08 | Permission proof ready (T-094). |
| R6 | At one BGG request every 5 seconds, cold lookups wait in our queue under load. Developers report 429 responses even at that spacing (BGG-22, unverified). | Slow first lookups. Mitigated by caching. | BGG-21, BGG-22 | Monitor in M2 and M5. |
| R7 | mobile_scanner runs Google ML Kit on Android, under Google's terms, not an open source license, and ML Kit sends usage metrics to Google (MLKIT-01 to MLKIT-07). mobile_scanner has no other Android engine. | Android scanning, license rule, privacy disclosures. | B9 | Approved with disclosure (docs/decisions.md 2026-10-11). Disclose in T-078 and T-079. |
| R8 | One free VM is a single point of failure, and Oracle may reclaim it if it looks idle for 7 days (OCI-07). | Backend downtime. The app falls back to cached data. | B8 | Size the VM or upgrade (Q20). |
| R9 | No commission until EPN approves the app, and EPN wants a live store link first (EBAY-90, EBAY-91). | Revenue from launch day until approval. | B4 | Apply at launch (T-092, Q15). |
| R10 | EPN restricts disclosure wording and placement (EBAY-92, EBAY-93). Approved phrases such as "Ad" may sit badly with "no ads" and with Google Play's "Contains ads" answer (GPLAY-12). | Listing layout, copy, store declarations. | B5 | Choose wording (Q25). |
| R11 | Attestation as the brief specifies conflicts with "no device ids" (APPLE-13) and with Play Integrity's daily quota (GPLAY-07, GPLAY-08). | M5 protection design, privacy disclosures. | B7 | Decide (Q26). |
| R12 | Rights to BGG cover images are unclear, and BGG staff asked developers not to hotlink (BGG-42). | Cover images on game screens. | B10 | No images until BGG answers (Q5, answered 2026-10-12); the application asks BGG about image use. Screens work without images. |
| R13 | The first production eBay API call needs the account deletion endpoint live on a public HTTPS URL (EBAY-10, EBAY-11). That means a deployment before M4 can use production eBay data, including the category check (T-085) and recording test fixtures. | M4 schedule, deployment approval. | EBAY-10, EBAY-11 | Decide when the first deployment happens (Q8). |

## 10. Out of scope for v1

- User accounts, cloud sync, and social features.
- Buying or selling inside the app.
- Importing a BGG collection.
- Marketplaces other than eBay US, and currencies other than USD.
- Sold prices: Marketplace Insights is closed to new users (EBAY-100).
- New or sealed-condition prices, and auction listings [ASSUMPTION].
- Price alerts and push notifications [ASSUMPTION].
- Languages other than US English [ASSUMPTION].
- Web and desktop versions.
- Ads, in-app purchases, subscriptions, analytics, and crash reporting SDKs [ASSUMPTION].

## 11. Assumptions to confirm

Confirmed by you on 2026-10-11 (docs/decisions.md), so no longer assumptions: CI on GitHub Actions; Android API 24 and iOS 15 minimums; snapshots for games looked up in the last 90 days.

Confirmed by you on 2026-10-12 (docs/decisions.md): the Dart backend uses shelf with shelf_router, AOT compiled and run from a scratch Docker image (T-005).

Changed by research: the brief's BGG spacing of one request every 2 seconds becomes 5 seconds [ASSUMPTION] (BGG-20, BGG-21), as the brief allows.

Proposed in this PRD:
- The success measures (section 2) and collector size of 100+ games.
- Every number in section 8.3.
- Pricing: few-listings threshold of 3; stale marker after 6 hours; summaries hidden after 24 hours; fixed-price listings only; prices without shipping; no seller identifiers in the listing cache.
- Monetization and privacy: no rating prompts; no analytics or crash SDKs.
- Operations: AMD micro shape too small; session-start attestation with a short-lived server token; 7-day log retention; 14-day backups copied off the VM; the 80% budget warning.
- The out-of-scope items marked above.

Ticket-level proposals are marked in docs/backlog.md.

## 12. Open questions

Ids are stable: Q1 to Q22 are from round 1, Q23 to Q32 are new in round 2, Q33 to Q37 come from the fallback research (F1 to F5 in docs/handoffs/T-097.md), Q38 comes from the T-012 code review (it absorbs Q13), and Q39 from the T-027 code review. Where a question matches one in the research handoff (U1 to U9 in docs/handoffs/T-002.md) or the UX handoff (OQ1 to OQ15 under "Open questions" in docs/handoffs/T-003.md), those ids are shown. T-003 OQ1 (BGG attribution) is answered by research and needs no user decision: BoardGameGeek is credited by name with the "Powered by BGG" logo on every screen that shows BGG data (section 8.10). T-003 OQ2's eBay attribution part depends on an old eBay article (EBAY-80) and is checked in T-091; its image part is Q5. Answered questions move to the "Answered" list at the end of this section and keep their ids. When only part of a question is answered, the open part keeps the id with a "b" suffix (Q1b, Q6b, Q10b).

**Start now (long lead time)**

- Q10b (U6). Will you email the GameUPC operator (draft in docs/api-research.md section 3.3) for commercial permission, a production key, and limits before M2 backend work? Tracked as T-088. (Part (a) of Q10, the BGG application, is answered below.)
- Q37 (T-097 F5). Should the GameUPC email (T-088) also ask whether GameUPC can return a product title it holds itself, not taken from BGG? That would help the reduced product in Q33 if BGG refuses. Whether GameUPC stores titles independently of BGG is unknown (GUPC-07).

**Only if BGG refuses** (background: docs/api-research.md section 10 and B11; full recommendation in docs/handoffs/T-097.md)

- Q33 (T-097 F1). Which path do you want? (a) Pause or stop the project. (b) Ask BGG what would change its answer, for example a paid license, or also linking to the game's BGG page or GeekMarket listings. (c) Ship a reduced product: our own catalog seeded from Wikidata (CC0, about 5% of BGG's games, sparse details), a paid barcode database, and games users add by hand, with eBay prices unchanged. Proposed: (b) first, then choose between (a) and (c).
- Q34 (T-097 F2). Path (c) needs a paid barcode database. Published prices: EAN-Search.org from 19 EUR a month for 5,000 queries (FB-05), UPCitemdb $99 a month for 20,000 lookups a day (UPCDB-01), Barcode Lookup from $99 a month for 5,000 calls (FB-03). None of their terms clearly allows showing results in a public app, so we would ask the provider in writing first. Would you pay for one, and up to what monthly amount?
- Q35 (T-097 F3). In path (c), most games would show only a title, perhaps a publisher, and users would add many games by hand (Q11). Is that still a product you want to ship?
- Q36 (T-097 F4). Some Wikidata statements cite BGG as their source (WD-05), and GameUPC works through BGG ids. If BGG has refused us, should a lawyer confirm that using Wikidata board game data, and BGG ids as a lookup key, is safe? [ASSUMPTION: low risk, not legal advice.]

**Before the first store upload (T-036 in M2, T-082 in M5)**

- Q1b (open part of Q1). What is the app's final store name? The working title is "Board Game Collection" (Q1 part (a) below); PM is researching name options for you. The name can change after launch; the ids cannot. The name may include "eBay" only with EPN's written approval, and only descriptively (EBAY-82). The iOS short name (`CFBundleName`) must be under 16 characters (T-082 rename checklist), so the label under the icon may need a shorter form.
- Q6b (open part of Q6). Should the publisher be you as an individual or a company? This decides which Apple Developer Program and Google Play Console accounts you create, and the seller name both stores show. Options, costs, and a recommendation are in docs/store/developer-accounts.md. iPhone testing through TestFlight and Play internal testing (T-036) need the accounts.

**Before M2**

- Q7. Which iPhone and Android phone models can you test on? We will use them as the reference devices for section 8.3 and for manual checks.
- Q8. When should the first deployment to the VM happen? Two things need one before M5: iPhone testing in M2 (the phone must reach the backend), and the first production eBay call in M4, which needs the account deletion endpoint live on a public HTTPS URL (R13). Any deployment first needs attestation (T-066 to T-069), the Q26 decision, and a domain name for Caddy, which may cost money.
- Q9. Should a match the user confirms stay only on the device (proposed), or also go to our backend so other users get better matches? If we ever pass votes on to GameUPC, its demo sends a `user_id`, and we must not send any device or user identifier (GUPC-02).
- Q32 (T-003 OQ12 to OQ15). UX defaults; please veto any you dislike: sort and filter choices persist across launches, and the Collection tab bar stays pinned; on a listing row only the "View on eBay" button opens eBay, so the rest of the row does nothing (avoids accidental opens); at most 10 photos per item; the compact navigation bar hides while the keyboard is open.

**Before M3**

- Q11 (T-003 OQ7). Does "manual entry" mean adding a game that has no BGG match by typing its details? Those games would have no metadata refresh and no prices.
- Q12 (T-003 OQ6). Should the full backup file include photos? It could reach hundreds of MB.
- Q13. Merged into Q38, which asks the same question with the platform facts from the T-012 review. Answer Q38 instead.
- Q38 (Q13, T-012 review R1-G4). Should Android Auto Backup and iOS iCloud backup copy the app's data, including the collection? Section 8.5 says the collection lives only on the phone, except in files the user exports. Today the app leaves Android's `allowBackup` unset, which means backup is on (GPLAY-14): the data goes to a private folder in the user's own Google Drive, up to 25 MB per app (GPLAY-15). iCloud Backup also includes app data unless we mark it excluded, and that mark is only a hint to iOS, not a guarantee (APPLE-16, APPLE-17). Options: (a) keep backups on, which protects against a lost phone, and say so in the privacy policy and the Google Play Data safety answers; (b) turn them off (Android `allowBackup="false"` plus `dataExtractionRules`, iOS exclusion marks), so only the user's export and backup files leave the phone. Even with (b), some Android 12+ devices still copy data in a phone-to-phone transfer unless the rules say otherwise (GPLAY-17). Proposed: (a) [ASSUMPTION]. The privacy policy (T-078) and the Data safety answers (T-079) depend on the answer, and it must be settled before the collection storage ticket (T-037). Added 2026-10-14: if the app's backup data is over 25 MB, Android backs up nothing at all for the app, not just the excess (GPLAY-28, blocking risk B13), so under (a) photos and large caches must stay out of the backup.
- Q39 (T-027 review R1-S5). Should the game details we download from our backend (up to 500 games, re-downloadable) live in a separate cache file that the operating system's backups skip, while your confirmed barcode matches and the collection stay in the main file? Android never backs up the cache folder (GPLAY-27), and iOS leaves `Library/Caches` out of iCloud Backup (APPLE-16). This keeps the cache from pushing Android over its 25 MB limit (GPLAY-28) and keeps backup files small. The cost: the phone may delete cached details when storage is low, and then a game's details need a connection to load again (confirmed matches and the collection are not affected). It is cheap now and needs a data migration after release. Proposed: yes [ASSUMPTION]; the work is T-102, before T-037.
- Q14. Is 2,000 games per device the right size to design and test for [ASSUMPTION]?
- Q28 (T-003 OQ8). The brief lists only target price and priority for Wanted games. The UX spec adds a Notes field to Wanted as well. Keep it or drop it?
- Q29 (T-003 OQ9). After a restore, the app keeps a safety copy of the previous collection on the device until the user leaves the screen or closes the app, so the restore can be undone without a confirmation dialog. Is that acceptable?
- Q30 (T-003 OQ10). When a CSV import contains a game that is already in the collection, should the row be skipped (proposed) or update the existing item?

**Before M4**

- Q15 (U4). Do you have an EPN account and a campaign id? EPN reviews the app only once the store listing is live (EBAY-90) and pays nothing for unapproved app traffic (EBAY-91). Is it acceptable that early clicks may earn nothing?
- Q16. How do we define the price? Proposed: item price without shipping (the Browse API price excludes it, EBAY-53), used condition only, and fixed-price listings only, with no auctions. New and sealed prices are out of scope.
- Q17. If more games need snapshots than the eBay budget allows (5,000 Browse calls a day by default, EBAY-70), which come first? The proposal is the most recently looked-up games first, keeping 20% of the budget for on-demand lookups [ASSUMPTION]. A higher limit needs the Application Growth Check (EBAY-72, T-095).
- Q18. Are the thresholds in section 6 right: fewer than 3 listings is "few", the stale marker comes after 6 hours, and summaries are hidden after 24 hours (until eBay answers Q24)?
- Q24 (U3). Will you send eBay Developer Support the question in docs/api-research.md section 2.12 before M4 starts (T-089)? Until eBay answers, should the snapshot and history flag stay off? (The PRD builds history behind the flag either way.)
- Q25 (U5, T-003 OQ3). Which EPN-approved disclosure wording do you want next to the listings: "Paid link", "Ad", "Sponsored by eBay", or a sentence such as "As an eBay Partner, we may be compensated if you make a purchase" (EBAY-93)? "Ad" may sit badly with "no ads" and with Google Play's "Contains ads" answer (GPLAY-12).
- Q27. The brief asks for Marketplace Insights behind a flag, but it is closed to new users and cannot be requested (EBAY-100, EBAY-102, EBAY-103). Proposed: keep only the "sold" label in the contract and the app, and build the client (T-059) only if eBay grants access. Or should we build it now from documentation, without real responses to test against?

**Before M5 (or before an earlier deployment, Q8)**

- Q19. Is it right to ship no crash reporting or analytics, relying on store console crash reports only (proposed)?
- Q20 (U7). The VM: research favors Ampere A1 (arm64) within 2 OCPUs and 12 GB (OCI-02). To avoid idle reclamation (OCI-07), do we size the VM so normal use stays above 20% memory, or upgrade to Pay As You Go (a paid account, $0 within the free limits, effect on reclamation UNVERIFIED, OCI-09, OCI-10)? Which domain name will we use?
- Q21. Are 7-day request log retention and 14-day backup retention right? Where should backups be copied off the VM?
- Q22. Where will the privacy policy and support page be hosted? The privacy policy needs a public, non-geofenced web page, not a PDF (GPLAY-03), linked in both stores and inside the app (APPLE-02). What support email should the listings show?
- Q26 (U8). App Attest needs our server to keep a public key and counter for each install (APPLE-13), a pseudonymous per-install record. Do you accept it (and we disclose it), or should we design protection without per-install assertions?

**Answered** (kept for reference; source: docs/decisions.md)

- Q1 part (a), answered 2026-10-13. The Android application id and the iOS bundle id are `com.bartbasi.boardgamecollection`, and the working title is "Board Game Collection". The ids are permanent once uploaded to a store. The final store name stays open as Q1b above. M1's placeholders (name "Board Game Collector", id `com.example.boardgamecollector`) are replaced through the rename checklist in T-082 (or T-036, whichever uploads first).
- Q2, answered 2026-10-11. The GitHub repository bartbasi/boardgame is private. iOS builds on macOS runners run only on main and on manual runs (T-014).
- Q3, answered 2026-10-11. Confirmed: GitHub Actions for CI, minimum Android API 24 and iOS 15, and price snapshots for games looked up in the last 90 days. Their [ASSUMPTION] markers are removed. The backend framework was decided in T-005 on 2026-10-12: shelf with shelf_router.
- Q4 (U9, T-003 OQ4), answered 2026-10-11. Google ML Kit is approved on Android through mobile_scanner, with its usage metrics disclosed in the privacy policy and the Google Play Data safety form (MLKIT-01 to MLKIT-08; T-078, T-079). iOS uses Apple's scanner.
- Q5 (T-003 OQ2, OQ5), answered 2026-10-12. No cover images and no listing photos for now. Every screen works without images, and the API contract carries no image URL fields (T-018). The BGG license application (T-087) asks BGG about image use; whether images later load directly or through a backend proxy is decided after BGG answers (BGG-42, R12).
- Q6 part (a), answered 2026-10-13. You have no Apple Developer Program or Google Play Console account yet. The individual or company choice stays open as Q6b above.
- Q10 part (a) (U1), answered 2026-10-11. You review and submit the BGG application (docs/api-research.md section 1.6) yourself (T-087). You submitted it on 2026-10-13 and are waiting for BGG's answer. Part (b), GameUPC, stays open as Q10b above.
- Q23 (U2), answered 2026-10-11. PM researched fallback game data sources in parallel, in case BGG refuses (T-097, done). Result: no fallback keeps the product as specified (B11). Follow-up questions are Q33 to Q37.
- Q31 (T-003 OQ11), answered 2026-10-12. The seed color is `0xFF1F6B5C` (a deep green-teal), with wallpaper-based dynamic color turned off. T-012 uses it from M1.
