---
name: reference-research-access
description: Which official partner and data-source sites block the WebFetch tool, which are readable, and workarounds (search restricted to domain, Wikidata SPARQL via URL); where key terms pages live for BGG, eBay, EPN, GameUPC, Oracle, and the T-097 fallback sources
metadata:
  type: reference
---

As of 2026-10-11, these official sites blocked WebFetch (HTTP 403, 429, or a bot challenge): boardgamegeek.com, most of developer.ebay.com (including the API License Agreement, call limits page, and KB articles), partnernetwork.ebay.com, oracle.com/cloud/free/faq, barcodelookup.com, ean-search.org/terms.html, ludopedia.com.br (403), and luding.org (429). The workaround was WebSearch restricted to the official domain, with facts marked "likely", not "confirmed". The user confirms those in a browser (backlog T-091).

Readable directly: eBay's Browse OpenAPI spec (https://developer.ebay.com/develop/api/spec/browse_api.json), the eBay account deletion page, Apple's review guidelines and DeviceCheck docs, Google Play policy and Play Integrity docs, the ML Kit terms, pub.dev, Oracle's Always Free docs on docs.oracle.com, gameupc.com with its demo.py, wikidata.org pages, Wikipedia and Commons policy pages, devs.upcitemdb.com (plans and termsofservice; www.upcitemdb.com/termsofservice is a 404), go-upc.com (plans/api and terms-and-conditions/), store.gs1us.org, ean-search.org/ean-database-api.html, and world.openproductsfacts.org.

T-091 re-check (2026-10-14): still blocked: boardgamegeek.com (403), developer.ebay.com license, call limits, OAuth, Growth Check, and api-docs pages (403), partnernetwork.ebay.com (307 to an eBay bot challenge; do not try to bypass), web.archive.org (tool refuses). Readable: developer.ebay.com/updates/newsletter/q2_2025 and q4_2025 (license change notes), and the 2018 license PDF developer.ebay.com/cms/files/api_license_2018-10-26.pdf via the PDF trick below. That PDF contains 9.6 "suggest or model prices" and the data protection addendum (EBAY-27, EBAY-110 to 116), which earlier passes missed because they only searched for known clauses. Lesson: read the full agreement text when any version is readable, not just the clauses you already know about.

eBay account deletion page (https://developer.ebay.com/marketplace-account-deletion) was readable again on 2026-10-15 (EBAY-12 to EBAY-18). Check developer research rows against the page before adding them: the T-084 draft said the public key is cached "about an hour", but the page says only "temporary but reasonable".

Apple documentation trick (2026-10-12): developer.apple.com/documentation/... pages render with JavaScript and WebFetch sees only the title. The same page is readable as JSON at developer.apple.com/tutorials/data/documentation/<same path>.json; cite the HTML URL and note the JSON form. developer.android.com/identity/data/autobackup is readable directly, and so is developer.android.com/guide/topics/manifest/application-element (manifest attribute defaults, for example `restoreAnyVersion`, GPLAY-29, 2026-10-14).

Store metadata limits (2026-10-13): Apple name/subtitle limits are readable at developer.apple.com/help/app-store-connect/reference/app-information/app-information (keywords at .../platform-version-information); Google Play limits at support.google.com/googleplay/android-developer/answer/9859152. tmsearch.uspto.gov needs JavaScript and does not render, so trademark checks must be done by the user. Store-name conflict checks rely on web search (incomplete for Google Play).

Developer account research (2026-10-13, PRD Q6b): developer.apple.com/programs/enroll/, developer.apple.com/help/account/membership/... , developer.apple.com/support/D-U-N-S/, the App Store Connect DSA help page, and Play Console help (support.google.com/googleplay/android-developer/answer/13634885, 13628312, 13634081, 13634888, 14151465, 6112435) were all readable directly. Facts are APPLE-18 to 25 and GPLAY-18 to 26; user summary in docs/store/developer-accounts.md.

GS1 (2026-10-13, section 11, GS1-01 to GS1-12): gs1.org returns 403 and the General Specifications at ref.gs1.org/standards/genspecs/ exceed WebFetch's 10 MB limit. support.gs1.org (help center), gs1us.org pages, and ref.gs1.org Digital Link are readable. PDF trick: WebFetch cannot parse PDFs but saves them under the session tool-results folder; Read on that saved file (no pages parameter, pdftoppm is missing) returns the text. Worked for documents.gs1us.org PDFs and a ref.gs1.org architecture PDF.

Wikidata trick: the query service answers a URL-encoded SPARQL GET through WebFetch, for example https://query.wikidata.org/sparql?format=json&query=<encoded>. Use COUNT queries for live coverage numbers instead of estimating. Board game class is Q131436.

Tool hiccup: on 2026-10-11 WebFetch and WebSearch both returned a "session limit" error for a while, intermittently. Writing up verified facts first and retrying later worked; fire calls two or three at a time, not six.

The fact ids and full source URLs live in docs/api-research.md; that file is the source of record. Re-check after 2027-01-09 (90 days).

How to apply: when re-checking or adding facts, try the readable sources first, mark search-only facts as "likely", and add anything a human must read to api-research section 8. Related: [[reference-dependency-terms]], [[criteria-patterns]].
