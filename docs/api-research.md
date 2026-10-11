# API and Policy Research

- Ticket: T-002
- Owner: product-manager
- Full check done: 2026-10-11. Re-check any fact before it drives a decision after 2027-01-09 (90 days).
- Fact ids (BGG-xx, EBAY-xx, and so on) are stable. Tickets and code comments should cite them.

## How to read this file

Every fact has a source URL, the date checked, a short quote or close paraphrase, and a confidence level:

- **confirmed**: I read it on the official page on the date shown. The quote is verbatim or very close.
- **likely**: it comes from an official page, but I could only read that page through a web search restricted to the official domain, because the site blocked our page fetcher (HTTP 403 or a bot challenge). The wording is a close paraphrase, not a verified quote. Some "likely" items also come from official pages that are several years old.
- **unverified**: I found no official source. The row says what I tried. Do not build on it.

Access problem: boardgamegeek.com, most of developer.ebay.com (including the API License Agreement and the call limits page), partnernetwork.ebay.com, and oracle.com/cloud/free/faq all blocked the fetcher on 2026-10-11. Forum posts are recorded only as leads. Section 8 lists the "likely" items a person should confirm in a browser before they drive a decision.

## Blocking risks

These could block or reshape a feature. Each one is repeated in the T-002 report to the orchestrator.

| Id | Risk | What it affects | Evidence | Recommended action |
|---|---|---|---|---|
| B1 | **BGG may refuse or charge for a commercial license.** The XML API terms allow only non-commercial use without a license. BGG decides commercial licenses case by case, says it may decline any app that competes with any part of its business, and runs its own marketplace (GeekMarket). Our app shows eBay prices and earns eBay affiliate commission. The published free tiers cover apps paid by users or by ads, not affiliate commission; sales-based apps "usually" pay from day one. | Everything. Search, game details, and barcode results all depend on BGG ids and data. No replacement source has been researched. | BGG-10 to BGG-14 | Apply now, before M2 code, with the honest description in section 1.6. Do not ship without a written license. Decide whether to research a fallback data source if BGG says no. |
| B2 | **Storing eBay price history is a gray area in the eBay API License Agreement.** Displayed listing data may be at most 6 hours old, other eBay content at most 24 hours old, and copies must be deleted when no longer needed. Deriving certain aggregates (for example average selling price for an eBay category) needs eBay's written permission. Nothing I could read names per-product asking-price statistics, but nothing clearly allows a 90-day stored history either. | M4: daily snapshots, history chart, collection total value. Also PRD section 6 (48-hour stale marker) and offline display of cached prices. | EBAY-20 to EBAY-26, section 2.4 | Send eBay Developer Support the question in section 2.12 before M4 snapshot work. Build snapshots and history behind a flag so they can be switched off. Hide cached listings older than 6 hours. |
| B3 | **Sold prices are not available.** eBay says Marketplace Insights "is restricted and not open to new users at this time." EPN says it cannot be granted on request. No public application path exists. | Sold prices in v1. | EBAY-100 to EBAY-103 | Plan v1 as asking prices only. Keep the flag off. The PRD already plans for this. |
| B4 | **No commission until EPN approves the app, and EPN needs the app to be live first.** Promoting eBay in a mobile app needs EPN's written approval. The application asks for an app store link and test access. EPN withholds compensation for traffic from software it has not approved. | Revenue from launch day until approval. | EBAY-90, EBAY-91 | Treat EPN approval as a launch task. Apply as soon as the store listing is live. Accept that early clicks may earn nothing. |
| B5 | **EPN disclosure rules restrict our wording and placement.** In apps the disclosure must be visible without scrolling and close to the links. "Affiliate link" is not an approved phrase. Approved phrases include "Ad" and "Paid link", which may sit awkwardly with "no ads" and with Google Play's "Contains ads" declaration. | Listing view layout, copy (UX), Settings, store declarations. | EBAY-92, EBAY-93, GPLAY-12 | UX and legal copy must use an approved phrase. User decides the wording (open question U5). |
| B6 | **GameUPC has no published terms, limits, or availability promise.** The only documented endpoint is under a /test/ path with a shared test key. The operator's 3-year availability pledge from 2021 has expired; a 2025 update exists but I could not read it. | Barcode lookup (M2). Title search remains as fallback. | GUPC-01 to GUPC-07 | User emails the operator (draft in section 3.3) for commercial permission, a production key, and limits before M2 backend work. |
| B7 | **Attestation as specified conflicts with "no device ids" and with Play Integrity quotas.** App Attest requires our server to store a per-install public key and counter. Play Integrity allows 10,000 token requests and 10,000 decodes per day by default, across all installs, so checking every request will not scale. | M5 protection design, PRD sections 8.5 and 8.6, privacy labels. | APPLE-12 to APPLE-14, GPLAY-07 to GPLAY-09 | Verify integrity at session start and issue a short-lived server token. Decide whether a per-install App Attest key is acceptable under the privacy rules (open question U8). |
| B8 | **Oracle Always Free is smaller than often quoted and can reclaim idle VMs.** Ampere A1 is now 2 OCPUs and 12 GB in total. An A1 VM counts as idle if, over 7 days, CPU (95th percentile), network, and memory are all under 20%. A small, efficient backend on a 12 GB VM could look idle. | Hosting, PRD section 8.3 memory targets, uptime. | OCI-02, OCI-07, OCI-10 | Size the VM so normal use stays above 20% memory, or approve a Pay As You Go upgrade (paid account, open question U7). Keep backups off the VM. |
| B9 | **The brief's scanner package brings Google ML Kit into the Android app.** mobile_scanner is BSD-3-Clause, but on Android it runs Google ML Kit, which is governed by Google's ML Kit terms and the Google APIs Terms of Service, not MIT, BSD, or Apache 2.0. ML Kit sends usage metrics to Google, and we must tell users. mobile_scanner offers no non-ML-Kit engine on Android. | Barcode scanning on Android (M2), CLAUDE.md rule 6, privacy policy, Data safety answers. | MLKIT-01 to MLKIT-08 | User approves ML Kit (PRD Q4), or asks us to research a different Android scanning package. If approved, disclose ML Kit metrics in the privacy policy and Data safety form. |
| B10 | **Image rights are unclear for BGG cover art.** BGG staff asked developers not to hotlink images and changed the image system so external links stop working. Rights to API images are not addressed in anything I could read. | Game detail and list screens (cover images), PRD Q5. | BGG-42 | Ask BGG in the license application (section 1.6). Design screens to work without cover images. |

## Summary for the user

- **BGG:** you need a registered app, a Bearer token, and a commercial license. BGG decides case by case and can refuse apps it sees as competing. It runs its own marketplace, and our app earns eBay commission, so a refusal is possible. A draft application is in section 1.6. BGG publishes no rate limit; its wiki says one request every 5 seconds works, so I propose 5 seconds instead of the brief's 2.
- **eBay Browse API:** looks available with a normal production key at 5,000 calls per day. It supports GTIN search, a used-condition filter, one category per call, and an affiliate header that makes eBay return an affiliate link for each listing. Board games appear to be category 2550; the backend should confirm with eBay's Taxonomy API.
- **eBay terms:** listings we show must be no more than 6 hours old, and we must show their age. Keeping a long price history built from listings is not clearly allowed or forbidden. Ask eBay in writing before building M4 (draft in section 2.12).
- **Sold prices:** Marketplace Insights is closed to new users. Plan v1 around asking prices only.
- **eBay Partner Network:** the app needs EPN approval, and EPN wants a live store link first. Until approval, clicks may earn nothing. The disclosure must sit near the listings, be visible without scrolling, and use approved words such as "Paid link". "Affiliate link" is not approved.
- **eBay compliance:** before the first production eBay call, we must subscribe to eBay's account deletion notifications (a small backend endpoint) or prove we store no eBay data. We will store some, so we need the endpoint.
- **GameUPC:** no terms, limits, or production details are published. Email the operator before relying on it (draft in section 3.3).
- **App stores:** neither store forbids linking out to eBay to buy physical goods. Both require a privacy policy and privacy forms, even if we collect nothing. Apple can ask for proof that we are allowed to show BGG and eBay content, so the BGG license and EPN approval matter for review too.
- **Integrity checks:** Play Integrity allows 10,000 checks per day by default, and App Attest needs a per-install key stored on our server. Both change the protection design.
- **Oracle:** the free Arm VM is 2 CPUs and 12 GB now, not 4 and 24. Oracle may reclaim VMs that look idle for 7 days.
- **Barcode scanner:** the brief's mobile_scanner package uses Google ML Kit on Android, with no other Android engine. ML Kit is under Google's terms, not an open source license, and sends usage metrics to Google, so it needs your approval and a privacy disclosure. iOS uses Apple's own scanner.

## 1. BoardGameGeek (BGG)

### 1.1 Access, registration, and token

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| BGG-01 | Registration is required for nearly all XML API use. Commercial and non-commercial apps register at https://boardgamegeek.com/applications. | https://boardgamegeek.com/using_the_xml_api | 2026-10-11 | "Registration is required for nearly all use of the XML API." | likely |
| BGG-02 | After approval you create a token on the applications page. Requests send it in an Authorization header as a Bearer token. No refresh is needed today; BGG says this may change. | https://boardgamegeek.com/using_the_xml_api and BGG staff post https://boardgamegeek.com/thread/3539581 | 2026-10-11 | Paraphrase: the header is "Bearer", a space, then the token, with no colon. | likely |
| BGG-03 | Send requests to boardgamegeek.com without "www". The www host can interfere with authorization. | https://boardgamegeek.com/thread/3539581 (BGG staff troubleshooting) | 2026-10-11 | "use the correct domain (boardgamegeek.com, WITHOUT a leading www)" | likely |
| BGG-04 | Approval can take a week or more. | https://boardgamegeek.com/using_the_xml_api | 2026-10-11 | Paraphrase: it may be a week or more before BGG responds. | likely |
| BGG-05 | BGG staff say an app that needs a token must either make requests from a server or ship the token in the app. We keep it on the server only (CLAUDE.md rule 8). | https://boardgamegeek.com/thread/3540336 (staff reply) | 2026-10-11 | Paraphrase of a staff reply. Forum post, so a lead only. | likely |
| BGG-06 | Each app's usage is shown under "Usage" on the applications page. | https://boardgamegeek.com/using_the_xml_api | 2026-10-11 | Paraphrase. | likely |

### 1.2 License terms and the commercial license

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| BGG-10 | The XML API Terms of Use grant a license to reproduce and display the data only for non-commercial purposes. | https://boardgamegeek.com/wiki/page/XML_API_Terms_of_Use | 2026-10-11 | "solely for strictly non-commercial purposes" | likely |
| BGG-11 | Any commercial use needs a separate commercial license. BGG treats an app as commercial if the organization is for-profit, raises money in any way, shows ads, or gives a benefit for payment. Taking payments for features or supporting a commercial enterprise also counts. Our eBay affiliate revenue makes us commercial. | https://boardgamegeek.com/using_the_xml_api and https://boardgamegeek.com/wiki/page/BGG_XML_API_Commercial_Use | 2026-10-11 | "You need a commercial license if you want to use our API data for any commercial purpose." | likely |
| BGG-12 | Commercial licenses are priced case by case. Typical offers: free until 100 paying users for apps paid by users; free until 1,000 users for apps paid only by ads; apps monetized through sales (for example online game stores) usually need a paid license immediately. Affiliate commission is not named, so our fee is unknown. | https://boardgamegeek.com/using_the_xml_api and https://boardgamegeek.com/wiki/page/BGG_XML_API_Commercial_Use | 2026-10-11 | "Costs for commercial licenses, when applicable, are currently determined on a case-by-case basis." | likely |
| BGG-13 | BGG may decline any app that, in its judgment, competes with any part of its business or harms it. The commercial use page asks whether the app competes with BGG's business and how much traffic it generates, and says BGG may not offer a commercial license at all to a competing app. | https://boardgamegeek.com/using_the_xml_api and https://boardgamegeek.com/wiki/page/BGG_XML_API_Commercial_Use | 2026-10-11 | "competes with any part of BGG's business, or which harms us in any way" | likely |
| BGG-14 | BGG runs its own marketplace (GeekMarket) where users list games for sale, and BGG charges sellers a fee. | https://boardgamegeek.com/wiki/page/BGG_Marketplace and https://boardgamegeek.com/wiki/page/Marketplace_Seller_Guide | 2026-10-11 | Paraphrase: sellers list on BGG and pay an advertising fee on the sale price. Fee level not relevant to us. | likely |
| BGG-15 | You may not modify retrieved data. Usage must not interfere with BGG's servers, and BGG may monitor usage. BGG may end the license at any time for any reason, and may change the terms by posting them on the page. | https://boardgamegeek.com/wiki/page/XML_API_Terms_of_Use | 2026-10-11 | "BGG shall have the right to terminate this license" | likely |
| BGG-16 | Using the API or site data to train AI or LLM systems is strictly prohibited. | https://boardgamegeek.com/wiki/page/XML_API_Terms_of_Use | 2026-10-11 | Paraphrase: AI and LLM training is "strictly prohibited". | likely |
| BGG-17 | The XML API terms do not cover BGG's JSON API. BGG says using private endpoints outside normal browsing can violate its terms. Use XML API2 only. | https://boardgamegeek.com/wiki/page/BGG_JSON_API | 2026-10-11 | "XML_API_Terms_of_Use does NOT cover this API" | likely |

### 1.3 Rate limits, caching, and response codes

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| BGG-20 | BGG publishes no rate limit. It asks that requests come from your servers, that results be cached, and that you keep requests to a minimum. | https://boardgamegeek.com/using_the_xml_api | 2026-10-11 | "We are still determining exact usage limits for the XML API." | likely |
| BGG-21 | The API2 wiki says requests sent too often get 500 or 503 responses, and that a 5-second wait between requests seems to suffice. The wiki text is several years old. | https://boardgamegeek.com/wiki/page/BGG_XML_API2 | 2026-10-11 | "Currently, a 5-second wait between requests seems to suffice." | likely |
| BGG-22 | Developers report HTTP 429 even with tokens and even at 5-second spacing, and report that 429 responses carry no Retry-After header. | Forum: https://boardgamegeek.com/thread/3604601, https://boardgamegeek.com/thread/2065587, https://boardgamegeek.com/thread/3049077 | 2026-10-11 | Forum reports only. | unverified |
| BGG-23 | HTTP 202 is documented for collection requests: the request is queued, and the client retries with a delay until it gets a non-202 response. 202 is not documented for search or thing. | https://boardgamegeek.com/wiki/page/BGG_XML_API2 | 2026-10-11 | Paraphrase: a 202 means the request is queued and pending processing. | likely for collection; unverified for search and thing |
| BGG-24 | No clause found that sets a minimum or maximum cache time. The guide asks for server-side caching, so the brief's 7-day minimum fits. | https://boardgamegeek.com/using_the_xml_api and https://boardgamegeek.com/wiki/page/XML_API_Terms_of_Use | 2026-10-11 | Absence of a clause in what I could read. The full terms text was not readable. | unverified |

**Proposed queue setting [ASSUMPTION]:** one request every 5 seconds, configurable, with up to 20 ids per thing request. On 429, 500, or 503, back off exponentially with jitter. On 202, retry with backoff. This replaces the brief's 2-second figure, which has no official source. At 5 seconds the queue can make at most 17,280 requests a day, so cold lookups wait in line under load (PRD risk R6).

### 1.4 Endpoints we need

Base URL: `https://boardgamegeek.com/xmlapi2/` (BGG-30).

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| BGG-30 | Base URL is https://boardgamegeek.com/xmlapi2/ | https://boardgamegeek.com/wiki/page/BGG_XML_API2 | 2026-10-11 | Paraphrase. | likely |
| BGG-31 | Search: `GET /xmlapi2/search?query=<text>&type=<types>&exact=1`. `type` is a comma-separated list from: rpgitem, videogame, boardgame, boardgameaccessory, boardgameexpansion, boardgamedesigner. `exact=1` limits results to exact name matches. | https://boardgamegeek.com/wiki/page/BGG_XML_API2 | 2026-10-11 | "Limit results to items that match the SEARCH_QUERY exactly" | likely |
| BGG-32 | Known quirks: `type=boardgame` also returns expansions, and exact search sometimes returns odd matches. | Forum: https://boardgamegeek.com/thread/1583046, https://boardgamegeek.com/thread/3601830 | 2026-10-11 | Forum reports only. | unverified |
| BGG-33 | Thing: `GET /xmlapi2/thing?id=<comma-separated ids>&type=<types>&stats=1`. At most 20 ids per request. | https://boardgamegeek.com/wiki/page/BGG_XML_API2 and BGG thread https://boardgamegeek.com/thread/3336313 | 2026-10-11 | Paraphrase: the id parameter takes a comma-delimited list, maximum 20. | likely |
| BGG-34 | Thing flags: `versions=1`, `videos=1`, `stats=1` (ranking and rating stats), `marketplace=1`, `comments=1`, `ratingcomments=1` (not together with comments), `page`, `pagesize` (10 to 100). `historical`, `from`, and `to` are not supported. | https://boardgamegeek.com/wiki/page/BGG_XML_API2 | 2026-10-11 | "stats=1 Returns ranking and rating stats for the item." | likely |

Response field names (name, yearpublished, minplayers, and so on) were not captured. The backend developer must record real responses as fixtures once the token exists and document the fields from those, not from memory.

### 1.5 Attribution and images

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| BGG-40 | Credit BoardGameGeek by name as the source of the data in all uses. | https://boardgamegeek.com/wiki/page/XML_API_Terms_of_Use | 2026-10-11 | "In all uses, you shall credit BoardGameGeek by name as the source of the data." | likely |
| BGG-41 | Public-facing uses must show the "Powered by BGG" logo, linked back to BoardGameGeek, at a size where the logo text is easily legible. Any of the official logo files may be used. The logo download page itself was not readable. | https://boardgamegeek.com/wiki/page/XML_API_Terms_of_Use and https://boardgamegeek.com/using_the_xml_api | 2026-10-11 | Paraphrase: logo "displayed at a size where the text is easily legible". | likely |
| BGG-42 | In 2018 BGG staff announced image system changes so that externally linked images would eventually stop working, and asked developers not to hotlink. A later developer report says API image links returned 403 when loaded from an app. Rights to cover images returned by the API are not addressed in anything I could read. | Staff announcement https://boardgamegeek.com/thread/1950503; report https://boardgamegeek.com/thread/1771107 | 2026-10-11 | Forum, staff announcement. Current policy not confirmed. | unverified |

### 1.6 Draft license application text

For the user to review and send through https://boardgamegeek.com/applications. Fill in the bracketed items. Everything here must stay true; change it if the product changes.

> **App name:** [name, PRD Q1]. **Publisher:** [you or your company, PRD Q6]. **Platforms:** iOS and Android, US only. **License type requested:** Commercial.
>
> **What the app does.** [Name] helps board game collectors catalog their games. A user scans a game box barcode or searches by title to identify a game, then files it on their phone as Owned, Wanted, or Evaluating, with notes such as condition and purchase price. The collection stays on the user's phone. There are no user accounts, and we do not collect personal data.
>
> **How we use the BGG XML API.** Only our server calls the API, using our token. We use `search` (to find games by title) and `thing` (for game details such as name, year, player count, playing time, and the BGG id). We cache results on our server for at least 7 days, send requests through a single queue with at least 5 seconds between requests, batch thing ids, and back off on errors. The phone never calls BGG directly. We do not modify BGG data, do not use BGG user data or collections, do not use the JSON API, and do not use BGG data to train AI models.
>
> **Attribution.** Every screen that shows BGG data credits BoardGameGeek by name and shows the "Powered by BGG" logo, linked to the game's BGG page, at a legible size.
>
> **How the app makes money.** The app is free, has no ads, and has no paid features. For each game it shows current used-market asking prices from eBay US listings (through eBay's official API) and a "View on eBay" button. Those links carry an eBay Partner Network affiliate tag, and eBay pays us a commission if the user buys. That commission is our only revenue. We do not sell anything ourselves, take payments, or host listings.
>
> **Expected volume.** [ASSUMPTION: fewer than N requests per day at launch; give the real estimate from the snapshot and caching design.]
>
> **Questions for you.** (1) May we show the cover image or thumbnail URL that the API returns? If yes, should the app load it from your image host, or should our server cache it? (2) We know BGG runs GeekMarket. We are open to conditions you set, such as [OPTIONAL, user decides: a link to the game's BGG page or marketplace listings on our game screen].

### 1.7 Risk note: competition with BGG

BGG says it may decline any app that competes with any part of its business (BGG-13), and it runs GeekMarket (BGG-14). Our app shows used-market prices from eBay and earns eBay commission, which BGG could see as steering buyers away from GeekMarket. The published free tiers do not cover affiliate revenue (BGG-12), so even approval may come with a fee. BGG can also end any license at any time (BGG-15). Without BGG data the app cannot identify or describe games, and no fallback has been researched. This is the single largest risk to the project.

## 2. eBay

### 2.1 Developer Program and production access

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| EBAY-01 | Buy APIs in production are meant for eBay partners. Acceptance depends on the business model, and approval is not guaranteed. | https://developer.ebay.com/api-docs/buy/static/buy-requirements.html | 2026-10-11 | "The use of eBay's Buy APIs in production is intended for eBay partners only." | confirmed |
| EBAY-02 | The Buy API overview marks Deal, Feed (beta), Offer, and Order as Limited Release. Browse has no Limited Release badge. | https://developer.ebay.com/api-docs/buy/static/buy-overview.html | 2026-10-11 | "Many of the Buy APIs are a Limited release available only to select developers approved by business units." | confirmed |
| EBAY-03 | EPN's developer questionnaire page says the Browse API does not require additional approval. | https://partnernetwork.ebay.com/page/developer-questionnaire | 2026-10-11 | Paraphrase: Browse, EPN Reporting, Finding, and Shopping APIs do not require additional approval. | likely |
| EBAY-04 | Affiliate integrations must be EPN members. The Application Growth Check is mandatory before production access to restricted Buy APIs. | https://developer.ebay.com/develop/get-started/get-started-on-a-buying-application | 2026-10-11 | "intended for certain approved eBay partners based on their application" | confirmed |
| EBAY-05 | The display rules on the Buy APIs Requirements page (show the eBay logo, link to the eBay User Agreement, fixed-price items only, no re-sorting, privacy policy link in the footer) apply to guest checkout integrations, not to browse-only apps. | https://developer.ebay.com/api-docs/buy/static/buy-requirements.html | 2026-10-11 | "The following user experience requirements apply to all guest checkouts, except where noted." | confirmed |

Reading: for a browse-only affiliate app, Browse production access is likely available with a normal production keyset (EBAY-02, EBAY-03). Confirm when the keyset is created: the developer portal should list Browse with a daily limit.

### 2.2 Marketplace account deletion compliance

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| EBAY-10 | Every developer must subscribe to marketplace account deletion notifications, or opt out, before the first production API call. Opting out is allowed only for apps that persist no eBay data. Non-compliance can end API access. | https://developer.ebay.com/marketplace-account-deletion | 2026-10-11 | "For any developer application that is not persisting any eBay data" | confirmed |
| EBAY-11 | The endpoint must use HTTPS (no localhost or internal IP) and support GET and POST. On a GET with a challenge code, reply 200 with JSON field `challengeResponse`, a SHA-256 hash of challenge code, verification token, and endpoint URL, in that order. Acknowledge each POST notification immediately with 200, 201, 202, or 204. The verification token is 32 to 80 characters: letters, digits, underscore, hyphen. After 24 hours of failures eBay marks the URL down; you then have 30 days to fix it. | https://developer.ebay.com/marketplace-account-deletion | 2026-10-11 | "The three parameters must be hashed in the following order or the verification will fail." | confirmed |

Reading: we will cache listings (which include seller usernames) and store derived statistics, so we should not claim the opt-out. The backend needs this endpoint before the first production eBay call. Because we store no eBay user data, handling a notification means acknowledging it and logging nothing personal.

### 2.3 API License Agreement: storing and showing eBay content

The current agreement page (https://developer.ebay.com/join/api-license-agreement, which redirects to https://developer.ebay.com/products/license) blocked the fetcher. The rows below come from search results restricted to developer.ebay.com, plus the 2017 and 2018 PDF versions. The indexed copy may predate the 2025-06-24 update (EBAY-25).

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| EBAY-20 | Displayed listing information may be at most 6 hours older than on eBay. Other eBay content may be at most 24 hours older. If a displayed listing is not as current as on eBay, the app must say how much older it is. | https://developer.ebay.com/join/api-license-agreement (section "Age of Displayed eBay Content"); same clause in https://developer.ebay.com/cms/files/api_license_2018-10-26.pdf | 2026-10-11 | "Displayed item listing information may not be more than six (6) hours older than information displayed on the eBay Site" | likely |
| EBAY-21 | You may make limited intermediate copies of eBay content only as needed for a permitted activity, and must delete them when no longer needed. | https://developer.ebay.com/join/api-license-agreement | 2026-10-11 | "All intermediate copies must be deleted when they are no longer required for the purpose for which they were created" | likely |
| EBAY-22 | "eBay Content" is broad: all information, data, content, and images retrieved from eBay. It excludes information you obtain independently of eBay. | https://developer.ebay.com/cms/files/api_license_2018-10-26.pdf (2018 version) | 2026-10-11 | "eBay Content does not include information that you obtain independent of eBay." | likely |
| EBAY-23 | You need eBay's express prior written permission to use or display eBay content in any way that enables derivation of, among other things: site-wide statistics, take-up rates for enhanced listings, performance statistics, average selling price or gross merchandise sold for any eBay category, aggregated seller or buyer data, conversion or success rates, and reserve auction information. I could not read the full current list. | https://developer.ebay.com/join/api-license-agreement; older numbering (3.1.4) quoted in eBay forum https://forums.developer.ebay.com/questions/6578/average-price.html | 2026-10-11 | "you must have eBay's express prior written permission to use or display eBay Content in any way that enables derivation of" | likely |
| EBAY-24 | "Restricted APIs" (APIs exposing market trends, pricing strategies, sales volumes, user behavior, or generated content) go only to select developers. Their data may not be fed to non-eBay AI, shared with or sold to third parties, or redistributed (raw or aggregated) by API or bulk download. Building pricing tools from Restricted API data needs eBay's written consent and gives eBay a broad license to those tools. | https://developer.ebay.com/join/api-license-agreement | 2026-10-11 | "With respect to Restricted APIs, Developer may not: Ingest or otherwise incorporate information from Restricted APIs" | likely |
| EBAY-25 | eBay posted an updated API License Agreement on 2025-06-24, adding restrictions on Restricted APIs and AI content. | https://developer.ebay.com/updates/newsletter/q2_2025 | 2026-10-11 | Paraphrase: updated agreement with important restrictions on Restricted APIs and AI content. | likely |
| EBAY-26 | After termination, destroy all copies of eBay content and personal information within 10 days and certify it on request. eBay may audit how eBay data is stored, used, and handled. | https://developer.ebay.com/join/api-license-agreement | 2026-10-11 | Paraphrase. | likely |

### 2.4 What the terms allow and forbid for our plan

Our plan: show live listings, and store daily aggregated statistics (median, low, high, count) per game for a history chart and a collection total.

**Allowed (based on EBAY-20, EBAY-21):**
- Calling Browse with an application token and showing listings (title, price, condition, image, link) to users.
- Caching Browse responses on the server for at most 6 hours to save calls, then deleting them.
- Computing median, low, high, and count from listings fetched within the last 6 hours and showing them with their age.
- Showing the data age on every listing and price. The PRD already requires this.

**Unclear, needs eBay's written answer (section 2.12):**
- Keeping daily statistics derived from listings for 90 days or more and showing them as a history chart. For: they are our own numbers about one product's asking prices, and no clause I could read names that. Against: "other eBay Content" must be within 24 hours of eBay (EBAY-20), copies must be deleted when no longer needed (EBAY-21), and the derived-aggregates list needs permission for several kinds of statistics (EBAY-23). I could not read the full current list.
- Showing a stored statistic older than 24 hours, including offline (PRD section 6 rule 6 and section 8.2).
- The collection total value, if it uses stored statistics older than 24 hours.

**Forbidden without eBay's written permission:**
- Showing listing information more than 6 hours old (EBAY-20). Offline, cached listings older than 6 hours must be hidden, not shown with a "last updated" label.
- Deriving site-wide statistics, average selling price for an eBay category, seller performance data, aggregated buyer or seller data, or conversion rates (EBAY-23).
- Using Marketplace Insights data for a pricing tool, feeding it to non-eBay AI, or redistributing it (EBAY-24). This matters if eBay ever grants access.
- Keeping eBay content more than 10 days after the agreement ends (EBAY-26).

### 2.5 OAuth client credentials

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| EBAY-30 | All Browse methods require an application access token, obtained with the client credentials grant. | https://developer.ebay.com/develop/api/buy/browse_api/item_summary/search | 2026-10-11 | "All methods in the Browse API require an Application access token" | confirmed |
| EBAY-31 | Token request: `POST https://api.ebay.com/identity/v1/oauth2/token` (sandbox: api.sandbox.ebay.com). Header `Authorization: Basic <Base64 of client_id:client_secret>`. Body: `grant_type=client_credentials` and `scope=<URL-encoded, space-separated scopes>`. | https://developer.ebay.com/api-docs/static/oauth-client-credentials-grant.html | 2026-10-11 | Paraphrase from search results; the page blocked the fetcher. | likely |
| EBAY-32 | The response has access_token, expires_in (7,200 seconds, so 2 hours), and token_type. eBay recommends keeping the token in memory and reusing it until it expires. | https://developer.ebay.com/api-docs/static/oauth-client-credentials-grant.html and https://developer.ebay.com/api-docs/static/oauth-best-practices.html | 2026-10-11 | Paraphrase. | likely |
| EBAY-33 | The scope for item_summary search is `https://api.ebay.com/oauth/api_scope`. | https://developer.ebay.com/develop/api/spec/browse_api.json (OpenAPI spec) | 2026-10-11 | Security scheme api_auth with that scope. | confirmed |
| EBAY-34 | Minting client credentials tokens is rate limited; the search result said 1,000 per day per application. With 2-hour tokens we need about 12 a day. | https://developer.ebay.com/api-docs/static/oauth-rate-limits.html | 2026-10-11 | Paraphrase from search; page blocked. | likely |

### 2.6 Browse API item_summary search

Source of record: eBay's OpenAPI spec for Browse, https://developer.ebay.com/develop/api/spec/browse_api.json (info.version v1.20.4), read directly on 2026-10-11, plus the filters page.

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| EBAY-40 | Endpoint: `GET https://api.ebay.com/buy/browse/v1/item_summary/search`. Sandbox host: api.sandbox.ebay.com. | browse_api.json | 2026-10-11 | Servers "https://api.ebay.com{basePath}", basePath "/buy/browse/v1". | confirmed |
| EBAY-41 | `q`: keywords, at most 100 characters; longer strings are truncated. | browse_api.json | 2026-10-11 | "Maximum length: 100 characters." | confirmed |
| EBAY-42 | `gtin`: search by GTIN (UPC, EAN, or ISBN). Do not combine gtin or epid with `q`. A gtin can be combined with category_ids. | browse_api.json | 2026-10-11 | "neither an epid or gtin value should be combined with a keywords search through the q parameter" | confirmed |
| EBAY-43 | `category_ids`: one category id per request. A top-level (L1) category also requires `q`. | browse_api.json | 2026-10-11 | "Currently, you can pass in only one category ID per request." | confirmed |
| EBAY-44 | `limit` 1 to 200, default 50. `offset` 0 to 9,999, default 0. A search returns at most 10,000 items. Offset must be zero or a multiple of limit (error 12515). | browse_api.json; offset rule from https://developer.ebay.com/api-docs/buy/browse/release-notes-archive.html | 2026-10-11 | "This method can return a maximum of 10,000 items." | confirmed (offset rule: likely) |
| EBAY-45 | By default, only listings that offer FIXED_PRICE (Buy It Now) are returned. Auctions need the buyingOptions filter. | browse_api.json | 2026-10-11 | "Only listings where FIXED_PRICE (Buy It Now) is a buying option are returned by default." | confirmed |
| EBAY-46 | `sort` defaults to Best Match. `fieldgroups` defaults to MATCHING_ITEMS. `auto_correct=KEYWORD` enables keyword autocorrection. | browse_api.json | 2026-10-11 | "If no sort parameter is submitted, the result set is sorted by "Best Match"." | confirmed |
| EBAY-47 | Condition filters: `conditions` takes NEW, USED, or UNSPECIFIED (case sensitive) and returns items in those broad groups. `conditionIds` takes specific ids. Condition values can vary by category. The exact used-condition ids for board games are UNVERIFIED. | https://developer.ebay.com/api-docs/buy/static/ref-buy-browse-filters.html | 2026-10-11 | "Item condition values can vary by category." | confirmed |
| EBAY-48 | Other filters: `price:[min..max]` (must be used with `priceCurrency:USD`), `itemLocationCountry:US`, `deliveryCountry:US`, `excludeCategoryIds`. | https://developer.ebay.com/api-docs/buy/static/ref-buy-browse-filters.html | 2026-10-11 | "This filter must be used with the priceCurrency filter." | confirmed |
| EBAY-49 | `X-EBAY-C-MARKETPLACE-ID` defaults to EBAY_US and is required only outside the US. Send it anyway for clarity [ASSUMPTION]. | browse_api.json | 2026-10-11 | "It is required for all marketplaces outside of the US." | confirmed |
| EBAY-50 | `X-EBAY-C-ENDUSERCTX` carries `affiliateCampaignId` (the 10-digit EPN campaign id) and optionally `affiliateReferenceId` (up to 256 characters). It can also carry `contextualLocation` (URL-encoded country and zip) for shipping estimates. | https://developer.ebay.com/api-docs/buy/static/api-browse.html and browse_api.json | 2026-10-11 | "This header is required to support revenue sharing for eBay Partner Network." | confirmed |
| EBAY-51 | `itemAffiliateWebUrl` is the View Item URL with the affiliate tracking id. It is returned only when the marketplace is part of EPN and the request sends affiliate details in X-EBAY-C-ENDUSERCTX. `itemWebUrl` is the plain View Item URL. | browse_api.json (ItemSummary schema) | 2026-10-11 | "The URL to the View Item page of the item which includes the affiliate tracking ID." | confirmed |
| EBAY-52 | Partners must use itemAffiliateWebUrl to send buyers to the listing to earn commission. | https://developer.ebay.com/api-docs/buy/browse/types/gct:ItemSummary | 2026-10-11 | "Partners must use this URL to forward buyers to the listing on the eBay marketplace." | likely |
| EBAY-53 | `price` is the item cost only, without shipping or discounts. For calculated shipping, `shippingOptions` is returned only if X-EBAY-C-ENDUSERCTX is sent. | browse_api.json | 2026-10-11 | "This amount does not include any adjustments such as discounts or shipping costs." | confirmed |
| EBAY-54 | `total` is only an indicator and should not drive pagination. `next` appears only when another page exists. | browse_api.json | 2026-10-11 | "The total number of items that match the input criteria." | confirmed |

Example header and filter syntax, from the official pages (placeholders in angle brackets):

```
X-EBAY-C-ENDUSERCTX: affiliateCampaignId=<campaign id>,affiliateReferenceId=<reference>
filter=conditions:{USED}
filter=price:[10..50],priceCurrency:USD
filter=conditionIds:{1000|1500}
```

### 2.7 Board games category

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| EBAY-60 | On ebay.com, "Board & Traditional Games" is category 2550. Its children include "Contemporary Manufacture" (180349) and "Vintage Manufacture" (19100). | eBay category pages: https://www.ebay.com/b/Board-Traditional-Games/2550/bn_1642741, https://www.ebay.com/b/Contemporary-Manufacture-Board-Traditional-Games/180349/bn_1642048, https://www.ebay.com/b/Vintage-Manufacture-Board-Traditional-Games/19100/bn_1642569 | 2026-10-11 | Ids read from official eBay page URLs and breadcrumbs through search; pages blocked the fetcher. | likely |
| EBAY-61 | The Taxonomy API confirms ids: getDefaultCategoryTreeId returns 0 for EBAY_US; getCategorySubtree with a category_id returns that category and all descendants; leaf nodes have leafCategoryTreeNode true. | https://developer.ebay.com/api-docs/commerce/taxonomy/resources/category_tree/methods/getCategorySuggestions and https://developer.ebay.com/develop/guides/sell/listing-metadata-guide | 2026-10-11 | Paraphrase. | likely |

Action: the backend confirms 2550 and its children with the Taxonomy API and records the result here before M4 code relies on it. Whether a search on non-leaf 2550 includes its children is UNVERIFIED.

### 2.8 Call limits and the Application Growth Check

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| EBAY-70 | Browse default limit: 5,000 calls per day for all methods except getItems; getItems is also 5,000 per day. | https://developer.ebay.com/develop/get-started/api-call-limits | 2026-10-11 | "All methods except getItems: 5000 API calls per day" | likely |
| EBAY-71 | A 429 response means the daily limit is used up until the next reset. The reset time and time zone are UNVERIFIED. | eBay developer forum https://forums.developer.ebay.com/questions/13528/how-the-daily-api-call-limit-works.html | 2026-10-11 | Forum answer only. | unverified |
| EBAY-72 | Higher limits need the free Application Growth Check. eBay reviews a working, testable app for license compliance, current API versions, at most two retries for infrastructure errors, and efficient calls (only the data needed, no needless polling). | https://developer.ebay.com/grow/application-growth-check | 2026-10-11 | Paraphrase. | likely |
| EBAY-73 | EPN says the Growth Check (it calls it Compatible Application Check) allows up to 100,000 calls a day, and more needs the developer questionnaire. | https://partnernetwork.ebay.com/page/developer-questionnaire | 2026-10-11 | Paraphrase. | likely |
| EBAY-74 | Daily usage can be read with the Developer Analytics API getRateLimits method. | https://developer.ebay.com/support/kb-article?KBid=5196 | 2026-10-11 | Paraphrase. | likely |

Budget reading [ASSUMPTION]: one GTIN search per tracked game per day, a keyword search only when GTIN finds too little, and on-demand refreshes when the 6-hour cache expires. At 5,000 calls a day, the snapshot job can cover at most a few thousand games before we need a Growth Check (PRD Q17).

### 2.9 Attribution and eBay marks

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| EBAY-80 | An eBay support article says the eBay content logo is needed when eBay content appears on pages the general public can see. The article is old, and the current API logo usage requirements were not readable. | https://developer.ebay.com/support/kb-article?KBid=550 | 2026-10-11 | "If non-customers can see your pages that show content that comes from eBay then the logo needs to be displayed." | confirmed for the article; current rule unverified |
| EBAY-81 | Passing the Growth Check authorizes the "eBay Compatible Application" logo. | developer.ebay.com search result (Growth Check pages) | 2026-10-11 | Paraphrase. | likely |
| EBAY-82 | eBay logos must be used exactly as downloaded from EPN's Creative Gallery: no recoloring, cropping, or effects, and not inside a sentence. "eBay" in an app name needs EPN's written approval and descriptive use only ("Fee Calculator for eBay" is fine, "eBay Fee Calculator" is not). Domains and company names may not include eBay marks. | https://partnernetwork.ebay.com/legal and https://partnernetwork.ebay.com/solutions/common-missteps-to-avoid | 2026-10-11 | Paraphrase. | likely |

### 2.10 eBay Partner Network (EPN)

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| EBAY-90 | Promoting eBay through a mobile app needs EPN approval. The application asks for a direct app store link, whether eBay is integrated, whether the app offers incentives, whether it collects user data, and test access. The app must be integrated (or will be within a week) so EPN can test it. | https://partnernetwork.ebay.com/page/mobile-apps | 2026-10-11 | "Provide a direct link to the apps store where your app can be downloaded." | likely |
| EBAY-91 | EPN withholds all compensation for traffic sent through software applications it has not approved. | https://partnernetwork.ebay.com/legal (Network Agreement) | 2026-10-11 | Paraphrase from search results. | likely |
| EBAY-92 | Every partner must disclose the EPN relationship. For links in mobile apps the disclosure must be "above the fold", visible without scrolling, and close to the links. A link to a disclosure page, small print in a menu, or a disclosure only in Terms, Legal, or About pages is not enough. | https://partnernetwork.ebay.com/resources/affiliate-disclosure-faq | 2026-10-11 | Paraphrase: the disclosure statement itself must be in close proximity to the affiliate links. | likely |
| EBAY-93 | Approved disclosure phrases include "Ad", "Paid Ad", "Advertisement", "Sponsored by eBay", and "Paid Link". The FAQ's sample is "As an eBay Partner, I may be compensated if you make a purchase". Not approved: "Affiliate Link", "Buy Now", "Commissionable Link", "#affiliate". EPN's two lists disagree on some hashtags. | https://partnernetwork.ebay.com/resources/phrases-and-hashtags-approved-not-approved-for-use-in-affiliate-disclosure and the FAQ above | 2026-10-11 | Paraphrase. | likely |
| EBAY-94 | Prohibited: cookie stuffing, roundtripping, and bad-faith qualifying events. Cashback or other incentives need prior approval. Software must get affirmative consent to install and disclose its main functions. No sniping or auto-bid tools. EPN data may not be used to train machine learning systems. | https://partnernetwork.ebay.com/legal | 2026-10-11 | Paraphrase from search results. | likely |
| EBAY-95 | Promotional content must be clearly and prominently identified as advertising. | https://partnernetwork.ebay.com/legal | 2026-10-11 | Paraphrase. | likely |

Reading: EPN links inside a mobile app listing view are allowed once EPN approves the app (EBAY-90). The campaign id goes in X-EBAY-C-ENDUSERCTX (EBAY-50), and we open itemAffiliateWebUrl when present, else itemWebUrl (EBAY-51). The app must not reward users for tapping (EBAY-94).

### 2.11 Marketplace Insights (sold data)

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| EBAY-100 | Marketplace Insights is closed to new users. | https://developer.ebay.com/api-docs/buy/static/ref-marketplace-supported.html | 2026-10-11 | "Note: The Marketplace Insights API is restricted and not open to new users at this time." | confirmed |
| EBAY-101 | It is a Limited Release API that returns the sales history of items sold on eBay. | https://developer.ebay.com/develop/get-started/get-started-on-a-buying-application | 2026-10-11 | "Retrieve the sales history of items sold on eBay." | confirmed |
| EBAY-102 | EPN says Marketplace Insights, Order, and Offer access cannot be granted on request. | https://partnernetwork.ebay.com/page/developer-questionnaire | 2026-10-11 | Paraphrase: "cannot be granted upon request". | likely |
| EBAY-103 | How to apply: UNVERIFIED. No public application path found. I tried the developer.ebay.com Buy API pages, the EPN pages, and eBay developer forum threads (several unanswered requests for access). The only documented routes are the general Buy API process (EPN account, Buy API application, Growth Check) and the EPN developer questionnaire, which says this API cannot be granted on request. | See EBAY-04, EBAY-100, EBAY-102 | 2026-10-11 | None. | unverified |

If eBay ever grants access, Marketplace Insights is very likely a "Restricted API" under EBAY-24, which needs separate written consent before its data feeds a pricing tool.

### 2.12 Draft question for eBay Developer Support

For the user to send from the eBay developer account before M4 starts:

> We are building a free mobile app for US board game collectors and plan to apply to the eBay Partner Network. Our server calls the Browse API item_summary search for one product at a time (by GTIN, or by keywords in the board games category) and shows the current listings with "View on eBay" links using itemAffiliateWebUrl. We never show listing data more than 6 hours old, and we show its age.
>
> From each day's results we compute four numbers for that one product: the median, low, and high asking price and the number of listings. We would like to store those four numbers once a day per product, for up to [ASSUMPTION: 365] days, to show a price history chart and an estimated value of the user's own collection. We would not store the listings themselves beyond 6 hours, and we would not compute category-wide or site-wide statistics.
>
> Does the API License Agreement allow this? If it needs eBay's written permission, how do we request it?

## 3. GameUPC

### 3.1 Facts

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| GUPC-01 | The site describes a REST API for looking up BGG games by UPC, with demos. It publishes no terms of use, privacy policy, pricing, rate limits, or availability promise. | https://gameupc.com/ | 2026-10-11 | "The easily consumable REST API makes it quick to integrate into your app." | confirmed |
| GUPC-02 | The demo calls `https://api.gameupc.com/test/upc/{upc}` (search with `?search=<terms>`) and sends header `x-api-key` with the test key `test_test_test_test_test`. The response has `bgg_info_status` (values seen: `verified`, `choose_from_bgg_info_or_search`) and a `bgg_info` array whose entries include `id`, `confidence`, and `update_url`. Users vote by POSTing JSON with a `user_id` to `update_url`. | https://gameupc.com/demo.py | 2026-10-11 | Paraphrase of the demo script; field names as written in the script. | confirmed |
| GUPC-03 | A barcode to BGG id mapping generally needs two uncontested votes to count as good. | https://gameupc.com/demo.py (code comment) | 2026-10-11 | Paraphrase of the comment. | confirmed |
| GUPC-04 | Contact is by email: the site says to email the site's name at grettir.org. | https://gameupc.com/ | 2026-10-11 | "To reach me, send email to the name of this site @grettir.org" | confirmed |
| GUPC-05 | In 2021 the operator declared the API a stable v1.0, promised to keep it up and freely available for 3 years, and offered production keys on request. That promise ran out around early 2024. | Operator's post https://boardgamegeek.com/thread/2579359 | 2026-10-11 | Forum post by the operator; lead only. | likely |
| GUPC-06 | The operator posted "Update on UPC to BGG lookups" around 2025. I could not read past its opening, so its new commitments are unknown. | https://boardgamegeek.com/thread/3519987 | 2026-10-11 | Not readable. | unverified |
| GUPC-07 | Production base URL, production key process, rate limits, commercial use terms, and uptime: UNVERIFIED. I tried gameupc.com, gameupc.com/demo.html, gameupc.com/demo.py, api.gameupc.com (HTTP 403), web search, and BGG threads. | n/a | 2026-10-11 | None. | unverified |
| GUPC-08 | GameUPC returns BGG ids that point to BGG data. Anything we show from BGG still falls under BGG's terms. | Inference from GUPC-02 and BGG-10 | 2026-10-11 | Inference. | unverified |

### 3.2 What happens if GameUPC is unavailable

Nothing official is documented. Our own plan: the backend treats a GameUPC timeout or error as "no match" and the app offers title search (BGG) and manual barcode entry. Confirmed matches cached on the device keep working offline. If the user approves sharing confirmed matches with our backend (PRD Q9), our own barcode table could reduce dependence on GameUPC. If we ever send votes to GameUPC, we must not send any device or user identifier as `user_id` (PRD section 8.5).

### 3.3 Draft email to the GameUPC operator

> Hello. We are building a free iOS and Android app for board game collectors (no ads; revenue comes from eBay Partner Network commission on "View on eBay" links). We would like to use the GameUPC API from our server to turn scanned UPCs into BGG ids, caching results so we call you as little as possible.
>
> Could you tell us: (1) whether commercial use like ours is allowed, and on what terms; (2) how to get a production key and the production base URL; (3) any rate limits; (4) your plans for keeping the service running; and (5) how you would like to be credited. Would you also like us to send back user-confirmed matches (with no user identifiers) to help the database?

## 4. Apple App Store

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| APPLE-01 | `NSCameraUsageDescription` is required if the app uses APIs that access the camera. Its text tells people why the app wants the camera. | https://developer.apple.com/documentation/bundleresources/information-property-list/nscamerausagedescription | 2026-10-11 | "This key is required if your app uses APIs that access the device's camera." | confirmed |
| APPLE-02 | Guideline 5.1.1(i): every app needs a privacy policy link in App Store Connect and inside the app. The policy must say what data is collected, how, and all uses; confirm third parties give equal protection; and explain retention, deletion, and how to revoke consent. | https://developer.apple.com/app-store/review/guidelines/ | 2026-10-11 | "All apps must include a link to their privacy policy in the App Store Connect metadata field and within the app in an easily accessible manner." | confirmed |
| APPLE-03 | Guideline 5.1.1(ii): get consent for data collection, and write purpose strings that clearly and completely describe the use. | https://developer.apple.com/app-store/review/guidelines/ | 2026-10-11 | "Ensure your purpose strings clearly and completely describe your use of the data." | confirmed |
| APPLE-04 | Privacy details (the "privacy label") are required for new apps and updates, including third-party SDK practices. "Collect" means sending data off the device and keeping it longer than needed to serve the request in real time. Data processed only on the device is not collected. Some data is optional to disclose only if it meets all listed criteria. | https://developer.apple.com/app-store/app-privacy-details/ | 2026-10-11 | "Data that is processed only on device is not "collected" and does not need to be disclosed in your answers." | confirmed |
| APPLE-05 | App Store Connect requires a public Privacy Policy URL. A Privacy Choices URL is optional. | https://developer.apple.com/app-store/app-privacy-details/ | 2026-10-11 | "Privacy Policy (Required): The URL to your publicly accessible privacy policy." | confirmed |
| APPLE-06 | Guideline 3.1.3(e): apps that let people buy physical goods used outside the app must use payment methods other than in-app purchase. We take no payments; linking out to eBay listings is consistent with this. | https://developer.apple.com/app-store/review/guidelines/ | 2026-10-11 | "you must use purchase methods other than in-app purchase to collect those payments" | confirmed (the "consistent" part is my reading) |
| APPLE-07 | Guideline 4.2: apps need features and utility beyond a repackaged website. 4.2.2: apart from catalogs, apps shouldn't be mainly marketing, ads, content aggregators, or a collection of links. Our collection features matter for review. | https://developer.apple.com/app-store/review/guidelines/ | 2026-10-11 | "Other than catalogs, apps shouldn't primarily be marketing materials, advertisements, web clippings, content aggregators, or a collection of links." | confirmed |
| APPLE-08 | Guideline 5.2.2: if an app uses, monetizes, or displays content from a third-party service, it must be specifically permitted under that service's terms, and authorization must be provided on request. We need the BGG license and EPN approval in hand. | https://developer.apple.com/app-store/review/guidelines/ | 2026-10-11 | "Authorization must be provided upon request." | confirmed |
| APPLE-09 | Guideline 2.3.1(a): misleading marketing, including promoting a false price, can get an app removed. Labeling asking prices clearly supports this. | https://developer.apple.com/app-store/review/guidelines/ | 2026-10-11 | "promoting a false price, whether within or outside of the App Store" | confirmed |
| APPLE-10 | No guideline addresses showing third-party prices or affiliate links. I read the full guidelines page (last updated June 8, 2026). | https://developer.apple.com/app-store/review/guidelines/ | 2026-10-11 | "Last Updated: [June 8, 2026]" | confirmed |
| APPLE-11 | App Attest (`DCAppAttestService`) is available from iOS 14.0. Check `isSupported` and skip the service gracefully if unsupported. Generate one key per user per device, attest it with a one-time server challenge of at least 16 bytes, and verify on the server. Keys survive updates but not reinstall, device migration, or restore from backup. There is no limit on assertions per key. | https://developer.apple.com/documentation/devicecheck/dcappattestservice and https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity | 2026-10-11 | "If the user's app doesn't pass the compatibility check, gracefully bypass the service." | confirmed |
| APPLE-12 | App Attest limits: attestation is typically once per user per device; keep attestKey calls under about 100 per second across all installs (the threshold changes dynamically); ramp no more than 10 million users a day. Development uses a sandbox; after distribution (TestFlight or App Store) the app always uses production. Entitlement: `com.apple.developer.devicecheck.appattest-environment`. | https://developer.apple.com/documentation/devicecheck/preparing-to-use-the-app-attest-service | 2026-10-11 | "we generally recommend that your apps call this method fewer than 100 request per second across all installations of your apps" | confirmed |
| APPLE-13 | Server verification checks the certificate chain against Apple's App Attest root CA, the nonce, the key id, the App ID hash, a counter of 0, and the aaguid (appattestdevelop or appattest). The server then stores the public key and receipt. For each assertion it checks the signature, that the counter increased, and the challenge, then stores the new counter. So the server must keep per-install state. | https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server | 2026-10-11 | "Store counter to use in step 5 when verifying the next assertion." | confirmed |
| APPLE-14 | The attestation receipt can be used server to server to get a fraud risk metric; details are in "Assessing fraud risk". | https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server | 2026-10-11 | Paraphrase. | confirmed |
| APPLE-15 | Apps and listed third-party SDKs record collected data types and "required reason" API use in a privacy manifest, `PrivacyInfo.xcprivacy`. Apple announced upload enforcement for missing required reasons from spring 2024. | https://developer.apple.com/documentation/bundleresources/privacy-manifest-files and Apple news https://developer.apple.com/news/?id=pvszzano | 2026-10-11 | "The required reasons APIs your app or third-party SDK uses." | confirmed (manifest); likely (enforcement) |

Proposed camera purpose string for UX review [ASSUMPTION]: "Scan a game's barcode to look it up. If you add photos of your games, they stay on this device." Adjust if photos are picked from the library instead of taken with the camera.

## 5. Google Play

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| GPLAY-01 | `CAMERA` is a dangerous (runtime) permission. Declaring it implies camera hardware features; declare `<uses-feature>` explicitly to control store filtering. | https://developer.android.com/reference/android/Manifest.permission#CAMERA and https://developer.android.com/guide/topics/manifest/uses-feature-element | 2026-10-11 | Paraphrase: protection level dangerous; required to access the camera device. | likely |
| GPLAY-02 | Request only permissions needed for current features promoted in the listing, and request them in context, one step at a time. | https://support.google.com/googleplay/android-developer/answer/9888170 | 2026-10-11 | "necessary to implement current features or services in your app that are promoted in your Google Play listing" | confirmed |
| GPLAY-03 | All apps must post a privacy policy link in Play Console and in the app. It must be at an active, public, non-geofenced URL and not a PDF. It must include developer information and a privacy contact, the data accessed, collected, used, and shared and with whom, secure handling, retention and deletion, and a clear "privacy policy" title. | https://support.google.com/googleplay/android-developer/answer/10144311 | 2026-10-11 | "All apps must post a privacy policy link in the designated field within Play Console" | confirmed |
| GPLAY-04 | Camera data is personal and sensitive user data. Use a runtime permission request before accessing it. | https://support.google.com/googleplay/android-developer/answer/10144311 | 2026-10-11 | "Use a runtime permissions request whenever available, prior to accessing data gated by Android permissions." | confirmed |
| GPLAY-05 | Where prominent disclosure is required, it must be inside the app (not only in the privacy policy) and followed by a consent step that needs an affirmative action. | https://support.google.com/googleplay/android-developer/answer/10144311 | 2026-10-11 | "Cannot only be placed in a privacy policy or terms of service." | confirmed (whether it applies to us is unverified) |
| GPLAY-06 | Every published app must complete the Data safety form, even one that collects no user data. "Collect" means sending data off the device. Ephemeral processing (in memory only, no longer than needed for the request) and on-device processing are exempt from the store label. Transfers to a service provider acting on our instructions are not "sharing". Relevant data types: "In-app search history", "Crash logs", "Diagnostics", "Device or other IDs". | https://support.google.com/googleplay/android-developer/answer/10787469 | 2026-10-11 | "Even developers with apps that do not collect any user data must complete this form and provide a link to their privacy policy." | confirmed |
| GPLAY-07 | Play Integrity standard requests suit frequent checks (a few hundred ms, needs warm-up, Google mitigates replay). Classic requests take seconds and are for rare, high-value actions. Default quota: 10,000 total requests per day across all installs. Minimum listed: Android 6.0 (API 23). | https://developer.android.com/google/play/integrity/overview | 2026-10-11 | "By default, your app can make up to 10,000 total requests per day across all installs." | confirmed |
| GPLAY-08 | Setup: link a Google Cloud project in Play Console (Protected with Play). Two daily quotas of 10,000 each: token requests (classic plus standard preparations) and token decryptions. Increases need a form, the app must be on Google Play, and review can take up to a week. | https://developer.android.com/google/play/integrity/setup | 2026-10-11 | "Your app or SDK has a default daily limit of 10,000 total requests, tied to the associated Cloud Project Number." | confirmed |
| GPLAY-09 | Standard requests: each app instance can prepare the token provider at most 5 times a minute; `requestHash` is at most 500 bytes and should be a hash of the request; tokens are decrypted on Google's servers via `playintegrity.googleapis.com/v1/PACKAGE_NAME:decodeIntegrityToken` using a service account; decoding the same token twice clears its verdicts. | https://developer.android.com/google/play/integrity/standard | 2026-10-11 | "To obtain the device integrity verdicts, you must decrypt the integrity token on Google's servers." | confirmed |
| GPLAY-10 | Cost of Play Integrity: UNVERIFIED. No pricing found on developer.android.com or support.google.com. | n/a | 2026-10-11 | None. | unverified |
| GPLAY-11 | Google Play billing must not be used for physical goods. The rule against leading users to other payment methods applies "other than the conditions described in Section 3", which include physical goods. Linking out to eBay for physical goods is consistent with this. | https://support.google.com/googleplay/android-developer/answer/9858738 | 2026-10-11 | "for the purchase or rental of physical goods (such as groceries, clothing, housewares, electronics)" | confirmed (the "consistent" part is my reading) |
| GPLAY-12 | The "Contains ads" declaration covers ads through third-party ad SDKs and display, native, or banner ads. It is not meant to cover paid product placement. Affiliate links are not mentioned. | https://support.google.com/googleplay/android-developer/answer/9859455 (Ads section) | 2026-10-11 | "isn't meant to cover whether an app contains other kinds of commercial content, like paid product placement" | confirmed |
| GPLAY-13 | No Google Play policy found that specifically covers affiliate links or showing third-party prices. Searched support.google.com policy pages. | n/a | 2026-10-11 | None. | unverified |

## 6. Google ML Kit (PRD risk R7)

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| MLKIT-01 | The ML Kit terms incorporate and are subject to the Google APIs Terms of Service. | https://developers.google.com/ml-kit/terms | 2026-10-11 | "These terms incorporate and are subject to the Google APIs Terms of Service." | confirmed |
| MLKIT-02 | ML Kit does not send input data (camera images) or outputs to Google, but it does send API performance and usage metrics. | https://developers.google.com/ml-kit/terms | 2026-10-11 | "ML Kit does not send that data and the resultant outputs to Google servers." | confirmed |
| MLKIT-03 | Developers must tell users about Google's processing of ML Kit metrics data. | https://developers.google.com/ml-kit/terms | 2026-10-11 | "You are responsible for informing users of your app about Google's processing of ML Kit metrics data." | confirmed |
| MLKIT-04 | On Android, ML Kit collects device information, app package and version, performance metrics, and API configuration for diagnostics and usage analytics, encrypted in transit and not transferred to third parties. Per-installation identifiers are "not intended to uniquely identify a user or physical device". The developer decides the Data safety answers. | https://developers.google.com/ml-kit/android-data-disclosure | 2026-10-11 | "For the collected data listed on this page, ML Kit does not transfer this data to third-parties." | confirmed |
| MLKIT-05 | mobile_scanner (latest 7.4.2 on the check date) is licensed BSD-3-Clause. On Android it uses Google ML Kit barcode scanning, bundled by default. On iOS and macOS it uses AVFoundation and Apple Vision, not ML Kit. | https://pub.dev/packages/mobile_scanner | 2026-10-11 | "This package uses by default the bundled version of MLKit Barcode-scanning for Android." | confirmed |
| MLKIT-06 | mobile_scanner can switch Android to the unbundled ML Kit model, downloaded on first use through Google Play services, by setting `dev.steenbakker.mobile_scanner.useUnbundled=true` in android/gradle.properties. Bundled adds about 3 to 10 MB to the app; unbundled about 600 KB. Either way it is still ML Kit. | https://pub.dev/packages/mobile_scanner | 2026-10-11 | Paraphrase: the unbundled version is "downloaded on first use via Google Play Services". | confirmed |
| MLKIT-07 | mobile_scanner lists no non-ML-Kit engine for Android. ZXing is mentioned only for the web platform (zxing-wasm and legacy ZXing-js). Avoiding ML Kit on Android would mean a different scanning package, which is not researched here. | https://pub.dev/packages/mobile_scanner | 2026-10-11 | Paraphrase: ZXing backends are listed for web only. | confirmed |
| MLKIT-08 | ML Kit barcode scanning on Android supports UPC-A, UPC-E, EAN-13, and EAN-8 (13 formats in total) and requires Android API level 23 or higher, which fits our API 24 minimum. Google's page lists bundled at about 2.4 MB and unbundled at about 200 KB, which differs from the mobile_scanner page's estimates. | https://developers.google.com/ml-kit/vision/barcode-scanning/android | 2026-10-11 | "This API requires Android API level 23 or above." | confirmed |
| MLKIT-09 | Whether ML Kit is free of charge is not stated on the terms page. | https://developers.google.com/ml-kit/terms | 2026-10-11 | Not stated. | unverified |

Reading: using mobile_scanner as the brief specifies brings ML Kit into the Android app. ML Kit is under Google's terms, not MIT, BSD, or Apache 2.0, so CLAUDE.md rule 6 requires the user's approval (PRD Q4). If approved, the privacy policy must mention ML Kit metrics (MLKIT-03) and the Data safety answers must account for them (MLKIT-04). iOS is not affected (MLKIT-05).

## 7. Oracle Cloud Always Free

| Id | Fact | Source | Checked | Quote or paraphrase | Confidence |
|---|---|---|---|---|---|
| OCI-01 | AMD: up to two VM.Standard.E2.1.Micro instances, each 1/8 OCPU (can burst), 1 GB memory, up to 50 Mbps internet bandwidth. | https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm | 2026-10-11 | "Memory: 1 GB" | confirmed |
| OCI-02 | Arm (Ampere A1, VM.Standard.A1.Flex): the first 1,500 OCPU hours and 9,000 GB hours per month are free, equal to 2 OCPUs and 12 GB memory in total. Many older guides say 4 OCPUs and 24 GB; that is out of date. | https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm | 2026-10-11 | "For Always Free tenancies, this is equivalent to 2 OCPUs and 12 GB of memory." | confirmed |
| OCI-03 | Block storage: 200 GB total across boot and block volumes, plus five volume backups. Each instance gets a boot volume of about 47 to 50 GB (the page gives both numbers). | https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm | 2026-10-11 | "All tenancies receive a total of 200 GB of Block Volume storage, and five volume backups" | confirmed |
| OCI-04 | 10 TB of outbound data per month. | same | 2026-10-11 | "you get 10 TB per month of outbound data" | confirmed |
| OCI-05 | Always Free compute and block volumes must be created in the tenancy's home region. | same | 2026-10-11 | "You must create the Always Free compute instances in your home region." | confirmed |
| OCI-06 | "Out of host capacity" means a temporary lack of free shapes in the home region; try another availability domain or wait. | same | 2026-10-11 | Paraphrase. | confirmed |
| OCI-07 | Idle Always Free instances may be reclaimed. An instance is idle if, over 7 days, CPU utilization at the 95th percentile is under 20%, network utilization is under 20%, and memory utilization is under 20% (memory applies to A1 shapes only). | same | 2026-10-11 | "Idle Always Free compute instances may be reclaimed by Oracle." | confirmed |
| OCI-08 | If A1 use exceeds the Always Free allowance, all A1 instances are disabled and deleted after 30 days unless the account is upgraded. After the free trial, Always Free resources keep running. | https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier.htm | 2026-10-11 | "all existing OCI Ampere A1 Compute instances are disabled and then deleted after 30 days, unless you upgrade to a paid account" | confirmed |
| OCI-09 | After upgrading to Pay As You Go, Oracle does not charge for Always Free resources, only for use above the limits. | https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm | 2026-10-11 | "Oracle doesn't charge for Always Free resources after you upgrade" | confirmed |
| OCI-10 | Whether a Pay As You Go account is exempt from idle reclamation: UNVERIFIED. The docs pages are silent and https://www.oracle.com/cloud/free/faq/ blocked the fetcher. | n/a | 2026-10-11 | None. | unverified |

Reading: the A1 shape (linux/arm64) is the realistic choice; 1 GB on the AMD micro shape is likely too small for PostgreSQL, the Dart server, and Caddy together [ASSUMPTION]. On a 12 GB A1 VM, the PRD's target of 512 MB to 1 GB for the whole stack is under 20% memory, so a quiet week could mark the VM idle (OCI-07). Options: a smaller A1 shape (for example 1 OCPU and 4 GB) so normal use stays above 20%, or a Pay As You Go upgrade (paid account, needs the user's approval, and its effect on reclamation is unverified).

## 8. Items to confirm in a browser

These are "likely" facts that drive decisions. A person should read the page and update the confidence to "confirmed" or correct the row:

1. BGG-10 to BGG-17 and BGG-40, BGG-41: read https://boardgamegeek.com/using_the_xml_api, https://boardgamegeek.com/wiki/page/XML_API_Terms_of_Use, and https://boardgamegeek.com/wiki/page/BGG_XML_API_Commercial_Use before sending the license application.
2. EBAY-20 to EBAY-26: read the current API License Agreement (the version you accept when creating keys). Check the "Age of Displayed eBay Content" section, the derived-aggregates list, and the Restricted APIs section.
3. EBAY-70: read the Browse row on the API call limits page, and the limits shown for your keyset in the developer portal.
4. EBAY-90 to EBAY-94: read the EPN Network Agreement and disclosure FAQ when creating the EPN account.

## 9. Re-check log

| Date | What | Who |
|---|---|---|
| 2026-10-11 | First full pass, all sections. | product-manager (T-002) |
