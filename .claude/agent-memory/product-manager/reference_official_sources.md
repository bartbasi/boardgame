---
name: reference-official-sources
description: Where each provider's official docs and terms live (BGG, eBay, EPN, GameUPC, Apple, Google Play, ML Kit, Oracle) and which ones block the fetcher, with workarounds
metadata:
  type: reference
---

Official sources of record used for docs/api-research.md (first pass 2026-10-11, T-002). Facts themselves live in docs/api-research.md; this file is only about where to look and how to get in.

**Blocked to WebFetch (HTTP 403 or bot challenge) on 2026-10-11:** all of boardgamegeek.com, most of developer.ebay.com (license agreement, call limits, item_summary HTML page, OAuth pages), partnernetwork.ebay.com, oracle.com/cloud/free/faq, api.gameupc.com. web.archive.org is refused by the tool. Workaround: WebSearch with allowed_domains set to the official domain; it summarizes the page. Record such facts as "likely", not "confirmed". Do not use third-party reader proxies.

**Fetchable and best sources:**
- eBay Browse: OpenAPI spec https://developer.ebay.com/develop/api/spec/browse_api.json (about 400k chars; read with offset 0, 100000, 200000, 300000). Also api-docs/buy/static/*.html pages (api-browse, buy-requirements, buy-overview, ref-buy-browse-filters, ref-marketplace-supported) and developer.ebay.com/marketplace-account-deletion.
- eBay license: https://developer.ebay.com/join/api-license-agreement (redirects to /products/license; blocked). Old PDFs at developer.ebay.com/cms/files/api_license_2018-10-26.pdf (binary; Read cannot render PDFs without poppler).
- EPN: partnernetwork.ebay.com pages mobile-apps, developer-questionnaire, resources/affiliate-disclosure-faq, legal (Network Agreement). Search only.
- BGG: using_the_xml_api, wiki/page/XML_API_Terms_of_Use, wiki/page/BGG_XML_API_Commercial_Use, wiki/page/BGG_XML_API2, applications page boardgamegeek.com/applications. Search only.
- GameUPC: gameupc.com and gameupc.com/demo.py (fetchable). No terms page exists. Operator threads on BGG 2579359 and 3519987.
- Apple docs render with JavaScript; fetch the JSON form instead: https://developer.apple.com/tutorials/data/documentation/<path>.json (for example devicecheck/dcappattestservice.json). Review guidelines HTML is fetchable (about 112k chars, use offset 100000 for the end and the "Last Updated" date).
- Google Play policy: support.google.com/googleplay/android-developer/answer/ 10144311 (User Data), 10787469 (Data safety), 9888170 (permissions), 9858738 (Payments), 9859455 (App content, Ads section). Play Integrity: developer.android.com/google/play/integrity/{overview,setup,standard}.
- ML Kit: developers.google.com/ml-kit/terms and /ml-kit/android-data-disclosure; pub.dev/packages/mobile_scanner.
- Oracle: docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm and freetier.htm (fetchable).

Re-check rule: facts older than 90 days must be re-checked before they drive a decision. First pass expires 2027-01-09.
