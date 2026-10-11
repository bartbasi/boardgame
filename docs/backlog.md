# Backlog

Owner: product-manager. Every ticket for the app, the backend, and the docs. Requirements live in docs/PRD.md; upstream facts in docs/api-research.md; decisions in docs/decisions.md.

## Ticket format

```
### T-012 Barcode lookup endpoint
- Milestone: M2
- Owner: backend-developer
- Status: todo | ready | in-progress | in-review | done | blocked
- Depends on: T-010
- UX spec: docs/ux/screens/scan-result.md (or n/a)
- Linked files: server/lib/src/api/v1/lookup.dart
- Acceptance criteria:
  1. Given ..., when ..., then ... (proved by: unit | widget | golden | integration | endpoint | manual)
```

Status values:

- **todo:** written, but cannot start yet (a dependency, an open question, or a checkpoint is pending).
- **ready:** can start now.
- **in-progress:** someone is working on it.
- **in-review:** built; QA, review, UX check, or PM sign-off is under way.
- **done:** tests pass, review has no must-fix items, UX passed (UI tickets), and PM approved.
- **blocked:** waiting on something outside the team (an account, an approval, a user answer). The blocker is named in "Depends on".

Test types: unit, widget, golden, integration, endpoint (backend HTTP test against the running handler), manual (a person checks, on a device where stated).

Stubs (M3 to M5) have only an id, title, owner, milestone, status, and a one-line goal. They get full acceptance criteria before they move to ready.

## Shared test definitions

UI and backend tickets refer to these so that every ticket uses the same values.

- **Window sizes** for widget and golden tests [ASSUMPTION until T-003 confirms]: compact 390 x 844 dp, medium 744 x 1133 dp, expanded 1280 x 800 dp.
- **Large text:** text scale factor 2.0.
- **Accessibility guidelines pass** means flutter_test's `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, and `textContrastGuideline` all pass for the screen, in light and dark themes.
- **Offline** in app tests: the fake data source returns the no-connection failure.
- **Golden names:** `<screen>_<state>_<theme>_<size>.png` under app/test/goldens/, as listed in each screen spec.
- **Barcode vectors** (check digits verified by hand):
  - Valid UPC-A: `036000291452`, `012345678905`
  - Valid EAN-13: `4006381333931`, `0036000291452` (the EAN-13 form of `036000291452`)
  - Valid EAN-8: `96385074`
  - Bad check digit: `036000291453`
  - Wrong length: `12345`
  - Non-digit: `03600029145A`
- **"Per api-research"** means the value comes from docs/api-research.md. If it is missing there, the developer stops and raises it (CLAUDE.md rule 1). Numbers marked [ASSUMPTION] are proposals; when the user changes them, PM updates the ticket.

## Parallel lanes

### M1

1. Orchestrator first: T-004 and T-006 (both short). T-005 (the backend framework proposal) runs at the same time.
2. Then two lanes run in parallel:
   - App lane: T-012, T-013, T-014, T-015, in that order.
   - Backend lane: T-007, T-008, T-009, T-010, T-011, in that order.
3. Orchestrator: T-016 any time. T-017 after T-007, T-008, and T-012 (it needs real lockfiles).

T-014 and T-015 both edit app.yml, and T-011 and T-019 both edit server.yml, so each pair runs in sequence.

### M2

Gate before M2 starts: T-002 has confirmed the BGG and GameUPC facts, T-003 has the M2 screen specs, and the user has answered PRD Q4 (ML Kit), Q5 (images), and Q10 (BGG token and GameUPC access).

- Backend lane: T-018 first, because the app's T-028 needs the contract. Then T-019, T-021, T-022, T-023, T-024, T-025. T-020 fits anywhere after T-008.
- App lane: T-026 and T-027 start right away (no backend dependency) and can run in parallel worktrees because they touch separate folders. Then T-030 and T-031, then T-028 (after T-018 is merged), T-029, T-032, T-033, T-034, T-035. T-036 when its blockers clear.
- The app lane and the backend lane run in parallel. Within a lane, run tickets in sequence unless noted. Most app tickets touch the router and app/lib/l10n/app_en.arb, and most backend tickets touch the router and server/.env.example.

---

## Planning

### T-001 PRD and first backlog
- Milestone: Planning
- Owner: product-manager
- Status: in-review
- Depends on: none
- UX spec: n/a
- Linked files: docs/PRD.md, docs/backlog.md, docs/handoffs/T-001.md
- Acceptance criteria:
  1. Given docs/PRD.md, when the user reads it, then it covers goals, users, user stories, features by milestone M1 to M5, pricing rules, monetization constraints, non-functional requirements with numeric targets, external risks, out of scope, assumptions, and open questions (proved by: manual, user review).
  2. Given each [ASSUMPTION] in docs/brief.md (GitHub Actions; Android API 24 and iOS 15; dart_frog or shelf; 90 days), when docs/PRD.md is searched, then each one is present and still marked (proved by: manual).
  3. Given every M1 and M2 ticket in this file, then every criterion is Given, When, Then with concrete values and names a test type, and every ticket has one owner and its dependencies (proved by: manual).
  4. Given docs/PRD.md and docs/backlog.md, when searched for U+2014 and for a double hyphen used as a dash outside code spans, then nothing is found (proved by: manual now; the repo.yml check after T-016).

### T-002 API and store policy research
- Milestone: Planning
- Owner: product-manager
- Status: in-progress
- Depends on: none
- UX spec: n/a
- Linked files: docs/api-research.md
- Acceptance criteria:
  1. Given the research checklist (BGG XML API license, token, rate limits, caching, logo rules; eBay production access, API License Agreement, Browse API limits, caching rules, attribution, EPN links in a listing view, campaign id and itemAffiliateWebUrl, Marketplace Insights application; GameUPC terms, limits, and outages; App Store and Google Play camera permission text, privacy policy, privacy labels, Data Safety, App Attest and Play Integrity requirements and quotas, third-party prices and link-out rules), when docs/api-research.md is reviewed, then every item has a fact with source URL, date checked, a quote or close paraphrase, and confidence, or an UNVERIFIED note that says what was tried (proved by: manual).
  2. Given any finding that could block or reshape a feature, then it is in "Blocking risks" at the top of the file and in the report to the orchestrator (proved by: manual).
  3. Given BGG's license process, then the file has an honest draft description of the app for the commercial license application and flags the risk that BGG may see the app as competing with its marketplace (proved by: manual).
  4. Given tickets T-021, T-024, and T-025, then the facts they need are present and marked confirmed or UNVERIFIED: BGG XML API2 base URL and the search and thing paths and parameters, how the Bearer token is sent, the rate limit, 202 and 429 behavior, caching expectations, attribution rules; GameUPC endpoint, auth, response fields, rate limit, caching terms, and commercial terms (proved by: manual).
  5. Given the Google ML Kit notes in docs/handoffs/T-001.md, then they are recorded in docs/api-research.md with source, date, and confidence (proved by: manual).

### T-003 UX flows, screen specs, components, copy, and accessibility checklist (M2 to M4)
- Milestone: Planning
- Owner: ux-designer
- Status: ready
- Depends on: T-001 (the draft is enough to start; revise after the user's review)
- UX spec: n/a (this ticket writes them)
- Linked files: docs/ux/
- Acceptance criteria:
  1. Given docs/ux/flows/, then there is one file per flow: scan to game detail, manual barcode entry, title search to game detail, barcode with zero or several matches (candidates and correction), add to collection, move between lists, edit an item, export and import, backup and restore, view prices and history, open a listing on eBay (proved by: manual).
  2. Given docs/ux/screens/, then these specs exist with these exact file names, each following the ux-designer screen spec template: app-shell.md, scanner.md, manual-entry.md, search.md, lookup-result.md, game-detail.md (including the M4 pricing section), collection.md, add-to-collection.md, collection-item-edit.md, backup-and-export.md, settings.md, listings.md, price-history.md (proved by: manual).
  3. Given each screen spec, then it covers loading, empty, error, offline with cached data, and success states (and partial data where relevant), light and dark themes, compact, medium, and expanded layouts, and lists its golden cases by file name (proved by: manual).
  4. Given docs/ux/copy.md, then every user-facing string in the specs has a stable key, is US English, and contains no em dash and no double hyphen used as a dash (proved by: manual).
  5. Given the pricing parts of game-detail.md, listings.md, price-history.md, and collection.md, then every price shows amount, asking or sold label, source eBay, sample size, and data age; an asking price is never labeled sold, value, or sale; zero listings reads "No current listings" (or the copy.md equivalent), never $0; and the affiliate disclosure sits near the listings and in Settings, with placeholder wording until T-050 (proved by: manual).
  6. Given scanner.md, then it specifies the camera permission rationale, the denied and permanently denied states with an "Open settings" action, the camera unavailable state, the torch toggle, scan feedback, and one-tap access to manual entry and title search in every state (proved by: manual).
  7. Given app-shell.md, then it decides the top-level destinations, the navigation pattern for each window size, and the seed color, and it confirms or changes the window sizes in "Shared test definitions" (proved by: manual).
  8. Given every spec, then no screen has an interstitial, an onboarding wall, a rating prompt, or a confirmation step before opening eBay (proved by: manual).
  9. Given docs/ux/components.md and docs/ux/accessibility-checklist.md, then every component used in a spec is listed with its states, and the checklist covers WCAG 2.2 AA contrast, 48 dp targets, text at 200%, semantic labels, focus order, announcements, chart text summaries, and reduce motion (proved by: manual).

---

## M1 Foundations

### T-004 Decide: Dart pub workspace or path dependencies
- Milestone: M1
- Owner: orchestrator
- Status: todo
- Depends on: none
- UX spec: n/a
- Linked files: docs/decisions.md, root pubspec.yaml (only if a workspace is chosen)
- Acceptance criteria:
  1. Given the two options (a pub workspace at the repo root covering app, server, and packages/api_contract; or separate packages with path dependencies on packages/api_contract), when the decision is made, then docs/decisions.md has an entry that states the choice and covers: building the server Docker image without the Flutter SDK, how many pubspec.lock files exist and where, CI caching, and how T-017 finds every lockfile (proved by: manual).
  2. Given the chosen setup, when the server's dependencies are resolved in an environment with only the Dart SDK (no Flutter SDK), then resolution succeeds and package:api_contract can be imported (proved by: manual now; automated by the Docker build in T-009).
  3. Given the chosen setup, when the app's dependencies are resolved, then package:api_contract can be imported from app/ (proved by: manual now; automated by T-014).
  4. Given the decision relies on pub or Flutter behavior, then the entry cites the official dart.dev or docs.flutter.dev page it used (proved by: manual).

### T-005 Decide: shelf or dart_frog for the backend
- Milestone: M1
- Owner: backend-developer (writes the proposal; the orchestrator records the decision after the user confirms)
- Status: todo
- Depends on: none
- UX spec: n/a
- Linked files: docs/handoffs/T-005.md, docs/decisions.md
- Acceptance criteria:
  1. Given both frameworks, when the proposal is written in docs/handoffs/T-005.md, then it compares: the license of each framework and of every package it pulls in, the latest release date and maintenance activity on pub.dev, middleware support for attestation and per-IP rate limits, how endpoints are tested, AOT compilation with `dart compile exe`, any CLI or code generation requirement, and the idle memory of a minimal /health server measured in a linux/amd64 container, in MB (proved by: manual).
  2. Given the comparison, then the proposal recommends one option (or, as the brief allows, a clearly better alternative) and says what would make us switch later (proved by: manual).
  3. Given any spike code, then it stays on the ticket branch and is not merged to main (proved by: manual).
  4. Given the user confirms, then docs/decisions.md records the decision, the orchestrator removes the [ASSUMPTION] marker for the backend framework from CLAUDE.md, and PM removes it from docs/PRD.md (proved by: manual).

### T-006 Root tooling: shared strict lints, editor config, README outline
- Milestone: M1
- Owner: orchestrator
- Status: todo
- Depends on: none
- UX spec: n/a
- Linked files: analysis_options.yaml (root), .editorconfig, README.md
- Acceptance criteria:
  1. Given the root analysis_options.yaml, then it enables `strict-casts`, `strict-inference`, and `strict-raw-types` and includes a recommended lint set whose license is MIT, BSD, or Apache 2.0; app, server, and packages/api_contract include this file rather than copying it (proved by: manual; checked again in T-007, T-008, T-012).
  2. Given a scratch file in server/ containing `final int x = jsonDecode('1');`, when `dart analyze` runs, then it reports an error for the implicit cast (proved by: manual; scratch file not committed).
  3. Given .editorconfig, then it sets UTF-8, LF line endings, a final newline, and 2-space indents for Dart, YAML, JSON, and Markdown, consistent with .gitattributes (proved by: manual).
  4. Given README.md, then it has headings for local setup, registering for BGG, eBay, and GameUPC access, environment variables, running tests, building releases, and deploying to the Oracle VM, each with a one-line note naming the ticket that fills it in (proved by: manual).

### T-007 API contract package skeleton
- Milestone: M1
- Owner: backend-developer
- Status: todo
- Depends on: T-004, T-006
- UX spec: n/a
- Linked files: packages/api_contract/
- Acceptance criteria:
  1. Given packages/api_contract/pubspec.yaml, then it has no Flutter SDK dependency, and `dart test` runs in the package with only the Dart SDK (proved by: unit, run in CI by T-011).
  2. Given the error envelope DTO (a machine-readable code and a human-readable message, with its JSON shape documented in the package README), when each error fixture in packages/api_contract/test/fixtures/ is decoded and encoded again, then the result equals the fixture (proved by: unit).
  3. Given the health DTO (status and version), when its fixture is decoded and encoded again, then the result equals the fixture (proved by: unit).
  4. Given a fixture with an extra unknown field, when decoded, then decoding succeeds and ignores the field (proved by: unit).
  5. Given a fixture missing a required field, when decoded, then decoding fails with a typed error the caller can catch, never a silent null (proved by: unit).
  6. Given an error code the client does not know, such as `brand_new_code`, when decoded, then it maps to an `unknown` code instead of failing (proved by: unit).
  7. Given the DTOs, then they use freezed and json_serializable, the handoff says whether generated files are committed or generated in CI, and `dart analyze` reports zero issues with the shared strict lints (proved by: unit, plus the CI analyze step).
  8. Given the package README, then it states the compatibility rule: changes within /v1 are additive only, and removing or renaming a field needs a new API version (proved by: manual).
  9. Given the package tests, then line coverage is at least 80% (proved by: unit, coverage report).

### T-008 Backend skeleton: /health, fail-fast config, minimal structured logs
- Milestone: M1
- Owner: backend-developer
- Status: todo
- Depends on: T-005, T-007
- UX spec: n/a
- Linked files: server/, server/.env.example
- Acceptance criteria:
  1. Given the server is running, when GET /health is called, then it returns 200 with `Content-Type: application/json` and a body that decodes with the api_contract health DTO, with status "ok" and the build version. /health stays outside /v1 so Compose and Caddy health checks can use it [ASSUMPTION] (proved by: endpoint).
  2. Given an unknown path such as GET /v1/nope, then the response is 404 with the error envelope, code `not_found`, and no stack trace or framework text (proved by: endpoint).
  3. Given a test-only route that throws, then the response is 500 with code `internal_error` and no exception text or stack trace in the body, and the error with its stack trace is written to the log at error level (proved by: endpoint with log capture).
  4. Given a required variable is missing (for example PORT is unset), when the server starts, then it exits with a non-zero code before listening and prints one message naming every missing or invalid variable, without printing any variable's value (proved by: unit on the config loader; manual run).
  5. Given PORT=abc or LOG_LEVEL=loud, then startup fails with a message naming the variable and its allowed values (proved by: unit).
  6. Given server/.env.example, then it lists every variable the config loader reads, with placeholder values only, and a test compares the loader's variable names with the file's keys and fails on any difference (proved by: unit).
  7. Given any request, then exactly one JSON log line is written with a UTC ISO 8601 timestamp, level, method, route template (for example `/v1/games/{bggId}`), status, and duration in ms (proved by: unit with log capture).
  8. Given a request with an X-Forwarded-For header, a User-Agent header, the query string `?q=secret`, and a body, then no log line contains the IP, the user agent, the query string, any header, or the body (proved by: unit with log capture).
  9. Given SIGTERM, then the server stops accepting connections, lets in-flight requests finish for up to 10 s [ASSUMPTION], and exits 0 (proved by: integration, run on Linux in CI or in Docker).
  10. Given the server package, then `dart analyze` reports zero issues, `dart format` is clean, and line coverage is at least 80% (proved by: unit, coverage report).

### T-009 Server Dockerfile for linux/arm64 and linux/amd64
- Milestone: M1
- Owner: backend-developer
- Status: todo
- Depends on: T-008
- UX spec: n/a
- Linked files: server/Dockerfile, a Dockerfile-specific ignore file owned by backend-developer (if a root .dockerignore is needed instead, ask the orchestrator)
- Acceptance criteria:
  1. Given the repo, when `docker buildx build --platform linux/arm64,linux/amd64` runs with server/Dockerfile, then both images build. Building both covers either VM shape (PRD Q20) (proved by: manual on the dev machine; automated in T-011).
  2. Given the amd64 image and a valid env file, when the container starts, then GET /health returns 200 within 5 s (proved by: manual).
  3. Given a required variable is missing, when the container starts, then it exits non-zero and logs the config error from T-008 (proved by: manual).
  4. Given the final image, then `docker image inspect` shows a non-root user, and the image holds only the compiled server and its runtime files: no Dart SDK, no source, no .env, no .git, no app/ (proved by: manual).
  5. Given the final image, then its size is 100 MB or less on each platform [ASSUMPTION], recorded in the handoff (proved by: manual).
  6. Given the build context, then the ignore file excludes .env files, .git, app/, .claude/, and build output (proved by: manual).
  7. Given the base images, then each is pinned to an exact version or digest, supports both platforms, and has its license noted in the handoff (proved by: manual).

### T-010 Local Docker Compose with PostgreSQL and Caddy
- Milestone: M1
- Owner: backend-developer
- Status: todo
- Depends on: T-009
- UX spec: n/a
- Linked files: deploy/ (local Compose file, Caddyfile, .env.example)
- Acceptance criteria:
  1. Given deploy/.env created from deploy/.env.example, when the documented `docker compose up` command runs, then the server, PostgreSQL, and Caddy start, and `curl -k https://localhost/health` returns 200 through Caddy (proved by: manual).
  2. Given the running stack, then only Caddy publishes host ports (80 and 443), the server port is not published, and PostgreSQL is published at most on 127.0.0.1 (proved by: manual, `docker compose ps`).
  3. Given rows written to PostgreSQL, when the stack is stopped with `docker compose down` (without removing volumes) and started again, then the rows are still there (proved by: manual).
  4. Given the PostgreSQL credentials, then they come only from deploy/.env, and deploy/.env.example lists every variable with placeholder values (proved by: manual).
  5. Given each service, then it has a memory limit, and the stack's idle memory measured with `docker stats` is recorded in the handoff, with a target of 512 MB or less [ASSUMPTION] (proved by: manual).
  6. Given the health checks, then the server's uses /health, PostgreSQL's uses pg_isready, and the server starts only after PostgreSQL is healthy (proved by: manual).
  7. Given the PostgreSQL and Caddy images, then each is pinned to an exact version that exists for linux/arm64 and linux/amd64 (proved by: manual).

Production settings (domain, real certificates, backups) are T-071 and T-072, not this ticket.

### T-011 server.yml CI workflow
- Milestone: M1
- Owner: backend-developer
- Status: todo
- Depends on: T-007, T-008, T-009
- UX spec: n/a
- Linked files: .github/workflows/server.yml
- Acceptance criteria:
  1. Given a push or pull request that changes server/, packages/api_contract/, deploy/, or .github/workflows/server.yml, then the workflow runs (proved by: manual, observe a run).
  2. Given the workflow, then for server/ and packages/api_contract/ it runs `dart format --output=none --set-exit-if-changed`, `dart analyze --fatal-infos`, and `dart test` with coverage, on the Dart SDK version recorded in docs/decisions.md (proved by: manual, read the workflow and run log).
  3. Given line coverage below 80% for server/ or packages/api_contract/, then the workflow fails (proved by: manual, a scratch branch that lowers coverage, deleted afterward).
  4. Given the workflow, then it builds the server image for linux/arm64 and linux/amd64 and pushes nothing (proved by: manual, run log).
  5. Given the workflow file, then `permissions` is read-only (`contents: read`) and every third-party action is pinned to a full commit SHA (proved by: manual).
  6. Given the tests, then none needs a secret or network access to BGG, eBay, or GameUPC, and the workflow defines no secrets (proved by: manual).
  7. Given a typical change, then the workflow finishes in 10 minutes or less [ASSUMPTION], with the duration recorded in the handoff (proved by: manual).

### T-012 App skeleton: project, feature folders, navigation, themes, strings
- Milestone: M1
- Owner: flutter-developer
- Status: todo
- Depends on: T-004, T-006
- UX spec: docs/ux/screens/app-shell.md (T-003). Until it exists, use the destinations Scan, Collection, and Settings [ASSUMPTION] and a placeholder seed color.
- Linked files: app/
- Acceptance criteria:
  1. Given app/, then it is a Flutter project with Android minSdk 24 and iOS deployment target 15.0 [ASSUMPTION], using the display name and ids from PRD Q1 (placeholders until answered) (proved by: manual, read the build files).
  2. Given lib/features/, then scanner, game_detail, pricing, collection, and settings each have data, domain, and presentation folders, and shared code lives in lib/core/ (proved by: manual).
  3. Given any Dart file under a domain folder, when the architecture test runs, then it fails if the file imports package:flutter, dart:ui, or any plugin package; it passes for the skeleton, and it proves itself against a fixture that contains a forbidden import (proved by: unit).
  4. Given a compact window (390 x 844 dp), then a bottom NavigationBar shows the top-level destinations; given a medium or expanded window (744 or 1280 dp wide), then a NavigationRail shows them (proved by: widget).
  5. Given the user scrolls a placeholder list on Collection, switches to Settings, and comes back, then the scroll position is kept (proved by: widget).
  6. Given the system theme is dark, then the app uses the dark Material 3 color scheme generated from the same seed as the light scheme; given light, then the light scheme (proved by: widget with platform brightness set).
  7. Given each placeholder screen at text scale 2.0 in compact and expanded sizes, then no overflow error is thrown (proved by: widget).
  8. Given the navigation destinations, then each has a semantic label and the accessibility guidelines pass in both themes (proved by: widget).
  9. Given user-facing strings, then they come from app/lib/l10n/app_en.arb through Flutter's localization code generation [ASSUMPTION], with keys matching docs/ux/copy.md once it exists, and no widget contains a hard-coded user-facing string (proved by: manual review).
  10. Given Riverpod code generation, then a generated provider is used by the shell, and the handoff states whether generated files are committed or generated in CI (proved by: unit and manual).
  11. Given an Android emulator at API 24 and one at the newest installed API level, then the app launches and shows the shell in both themes (proved by: manual on emulator).
  12. Given the app, then `flutter analyze` reports zero issues with the shared strict lints and `dart format` is clean (proved by: manual now; CI from T-014).

### T-013 App core: Result, Failure types, and HTTP client with retries
- Milestone: M1
- Owner: flutter-developer
- Status: todo
- Depends on: T-012
- UX spec: n/a
- Linked files: app/lib/core/
- Acceptance criteria:
  1. Given lib/core, then a pure Dart Result type (success or failure) and a sealed Failure hierarchy exist with at least: no connection, timeout, rate limited (with an optional retry-after duration), service unavailable, not found, invalid input (with the API error code), and unexpected (proved by: unit, including an exhaustive switch over all cases).
  2. Given the app is built with `--dart-define=API_BASE_URL=https://api.example.test`, then every request goes to that base URL (proved by: unit with a fake HTTP adapter).
  3. Given a release build configuration and an API_BASE_URL that is not https, then the config parser returns a typed failure and no request is sent. Debug builds may use http for local development [ASSUMPTION] (proved by: unit).
  4. Given a GET that gets 503 twice and then 200, then the caller receives the 200 result after 3 attempts, and the waits before attempts 2 and 3 fall within 0 to 500 ms and 0 to 1,000 ms. The policy is full jitter, base 500 ms, factor 2, cap 8 s, at most 3 retries [ASSUMPTION] (proved by: unit with a fake clock and seeded random).
  5. Given four 503 responses in a row, then the caller receives the service unavailable failure after exactly 4 attempts (proved by: unit).
  6. Given a 429 with `Retry-After: 3`, then the next attempt waits at least 3 s; given `Retry-After` as an HTTP date 5 s in the future, then at least 5 s (proved by: unit with a fake clock).
  7. Given a 429 with `Retry-After: 120`, which is above the 30 s cap [ASSUMPTION], then there is no retry and the caller receives the rate limited failure carrying 120 s (proved by: unit).
  8. Given a 400, 401, 403, or 404, then there is no retry and the matching failure is returned (proved by: unit, table-driven).
  9. Given a non-GET request that gets 503, then it is attempted exactly once; only GET is retried (proved by: unit).
  10. Given a connect timeout of 10 s and a receive timeout of 15 s [ASSUMPTION], then one call, including all retries and waits, never takes longer than 20 s [ASSUMPTION]; at that limit it returns the timeout failure (proved by: unit with a fake clock).
  11. Given each error the HTTP library can raise (connection error, each timeout kind, bad response, cancel, unknown) and a response body that is not valid JSON, then the client returns a Failure and never throws (proved by: unit, table-driven).
  12. Given a release build, then request and response bodies are never logged (proved by: unit or manual review).
  13. Given lib/core domain and data code, then line coverage is at least 80% (proved by: unit, coverage report).

### T-014 app.yml CI workflow
- Milestone: M1
- Owner: flutter-developer
- Status: todo
- Depends on: T-012
- UX spec: n/a
- Linked files: .github/workflows/app.yml
- Acceptance criteria:
  1. Given a push or pull request that changes app/, packages/api_contract/, or .github/workflows/app.yml, then the workflow runs (proved by: manual, observe a run).
  2. Given the workflow, then it uses the Flutter version recorded in docs/decisions.md (3.47.7 today), set in one place in the file (proved by: manual).
  3. Given the ubuntu job, then it resolves dependencies, runs code generation if generated files are not committed, then runs `dart format --output=none --set-exit-if-changed`, `flutter analyze --fatal-infos`, and `flutter test --coverage` (proved by: manual, run log).
  4. Given line coverage below 80% for files under lib/core/ and lib/features/*/domain/ and lib/features/*/data/, then the workflow fails, and the coverage report is uploaded as an artifact in every run (proved by: manual, a scratch branch, deleted afterward).
  5. Given the ubuntu job, then `flutter build apk --debug` succeeds (proved by: manual, run log).
  6. Given a push to main or a manual run, then a macOS job runs `flutter build ios --no-codesign` and succeeds; it does not run on other branches [ASSUMPTION, pending PRD Q2] (proved by: manual, run log).
  7. Given the workflow file, then permissions are read-only and every third-party action is pinned to a full commit SHA (proved by: manual).
  8. Given a typical change, then the ubuntu jobs finish in 15 minutes or less [ASSUMPTION] (proved by: manual).

### T-015 Linux golden image pipeline
- Milestone: M1
- Owner: flutter-developer
- Status: todo
- Depends on: T-014
- UX spec: docs/ux/screens/app-shell.md (for the sample goldens; placeholders until T-003)
- Linked files: app/test/goldens/, app/test/ (golden helpers and test config), app/tool/ (Docker script), .github/workflows/app.yml
- Acceptance criteria:
  1. Given the Windows dev machine with Docker Desktop, when the documented command runs, then it renders and updates goldens inside a Linux container that uses the same Flutter version as CI; the handoff gives the exact command so the orchestrator can record it in docs/decisions.md (proved by: manual).
  2. Given goldens produced by that command and committed, when app.yml runs the golden tests on ubuntu, then they pass with no changes (proved by: CI run on the ticket branch).
  3. Given `flutter test --update-goldens` run directly on Windows or macOS, then the run fails with a message pointing to the Docker command, and no PNG is written (proved by: unit for the platform guard, plus a manual run on Windows).
  4. Given any golden, then text renders as real, readable glyphs in the app's fonts, not boxes, so UX and PM can review copy (proved by: manual, open the PNG).
  5. Given the golden helper, then it renders a widget at the shared window sizes, in light and dark, at text scale 1.0 and 2.0, and names files `<screen>_<state>_<theme>_<size>.png` under app/test/goldens/ (proved by: golden).
  6. Given the app shell from T-012, then these goldens exist and pass: app_shell_default_light_compact.png, app_shell_default_dark_compact.png, app_shell_default_light_expanded.png, app_shell_default_dark_expanded.png (proved by: golden).
  7. Given a golden mismatch in CI, then the job fails and uploads the diff images as an artifact (proved by: manual, a scratch commit that changes a color, reverted afterward).
  8. Given font files bundled for tests, then their license is recorded in the handoff, and anything other than MIT, BSD, or Apache 2.0 is approved by the user before it is committed (proved by: manual).

### T-016 repo.yml: secret scanning and prose style check
- Milestone: M1
- Owner: orchestrator
- Status: todo
- Depends on: none
- UX spec: n/a
- Linked files: .github/workflows/repo.yml, the prose check script (location chosen by the orchestrator)
- Acceptance criteria:
  1. Given any push or pull request, then repo.yml runs secret scanning over the new commits (proved by: manual, observe a run).
  2. Given a scratch branch that commits a fake but well-formed credential (for example a string in AWS access key format), then the job fails and names the file and line; the branch is deleted afterward (proved by: manual).
  3. Given the secret scanner, then its license is MIT, BSD, or Apache 2.0, it is free for this repository, and any license key requirement is raised with the user before use (proved by: manual).
  4. Given a tracked file named `.env` or `.env.<anything>` other than `.env.example`, then the job fails (proved by: manual, scratch branch).
  5. Given the prose check, then it scans README.md, CLAUDE.md, every .md file under docs/, and app/lib/l10n/*.arb (proved by: manual, read the script).
  6. Given U+2014 (em dash) anywhere in those files, then the check fails and prints file, line, and column (proved by: unit tests for the script, plus a manual run).
  7. Given a double hyphen used as a dash outside inline code and fenced code blocks, then the check fails. The rule: exactly two hyphens (not part of a longer run) with whitespace or line end on both sides, or a letter or digit on both sides. So `word -- word`, `word--word`, and `word --` at the end of a line all fail (proved by: unit).
  8. Given legitimate hyphens, then the check passes for: `--coverage` inside backticks, `flutter test --coverage` in a fenced code block, a flag in plain text such as: run the tests with --coverage (whitespace before, letter after), table separators like `|---|---|`, horizontal rules and front matter lines `---`, and HTML comments `<!-- note -->` (proved by: unit).
  9. Given the main branch when this ticket merges, then the check passes (proved by: manual run).
  10. Given the workflow file, then permissions are read-only and every third-party action is pinned to a full commit SHA (proved by: manual).

### T-017 repo.yml: dependency license check
- Milestone: M1
- Owner: orchestrator
- Status: todo
- Depends on: T-004, T-007, T-008, T-012
- UX spec: n/a
- Linked files: .github/workflows/repo.yml, license allowlist and third-party components list (locations chosen by the orchestrator)
- Acceptance criteria:
  1. Given every pubspec.lock in the repo (per T-004), when the check runs on a push or pull request, then it finds the license of every direct, dev, and transitive package and prints the list in the run log (proved by: manual).
  2. Given a package licensed MIT, BSD-2-Clause, BSD-3-Clause, or Apache-2.0, then it passes (proved by: unit with a fixture lockfile and fixture license data).
  3. Given a package with any other license, or a license the tool cannot determine, then the check fails and names the package, version, and license found, unless the package is on the allowlist (proved by: unit).
  4. Given the allowlist, then every entry names the package, the license, and the docs/decisions.md entry where the user approved it; an entry without that reference fails the check (proved by: unit).
  5. Given components the lockfile check cannot see (Docker base images, native SDKs pulled in by plugins such as Google ML Kit, bundled fonts), then each is listed by hand with its license and approval status in the third-party components list, and ML Kit shows "pending user approval (PRD Q4)" until the user answers (proved by: manual).
  6. Given the tool used for the check, then its own license is MIT, BSD, or Apache 2.0 and it is free (proved by: manual).

---

## M2 Identify a game

Backend tickets here depend on T-002 for upstream facts. Do not start one until docs/api-research.md has the facts it needs.

### T-018 API contract: M2 DTOs and error codes
- Milestone: M2
- Owner: backend-developer
- Status: todo
- Depends on: T-007, T-002 (BGG and GameUPC fields), T-003 (what the screens show), PRD Q5 (where image URLs point)
- UX spec: n/a (reads search.md, lookup-result.md, game-detail.md)
- Linked files: packages/api_contract/
- Acceptance criteria:
  1. Given the barcode lookup response, then it has the normalized code (a GTIN-13 string), a status of `matched`, `candidates`, `none`, or `unavailable`, and a list of game summaries that is empty for `none` and `unavailable` (proved by: unit, a fixture round trip for each status).
  2. Given a game summary, then it has bggId (a positive integer), name, a nullable year published, a nullable thumbnail URL, and any other field the T-003 specs need that docs/api-research.md confirms BGG provides and lets us show (proved by: unit, fixture round trip).
  3. Given the search response, then it has the query as the server normalized it and a list of game summaries (proved by: unit).
  4. Given the game detail response, then it has the fields game-detail.md needs that docs/api-research.md confirms (for example name, year, image, player count, play time, designers, publishers, description), each nullable where BGG may omit it, plus `fetchedAt` as an ISO 8601 UTC timestamp (proved by: unit, including a fixture with every optional field missing).
  5. Given a field the specs want that docs/api-research.md does not confirm, then it is left out and listed under "Open questions" in the handoff (proved by: manual).
  6. Given the error codes `invalid_barcode`, `invalid_query`, `invalid_bgg_id`, `not_found`, `rate_limited`, `upstream_unavailable`, and `internal_error`, then each decodes from a fixture, and an unknown code decodes to `unknown` (proved by: unit).
  7. Given packages/api_contract/test/fixtures/, then there is one example JSON file per response type and status, and the app's data layer tests in T-028 reuse them (proved by: unit).
  8. Given the handoff, then it lists every DTO and field added, for the flutter-developer (proved by: manual).

### T-019 Server: PostgreSQL access, migrations, and database health
- Milestone: M2
- Owner: backend-developer
- Status: todo
- Depends on: T-008, T-010, T-011
- UX spec: n/a
- Linked files: server/ (database access, migrations), server/.env.example, .github/workflows/server.yml (PostgreSQL service for tests)
- Acceptance criteria:
  1. Given an empty database, when the server starts, then it applies every migration in order, each in a transaction, and records each applied version (proved by: integration against real PostgreSQL, same major version as Compose).
  2. Given a database already at the latest version, when the server starts again, then no migration runs (proved by: integration).
  3. Given a migration that fails, then its changes roll back, the server logs which migration failed, and it exits non-zero (proved by: integration with a deliberately broken test migration).
  4. Given the database settings, then they come from variables listed in server/.env.example, and the password never appears in logs or error output (proved by: unit with log capture).
  5. Given the connection pool, then its maximum size comes from config, with a default of 5 [ASSUMPTION] (proved by: unit).
  6. Given PostgreSQL is reachable, then GET /health returns 200 with database "ok"; given it is down, then GET /health returns 503 with database "unavailable" within 2 s, the server keeps running, and it recovers when the database comes back (proved by: endpoint and integration).
  7. Given server.yml, then CI runs these tests against a PostgreSQL service container, and no test for this ticket mocks the database driver (proved by: manual, workflow and run log).
  8. Given the schema, then no table has a column for a user id, device id, IP address, or user agent (proved by: manual, reviewer and PM read the migrations).

### T-020 Server: per-IP rate limiting on /v1
- Milestone: M2
- Owner: backend-developer
- Status: todo
- Depends on: T-008
- UX spec: n/a
- Linked files: server/ (middleware), server/.env.example
- Acceptance criteria:
  1. Given a limit of 60 requests per minute per IP [ASSUMPTION, configurable], when one IP sends 70 requests to /v1 routes within 10 s, then at most 60 succeed and the rest get 429 with error code `rate_limited` and a `Retry-After` header holding a whole number of seconds, at least 1 (proved by: endpoint with a fake clock).
  2. Given IP A is being limited, when IP B sends a request, then B's request succeeds (proved by: endpoint).
  3. Given IP A was limited, when a full minute passes on the fake clock, then A's requests succeed again (proved by: unit).
  4. Given the direct peer is a trusted proxy (Caddy, configured by address), then the client IP comes from the X-Forwarded-For entry Caddy added; given the direct peer is not trusted, then X-Forwarded-For is ignored and the socket address is used (proved by: endpoint with a spoofed header).
  5. Given GET /health, then this limiter does not apply (proved by: endpoint).
  6. Given the limiter, then IP addresses are held only in memory, never written to logs or the database, and each entry is removed once its window passes (proved by: unit with log capture; the tracked count is 0 after expiry).
  7. Given 200,000 distinct IPs within one minute, then the number of tracked IPs never exceeds the configured maximum, default 100,000 [ASSUMPTION], with the oldest entries evicted first (proved by: unit).

### T-021 Server: BGG XML API client and shared request queue
- Milestone: M2
- Owner: backend-developer
- Status: todo
- Depends on: T-002, T-008; PRD Q10 (a BGG token to record fixtures)
- UX spec: n/a
- Linked files: server/ (BGG client and queue), server/test/fixtures/bgg/, server/.env.example
- Acceptance criteria:
  1. Given 5 BGG requests enqueued at the same moment, then they start at 0, 2, 4, 6, and 8 s on a fake clock. There is one queue per server process with a minimum interval of 2 s by default, configurable, and set to the value in docs/api-research.md if it states a different limit (proved by: unit).
  2. Given any BGG request, then the scheme is https, the host is exactly boardgamegeek.com (never www.boardgamegeek.com), and the paths and parameters are the ones docs/api-research.md documents (proved by: unit, capturing requests).
  3. Given any BGG request, then it carries the Bearer token from config the way docs/api-research.md documents; the token never appears in logs, errors, or fixtures; a missing token fails startup (proved by: unit with log capture, plus a test that scans the fixtures folder for the token pattern).
  4. Given BGG answers 202 twice and then 200, then the client waits the delay docs/api-research.md gives (2 s, doubling, if it gives none [ASSUMPTION]) between tries and returns the parsed 200 result; after 5 consecutive 202 answers [ASSUMPTION] it returns an upstream unavailable failure (proved by: unit with a fake clock).
  5. Given BGG answers 429 with `Retry-After: 30`, then the whole queue pauses for at least 30 s, not only that request; without Retry-After it pauses 60 s [ASSUMPTION] (proved by: unit with a fake clock).
  6. Given a 5xx, a timeout (10 s default [ASSUMPTION]), or malformed XML, then the client returns a typed failure and no exception escapes it (proved by: unit with fixtures).
  7. Given an XML fixture whose DOCTYPE declares an external entity pointing to a local file or a URL, then parsing neither reads the file nor makes a network call, and the result is a parse failure or the entity stays unresolved (proved by: unit).
  8. Given recorded search and thing fixtures with the token scrubbed, then the parser maps them to internal models, including Unicode names such as "Café International" and HTML entities in descriptions decoded to plain text (proved by: unit).
  9. Given more than 50 requests already waiting [ASSUMPTION], then a new request fails fast with a busy failure, so endpoints can answer 503 with Retry-After instead of hanging (proved by: unit).
  10. Given each upstream call, then one log line records the BGG operation name, status, and duration, with no token and no search text (proved by: unit with log capture).

### T-022 Server: GET /v1/games/{bggId} with 7-day cache
- Milestone: M2
- Owner: backend-developer
- Status: todo
- Depends on: T-018, T-019, T-021
- UX spec: n/a
- Linked files: server/ (games route, game cache, migration)
- Acceptance criteria:
  1. Given bggId 13 was fetched less than 7 days ago and is cached, then the endpoint returns 200 from the database and the BGG fake records 0 calls (proved by: endpoint).
  2. Given bggId 13 is not cached, then the server fetches it through the queue, stores it, and returns 200 with `fetchedAt` set to the fetch time (proved by: endpoint).
  3. Given a cache entry older than 7 days and BGG failing, then the endpoint returns the stale entry with 200 and its original `fetchedAt` (proved by: endpoint).
  4. Given a cache lifetime configured below 7 days, then startup fails with a config error (proved by: unit).
  5. Given bggId values `0`, `-1`, `abc`, `1.5`, and `99999999999` (above the maximum of 2,147,483,647 [ASSUMPTION]), then the endpoint returns 400 `invalid_bgg_id` and makes no BGG call (proved by: endpoint, table-driven).
  6. Given BGG reports no item for the id, then the endpoint returns 404 `not_found` and caches that answer for 24 hours [ASSUMPTION] (proved by: endpoint).
  7. Given BGG is unavailable or the queue is busy and nothing is cached, then the endpoint returns 503 `upstream_unavailable` with a Retry-After header, and the body contains no upstream error text (proved by: endpoint).
  8. Given any 200 response, then it decodes with the api_contract game detail DTO (proved by: endpoint).
  9. Given the stored and returned data, then it holds only fields that docs/api-research.md confirms and BGG's terms allow (proved by: manual, reviewer and PM compare).

### T-023 Server: GET /v1/games/search
- Milestone: M2
- Owner: backend-developer
- Status: todo
- Depends on: T-018, T-019, T-021
- UX spec: n/a
- Linked files: server/ (search route, search cache, migration)
- Acceptance criteria:
  1. Given `q` missing, empty, one character after trimming, or longer than 100 characters [ASSUMPTION], then the endpoint returns 400 `invalid_query` and makes no BGG call (proved by: endpoint, table-driven).
  2. Given `q=catan`, then the endpoint returns 200 with at most 50 results [ASSUMPTION], limited to the BGG item types docs/api-research.md lists for board games and expansions (proved by: endpoint with fixture).
  3. Given results, then exact name matches (case-insensitive) come first and the rest keep BGG's order (proved by: unit).
  4. Given the queries "Catan", " catan ", and "CATAN" within 24 hours [ASSUMPTION], then the second and third are served from the cache and the BGG fake records 1 call in total (proved by: endpoint).
  5. Given a query with no results, then the endpoint returns 200 with an empty list, not 404 (proved by: endpoint).
  6. Given `q` = "Café & Co", then the BGG request carries exactly that text, correctly encoded (proved by: unit, decoding the captured request).
  7. Given BGG is unavailable and nothing is cached, then the endpoint returns 503 `upstream_unavailable` with Retry-After (proved by: endpoint).
  8. Given any search, then the query text does not appear in any log line (proved by: unit with log capture).
  9. Given any 200 response, then it decodes with the api_contract search DTO (proved by: endpoint).

### T-024 Server: GameUPC client
- Milestone: M2
- Owner: backend-developer
- Status: todo
- Depends on: T-002, T-008; PRD Q10 (GameUPC access to record fixtures)
- UX spec: n/a
- Linked files: server/ (GameUPC client), server/test/fixtures/gameupc/, server/.env.example
- Acceptance criteria:
  1. Given a lookup, then the client calls only the host, endpoint, and auth method documented in docs/api-research.md, with credentials from config that never appear in logs or fixtures (proved by: unit, capturing requests, with log capture).
  2. Given recorded fixtures for one match, several matches, and no match, then the client maps them to BGG ids with names and any ranking field docs/api-research.md confirms (proved by: unit).
  3. Given a timeout of 3 s [ASSUMPTION], a 5xx, a 429, or malformed JSON, then the client returns a typed unavailable failure and never throws (proved by: unit, table-driven).
  4. Given a 429 with `Retry-After: 60`, then for the next 60 s the client returns unavailable immediately without calling GameUPC (proved by: unit with a fake clock).
  5. Given 5 consecutive failures [ASSUMPTION], then the client skips calls for 60 s [ASSUMPTION] and then tries again (proved by: unit with a fake clock).
  6. Given the rate limit in docs/api-research.md, then the client never exceeds it (proved by: unit with a fake clock).
  7. Given GameUPC's terms in docs/api-research.md (commercial use, caching, attribution), then the handoff states how this client complies (proved by: manual).

### T-025 Server: GET /v1/lookup/barcode/{code}
- Milestone: M2
- Owner: backend-developer
- Status: todo
- Depends on: T-018, T-019, T-021, T-022, T-024
- UX spec: n/a
- Linked files: server/ (lookup route, barcode validation, mapping store, migration)
- Acceptance criteria:
  1. Given `036000291452`, `4006381333931`, and `96385074`, then they pass validation; given `036000291453`, `12345`, and `03600029145A`, then the endpoint returns 400 `invalid_barcode` and makes no upstream call (proved by: endpoint, table-driven).
  2. Given `036000291452` and `0036000291452`, then both normalize to the GTIN-13 `0036000291452` and share one stored mapping [ASSUMPTION: GTIN-13 is the storage key] (proved by: unit and endpoint).
  3. Given GameUPC returns exactly one BGG id, then the endpoint returns 200 with status `matched` and one game summary (proved by: endpoint).
  4. Given GameUPC returns several BGG ids, then the endpoint returns 200 with status `candidates` and up to 10 summaries [ASSUMPTION] in GameUPC's ranking order (proved by: endpoint).
  5. Given GameUPC returns no BGG id, then the endpoint returns 200 with status `none` and an empty list, not 404 (proved by: endpoint).
  6. Given GameUPC times out or fails and no mapping is stored, then the endpoint returns 200 with status `unavailable` within 4 s in total [ASSUMPTION], and that answer is not stored as a mapping (proved by: endpoint with a slow fake).
  7. Given a stored mapping younger than 30 days [ASSUMPTION, or the period docs/api-research.md allows], then GameUPC is not called (proved by: endpoint, fake call count 0).
  8. Given candidates, then each summary has at least bggId and name, taken from GameUPC's response if docs/api-research.md confirms it includes names, otherwise from the game cache or from BGG through the queue (proved by: endpoint).
  9. Given docs/api-research.md confirms GameUPC can return a product name without a BGG id, then the backend runs a BGG title search with that name and returns status `candidates` with those results. If it is not confirmed, this criterion is dropped and the handoff says so (proved by: endpoint).
  10. Given any lookup, then the database receives only the barcode, the mapping, and timestamps, and nothing about the requester (proved by: manual, reviewer and PM read the migration and code).
  11. Given any 200 response, then it decodes with the api_contract lookup DTO (proved by: endpoint).

### T-026 App: barcode value object and validation
- Milestone: M2
- Owner: flutter-developer
- Status: todo
- Depends on: T-012
- UX spec: n/a
- Linked files: app/lib/features/scanner/domain/
- Acceptance criteria:
  1. Given `036000291452`, `012345678905`, `4006381333931`, `0036000291452`, and `96385074`, then parsing returns success (proved by: unit).
  2. Given `036000291453`, `12345`, `03600029145A`, an empty string, and a 14-digit string, then parsing returns an invalid barcode failure that states the reason: wrong length, non-digit, or bad check digit (proved by: unit, table-driven).
  3. Given ` 036000291452 ` with spaces around it, then it parses after trimming (proved by: unit).
  4. Given `036000291452` and `0036000291452`, then both produce the same GTIN-13 key `0036000291452`, the same rule as the server in T-025 (proved by: unit).
  5. Given the file, then it imports no Flutter or plugin package (the architecture test from T-012 passes) and has 100% line coverage (proved by: unit, coverage report).

### T-027 App: local database foundation with Drift
- Milestone: M2
- Owner: flutter-developer
- Status: todo
- Depends on: T-012
- UX spec: n/a
- Linked files: app/lib/core/ (database), the schema export folder Drift's tooling uses
- Acceptance criteria:
  1. Given a fresh install, then the database is created at schema version 1 with a table of confirmed barcode matches (GTIN-13 key, bggId, confirmed time) and a table of cached game details (bggId key, data, fetchedAt, lastViewedAt) (proved by: unit with an in-memory database).
  2. Given a confirmed match from `0036000291452` to bggId 13, when a new match from the same code to bggId 822 is saved, then reading the code returns 822 (proved by: unit).
  3. Given 501 cached games, then the least recently viewed one is evicted so 500 remain [ASSUMPTION]; M3 will exempt games in the collection (proved by: unit).
  4. Given the schema, then it is exported for Drift's migration tooling, and a migration test exists that later schema versions extend (proved by: unit).
  5. Given database work, then it runs off the UI isolate [ASSUMPTION] (proved by: manual review).
  6. Given a database error, then the caller receives a Failure, not an exception (proved by: unit with a failing fake).
  7. Given the database code, then line coverage is at least 80% (proved by: unit, coverage report).

### T-028 App: games remote data source
- Milestone: M2
- Owner: flutter-developer
- Status: todo
- Depends on: T-013, T-018
- UX spec: n/a
- Linked files: app/lib/features/*/data/ (the developer records in the handoff which feature folder holds the shared games data source)
- Acceptance criteria:
  1. Given a lookup for `036000291452`, a search for "Café & Co", and a detail request for bggId 13, then the requests go to `/v1/lookup/barcode/0036000291452`, `/v1/games/search` with `q` carrying exactly "Café & Co" (correctly encoded), and `/v1/games/13` on the configured base URL (proved by: unit with a fake HTTP adapter, decoding the captured request).
  2. Given every response fixture in packages/api_contract/test/fixtures/, then each decodes and maps to the matching domain entity, and missing optional fields map to absent values, not empty strings or zeros (proved by: unit).
  3. Given 400 `invalid_barcode`, 400 `invalid_query`, 400 `invalid_bgg_id`, 404 `not_found`, 429 `rate_limited` with Retry-After 30, 503 `upstream_unavailable`, a timeout, and no connection, then each maps to the matching Failure (proved by: unit, table-driven).
  4. Given a 200 whose body does not match the contract, then the result is the unexpected failure and nothing throws (proved by: unit).
  5. Given the architecture test, then package:api_contract is imported only under lib/**/data/, never in domain or presentation (proved by: unit).
  6. Given this data source, then line coverage is at least 80% (proved by: unit, coverage report).

### T-029 App: games repository with on-device cache
- Milestone: M2
- Owner: flutter-developer
- Status: todo
- Depends on: T-027, T-028
- UX spec: n/a
- Linked files: app/lib/features/*/domain/ (repository interface), app/lib/features/*/data/ (implementation)
- Acceptance criteria:
  1. Given a confirmed match for `0036000291452` stored on the device, when a lookup runs for `036000291452`, then it returns that game as matched and the remote fake records 0 calls (proved by: unit).
  2. Given the backend returns status `matched` with one game, then that match is stored on the device as confirmed [ASSUMPTION: a single backend match counts as confirmed until the user corrects it] (proved by: unit).
  3. Given a code that already has a stored match, when the user confirms a different game, then the new match replaces the old one (proved by: unit).
  4. Given the device is online and bggId 13 loads, then the result is marked fresh, the cache is updated, and lastViewedAt is set (proved by: unit).
  5. Given loading bggId 13 fails with no connection, a timeout, or service unavailable, and a cached copy exists, then the cached copy is returned marked stale with its fetchedAt, not a failure (proved by: unit, table-driven).
  6. Given no cached copy and no connection, then the no connection failure is returned (proved by: unit).
  7. Given a title search, then its results are not cached on the device [ASSUMPTION] and failures pass through unchanged (proved by: unit).
  8. Given the repository, then its interface lives in a domain folder and its implementation in a data folder (proved by: unit, architecture test).
  9. Given the repository code, then line coverage is at least 80% (proved by: unit, coverage report).

### T-030 App: scanner screen
- Milestone: M2
- Owner: flutter-developer
- Status: todo
- Depends on: T-003, T-012, T-026; PRD Q4 (user approval of Google ML Kit on Android)
- UX spec: docs/ux/screens/scanner.md
- Linked files: app/lib/features/scanner/presentation/, app/android/ (camera permission), app/ios/Runner/Info.plist (camera usage text)
- Acceptance criteria:
  1. Given the camera permission has never been requested, when the user opens Scan for the first time, then the system permission prompt appears; it never appears at app start or on any other screen (proved by: widget with a fake permission service; manual on an Android phone and an iPhone).
  2. Given permission is granted, when the fake scanner emits EAN-13 `4006381333931`, then the app fires one haptic feedback and opens the lookup result for `4006381333931` (proved by: widget with a fake scanner).
  3. Given a real camera and a printed EAN-13 test label in normal indoor light, then the lookup result opens within 1 s of the label coming into view (proved by: manual on an Android phone and an iPhone).
  4. Given detections in formats other than UPC-A, EAN-13, and EAN-8 (QR, UPC-E, Code 128), then nothing happens (proved by: widget with a fake scanner).
  5. Given a detection with a bad check digit (`036000291453`), then nothing happens: no haptic, no navigation (proved by: widget).
  6. Given the same code detected 5 times within 500 ms, then exactly one navigation happens; after the user comes back to the scanner, the same code can be scanned again. The debounce window is 2 s [ASSUMPTION] (proved by: widget with a fake clock).
  7. Given a device with a torch, then a torch toggle shows, switches the torch on and off, and its label changes between the copy.md on and off strings; given no torch, then the toggle is hidden (proved by: widget with a fake controller; manual on device).
  8. Given permission is denied or permanently denied (on iOS, denied or restricted), then the screen shows the copy.md explanation and an "Open settings" button that opens the app's page in system settings (proved by: widget with a fake permission state; manual on device for the settings link).
  9. Given every scanner state (starting, scanning, denied, camera unavailable), then manual entry and title search are visible and one tap away (proved by: widget).
  10. Given the user switches tabs or sends the app to the background, then the camera stops, and it restarts on return (proved by: widget with a fake controller; manual on device).
  11. Given the device is offline, then scanning still works and opens the lookup result, which handles being offline (proved by: widget).
  12. Given the iOS Info.plist and the Android manifest, then the camera usage text matches docs/ux/copy.md and the store guidance in docs/api-research.md (proved by: manual).
  13. Given both themes at text scale 2.0 in compact and expanded sizes, then nothing overflows and the accessibility guidelines pass, and a successful scan is announced to screen readers with the copy.md text (proved by: widget).
  14. Given the golden list in scanner.md (with the camera preview replaced by a placeholder), then every listed golden exists and passes (proved by: golden).

### T-031 App: manual barcode entry
- Milestone: M2
- Owner: flutter-developer
- Status: todo
- Depends on: T-003, T-026
- UX spec: docs/ux/screens/manual-entry.md
- Linked files: app/lib/features/scanner/presentation/
- Acceptance criteria:
  1. Given the scanner screen or the search screen, when the user taps the manual entry action, then the manual entry screen opens (proved by: widget).
  2. Given the barcode field, then it shows a numeric keyboard, accepts digits only, and stops at 13 characters (proved by: widget).
  3. Given `036000291452` is entered and submitted, then the app opens the lookup result for that code (proved by: widget).
  4. Given `036000291453` or `12345` is submitted, then an inline copy.md error explains the problem, focus stays in the field, the error is announced to screen readers, and there is no navigation (proved by: widget).
  5. Given the initial (empty) state, then the field shows the copy.md helper text. This screen makes no network call, so loading and offline are handled by the lookup result screen; given the device is offline, submitting a valid code still opens the lookup result (proved by: widget).
  6. Given both themes at text scale 2.0 in compact and expanded sizes, then nothing overflows and the accessibility guidelines pass (proved by: widget).
  7. Given the golden list in manual-entry.md, then every listed golden exists and passes (proved by: golden).

### T-032 App: title search screen
- Milestone: M2
- Owner: flutter-developer
- Status: todo
- Depends on: T-003, T-029; PRD Q5 (thumbnails)
- UX spec: docs/ux/screens/search.md
- Linked files: app/lib/features/*/presentation/ (search screen)
- Acceptance criteria:
  1. Given the user types "ca", then a search runs 400 ms after the last keystroke [ASSUMPTION]; given one character, then no search runs and the copy.md hint shows (proved by: widget with a fake timer and a fake repository).
  2. Given results, then each row shows name and year, with a thumbnail when present and a placeholder otherwise, and tapping a row opens the game detail for that bggId (proved by: widget).
  3. Given a search in flight, then skeleton rows show (proved by: widget).
  4. Given zero results, then the copy.md empty state suggests checking the spelling and offers manual barcode entry (proved by: widget).
  5. Given the service unavailable failure, then a plain-language error with a Retry button shows, and Retry runs the same query again (proved by: widget).
  6. Given the device is offline, then the copy.md offline message shows with Retry, and no raw error text appears (proved by: widget).
  7. Given the rate limited failure with 30 s, then the copy.md message asks the user to try again shortly, with Retry available (proved by: widget).
  8. Given the user types "cat" and then "catan", and the "cat" response arrives after the "catan" response, then the "catan" results stay on screen (proved by: widget).
  9. Given the screen was opened for a barcode that had no match, when the user taps a result, then that barcode is stored as a confirmed match for the game and its detail opens (proved by: widget).
  10. Given both themes at text scale 2.0 in compact, medium, and expanded sizes, then nothing overflows, the accessibility guidelines pass, and each row is read by screen readers with its name and year (proved by: widget).
  11. Given the golden list in search.md, then every listed golden exists and passes (proved by: golden).

### T-033 App: lookup result and candidate selection
- Milestone: M2
- Owner: flutter-developer
- Status: todo
- Depends on: T-003, T-029, T-032; PRD Q5 (thumbnails)
- UX spec: docs/ux/screens/lookup-result.md
- Linked files: app/lib/features/scanner/presentation/ (lookup result)
- Acceptance criteria:
  1. Given status `matched`, then the app opens that game's detail directly (proved by: widget with a fake repository).
  2. Given status `candidates` with 3 games, then all 3 show with name, year, and thumbnail or placeholder, plus a search by title action; tapping the second stores it as the confirmed match for the barcode and opens its detail (proved by: widget).
  3. Given status `none`, then the copy.md not-found message shows with actions to search by title and to enter a different barcode (proved by: widget).
  4. Given status `unavailable`, then the copy.md "barcode lookup is not available right now" message shows with a search by title action (proved by: widget).
  5. Given the lookup is in flight, then a skeleton shows (proved by: widget).
  6. Given the device is offline and the code has a confirmed match on the device, then the game detail opens; given offline with no stored match, then the copy.md offline message shows with Retry and a search by title action (proved by: widget).
  7. Given the service unavailable or rate limited failure, then a plain-language error with Retry shows (proved by: widget).
  8. Given the correction entry point (used by "Not this game?" in T-034), when the user picks a different candidate or search result, then the new choice replaces the stored match for that barcode (proved by: widget).
  9. Given both themes at text scale 2.0 in compact, medium, and expanded sizes, then nothing overflows, the accessibility guidelines pass, and candidate rows have screen reader labels with name and year (proved by: widget).
  10. Given the golden list in lookup-result.md, then every listed golden exists and passes (proved by: golden).

### T-034 App: game detail screen
- Milestone: M2
- Owner: flutter-developer
- Status: todo
- Depends on: T-003, T-029, T-033; PRD Q5 (cover images)
- UX spec: docs/ux/screens/game-detail.md (the M2 part)
- Linked files: app/lib/features/game_detail/presentation/
- Acceptance criteria:
  1. Given a game with every field, then the fields game-detail.md lists (for example name, year, cover image, players, play time, designers, publishers, description) show as specified (proved by: widget with a fixture).
  2. Given a game missing optional fields (no year, no image, no designers), then those parts are hidden or show the spec's placeholder, never "null", "0", or an empty label (proved by: widget).
  3. Given the screen, then the BGG attribution that docs/api-research.md requires (logo, wording, link) shows where the spec places it, and its link opens outside the app (proved by: widget and golden; manual check against BGG's rules).
  4. Given loading, then a skeleton shows (proved by: widget).
  5. Given not found, then the copy.md not-found message shows with a search action (proved by: widget).
  6. Given an error with no cached copy, then a plain-language error with Retry shows (proved by: widget).
  7. Given the device is offline and a copy fetched 3 days ago is cached, then the cached data shows with the copy.md "Last updated" label reading 3 days ago, and no error screen (proved by: widget with a fake clock).
  8. Given pull to refresh succeeds, then the data and the "Last updated" label update; given it fails, then the cached data stays and a non-blocking copy.md message appears (proved by: widget).
  9. Given the cover image is loading, fails, or is missing, then a placeholder shows, and the image has the copy.md semantic label (for example "Cover of Catan") (proved by: widget).
  10. Given a 200-character Unicode title, then it wraps without overflow at text scale 2.0 in compact, medium, and expanded sizes (proved by: widget).
  11. Given the screen was opened from a barcode, then a "Not this game?" action opens the correction flow from T-033 for that barcode (proved by: widget).
  12. Given M2, then no collection or pricing sections show yet [ASSUMPTION] (proved by: widget).
  13. Given both themes, then the accessibility guidelines pass (proved by: widget).
  14. Given the M2 golden list in game-detail.md, then every listed golden exists and passes (proved by: golden).

### T-035 App: M2 flow integration test
- Milestone: M2
- Owner: flutter-developer
- Status: todo
- Depends on: T-030, T-031, T-032, T-033, T-034
- UX spec: n/a
- Linked files: app/integration_test/
- Acceptance criteria:
  1. Given a mocked scanner that emits `036000291452` and a fake backend that returns one match for bggId 13, then the game detail for bggId 13 shows (proved by: integration).
  2. Given the fake backend returns 3 candidates, when the test taps the second, then its detail shows; when the same code is scanned again with the fake backend now failing, then the same game opens from the device cache (proved by: integration).
  3. Given status `none`, when the test searches "catan" and picks the first result, then its detail shows and the match is stored for the barcode (proved by: integration).
  4. Given manual entry of `4006381333931`, then the same lookup flow runs (proved by: integration).
  5. Given CI, then these tests run in app.yml on every push, on a target the developer chooses and records in the handoff (proved by: manual, run log).

### T-036 App: test builds for TestFlight and Play internal testing
- Milestone: M2
- Owner: flutter-developer
- Status: blocked
- Depends on: T-014; PRD Q1 (ids), Q6 (Apple Developer and Play Console accounts), Q8 (a backend reachable from a phone). Uploading a build needs the orchestrator to get the user's approval first.
- UX spec: n/a
- Linked files: .github/workflows/app.yml, app/ios/, app/android/
- Acceptance criteria:
  1. Given a manual run of the release job in app.yml, then a signed iOS build is uploaded to TestFlight and appears there for internal testers (proved by: manual).
  2. Given the same run, then a signed Android App Bundle is uploaded to the Play Console internal testing track (proved by: manual).
  3. Given signing keys, certificates, and store API keys, then they exist only as GitHub Actions secrets, none is in the repo, and secret scanning passes (proved by: manual).
  4. Given two runs in a row, then the second has a higher build number, set automatically (proved by: manual).
  5. Given the test build, then API_BASE_URL points to the backend chosen in PRD Q8 (proved by: manual).
  6. Given the handoff, then it lists every secret by name with how to create it, for the orchestrator to put in README.md (proved by: manual).

---

## M3 Collection (stubs)

### T-037 Collection data model and database tables
- Milestone: M3
- Owner: flutter-developer
- Status: todo
- Goal: Drift tables and a tested migration from schema v1 for Owned, Wanted, and Evaluating items with their fields, one list per game at a time.

### T-038 Add to collection and move between lists
- Milestone: M3
- Owner: flutter-developer
- Status: todo
- Goal: From game detail, file a game in one list, and move it to another list later without losing shared fields.

### T-039 Collection list screens with sort, filter, and search
- Milestone: M3
- Owner: flutter-developer
- Status: todo
- Goal: Three lists with sort, filter, and search, fast at 2,000 games, with helpful empty states.

### T-040 Owned item details and edit
- Milestone: M3
- Owner: flutter-developer
- Status: todo
- Goal: View and edit condition, purchase price, purchase date, edition, expansions owned, and notes.

### T-041 Photos for Owned items
- Milestone: M3
- Owner: flutter-developer
- Status: todo
- Goal: Add, view, and delete photos of owned copies, stored only on the device, with permission handling.

### T-042 Wanted and Evaluating details and edit
- Milestone: M3
- Owner: flutter-developer
- Status: todo
- Goal: Target price and priority for Wanted; notes and date added for Evaluating.

### T-043 Manual collection entry
- Milestone: M3
- Owner: flutter-developer
- Status: todo
- Goal: Add a game that has no BGG match by typing its details (scope depends on PRD Q11).

### T-044 Collection offline behavior and metadata refresh
- Milestone: M3
- Owner: flutter-developer
- Status: todo
- Goal: The collection works fully offline, and game metadata refreshes in the background when online, without blocking the user.

### T-045 CSV export
- Milestone: M3
- Owner: flutter-developer
- Status: todo
- Goal: Export each list or the whole collection to CSV through the system share sheet, with formula injection guarded.

### T-046 CSV import
- Milestone: M3
- Owner: flutter-developer
- Status: todo
- Goal: Import a CSV with row-level validation, a preview, and a clear report of skipped rows.

### T-047 Full backup and restore file
- Milestone: M3
- Owner: flutter-developer
- Status: todo
- Goal: Save and restore the whole collection in one versioned file, including photos if PRD Q12 says so, and restore backups from older schema versions.

### T-048 Settings screen with backup, export, and import
- Milestone: M3
- Owner: flutter-developer
- Status: todo
- Goal: The Settings screen with entries for backup, restore, export, and import.

### T-049 Integration test: scan to add to collection
- Milestone: M3
- Owner: flutter-developer
- Status: todo
- Goal: The brief's integration test: mocked scan, lookup, detail, add to Owned, and the game appears in the Owned list.

---

## M4 Pricing (stubs)

### T-050 Affiliate disclosure wording
- Milestone: M4
- Owner: product-manager
- Status: todo
- Goal: Short and full EPN affiliate disclosure text in docs/legal/, checked against EPN and FTC requirements, for the listings view and Settings.

### T-051 API contract: pricing DTOs
- Milestone: M4
- Owner: backend-developer
- Status: todo
- Goal: Price summary, listing, and history DTOs that carry the asking or sold label, source, sample size, and data age.

### T-052 Server: eBay OAuth application token
- Milestone: M4
- Owner: backend-developer
- Status: todo
- Goal: Get, cache, and refresh the eBay application token as docs/api-research.md documents, with secrets only in .env.

### T-053 Server: eBay Browse API client
- Milestone: M4
- Owner: backend-developer
- Status: todo
- Goal: Search by GTIN first and keywords as fallback, used condition, board game category, EPN campaign id passed as documented, itemAffiliateWebUrl with plain URL fallback.

### T-054 Server: listing filter and price statistics
- Milestone: M4
- Owner: backend-developer
- Status: todo
- Goal: Remove lots, bundles, and outliers by documented, tested rules, then compute median, low, high, and count.

### T-055 Server: GET /v1/prices/{bggId}
- Milestone: M4
- Owner: backend-developer
- Status: todo
- Goal: Current price summary and listings, labeled as asking prices, with source and timestamp, inside the eBay budget.

### T-056 Server: looked-up games registry
- Milestone: M4
- Owner: backend-developer
- Status: todo
- Goal: Record which games were looked up and when (no identifiers) so the snapshot job knows the last 90 days [ASSUMPTION].

### T-057 Server: daily snapshot job and eBay call budget
- Milestone: M4
- Owner: backend-developer
- Status: todo
- Goal: A daily snapshot for each tracked game, within the daily call budget, with budget use logged and a warning at 80% [ASSUMPTION].

### T-058 Server: GET /v1/prices/{bggId}/history
- Milestone: M4
- Owner: backend-developer
- Status: todo
- Goal: Daily snapshot history for one game, with the date the history starts.

### T-059 Server: Marketplace Insights behind a feature flag
- Milestone: M4
- Owner: backend-developer
- Status: todo
- Goal: Sold prices from Marketplace Insights, labeled as sold, behind a flag that is off by default until eBay approves access.

### T-060 App: pricing data layer and local price cache
- Milestone: M4
- Owner: flutter-developer
- Status: todo
- Goal: Repository for price summary, listings, and history with on-device cache, so last known prices show offline.

### T-061 App: price summary on game detail
- Milestone: M4
- Owner: flutter-developer
- Status: todo
- Goal: Median, low, high, and count with asking label, source, sample size, and data age; few-listing and stale markers.

### T-062 App: listings with "View on eBay" and affiliate disclosure
- Milestone: M4
- Owner: flutter-developer
- Status: todo
- Goal: Listing rows that open the backend-provided URL outside the app with no confirmation step, plus the inline disclosure.

### T-063 App: price history chart with screen reader summary
- Milestone: M4
- Owner: flutter-developer
- Status: todo
- Goal: An fl_chart history chart with a text summary and an empty state that says when history starts.

### T-064 App: collection total value
- Milestone: M4
- Owner: flutter-developer
- Status: todo
- Goal: Total estimated value of Owned games, labeled as based on eBay asking prices, with the count of games without price data.

### T-065 App: affiliate disclosure in Settings
- Milestone: M4
- Owner: flutter-developer
- Status: todo
- Goal: The full affiliate disclosure from docs/legal/ in Settings.

---

## M5 Hardening and store readiness (stubs)

### T-066 Server: App Attest verification
- Milestone: M5
- Owner: backend-developer
- Status: todo
- Goal: Verify App Attest on every /v1 request from iOS as docs/api-research.md documents. Must land before any public deployment.

### T-067 Server: Play Integrity verification
- Milestone: M5
- Owner: backend-developer
- Status: todo
- Goal: Verify Play Integrity on every /v1 request from Android as docs/api-research.md documents. Must land before any public deployment.

### T-068 App: App Attest on iOS
- Milestone: M5
- Owner: flutter-developer
- Status: todo
- Goal: Generate and attach App Attest assertions to backend requests, with graceful behavior when attestation is unavailable.

### T-069 App: Play Integrity on Android
- Milestone: M5
- Owner: flutter-developer
- Status: todo
- Goal: Request and attach Play Integrity tokens to backend requests, within quota, with graceful fallback.

### T-070 Server: log retention and aggregate counters
- Milestone: M5
- Owner: backend-developer
- Status: todo
- Goal: Delete request logs after 7 days [ASSUMPTION] and keep only aggregate daily counts (no identifiers) for the PRD success measures.

### T-071 Deploy: Oracle VM setup and production Compose runbook
- Milestone: M5
- Owner: backend-developer
- Status: todo
- Goal: A written, reviewed runbook and production Compose and Caddy config for the VM. Running it needs the user's approval.

### T-072 Deploy: daily backups and tested restore
- Milestone: M5
- Owner: backend-developer
- Status: todo
- Goal: Daily PostgreSQL backups kept 14 days [ASSUMPTION], with a restore procedure tested against a scratch database.

### T-073 App: offline behavior audit and fixes
- Milestone: M5
- Owner: flutter-developer
- Status: todo
- Goal: Every screen shows cached data with "Last updated" instead of an error screen when offline.

### T-074 App: error handling audit and fixes
- Milestone: M5
- Owner: flutter-developer
- Status: todo
- Goal: Every failure path shows plain language and Retry, with no raw exceptions anywhere.

### T-075 Accessibility audit
- Milestone: M5
- Owner: ux-designer
- Status: todo
- Goal: Audit every screen against docs/ux/accessibility-checklist.md with TalkBack, VoiceOver, and text at 200%, and file findings.

### T-076 App: accessibility fixes
- Milestone: M5
- Owner: flutter-developer
- Status: todo
- Goal: Fix every finding from T-075.

### T-077 Performance measurement against PRD targets
- Milestone: M5
- Owner: qa-engineer
- Status: todo
- Goal: Measure every target in PRD section 8.3 on the reference devices and report the results.

### T-078 Privacy policy and terms of use
- Milestone: M5
- Owner: product-manager
- Status: todo
- Goal: Drafts in docs/legal/ that match what the app and backend actually do, including third-party processing.

### T-079 App Store privacy label and Google Play Data Safety answers
- Milestone: M5
- Owner: product-manager
- Status: todo
- Goal: Answers in docs/store/ that match the app's real data flows, including ML Kit metrics if approved.

### T-080 Store listing text
- Milestone: M5
- Owner: product-manager
- Status: todo
- Goal: App Store and Google Play listing text in docs/store/, with honest pricing claims (asking prices, eBay US).

### T-081 App: Settings about, privacy, licenses, and attributions
- Milestone: M5
- Owner: flutter-developer
- Status: todo
- Goal: About, privacy policy link, open source licenses, and BGG and eBay attributions in Settings.

### T-082 App: release builds and store submission prep
- Milestone: M5
- Owner: flutter-developer
- Status: todo
- Goal: Signed release builds for both stores, with final ids, icons, and version numbering. Submission needs the user's approval.

### T-083 README and final assumptions, limitations, and risks
- Milestone: M5
- Owner: orchestrator
- Status: todo
- Goal: README complete per the brief, plus the final list of assumptions, known limitations, and open risks.
