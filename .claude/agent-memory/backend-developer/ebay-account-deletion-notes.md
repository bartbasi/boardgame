---
name: ebay-account-deletion-notes
description: T-084 eBay account deletion endpoint facts (challenge_code, hex SHA-256, unread-body connection close in dart:io, shelf Request rejects non-UTF-8 query, optional config pair, gitleaks-safe placeholders)
metadata:
  type: project
---

Learned on T-084 (2026-10-14):

- developer.ebay.com/marketplace-account-deletion was readable by WebFetch on 2026-10-14 (T-002 found most of developer.ebay.com blocked). Facts: query param `challenge_code`; SHA-256 of code+token+endpoint as lowercase hex; content-type application/json; signature check is "should"; up to 1,500 notifications/day; eBay resends until acknowledged. Proposed as EBAY-12 to EBAY-18 in the T-084 handoff (PM owns api-research.md).
- dart:io closes the connection after the response if the request body was not fully read (`incoming.fullBodyRead` in sdk/lib/_http/http_impl.dart). Behind Caddy that can reset a proxied POST; read and drop the body with a byte cap instead of ignoring it.
- `Uri.queryParametersAll` throws FormatException on non-UTF-8 escapes (`%ff`) but keeps a stray `%zz` literally. shelf's `Request` constructor refuses such URIs, and bindAndServe answers 404 before handlers, so a handler-level catch is dead code.
- Route mounted at `/ebay` on the root router with its own RateLimiter (60/min, 10,000 keys) so /v1 guards (T-066 attestation) never apply. Config pair optional (both or neither) until the eBay client exists; proposed to make it required with production eBay credentials.
- Placeholders for secret-like values: use low-entropy repeats (`replace-me-replace-me-...`, `fake-token-fake-token-...`) to stay under gitleaks' entropy threshold. Compute fixture hashes outside Dart with `printf '%s' ... | sha256sum`.
- deploy/.env.example: server.yml requires every uncommented variable to be a `${VAR:?}` guard, so optional variables go in commented-out lines and Compose uses `${VAR:-}`.
- Round 2 review (R1-M1): `Stream.timeout` bounds only the gap between chunks; any route that reads a body needs ONE overall deadline (Timer + cancel the subscription), or a trickling client holds connections for days. Caddy body limits/timeouts are a second layer (T-071).
- Round 2: the route limit was raised to 300 per minute (orchestrator decision); a config URL that is hashed verbatim must be canonical (`Uri.parse(url).toString() == url`); optional secret pairs go commented out in server/.env.example too (env_example_test parses `# KEY=value`).
- Round 3 (QA R2-B1, verified by raw-socket probe): cancelling a request body makes dart:io destroy the connection, so the handler's 408/413 is NEVER delivered; the response is only a value in-process and in the request log. And if a handler answers WITHOUT subscribing to the body, dart:io drains the whole declared Content-Length before writing headers (http_impl.dart `drainRequest`, ~line 1822), with no deadline. So "return early without reading" is a slowloris hole; subscribe and cancel instead. Every non-body route in the server has this (proposed follow-up ticket). Always probe connection behaviour with raw sockets before documenting it.
- QA tests pin current constants and behaviour; when a finding changes them, list the QA tests that will fail and leave them to QA.
- `coverage:test_with_coverage` exits 255 if any test fails; run it on the test files that pass without a database.

**Why:** these cost a round of probing; T-052/T-053 (eBay client) and T-055 (listing cache) build on this.
**How to apply:** keep the listing cache free of seller/buyer/user ids (test/ebay/no_ebay_user_data_test.dart guards migrations); make the deletion pair required when eBay credentials are added.

Related: [[rate-limiter-notes]], [[server-skeleton-patterns]], [[postgres-access-notes]]
