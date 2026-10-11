---
name: reference-research-access
description: Which official partner sites block the WebFetch tool and how T-002 worked around it; where the key terms pages live for BGG, eBay, EPN, GameUPC, Oracle
metadata:
  type: reference
---

As of 2026-10-11, these official sites blocked WebFetch (HTTP 403 or a bot challenge): boardgamegeek.com, most of developer.ebay.com (including the API License Agreement and the call limits page), partnernetwork.ebay.com, and oracle.com/cloud/free/faq. The workaround was WebSearch restricted to the official domain, with facts marked "likely", not "confirmed". The user confirms those in a browser (backlog T-091).

Readable directly: eBay's Browse OpenAPI spec (https://developer.ebay.com/develop/api/spec/browse_api.json), the eBay account deletion page, Apple's review guidelines and DeviceCheck docs, Google Play policy and Play Integrity docs, the ML Kit terms, pub.dev, Oracle's Always Free docs on docs.oracle.com, and gameupc.com with its demo.py.

The fact ids and full source URLs live in docs/api-research.md; that file is the source of record. Re-check after 2027-01-09 (90 days).

How to apply: when re-checking or adding facts, try the readable sources first, mark search-only facts as "likely", and add anything a human must read to api-research section 8. Related: [[reference-dependency-terms]].
