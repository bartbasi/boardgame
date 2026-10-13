---
name: reference-research-access
description: Which official partner and data-source sites block the WebFetch tool, which are readable, and workarounds (search restricted to domain, Wikidata SPARQL via URL); where key terms pages live for BGG, eBay, EPN, GameUPC, Oracle, and the T-097 fallback sources
metadata:
  type: reference
---

As of 2026-10-11, these official sites blocked WebFetch (HTTP 403, 429, or a bot challenge): boardgamegeek.com, most of developer.ebay.com (including the API License Agreement, call limits page, and KB articles), partnernetwork.ebay.com, oracle.com/cloud/free/faq, barcodelookup.com, ean-search.org/terms.html, ludopedia.com.br (403), and luding.org (429). The workaround was WebSearch restricted to the official domain, with facts marked "likely", not "confirmed". The user confirms those in a browser (backlog T-091).

Readable directly: eBay's Browse OpenAPI spec (https://developer.ebay.com/develop/api/spec/browse_api.json), the eBay account deletion page, Apple's review guidelines and DeviceCheck docs, Google Play policy and Play Integrity docs, the ML Kit terms, pub.dev, Oracle's Always Free docs on docs.oracle.com, gameupc.com with its demo.py, wikidata.org pages, Wikipedia and Commons policy pages, devs.upcitemdb.com (plans and termsofservice; www.upcitemdb.com/termsofservice is a 404), go-upc.com (plans/api and terms-and-conditions/), store.gs1us.org, ean-search.org/ean-database-api.html, and world.openproductsfacts.org.

Apple documentation trick (2026-10-12): developer.apple.com/documentation/... pages render with JavaScript and WebFetch sees only the title. The same page is readable as JSON at developer.apple.com/tutorials/data/documentation/<same path>.json; cite the HTML URL and note the JSON form. developer.android.com/identity/data/autobackup is readable directly.

Store metadata limits (2026-10-13): Apple name/subtitle limits are readable at developer.apple.com/help/app-store-connect/reference/app-information/app-information (keywords at .../platform-version-information); Google Play limits at support.google.com/googleplay/android-developer/answer/9859152. tmsearch.uspto.gov needs JavaScript and does not render, so trademark checks must be done by the user. Store-name conflict checks rely on web search (incomplete for Google Play).

Wikidata trick: the query service answers a URL-encoded SPARQL GET through WebFetch, for example https://query.wikidata.org/sparql?format=json&query=<encoded>. Use COUNT queries for live coverage numbers instead of estimating. Board game class is Q131436.

Tool hiccup: on 2026-10-11 WebFetch and WebSearch both returned a "session limit" error for a while, intermittently. Writing up verified facts first and retrying later worked; fire calls two or three at a time, not six.

The fact ids and full source URLs live in docs/api-research.md; that file is the source of record. Re-check after 2027-01-09 (90 days).

How to apply: when re-checking or adding facts, try the readable sources first, mark search-only facts as "likely", and add anything a human must read to api-research section 8. Related: [[reference-dependency-terms]], [[criteria-patterns]].
