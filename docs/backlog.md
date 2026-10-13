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

- **Window sizes** for widget and golden tests (confirmed in docs/ux/screens/app-shell.md): compact 390 x 844 dp, medium 744 x 1133 dp, expanded 1280 x 800 dp. A fourth size, landscape 844 x 390 dp (phone landscape, expanded by width), is used only for goldens a spec names.
- **Large text:** text scale factor 2.0. Goldens rendered at 2.0 add the suffix `text200` to the state, for example `scanner_denied_text200_light_compact.png`.
- **Accessibility guidelines pass** means flutter_test's `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, and `textContrastGuideline` all pass for the screen, in light and dark themes.
- **Offline** in app tests: the fake data source returns the no-connection failure.
- **No-image mode:** every screen ticket that shows game images includes a widget test with the `showCoverImages` setting off (docs/ux/components.md). Rows lose the thumbnail and headers lose the cover, with no empty gaps or broken layout (BGG-42, PRD Q5). Since PRD Q5 was answered on 2026-10-12 (no images for now), no-image mode is the only mode the app ships with until BGG answers: the API contract has no image URL fields (T-018).
- **BGG attribution:** screens that show BGG data use the BggAttribution component from docs/ux/components.md (`common.bggCredit`, `common.bggLogoLabel`) where the screen spec places it (BGG-40, BGG-41). Until the official logo file arrives from T-087, the spec's placeholder box is used. The ticket records the swap as a follow-up, and the official logo must be in place before release (T-082).
- **Golden names:** `<screen>_<state>_<theme>_<size>.png` under app/test/goldens/, as listed in each screen spec. Screen names use underscores (app_shell, game_detail), and the state may carry a suffix after a second underscore (`price_success`, `longtitle_text200`). Every golden a spec lists is required unless PM removes it from the spec.
- **Fact ids** such as BGG-21 or EBAY-20 point to rows in docs/api-research.md. Blocking risk ids B1 to B11 point to its "Blocking risks" table.
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

Gate before M2 starts: met. The user answered PRD Q5 on 2026-10-12 (no images for now) and Q4 on 2026-10-11 (ML Kit approved), and submitted the BGG application on 2026-10-13 (T-087, waiting for BGG). M2 resumed on 2026-10-13 with the tickets not blocked by BGG, GameUPC, store accounts, or a deployment (docs/decisions.md). The BGG token comes from T-087 and GameUPC production details from T-088 (PRD Q10b), so T-021 to T-025 stay blocked until those arrive. T-036 is blocked on PRD Q6b (store accounts) and Q8 (a deployment).
- Ready on 2026-10-13: T-018, T-019, T-020 (backend), and T-026, T-027 (app). T-030 and T-031 become ready when T-026 is done; T-028 when T-018 is done.

- Backend lane: T-018 first, because the app's T-028 needs the contract. Then T-019, T-021, T-022, T-023, T-024, T-025. T-020 fits anywhere after T-008.
- App lane: T-026 and T-027 start right away (no backend dependency) and can run in parallel worktrees because they touch separate folders. Then T-030 and T-031, then T-028 (after T-018 is merged), T-029, T-032, T-033, T-034, T-035. T-036 when its blockers clear.
- The app lane and the backend lane run in parallel. Within a lane, run tickets in sequence unless noted. Most app tickets touch the router and app/lib/l10n/app_en.arb, and most backend tickets touch the router and server/.env.example.

### M4

- T-084 (eBay account deletion endpoint) must be deployed and verified by eBay before any production eBay API call (EBAY-10). That includes T-085 (category check) and recording production fixtures for T-053. So M4 backend work that needs production eBay data waits for a deployment (PRD Q8, R13). Sandbox calls are not affected.
- T-089 (the question to eBay) and T-090 (eBay and EPN accounts) should be done before M4 starts.

### User tasks

T-087 was submitted on 2026-10-13 and is waiting for BGG (approval can take a week or more after submission, BGG-04). T-088 should start now. T-091 any time. T-089 and T-090 before M4. T-092 and T-094 at launch. T-095 only if the eBay budget runs short.

---

## Planning

### T-001 PRD and first backlog
- Milestone: Planning
- Owner: product-manager
- Status: done
- Depends on: none
- UX spec: n/a
- Linked files: docs/PRD.md, docs/backlog.md, docs/handoffs/T-001.md
- Acceptance criteria:
  1. Given docs/PRD.md, when the user reads it, then it covers goals, users, user stories, features by milestone M1 to M5, pricing rules, monetization constraints, non-functional requirements with numeric targets, external risks, out of scope, assumptions, and open questions (proved by: manual, user review).
  2. Given each [ASSUMPTION] in docs/brief.md (GitHub Actions; Android API 24 and iOS 15; dart_frog or shelf; 90 days), when docs/PRD.md is searched, then each one is present and either still marked or, once the user confirmed it, cites the docs/decisions.md entry instead (GitHub Actions, API 24 and iOS 15, and 90 days were confirmed on 2026-10-11) (proved by: manual).
  3. Given every M1 and M2 ticket in this file, then every criterion is Given, When, Then with concrete values and names a test type, and every ticket has one owner and its dependencies (proved by: manual).
  4. Given docs/PRD.md and docs/backlog.md, when searched for U+2014 and for a double hyphen used as a dash outside code spans, then nothing is found (proved by: manual now; the repo.yml check after T-016).

### T-002 API and store policy research
- Milestone: Planning
- Owner: product-manager
- Status: done
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
- Status: done
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

### T-097 Research fallback game data sources if BGG refuses
- Milestone: Planning
- Owner: product-manager
- Status: done
- Depends on: none (runs in parallel with T-087; PRD Q23 and R1)
- UX spec: n/a
- Linked files: docs/api-research.md (new fallback section), docs/handoffs/T-097.md
- Acceptance criteria:
  1. Given each candidate game data source found, then docs/api-research.md records, as sourced facts (source URL, date checked, quote or close paraphrase, confidence) or as UNVERIFIED with what was tried: its terms for commercial use, including revenue from affiliate commission; its access method (API, data download, or license); its rate limits; its cost; and the attribution it requires (proved by: manual).
  2. Given each candidate, then the file records what data it provides against our needs: title search, the game detail fields in docs/ux/screens/game-detail.md (name, year, players, play time, designers, publishers, description, images), and barcode (UPC or EAN) mapping. Where a candidate has no barcode mapping, the file says whether GameUPC, which returns BGG ids (GUPC-02), could still be used with it (proved by: manual).
  3. Given a source whose terms forbid commercial use, or that could only be used by scraping against its terms, then it is listed as rejected with the reason, not recommended (proved by: manual).
  4. Given all candidates, then a comparison table shows each one against the needs in criterion 2 plus commercial use, limits, and cost (proved by: manual).
  5. Given the comparison, then the handoff gives a recommendation: the best fallback, or "no viable fallback". It says which features would change if we switched (barcode lookup, title search, game detail, attribution), the rough effort, and the cost, and it flags any paid option or non-MIT, BSD, or Apache 2.0 license for the user's approval (CLAUDE.md rule 6) (proved by: manual).
  6. Given a finding that could block or reshape a feature, then it is added to "Blocking risks" in docs/api-research.md and repeated in the report to the orchestrator (proved by: manual).

---

## M1 Foundations

### T-004 Decide: Dart pub workspace or path dependencies
- Milestone: M1
- Owner: orchestrator
- Status: done
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
- Status: done
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
- Status: done
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
- Status: done
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
- Status: done
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
- Status: done
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
  8. Given the build, then it compiles with `-DAPP_VERSION=<pubspec version>+<short git sha>` (T-008 handoff, proposed decision 2), and GET /health on the built image returns that version, not `0.1.0-dev` (proved by: manual).

### T-010 Local Docker Compose with PostgreSQL and Caddy
- Milestone: M1
- Owner: backend-developer
- Status: done
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
  8. Given the server service, then Compose sets `stop_grace_period: 15s` so the server's 10 s drain finishes before Docker sends SIGKILL, and `docker compose stop` during an idle period shows the server exits 0 with a `shutdown complete` log line (T-008 handoff, proposed decision 6) (proved by: manual).
  9. Given the server service, then Docker log rotation is set to `max-size: 10m` and `max-file: 3`, logs go to stdout only, and the handoff states whether a time-based rule is also needed to meet the 7-day retention target [ASSUMPTION], with the option checked against official Docker docs (T-008 handoff, proposed decision 3) (proved by: manual, read the Compose file and `docker inspect`).
  10. Given Caddy's reverse proxy to the server, then its upstream keep-alive is shorter than the server's 65 s idle timeout, with the Caddy setting confirmed in Caddy's official docs (T-008 handoff, proposed decision 6) (proved by: manual).
  11. Given the server service's build, then Compose uses the repo root as the build context and `server/Dockerfile` as the Dockerfile, so server/Dockerfile.dockerignore applies; the handoff lists the files in the build context (for example with `COPY . /ctx` and the same ignore file) and shows that only the allowlisted server and packages/api_contract sources are sent, with no .env, docs, app, or deploy files. The size is not the test: a fresh builder sends about 90 kB, a warm cache about 2 kB (T-009 review R1-G4, T-010 QA bug T-010-B1) (proved by: manual, read the Compose file and the context file list).
  12. Given the server's health check (AC6), then it runs `/app/server --healthcheck`, a server mode that calls /health on localhost and exits 0 on 200 and 1 otherwise (docs/decisions.md 2026-10-12, no busybox, no shell), with unit or endpoint tests for both exit codes (proved by: unit or endpoint, plus manual `docker inspect` health status).
  13. Given the scratch image has no /tmp, then if the server writes any temporary file, Compose mounts a writable tmpfs for it; otherwise the handoff states that no temp files are used (T-009 review R1-G4) (proved by: manual, read the Compose file and grep server/).

Production settings (domain, real certificates, backups) are T-071 and T-072, not this ticket.

### T-011 server.yml CI workflow
- Milestone: M1
- Owner: backend-developer
- Status: done
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
  8. Given the image build, then the cross-compiler binaries that `dart compile exe` downloads for a foreign target and the target-platform dart image are cached between runs, and a build on a fresh builder that has never seen the context (so nothing is skipped as already transferred) sends only the allowlisted files: the workflow fails if the transferred context is larger than the allowlisted files' size plus a small margin, far below the whole repo, proving server/Dockerfile.dockerignore applied to the real build (T-009 review R1-G3; reworded at T-011 sign-off: the earlier "about 2 kB" was a warm-builder figure, the full allowlisted context was about 87 kB) (proved by: manual, run log of two consecutive runs).
  9. Given the built images, then the workflow runs the checks listed in docs/handoffs/T-009.md "What CI (T-011) must verify": (a) the two-platform build from the repo root with `-f server/Dockerfile` and GIT_SHA and APP_VERSION build args succeeds; (b) the amd64 image with PORT and LOG_LEVEL returns 200 on GET /health within 5 s with version `<pubspec version>+<sha>`, and with no env exits 78; (c) the arm64 image passes the same /health smoke test under QEMU or on an arm64 runner; (d) `docker image inspect` shows user `65532:65532` on both platforms and each image is 100 MB or less; (e) a build without GIT_SHA fails (proved by: manual, run log).
  10. Given the image, then nothing is pushed to any registry, public or private, without the user's approval (docs/decisions.md 2026-10-12, glibc and MPL exception) (proved by: manual, read the workflow).

### T-098 server.yml: health check mode and Compose file checks
- Milestone: M1
- Owner: backend-developer
- Status: done (PM approved 2026-10-12; AC3 verified after 2026-10-19 by the orchestrator, who records the first ubuntu-latest Ubuntu 26 run in docs/handoffs/T-098.md and docs/decisions.md)
- Depends on: T-010, T-011 (both done). Can run in parallel with app tickets.
- UX spec: n/a
- Linked files: .github/workflows/server.yml, server/tool/image_smoke_test.sh
- Acceptance criteria:
  1. Given the amd64 and arm64 smoke tests, when the container is running and /health returns 200, then `docker exec <container> /app/server --healthcheck` exits 0, and the step fails on any other exit code (T-011 review R1-G5, T-010 AC12) (proved by: manual, run log for both platforms).
  2. Given a push that changes deploy/, then the workflow runs `docker compose -f deploy/docker-compose.yml --env-file deploy/.env.example config -q` and fails if it exits non-zero (T-011 review R1-G5) (proved by: manual, a scratch branch with a broken Compose file fails, deleted afterward, and a green run on the real file).
  3. Given the first server.yml run on Ubuntu 26 (`ubuntu-latest` moves from 2026-10-19, https://github.com/actions/runner-images/issues/14748), then the handoff records the run id, whether every step passed, and the image sizes reported by `docker image inspect`; if the size meaning changed (for example with the containerd image store), the smoke test wording and limit are updated or the runner is pinned to `ubuntu-24.04`, with a proposed decision (T-011 review R1-G7, T-011 open question 2) (proved by: manual, run log).
  4. Given the changed workflow, then T-011 AC1 to AC10 still hold: read-only permissions, actions pinned by SHA, nothing pushed, and wall time 10 minutes or less [ASSUMPTION] (proved by: manual, run log).

### T-012 App skeleton: project, feature folders, navigation, themes, strings
- Milestone: M1
- Owner: flutter-developer
- Status: done
- Depends on: T-004, T-006
- UX spec: docs/ux/screens/app-shell.md (T-003): four destinations Scan, Search, Collection, Settings, in that order, with Scan as the start destination; seed color `0xFF1F6B5C` (PRD Q31, confirmed 2026-10-12); dynamic color off.
- Linked files: app/
- Acceptance criteria:
  1. Given app/, then it is a Flutter project with Android minSdk 24 and iOS deployment target 15.0 (confirmed, docs/decisions.md 2026-10-11), using the display name and ids from PRD Q1 (placeholders until answered) (proved by: manual, read the build files).
  2. Given lib/features/, then scanner, game_detail, pricing, collection, and settings each have data, domain, and presentation folders, and shared code lives in lib/core/ (proved by: manual).
  3. Given any Dart file under a domain folder, when the architecture test runs, then it fails if the file imports package:flutter, dart:ui, or any plugin package; it passes for the skeleton, and it proves itself against a fixture that contains a forbidden import (proved by: unit).
  4. Given a compact window (390 x 844 dp), then a bottom NavigationBar shows Scan, Search, Collection, and Settings in that order; given a medium, expanded, or landscape window (744, 1280, or 844 dp wide), then a NavigationRail shows them; and the app starts on Scan with nothing shown between launch and the Scan placeholder (proved by: widget).
  5. Given the user scrolls a placeholder list on Collection, switches to Settings, and comes back, then the scroll position is kept; given the user taps the already selected destination, then it returns to that destination's root (proved by: widget).
  6. Given the system theme is dark, then the app uses the dark Material 3 color scheme generated with `ColorScheme.fromSeed` from `0xFF1F6B5C`, the same seed as the light scheme; given light, then the light scheme; dynamic (wallpaper) color is not used (proved by: widget with platform brightness set).
  7. Given each placeholder screen at text scale 2.0 in compact and expanded sizes, then no overflow error is thrown (proved by: widget).
  8. Given the navigation destinations, then each has a semantic label and the accessibility guidelines pass in both themes (proved by: widget).
  9. Given user-facing strings, then they come from app/lib/l10n/app_en.arb through Flutter's localization code generation [ASSUMPTION], with keys matching docs/ux/copy.md once it exists, and no widget contains a hard-coded user-facing string (proved by: manual review).
  10. Given Riverpod code generation, then a generated provider is used by the shell, and the handoff states whether generated files are committed or generated in CI (proved by: unit and manual).
  11. Given an Android emulator at API 24 and one at the newest installed API level, then the app launches and shows the shell in both themes (proved by: manual on emulator).
  12. Given the app, then `flutter analyze` reports zero issues with the shared strict lints and `dart format` is clean (proved by: manual now; CI from T-014).

### T-013 App core: Result, Failure types, and HTTP client with retries
- Milestone: M1
- Owner: flutter-developer
- Status: done
- Depends on: T-012
- UX spec: n/a
- Linked files: app/lib/core/, app/android/app/src/main/AndroidManifest.xml
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
  14. Given `flutter build apk --release`, then the release APK declares `android.permission.INTERNET`, which comes from app/android/app/src/main/AndroidManifest.xml and not only from the debug and profile manifests (T-012 review R1-G5). Check with `aapt dump permissions` on the release APK, recorded in the handoff (proved by: manual).
  15. Given that release APK installed on the API 36 emulator and built with an https API_BASE_URL the emulator can reach (the T-010 local stack if it is ready and its certificate is trusted, otherwise any public https URL the developer records in the handoff), when the HTTP client sends one GET, then it receives an HTTP response, not the no connection failure. The trigger used for this check is not committed (proved by: manual on emulator).
  16. Given a response body that is valid JSON but not a JSON object (`[]`, `"ok"`, `42`, `null`), for a 200 and for a 4xx or 5xx status, then the data layer never passes it to an api_contract `fromJson`: a 200 returns the unexpected failure, an error status maps to its Failure by status code alone, and nothing throws (docs/decisions.md 2026-10-12, T-007: callers check that a body is a JSON object before decoding) (proved by: unit, table-driven).

### T-014 app.yml CI workflow
- Milestone: M1
- Owner: flutter-developer
- Status: done (PM sign-off 2026-10-12, round 3; pull_request trigger and main push iOS build verified at merge, see docs/handoffs/T-014.md)
- Depends on: T-012
- UX spec: n/a
- Linked files: .github/workflows/app.yml
- Acceptance criteria:
  1. Given a push or pull request that changes app/, packages/api_contract/, or .github/workflows/app.yml, then the workflow runs (proved by: manual, observe a run).
  2. Given the workflow, then it uses the Flutter version recorded in docs/decisions.md (3.47.7 today), set in one place in the file (proved by: manual).
  3. Given the ubuntu job, then it resolves dependencies, runs code generation if generated files are not committed, then runs `dart format --output=none --set-exit-if-changed`, `flutter analyze --fatal-infos`, and `flutter test --coverage` (proved by: manual, run log).
  4. Given line coverage below 80% for files under lib/core/ and lib/features/*/domain/ and lib/features/*/data/, then the workflow fails, and the coverage report is uploaded as an artifact in every run (proved by: manual, a scratch branch, deleted afterward).
  5. Given the ubuntu job, then `flutter build apk --debug` succeeds (proved by: manual, run log).
  6. Given a push to main or a manual run, then a macOS job runs `flutter build ios --no-codesign` and succeeds; given a push to any other branch or a pull request, then no macOS job runs. The repository bartbasi/boardgame is private, and macOS builds run only on main and manual runs (docs/decisions.md 2026-10-11) (proved by: manual, run logs for a main push and a branch push).
  7. Given the workflow file, then permissions are read-only and every third-party action is pinned to a full commit SHA (proved by: manual).
  8. Given a typical change, then the ubuntu jobs finish in 15 minutes or less [ASSUMPTION] (proved by: manual).
  9. Given the ubuntu job, then it regenerates every committed generated file: `flutter gen-l10n` and `dart run build_runner build --delete-conflicting-outputs` in app/ (Riverpod and gen-l10n output), and `dart run build_runner build --delete-conflicting-outputs` in packages/api_contract/ (freezed and json_serializable output), then runs `git diff --exit-code` and fails on any difference (docs/decisions.md 2026-10-12, T-007 and T-012). Given a scratch commit that changes a string in app_en.arb without regenerating, then the job fails; the branch is deleted afterward (proved by: manual, run log).

### T-099 app.yml: coverage gate messages and edge cases (T-014 follow-up)
- Milestone: M1
- Owner: flutter-developer
- Status: done
- Depends on: T-014
- UX spec: n/a
- Linked files: app/tool/coverage_check.dart, app/test/tool/, app/test/coverage_imports_test.dart, .github/workflows/app.yml
- Can run in parallel with: T-015 and any backend ticket.
- Acceptance criteria:
  1. Given an lcov report at 100.0% (18/18 lines) and one rule failure (a `coverage:ignore-file` marker in a domain file), when the gate runs, then exactly one output line starts with `FAIL` (the rule failure), the numbers line does not start with `FAIL` and says the minimum was met and the gate failed on 1 rule, `annotations(report)` returns exactly one `::error::` line, and the exit code is 1 (T-014 review R3-S1, QA T-014-N1) (proved by: unit).
  2. Given coverage below the minimum (for example 64.3%, 18/28 lines) and no rule failures, then the numbers line starts with `FAIL` and is the only `::error::` annotation, and the exit code is 1 (proved by: unit).
  3. Given a file in lib/features/*/domain/ or lib/features/*/data/ whose every executable line sits between `// coverage:ignore-start` and `// coverage:ignore-end` (so it reports 0/0 lines), and it is not in `ignoreFileAllowlist`, then the gate fails with a message that names the file and the start/end markers, the same way a `coverage:ignore-file` marker fails. Given the same file in `ignoreFileAllowlist`, then it passes and the reason is printed. Given the same file in lib/core/, then it passes and is listed with its marker count (T-014 review R3-G1) (proved by: unit).
  4. Given the path-only scope helper (`isInScope` today), then it is annotated `@visibleForTesting`, or removed with its tests moved to `evaluateGate`, and the CLI uses only the header-based scope rule; `flutter analyze --fatal-infos` stays clean (T-014 review R3-G2) (proved by: unit and manual, code read in review).
  5. Given a hand-written file in lib/core/, domain, or data whose first directive is `part of`, then the generated imports test does not import it, `--write-imports` output compiles, and the gate report lists it as `part file: <path>` with its library named; the imports test imports the part's library instead, and the part's lines are counted under the part's own path, as lcov reports them (wording changed at T-099 sign-off, review R1-S1). Given a test fixture with such a file, then `flutter test` compiles and the committed imports test stays up to date (T-014 review R2-G3) (proved by: unit).
  6. Given a tag push (for example `v0.0.0-test`), then app.yml does not run; given a push to any branch that changes app/, packages/api_contract/, or .github/workflows/app.yml, then it still runs. Done by adding `branches: ['**']` (or an equivalent filter) to the push trigger (T-014 review R2-G4) (proved by: manual, run list for a scratch tag and a branch push, tag and branch deleted afterward).
  7. Given the ticket branch, then app.yml is green on a push: checks, codegen, and android pass, ios skipped, and the gate prints PASS with its exemptions (proved by: manual, run log id in the handoff).

### T-015 Linux golden image pipeline
- Milestone: M1
- Owner: flutter-developer
- Status: done
- Depends on: T-014
- UX spec: docs/ux/screens/app-shell.md (golden cases). Its two offline goldens need the offline banner and the Search screen, so they are delivered in T-032, not here.
- Linked files: app/test/goldens/, app/test/ (golden helpers and test config), .github/workflows/app.yml
- Note: reworded at sign-off to match the user's decision of 2026-10-12 (goldens render on GitHub Actions only, no local Docker image).
- Acceptance criteria:
  1. Given a pushed branch, when the developer runs these commands from the repository root, then app.yml's manual (workflow_dispatch) render job renders the goldens on ubuntu with the same Flutter version as the CI checks job, uploads them as the artifact `goldens`, and the downloaded PNGs are committed; the handoff gives the exact commands so the orchestrator can record them in docs/decisions.md (proved by: manual, a successful render run plus the commit of its PNGs):
     `gh workflow run app.yml --ref <branch> -f update_goldens=true`
     `gh run list --workflow app.yml --branch <branch> --event workflow_dispatch --limit 1`
     `rm -f app/test/goldens/*.png`
     `gh run download <run-id> --name goldens --dir app/test/goldens`
     `git add -A app/test/goldens`
     `git commit -m "T-0xx: update goldens from app.yml run <run-id>"`
  2. Given goldens produced by that render run and committed, when app.yml runs the golden tests on ubuntu, then they pass with no changes (proved by: CI run on the ticket branch).
  3. Given `flutter test --update-goldens` run directly on Windows or macOS, then the run fails with a message pointing to the app.yml render run (`gh workflow run app.yml --ref <branch> -f update_goldens=true`), and no PNG is written (proved by: unit for the platform guard, plus a manual run on Windows).
  4. Given any golden, then text renders as real, readable glyphs in the app's fonts, not boxes, so UX and PM can review copy (proved by: manual, open the PNG).
  5. Given the golden helper, then it renders a widget at the four shared window sizes (compact, medium, expanded, landscape), in light and dark, at text scale 1.0 and 2.0, and names files `<screen>_<state>_<theme>_<size>.png` under app/test/goldens/, adding the `text200` suffix to the state at text scale 2.0 (proved by: golden).
  6. Given the app shell from T-012, then these goldens exist and pass: app_shell_default_light_compact.png, app_shell_default_dark_compact.png, app_shell_default_light_expanded.png, app_shell_default_dark_expanded.png, app_shell_default_light_medium.png, app_shell_default_light_landscape.png, app_shell_default_text200_light_compact.png, app_shell_default_text200_dark_expanded.png (proved by: golden).
  7. Given a golden mismatch in CI, then the job fails and uploads the diff images as an artifact (proved by: manual, a scratch commit that changes a color, reverted afterward).
  8. Given font files bundled for tests, then their license is recorded in the handoff, and anything other than MIT, BSD, or Apache 2.0 is approved by the user before it is committed (proved by: manual).

### T-016 repo.yml: secret scanning and prose style check
- Milestone: M1
- Owner: orchestrator
- Status: done
- Depends on: none
- UX spec: n/a
- Linked files: .github/workflows/repo.yml, the prose check script (location chosen by the orchestrator)
- Acceptance criteria:
  1. Given any push or pull request, then repo.yml runs secret scanning over the new commits (proved by: manual, observe a run).
  2. Given a scratch branch that commits a fake but well-formed credential (for example a string in AWS access key format), then the job fails and names the file and line; the branch is deleted afterward (proved by: manual).
  3. Given the secret scanner, then its license is MIT, BSD, or Apache 2.0, it is free for this private repository (bartbasi/boardgame, docs/decisions.md 2026-10-11), and any license key requirement is raised with the user before use (proved by: manual).
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
- Status: done
- Depends on: T-004, T-007, T-008, T-012
- UX spec: n/a
- Linked files: .github/workflows/repo.yml, license allowlist and third-party components list (locations chosen by the orchestrator)
- Acceptance criteria:
  1. Given every pubspec.lock in the repo (per T-004), when the check runs on a push or pull request, then it finds the license of every direct, dev, and transitive package and prints the list in the run log (proved by: manual).
  2. Given a package licensed MIT, BSD-2-Clause, BSD-3-Clause, or Apache-2.0, then it passes (proved by: unit with a fixture lockfile and fixture license data).
  3. Given a package with any other license, or a license the tool cannot determine, then the check fails and names the package, version, and license found, unless the package is on the allowlist (proved by: unit).
  4. Given the allowlist, then every entry names the package, the license, and the docs/decisions.md entry where the user approved it; an entry without that reference fails the check (proved by: unit).
  5. Given components the lockfile check cannot see (Docker base images, native SDKs pulled in by plugins such as Google ML Kit, bundled fonts), then each is listed by hand with its license and approval status in the third-party components list, and ML Kit is listed as approved by the user on 2026-10-11 under the Google APIs Terms of Service, with a pointer to docs/decisions.md (MLKIT-01) (proved by: manual).
  6. Given the tool used for the check, then its own license is MIT, BSD, or Apache 2.0 and it is free (proved by: manual).

---

## M2 Identify a game

Backend tickets here depend on T-002 for upstream facts. Do not start one until docs/api-research.md has the facts it needs.

### T-018 API contract: M2 DTOs and error codes
- Milestone: M2
- Owner: backend-developer
- Status: ready
- Depends on: T-007, T-002 (BGG and GameUPC fields), T-003 (what the screens show), all done. PRD Q5 is satisfied: answered 2026-10-12, no cover images or listing photos for now (docs/decisions.md).
- UX spec: n/a (reads search.md, lookup-result.md, game-detail.md)
- Linked files: packages/api_contract/
- Images (PRD Q5): the contract has no image URL fields at all: no thumbnail URL in game summaries and no image URL in game detail. The no-image decision needs none, because every screen runs in no-image mode. If BGG later allows images (T-087), a follow-up ticket adds optional image fields as an additive /v1 change, after the direct-or-proxy decision. The handoff states that no image fields were added.
- Acceptance criteria:
  1. Given the barcode lookup response, then it has the normalized code (a GTIN-13 string), a status of `matched`, `candidates`, `none`, or `unavailable`, and a list of game summaries that is empty for `none` and `unavailable` (proved by: unit, a fixture round trip for each status).
  2. Given a game summary, then it has bggId (a positive integer), name, a nullable year published, and any other field the T-003 specs need that docs/api-research.md confirms BGG provides and lets us show. It has no thumbnail or other image URL field (PRD Q5) (proved by: unit, fixture round trip).
  3. Given the search response, then it has the query as the server normalized it and a list of game summaries (proved by: unit).
  4. Given the game detail response, then it has the fields game-detail.md needs that docs/api-research.md confirms (for example name, year, player count, play time, designers, publishers, description), each nullable where BGG may omit it, plus `fetchedAt` as an ISO 8601 UTC timestamp. It has no image URL field (PRD Q5) (proved by: unit, including a fixture with every optional field missing).
  5. Given a field the specs want that docs/api-research.md does not confirm, then it is left out and listed under "Open questions" in the handoff (proved by: manual).
  6. Given the error codes `invalid_barcode`, `invalid_query`, `invalid_bgg_id`, `not_found`, `rate_limited`, `upstream_unavailable`, and `internal_error`, then each decodes from a fixture, and an unknown code decodes to `unknown` (proved by: unit).
  7. Given packages/api_contract/test/fixtures/, then there is one example JSON file per response type and status, and the app's data layer tests in T-028 reuse them (proved by: unit).
  8. Given the handoff, then it lists every DTO and field added, for the flutter-developer (proved by: manual).
  9. Given the game detail and game summary responses, then they carry the URL of the game's BGG page, built by the backend, so the app's "Powered by BGG" link (BGG-41) never builds BGG URLs itself. The handoff notes how the URL format was confirmed on BGG's site (proved by: unit, fixture round trip).
- Decision needed before work starts (T-008 open question 4): should the contract add a `bad_request` error code (400) as an additive /v1 change for requests whose URL the server cannot parse (bad Host or X-Forwarded-Host)? Today those get 404 `not_found`. If yes, add it to AC6's list with a fixture, note it for the flutter-developer (the app treats it as a generic error), and change the server's rejection path in the same ticket or a follow-up. The orchestrator records the answer in docs/decisions.md.

### T-019 Server: PostgreSQL access, migrations, and database health
- Milestone: M2
- Owner: backend-developer
- Status: ready
- Depends on: T-008, T-010, T-011 (all done)
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
- Carried from T-010: decide the database collation (for example PostgreSQL's builtin provider, `POSTGRES_INITDB_ARGS="--locale-provider=builtin --builtin-locale=C.UTF-8"`, checked against the official PostgreSQL and image docs) and record it in docs/decisions.md before T-071's first database start, because it only takes effect on an empty volume (docs/decisions.md 2026-10-12). Also re-measure PostgreSQL memory under real queries against the 256 MB limit.

### T-020 Server: per-IP rate limiting on /v1
- Milestone: M2
- Owner: backend-developer
- Status: ready
- Depends on: T-008 (done)
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
  8. Given a handler or /v1 guard on a parameterized route such as `/v1/games/<bggId>` that throws an exception whose text holds the path value (for example `ArgumentError.value("secret-123", "bggId")` and a StateError that embeds the request URL), when the request `/v1/games/secret-123` is made, then the response is the 500 `internal_error` envelope and no log line contains `secret-123`: `describeError` logs only `name` and `message` for ArgumentError (never `invalidValue`) and redacts URL paths as well as query strings, keeping scheme and host (T-008 review R2-S1 and QA round 2 note: path text in guard exceptions must not be logged) (proved by: unit with log capture). If a /v1 data endpoint ships before this ticket, this criterion moves to that ticket.
- Design note (T-005, docs/decisions.md 2026-10-12): this ticket designs the rule that X-Forwarded-For is trusted only when the direct peer is Caddy's address on the Compose network (AC4). The handoff states how that address is configured and tested.

### T-021 Server: BGG XML API client and shared request queue
- Milestone: M2
- Owner: backend-developer
- Status: blocked (waiting for BGG's answer to T-087, submitted 2026-10-13)
- Depends on: T-002, T-008, T-087 (a BGG token needs an approved app registration, BGG-01, BGG-02, BGG-04; until then the client is built against recorded fixtures)
- UX spec: n/a
- Linked files: server/ (BGG client and queue), server/test/fixtures/bgg/, server/.env.example
- Acceptance criteria:
  1. Given 5 BGG requests enqueued at the same moment, then they start at 0, 5, 10, 15, and 20 s on a fake clock. There is one queue per server process, with a minimum interval of 5 s by default [ASSUMPTION: BGG publishes no limit, and its wiki says a 5-second wait seems to suffice, BGG-20, BGG-21], configurable (proved by: unit).
  2. Given any BGG request, then it goes to `https://boardgamegeek.com/xmlapi2/` (BGG-30): scheme https, host exactly boardgamegeek.com, never www (BGG-03), using only the search path (BGG-31) and the thing path (BGG-33). Nothing calls BGG's JSON API or other private endpoints (BGG-17) (proved by: unit, capturing requests).
  3. Given 45 game ids needed at once, then the client sends 3 thing requests with 20, 20, and 5 ids, because thing accepts at most 20 ids (BGG-33) (proved by: unit).
  4. Given any BGG request, then it carries the header `Authorization: Bearer <token>` with the token from config (BGG-02). The token never appears in logs, errors, or fixtures, and a missing token fails startup (proved by: unit with log capture, plus a test that scans the fixtures folder for the token pattern).
  5. Given BGG answers 202 twice and then 200, then the client waits at least 5 s and then at least 10 s (doubling, with jitter [ASSUMPTION]) and returns the parsed 200 result; after 5 consecutive 202 answers [ASSUMPTION] it returns an upstream unavailable failure. BGG documents 202 only for collection requests (BGG-23), but the client handles it anyway (proved by: unit with a fake clock).
  6. Given BGG answers 429, 500, or 503 (the wiki says requests sent too often get 500 or 503, BGG-21), then the whole queue pauses, not only that request. It pauses for the Retry-After value when present; otherwise it backs off exponentially with jitter, starting at 10 s, doubling, and capped at 5 minutes [ASSUMPTION; developers report 429 responses without Retry-After, BGG-22, unverified]. The request is retried at most 3 times [ASSUMPTION] and then returns a typed failure (proved by: unit with a fake clock).
  7. Given a timeout (10 s default [ASSUMPTION]) or malformed XML, then the client returns a typed failure and no exception escapes it (proved by: unit with fixtures).
  8. Given an XML fixture whose DOCTYPE declares an external entity pointing to a local file or a URL, then parsing neither reads the file nor makes a network call, and the result is a parse failure or the entity stays unresolved (proved by: unit).
  9. Given search and thing fixtures recorded from real BGG responses with the token scrubbed, then the parser maps them to internal models, including Unicode names such as "Café International" and HTML entities in descriptions decoded to plain text. Field names come from the recorded fixtures and are listed in the handoff, not taken from memory (docs/api-research.md section 1.4). Apart from entity decoding and trimming whitespace, BGG values are not changed (BGG-15) (proved by: unit).
  10. Given the expected wait for a new request (requests already waiting times the interval) is more than 20 s [ASSUMPTION], then the request fails fast with a busy failure, so endpoints can answer 503 with Retry-After instead of hanging (proved by: unit).
  11. Given each upstream call, then one log line records the BGG operation name, status, and duration, with no token and no search text (proved by: unit with log capture).

### T-022 Server: GET /v1/games/{bggId} with 7-day cache
- Milestone: M2
- Owner: backend-developer
- Status: blocked (on T-021, which waits for BGG)
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
  10. Given the migration, then the games table has an internal surrogate primary key and a `bgg_id` column that is unique and nullable (so a game from another source can exist later without one), and no other table uses `bgg_id` as its key (docs/decisions.md 2026-10-11, "Storage keys"). The route still takes `{bggId}` and finds the game through the `bgg_id` column, and responses keep the api_contract field `bggId`; the internal id never appears in a response (proved by: integration against real PostgreSQL, where inserting a second row with bgg_id 13 fails, plus endpoint check of the response body).
- Carried forward from T-013: `upstream_unavailable` must stay 503 with Retry-After (AC7), never 500. The app retries 502, 503, and 504 and maps 500 (`internal_error`) to the unexpected failure with no retry.

### T-023 Server: GET /v1/games/search
- Milestone: M2
- Owner: backend-developer
- Status: blocked (on T-021, which waits for BGG)
- Depends on: T-018, T-019, T-021
- UX spec: n/a
- Linked files: server/ (search route, search cache, migration)
- Acceptance criteria:
  1. Given `q` missing, empty, one character after trimming, or longer than 100 characters [ASSUMPTION], then the endpoint returns 400 `invalid_query` and makes no BGG call (proved by: endpoint, table-driven).
  2. Given `q=catan`, then the endpoint returns 200 with at most 50 results [ASSUMPTION], requesting only the BGG types `boardgame` and `boardgameexpansion` (BGG-31). Developers report that `type=boardgame` also returns expansions (BGG-32, unverified), so the result type comes from each item, not from the request (proved by: endpoint with fixture).
  3. Given results, then exact name matches (case-insensitive) come first and the rest keep BGG's order (proved by: unit).
  4. Given the queries "Catan", " catan ", and "CATAN" within 24 hours [ASSUMPTION], then the second and third are served from the cache and the BGG fake records 1 call in total (proved by: endpoint).
  5. Given a query with no results, then the endpoint returns 200 with an empty list, not 404 (proved by: endpoint).
  6. Given `q` = "Café & Co", then the BGG request carries exactly that text, correctly encoded (proved by: unit, decoding the captured request).
  7. Given BGG is unavailable and nothing is cached, then the endpoint returns 503 `upstream_unavailable` with Retry-After (proved by: endpoint).
  8. Given any search, then the query text does not appear in any log line (proved by: unit with log capture).
  9. Given any 200 response, then it decodes with the api_contract search DTO (proved by: endpoint).
- Carried forward from T-013: `upstream_unavailable` must stay 503 with Retry-After (AC7), never 500. The app retries 502, 503, and 504 and maps 500 (`internal_error`) to the unexpected failure with no retry.

### T-024 Server: GameUPC client
- Milestone: M2
- Owner: backend-developer
- Status: blocked (waiting for the GameUPC operator's answer, T-088)
- Depends on: T-002, T-008, T-088 (production base URL, key, limits, and permission are UNVERIFIED until the operator answers, GUPC-07)
- UX spec: n/a
- Linked files: server/ (GameUPC client), server/test/fixtures/gameupc/, server/.env.example
- Acceptance criteria:
  1. Given a lookup, then the client calls the configured base URL with the `x-api-key` header (GUPC-02), and the key never appears in logs or fixtures. Development and fixture recording may use the documented test endpoint `https://api.gameupc.com/test/upc/{upc}` with its public test key (GUPC-02). The production URL and key come only from config, after T-088 (proved by: unit, capturing requests, with log capture).
  2. Given recorded fixtures with `bgg_info_status` `verified` and one `bgg_info` entry, `choose_from_bgg_info_or_search` with several entries, and an empty `bgg_info`, then the client maps them to a list of BGG ids ordered by `confidence` (GUPC-02). An unknown status with entries maps to candidates, and one without entries maps to no match (proved by: unit).
  3. Given a timeout of 3 s [ASSUMPTION], a 5xx, a 429, or malformed JSON, then the client returns a typed unavailable failure and never throws (proved by: unit, table-driven).
  4. Given a 429 with `Retry-After: 60`, then for the next 60 s the client returns unavailable immediately without calling GameUPC (proved by: unit with a fake clock).
  5. Given 5 consecutive failures [ASSUMPTION], then the client skips calls for 60 s [ASSUMPTION] and then tries again (proved by: unit with a fake clock).
  6. Given GameUPC publishes no rate limit (GUPC-07), then the client sends at most 1 request per second [ASSUMPTION], configurable, until the operator gives a limit (proved by: unit with a fake clock).
  7. Given v1, then the client never calls `update_url` or sends votes, and no request it sends contains a device or user identifier (GUPC-02, PRD Q9) (proved by: unit, capturing requests).
  8. Given the operator's answer from T-088, then the handoff states how the client complies with the permission, limits, caching, and credit terms (proved by: manual).

### T-025 Server: GET /v1/lookup/barcode/{code}
- Milestone: M2
- Owner: backend-developer
- Status: blocked (on T-021 and T-024, which wait for BGG and GameUPC)
- Depends on: T-018, T-019, T-021, T-022, T-024
- UX spec: n/a
- Linked files: server/ (lookup route, barcode validation, mapping store, migration)
- Acceptance criteria:
  1. Given `036000291452`, `4006381333931`, and `96385074`, then they pass validation; given `036000291453`, `12345`, and `03600029145A`, then the endpoint returns 400 `invalid_barcode` and makes no upstream call (proved by: endpoint, table-driven).
  2. Given `036000291452` and `0036000291452`, then both normalize to the GTIN-13 `0036000291452` and share one stored mapping [ASSUMPTION: GTIN-13 is the storage key] (proved by: unit and endpoint).
  3. Given GameUPC returns status `verified` with exactly one BGG id (GUPC-02), then the endpoint returns 200 with status `matched` and one game summary (proved by: endpoint).
  4. Given GameUPC returns several BGG ids, then the endpoint returns 200 with status `candidates` and up to 10 summaries [ASSUMPTION], ordered by GameUPC's `confidence` (GUPC-02) (proved by: endpoint).
  5. Given GameUPC returns no BGG id, then the endpoint returns 200 with status `none` and an empty list, not 404 (proved by: endpoint).
  6. Given GameUPC times out or fails and no mapping is stored, then the endpoint returns 200 with status `unavailable` within 4 s in total [ASSUMPTION], and that answer is not stored as a mapping (proved by: endpoint with a slow fake).
  7. Given a stored mapping younger than 30 days [ASSUMPTION, or the period the GameUPC operator allows, T-088], then GameUPC is not called (proved by: endpoint, fake call count 0).
  8. Given candidates, then each summary has bggId and name. GameUPC's documented fields do not include names (GUPC-02), so names come from the game cache or from one batched BGG thing request of up to 20 ids through the queue (BGG-33). If the BGG queue is busy, the endpoint returns 503 `upstream_unavailable` with Retry-After and stores nothing new (proved by: endpoint).
  9. Given docs/api-research.md confirms GameUPC can return a product name without a BGG id (not confirmed as of 2026-10-11, GUPC-02, GUPC-07), then the backend runs a BGG title search with that name and returns status `candidates` with those results. If it is not confirmed when this ticket starts, this criterion is dropped and the handoff says so (proved by: endpoint).
  10. Given any lookup, then the database receives only the barcode, the mapping, and timestamps, and nothing about the requester (proved by: manual, reviewer and PM read the migration and code).
  11. Given any 200 response, then it decodes with the api_contract lookup DTO (proved by: endpoint).
  12. Given the migration, then the mapping table stores each GTIN-13 once and points to its games by their internal id (a foreign key to the games table from T-022), not by `bgg_id` (docs/decisions.md 2026-10-11, "Storage keys"). A BGG id from GameUPC that has no games row yet gets a row with only `bgg_id` set, which the game cache fills in later. Responses still carry `bggId`, never the internal id (proved by: integration against real PostgreSQL, storing a mapping for `0036000291452` to a BGG id with no cached game, then reading it back by barcode).
- Carried forward from T-013: `upstream_unavailable` must stay 503 with Retry-After (AC8), never 500. The app retries 502, 503, and 504 and maps 500 (`internal_error`) to the unexpected failure with no retry.

### T-026 App: barcode value object and validation
- Milestone: M2
- Owner: flutter-developer
- Status: ready
- Depends on: T-012 (done)
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
- Status: ready
- Depends on: T-012 (done). Windows Developer Mode is on since 2026-10-13, so Flutter plugins build on the dev machine (docs/decisions.md).
- UX spec: n/a
- Linked files: app/lib/core/ (database), the schema export folder Drift's tooling uses
- Acceptance criteria:
  1. Given a fresh install, then the database is created at schema version 1 with a games table (internal surrogate id as primary key, `bgg_id` unique and nullable, cached details data, fetchedAt, lastViewedAt) and a table of confirmed barcode matches (GTIN-13 key, the game's internal id as a foreign key, confirmed time). No table uses `bgg_id` as its key (docs/decisions.md 2026-10-11, "Storage keys") (proved by: unit with an in-memory database).
  2. Given a confirmed match from `0036000291452` to bggId 13, when a new match from the same code to bggId 822 is saved, then reading the code returns 822 (proved by: unit).
  3. Given 501 games with cached details, then the details of the least recently viewed game are evicted so 500 remain [ASSUMPTION]. If a confirmed match points to that game, its row (internal id and `bgg_id`) stays, so reading that barcode still returns the game's bggId. M3 will exempt games in the collection (proved by: unit).
  4. Given the schema, then it is exported for Drift's migration tooling, and a migration test exists that later schema versions extend (proved by: unit).
  5. Given database work, then it runs off the UI isolate [ASSUMPTION] (proved by: manual review).
  6. Given a database error, then the caller receives a Failure, not an exception (proved by: unit with a failing fake).
  7. Given the database code, then line coverage is at least 80% (proved by: unit, coverage report).
  8. Given details for bggId 13 are saved twice, then one games row exists, its internal id is unchanged, and a confirmed match pointing to it still resolves to bggId 13. Repositories take and return `bggId` as in the api_contract; the internal id never leaves the data layer (proved by: unit).

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
  7. Given a response whose Content-Length or bytes read exceed 1 MB [ASSUMPTION], then ApiClient (app/lib/core/data/network/) stops reading, returns the unexpected failure, does not retry, and nothing throws; a 900 KB response still decodes (T-013 review R1-G4) (proved by: unit with a fake HTTP adapter).

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
- Status: todo (becomes ready when T-026 is done; T-003 and T-012 are done, and Windows Developer Mode is on since 2026-10-13)
- Depends on: T-003, T-012, T-026. Google ML Kit on Android was approved on 2026-10-11 with disclosure (PRD Q4, docs/decisions.md, MLKIT-01 to MLKIT-08), so this ticket is no longer blocked by it.
- UX spec: docs/ux/screens/scanner.md
- Linked files: app/lib/features/scanner/presentation/, app/android/ (camera permission), app/ios/Runner/Info.plist (camera usage text)
- Acceptance criteria:
  1. Given the camera permission has never been requested, when the user opens Scan for the first time, then the system permission prompt appears; it never appears at app start or on any other screen (proved by: widget with a fake permission service; manual on an Android phone and an iPhone).
  2. Given permission is granted, when the fake scanner emits EAN-13 `4006381333931`, then the app fires one haptic feedback and opens the lookup result for `4006381333931` (proved by: widget with a fake scanner).
  3. Given a real camera and a printed EAN-13 test label in normal indoor light, then the lookup result opens within 1 s of the label coming into view (proved by: manual on an Android phone and an iPhone).
  4. Given detections in formats other than UPC-A, EAN-13, and EAN-8 (QR, UPC-E, Code 128), then nothing happens (proved by: widget with a fake scanner).
  5. Given a detection with a bad check digit (`036000291453`), then nothing happens: no haptic, no navigation (proved by: widget).
  6. Given the same code detected 5 times within 500 ms, then exactly one navigation happens; after the user comes back to the scanner, the same code can be scanned again. The debounce window is 2 s [ASSUMPTION] (proved by: widget with a fake clock).
  7. Given a device with a torch, then a torch toggle shows and switches the torch on and off, and its visible and semantic labels change between `scanner.torchOn`, `scanner.torchOff`, `scanner.torchLabelOn`, and `scanner.torchLabelOff` as scanner.md assigns them; given no torch, then the toggle is hidden (proved by: widget with a fake controller; manual on device).
  8. Given permission is denied or permanently denied, then the screen shows the copy.md explanation and an "Open settings" button that opens the app's page in system settings. Given iOS reports the camera as restricted (parental or device policy), then the screen shows `scanner.restricted.body` with no settings button, because settings cannot change it (proved by: widget with a fake permission state; manual on device for the settings link).
  9. Given every scanner state (starting, scanning, denied, permanently denied, restricted, camera unavailable), then manual entry and title search are visible and one tap away (proved by: widget).
  10. Given the user switches tabs or sends the app to the background, then the camera stops, and it restarts on return (proved by: widget with a fake controller; manual on device).
  11. Given the device is offline, then scanning still works and opens the lookup result, which handles being offline (proved by: widget).
  12. Given the iOS Info.plist, then `NSCameraUsageDescription` is present (APPLE-01) with the copy.md text `scanner.iosUsageDescription`, which clearly describes the use (APPLE-03). Given the Android manifest, then it declares the CAMERA permission (GPLAY-01), and the app requests it only on the scanner screen (GPLAY-02) (proved by: manual).
  13. Given both themes at text scale 2.0 in compact and expanded sizes, then nothing overflows and the accessibility guidelines pass, and a successful scan is announced to screen readers with the copy.md text (proved by: widget).
  14. Given the golden list in scanner.md (with the camera preview replaced by a placeholder), including the restricted state, then every listed golden exists and passes (proved by: golden).
  15. Given the merged Android manifest, then the camera hardware feature is declared as not required [ASSUMPTION], so the app installs on devices without a camera, where manual entry and title search still work (GPLAY-01) (proved by: manual, read the merged manifest).
  16. Given Android, then the bundled ML Kit model is used [ASSUMPTION], so the first scan works offline without a Google Play services download (MLKIT-06). The handoff records the change in APK size (proved by: manual).
  17. Given a screen reader is on, when the user changes destination with the bar (compact) or the rail (expanded), then the new destination's screen title is announced, for all four destinations, not only Scan (app-shell.md section 7; a T-012 gap, built here because Scan is the first real destination screen) (proved by: widget that captures the announcement; manual with TalkBack).
  18. Given this ticket replaces the Scan placeholder, then the Scan destination no longer uses `devPlaceholderBody`, and any `dev*` key in app_en.arb that no screen uses anymore is deleted. `dev*` keys must not ship (docs/decisions.md 2026-10-12, T-012) (proved by: unit, the strings test; manual grep of lib/).

### T-031 App: manual barcode entry
- Milestone: M2
- Owner: flutter-developer
- Status: todo (becomes ready when T-026 is done; T-003 is done)
- Depends on: T-003, T-026
- UX spec: docs/ux/screens/manual-entry.md
- Linked files: app/lib/features/scanner/presentation/
- Acceptance criteria:
  1. Given the scanner screen or the search screen, when the user taps the manual entry action, then the manual entry screen opens (proved by: widget).
  2. Given the barcode field, then it shows a numeric keyboard, drops non-digit characters as they are typed or pasted (`manualEntry.errorNonDigit` is only the spec's fallback), and stops at 13 characters (proved by: widget).
  3. Given `036000291452` (12 digits), `4006381333931` (13 digits), or `96385074` (8 digits) is entered and submitted, then the app opens the lookup result for that code (proved by: widget).
  4. Given `036000291453` or `12345` is submitted, then an inline copy.md error explains the problem, focus stays in the field, the error is announced to screen readers, and there is no navigation (proved by: widget).
  5. Given the initial (empty) state, then the field shows the copy.md helper text. This screen makes no network call, so loading and offline are handled by the lookup result screen; given the device is offline, submitting a valid code still opens the lookup result (proved by: widget).
  6. Given both themes at text scale 2.0 in compact and expanded sizes, then nothing overflows and the accessibility guidelines pass (proved by: widget).
  7. Given the golden list in manual-entry.md, then every listed golden exists and passes (proved by: golden).
  8. Given a compact window, when the barcode field gets focus, then the NavigationBar hides, and when focus leaves the field, then it returns; given a medium or expanded window, then the rail stays. This is the first text field in the app, so the shell behavior is built here and reused by later screens (app-shell.md section 2 [ASSUMPTION]; PRD Q32: if the user vetoes it, drop this criterion and note it in the handoff) (proved by: widget).

### T-032 App: title search screen
- Milestone: M2
- Owner: flutter-developer
- Status: todo
- Depends on: T-003, T-029. PRD Q5 is answered (2026-10-12, no images for now): the contract has no thumbnail field (T-018), so only no-image mode is built and tested. The thumbnail part of AC2 is deferred to the follow-up ticket that adds images, and the handoff says so.
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
  11. Given the golden list in search.md, then every listed golden exists and passes. This ticket also delivers the two offline goldens from app-shell.md (app_shell_offline_light_compact.png and app_shell_offline_dark_expanded.png), because the offline banner first appears on Search (proved by: golden).
  12. Given results from BGG, then the BggAttribution component (`common.bggCredit`, logo with `common.bggLogoLabel`) shows where search.md places it, following the BGG attribution rule in "Shared test definitions" (BGG-40, BGG-41) (proved by: widget and golden).
  13. Given no-image mode, then result rows show without thumbnails and without gaps (proved by: widget).
  14. Given a compact window, when the search field gets focus, then the NavigationBar hides, and it returns when focus leaves, using the shell behavior from T-031 (app-shell.md section 2 [ASSUMPTION]; PRD Q32: drop if vetoed) (proved by: widget).
  15. Given a medium or expanded window and a hardware keyboard, when the Search screen opens and the user presses Tab, then the first focus stop is the screen content (the search field), not the rail, and Shift+Tab from there reaches the rail (app-shell.md section 7, the "skip" pattern, `shell.skipToContent`; a T-012 gap) (proved by: widget with simulated key events; manual with a hardware keyboard on the emulator).
  16. Given this ticket replaces the Search placeholder, then the Search destination no longer uses `devPlaceholderBody`, and any `dev*` key in app_en.arb that no screen uses anymore is deleted (docs/decisions.md 2026-10-12, T-012) (proved by: unit, the strings test; manual grep of lib/).
- Carried forward from T-013 review R1-G3: `ServiceUnavailableFailure` drops the server's Retry-After today, and copy.md `common.errorUnavailableBody` has no seconds. If search.md or copy.md adds "Try again in N seconds" for service unavailable, this ticket adds an optional `retryAfter` to `ServiceUnavailableFailure` (like `RateLimitedFailure`) with a unit test; otherwise no change.

### T-033 App: lookup result and candidate selection
- Milestone: M2
- Owner: flutter-developer
- Status: todo
- Depends on: T-003, T-029, T-032. PRD Q5 is answered (2026-10-12, no images for now): the contract has no thumbnail field (T-018), so only no-image mode is built and tested. The thumbnail part of AC2 is deferred to the follow-up ticket that adds images, and the handoff says so.
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
  8. Given the correction entry point (used by "Not this game?" in T-034), then the screen uses the correction-mode copy from lookup-result.md and marks the stored game with the "Current match" tag; when the user picks a different candidate or search result, then the new choice replaces the stored match for that barcode (proved by: widget). The expanded two-pane preview in the spec is optional for this ticket.
  9. Given both themes at text scale 2.0 in compact, medium, and expanded sizes, then nothing overflows, the accessibility guidelines pass, and candidate rows have screen reader labels with name and year (proved by: widget).
  10. Given the golden list in lookup-result.md, then every listed golden exists and passes (proved by: golden).
  11. Given the states that show games (matched handoff, candidates, correction mode), then the BggAttribution component shows where lookup-result.md places it, following the BGG attribution rule in "Shared test definitions" (BGG-40, BGG-41) (proved by: widget and golden).
  12. Given no-image mode, then candidate rows show without thumbnails and without gaps (proved by: widget).

### T-034 App: game detail screen
- Milestone: M2
- Owner: flutter-developer
- Status: todo
- Depends on: T-003, T-029, T-033. PRD Q5 is answered (2026-10-12, no images for now): the contract has no image field (T-018), so only the no-image header is built and tested (AC15). The cover image in AC1 and the image loading and failure states in AC9 are deferred to the follow-up ticket that adds images, and the handoff says so. The official "Powered by BGG" logo comes from T-087 (BGG-41); a placeholder is used until then, per "Shared test definitions".
- UX spec: docs/ux/screens/game-detail.md (the M2 part)
- Linked files: app/lib/features/game_detail/presentation/
- Acceptance criteria:
  1. Given a game with every field, then the fields game-detail.md lists (for example name, year, cover image, players, play time, designers, publishers, description) show as specified (proved by: widget with a fixture).
  2. Given a game missing optional fields (no year, no image, no designers), then those parts are hidden or show the spec's placeholder, never "null", "0", or an empty label (proved by: widget).
  3. Given the screen, then the BggAttribution component credits BoardGameGeek by name (`common.bggCredit`) and shows the "Powered by BGG" logo (`common.bggLogoLabel`) at a legible size where game-detail.md places it. It links to the game's BGG page (URL from T-018), which opens outside the app. The logo follows the BGG attribution rule in "Shared test definitions" (BGG-40, BGG-41) (proved by: widget and golden; manual check against BGG's rules).
  4. Given loading, then a skeleton shows (proved by: widget).
  5. Given not found, then the copy.md not-found message shows with a search action (proved by: widget).
  6. Given an error with no cached copy, then a plain-language error with Retry shows (proved by: widget).
  7. Given the device is offline and a copy fetched 3 days ago is cached, then the cached data shows with `gameDetail.updatedLabel` ("Details last updated 3 days ago"), and no error screen (proved by: widget with a fake clock).
  8. Given pull to refresh succeeds, then the data and the "Last updated" label update; given it fails, then the cached data stays and a non-blocking copy.md message appears (proved by: widget).
  9. Given the cover image is loading, fails, or is missing, then a placeholder shows, and the image has the copy.md semantic label (for example "Cover of Catan") (proved by: widget).
  10. Given a 200-character Unicode title, then it wraps without overflow at text scale 2.0 in compact, medium, and expanded sizes (proved by: widget).
  11. Given the screen was opened from a barcode, then a "Not this game?" action opens the correction flow from T-033 for that barcode (proved by: widget).
  12. Given M2, then no collection or pricing sections show yet [ASSUMPTION] (proved by: widget).
  13. Given both themes, then the accessibility guidelines pass (proved by: widget).
  14. Given the M2 golden list in game-detail.md, then every listed golden exists and passes (proved by: golden).
  15. Given no-image mode, or a game with no cover image (BGG-42, PRD Q5), then the header shows no cover and the screen is complete without it, as game-detail.md lays out (proved by: widget, and golden `game_detail_noimages_light_compact.png`).

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
- Status: blocked (on PRD Q6b and Q8)
- Depends on: T-014 (done); PRD Q1 part (a), answered 2026-10-13: the ids are `com.bartbasi.boardgamecollection`; Q6b (individual or company publisher, then the Apple Developer and Play Console accounts; none exists yet as of 2026-10-13); Q8 (a backend reachable from a phone). The final store name (Q1b) is not needed for test builds; the working title "Board Game Collection" is used. Uploading a build needs the orchestrator to get the user's approval first.
- UX spec: n/a
- Linked files: .github/workflows/app.yml, app/ios/, app/android/
- Acceptance criteria:
  1. Given a manual run of the release job in app.yml, then a signed iOS build is uploaded to TestFlight and appears there for internal testers (proved by: manual).
  2. Given the same run, then a signed Android App Bundle is uploaded to the Play Console internal testing track (proved by: manual).
  3. Given signing keys, certificates, and store API keys, then they exist only as GitHub Actions secrets, none is in the repo, and secret scanning passes (proved by: manual).
  4. Given two runs in a row, then the second has a higher build number, set automatically (proved by: manual).
  5. Given the test build, then API_BASE_URL points to the backend chosen in PRD Q8 (proved by: manual).
  6. Given the handoff, then it lists every secret by name with how to create it, for the orchestrator to put in README.md (proved by: manual).
  7. Given the ids from PRD Q1 part (a), then the rename checklist on T-082 is applied before the first upload, unless T-082 already applied it: ids become `com.bartbasi.boardgamecollection`, and the name becomes the working title "Board Game Collection" until Q1b is answered (proved by: manual, the T-082 checklist search).
  8. Given the Android test build installed from the internal testing track on a phone, when the user runs a title search, then results come from the backend chosen in Q8. This proves a store-signed release build reaches the API (T-012 review R1-G5) (proved by: manual on device).

---

## M3 Collection (stubs)

### T-037 Collection data model and database tables
- Milestone: M3
- Owner: flutter-developer
- Status: todo
- Depends on: PRD Q38 (Android Auto Backup and iOS iCloud backup of app data; must be answered before this ticket starts)
- Goal: Drift tables and a tested migration from schema v1 for Owned, Wanted, and Evaluating items with their fields, one list per game at a time. Items point to games by internal id, not `bgg_id` (docs/decisions.md 2026-10-11, "Storage keys").
- Carry-over from T-012 review R1-G4 (becomes criteria when scoped): apply the Q38 answer. Android sets `android:allowBackup` explicitly in the main manifest (GPLAY-14); if backups are off, add `dataExtractionRules` for Android 12+, including the `device-transfer` section (GPLAY-16, GPLAY-17), and rules for Android 11 and lower; on iOS, mark the database and photo files excluded on every save (APPLE-17). If backups stay on, check the 25 MB limit against a 2,000-game collection (GPLAY-15).

### T-038 Add to collection and move between lists
- Milestone: M3
- Owner: flutter-developer
- Status: todo
- Goal: From game detail, file a game in one list, and move it to another list later without losing shared fields.

### T-039 Collection list screens with sort, filter, and search
- Milestone: M3
- Owner: flutter-developer
- Status: todo
- Goal: Three lists with sort, filter, and search, fast at 2,000 games, with helpful empty states, the BggAttribution component where collection.md places it (BGG-40, BGG-41), and a no-image mode widget test.
- Carry-overs from T-012 (become criteria when scoped): replace the Collection placeholder list and placeholder item screen, so `devPlaceholderItem` and `devPlaceholderBody` are no longer used there, and delete any `dev*` key no screen uses anymore (docs/decisions.md 2026-10-12). The list's search field hides the compact bar while focused, using the T-031 shell behavior (PRD Q32). The skip pattern from T-032 holds on Collection.

### T-040 Owned item details and edit
- Milestone: M3
- Owner: flutter-developer
- Status: todo
- Goal: View and edit condition, purchase price, purchase date, edition, expansions owned, and notes, with the BggAttribution component where collection-item-edit.md places it (BGG-40, BGG-41) and a no-image mode widget test.

### T-041 Photos for Owned items
- Milestone: M3
- Owner: flutter-developer
- Status: todo
- Goal: Add, view, and delete photos of owned copies, stored only on the device, with permission handling and a photo library purpose string that clearly describes the use (APPLE-03). UX drafts it; T-003 round 2 left it open.

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
- Carry-over from T-012 (becomes a criterion when scoped): replace the Settings placeholder so `devPlaceholderBody` is no longer used there, and delete any `dev*` key no screen uses anymore (docs/decisions.md 2026-10-12).

### T-049 Integration test: scan to add to collection
- Milestone: M3
- Owner: flutter-developer
- Status: todo
- Goal: The brief's integration test: mocked scan, lookup, detail, add to Owned, and the game appears in the Owned list.

---

## M4 Pricing (stubs)

### T-050 EPN disclosure wording
- Milestone: M4
- Owner: product-manager
- Status: todo
- Depends on: PRD Q25 (wording choice)
- Goal: Disclosure text in docs/legal/: a short line for next to the listings, visible without scrolling, using an EPN-approved phrase ("Affiliate link" is not approved), and a full version for Settings (EBAY-92, EBAY-93). Checked against EPN's rules and FTC guidance.

### T-051 API contract: pricing DTOs
- Milestone: M4
- Owner: backend-developer
- Status: todo
- Goal: Price summary, listing, and history DTOs that carry the asking label (a sold label exists but is unused in v1, EBAY-100), source, sample size, and the fetch time that age limits are measured from (EBAY-20). Listings carry no seller identifiers.

### T-052 Server: eBay OAuth application token
- Milestone: M4
- Owner: backend-developer
- Status: todo
- Depends on: T-090
- Goal: A client credentials token from the eBay token endpoint with the `https://api.ebay.com/oauth/api_scope` scope, kept in memory and reused until it expires after 2 hours, with secrets only in .env (EBAY-30 to EBAY-34).

### T-053 Server: eBay Browse API client
- Milestone: M4
- Owner: backend-developer
- Status: todo
- Depends on: T-052, T-085; T-084 live before any production call
- Goal: item_summary search by `gtin` first (never combined with `q`), keywords as fallback with one `category_ids` value, `conditions:{USED}`, fixed-price listings (the default), `X-EBAY-C-MARKETPLACE-ID: EBAY_US`, the campaign id in `X-EBAY-C-ENDUSERCTX`, itemAffiliateWebUrl with itemWebUrl as fallback, and at most two retries on infrastructure errors (EBAY-40 to EBAY-53, EBAY-72).

### T-054 Server: listing filter and price statistics
- Milestone: M4
- Owner: backend-developer
- Status: todo
- Goal: Remove lots, bundles, and outliers by documented, tested rules, then compute median, low, high, and count for one product. Never category-wide or site-wide statistics (EBAY-23).

### T-055 Server: GET /v1/prices/{bggId}
- Milestone: M4
- Owner: backend-developer
- Status: todo
- Goal: Current price summary and listings, labeled as asking prices, with source and fetch time. Listings are cached at most 6 hours, then deleted, and never served older (EBAY-20, EBAY-21). The cache stores no seller or buyer identifiers [ASSUMPTION]. Stays inside the eBay budget.

### T-056 Server: looked-up games registry
- Milestone: M4
- Owner: backend-developer
- Status: todo
- Goal: Record which games were looked up and when (no identifiers) so the snapshot job knows the last 90 days (confirmed, docs/decisions.md 2026-10-11).

### T-057 Server: daily snapshot job and eBay call budget
- Milestone: M4
- Owner: backend-developer
- Status: todo
- Goal: A daily snapshot of the four statistics for each tracked game, behind a backend flag that stays off until eBay answers (B2, PRD Q24). Stays within the 5,000-call default budget (EBAY-70), with budget use from T-086 logged and a warning at 80% [ASSUMPTION].

### T-058 Server: GET /v1/prices/{bggId}/history
- Milestone: M4
- Owner: backend-developer
- Status: todo
- Goal: Daily snapshot history for one game, with the date the history starts, behind the same flag as T-057. With the flag off, the endpoint reports that history is unavailable.

### T-059 Server: Marketplace Insights behind a feature flag
- Milestone: M4
- Owner: backend-developer
- Status: blocked
- Depends on: eBay granting access, which cannot be requested today (EBAY-100, EBAY-102, EBAY-103); PRD Q27
- Goal: On hold. If access is ever granted: sold prices labeled as sold, behind a flag that is off by default, and eBay's written consent before the data feeds a pricing tool (EBAY-24).

### T-060 App: pricing data layer and local price cache
- Milestone: M4
- Owner: flutter-developer
- Status: todo
- Goal: Repository for price summary, listings, and history with an on-device cache that follows PRD section 6 rule 6: listings older than 6 hours are hidden, including offline (EBAY-20), and summaries are shown only within their age limit.

### T-061 App: price summary on game detail
- Milestone: M4
- Owner: flutter-developer
- Status: todo
- Goal: Median, low, high, and count with asking label, source, sample size, and data age; a few-listings marker; a stale marker after 6 hours; after 24 hours, the "Price too old" state (`price.tooOldTitle`, `price.tooOldBody`) instead of numbers [ASSUMPTION, PRD section 6]; the short EPN disclosure (`common.disclosureShort`) directly above "See eBay listings" inside the price card (EBAY-92); and the history action (`price.seeHistory`) only when history is available. Goldens include `game_detail_price_toold_light_compact.png`.

### T-062 App: listings with "View on eBay" and the EPN disclosure
- Milestone: M4
- Owner: flutter-developer
- Status: todo
- Goal: Listing rows, each showing its own age (`listings.rowAge`, EBAY-20); there is no stale state, because listings older than 6 hours are never shown. Only the "View on eBay" button opens the backend-provided URL outside the app, with no confirmation step; tapping the rest of the row does nothing (PRD Q32). The EPN disclosure (`listings.disclosure`) is the first element of a pinned top region (the left column in landscape and expanded), visible without scrolling at every size, including landscape and text at 200% (EBAY-92, EBAY-93). Offline, or when listings are older than 6 hours, the screen shows `listings.offlineTitle` and `listings.offlineBody` and never shows rows. The BggAttribution component appears where listings.md places it, and there is a no-image mode widget test.

### T-063 App: price history chart with screen reader summary
- Milestone: M4
- Owner: flutter-developer
- Status: todo
- Goal: An fl_chart history chart with a text summary and an empty state that says when history starts. When the backend history flag is off (PRD Q24), the screen shows the "History unavailable" state (`history.unavailableTitle`, `history.unavailableBody`, golden `price_history_unavailable_light_compact.png`), and game detail hides its entry point. The BggAttribution component appears where price-history.md places it.

### T-064 App: collection total value
- Milestone: M4
- Owner: flutter-developer
- Status: todo
- Goal: Total estimated value of Owned games, labeled as based on eBay asking prices. Games whose summary is older than 24 hours count as having no current price data: they are left out of the total, and their rows read `collection.rowPriceMissing` (`collection.totalTooOld`, `collection.totalCoverage`). The total shows the count of games without current price data and an age line that uses "oldest price data".

### T-065 App: affiliate disclosure in Settings
- Milestone: M4
- Owner: flutter-developer
- Status: todo
- Goal: The full EPN disclosure from docs/legal/ in Settings, as visible text. This adds to the disclosure next to the listings and does not replace it (EBAY-92).

### T-084 Server: eBay marketplace account deletion endpoint
- Milestone: M4 (must be live before the first production eBay API call, so it may move earlier; PRD R13)
- Owner: backend-developer
- Status: todo
- Depends on: T-008, T-020; a public HTTPS deployment to go live (PRD Q8, T-071)
- UX spec: n/a
- Linked files: server/ (eBay notification route), server/.env.example
- Acceptance criteria (written in full now because the facts are confirmed, EBAY-10 and EBAY-11):
  1. Given a GET carrying eBay's challenge code, then the response is 200 with the JSON field `challengeResponse` holding the SHA-256 hash of the challenge code, the verification token, and the endpoint URL, joined in that order (EBAY-11). The exact query parameter name and the hash encoding come from the eBay page cited in EBAY-11; if docs/api-research.md does not record them, the developer raises it under "Research notes for PM" before coding (proved by: unit, with a fixed challenge code, token, and URL whose expected hash was computed independently and stored in the fixture).
  2. Given a POST notification, then the endpoint acknowledges it immediately with 200, 201, 202, or 204 (EBAY-11), and no part of the notification body is stored or logged (proved by: endpoint with log capture).
  3. Given the verification token in config, then startup fails unless it is 32 to 80 characters of letters, digits, underscore, or hyphen (EBAY-11) (proved by: unit, table-driven).
  4. Given the endpoint URL in config, then startup fails if it is not https or points to localhost or an internal IP address (EBAY-11) (proved by: unit).
  5. Given this route, then app attestation does not apply, because eBay's servers call it, not our app. It has its own per-IP limit of 60 requests per minute [ASSUMPTION] (proved by: endpoint).
  6. Given the listing cache from T-055, then it stores no seller or buyer identifiers [ASSUMPTION], so acknowledging a notification is all that is needed. The handoff confirms this against the cache schema (proved by: manual, reviewer and PM read the schema).
  7. Given production, then the endpoint is deployed, eBay's verification succeeds, and the subscription shows in the eBay developer portal before any production eBay credential goes on the server (proved by: manual, by the orchestrator with the user's approval).

### T-085 Server: confirm board game category ids with the Taxonomy API
- Milestone: M4 (early)
- Owner: backend-developer
- Status: todo
- Depends on: T-052; T-084 live (this is a production eBay call)
- Goal: Confirm category 2550 and its children 180349 and 19100 for EBAY_US with getDefaultCategoryTreeId and getCategorySubtree (EBAY-60, EBAY-61). Check whether a search on non-leaf 2550 includes its children (UNVERIFIED). Report the results under "Research notes for PM" so they are recorded in docs/api-research.md before T-053 relies on them.

### T-086 Server: daily eBay usage logging
- Milestone: M4
- Owner: backend-developer
- Status: todo
- Depends on: T-052
- Goal: Once a day, read the Browse calls used and remaining with the Developer Analytics getRateLimits method (EBAY-74) and log them. This feeds the 80% budget warning in T-057.

---

## M5 Hardening and store readiness (stubs)

### T-066 Server: App Attest verification
- Milestone: M5 (moves earlier if a deployment happens before M5, PRD Q8)
- Owner: backend-developer
- Status: todo
- Depends on: PRD Q26 (per-install key) and the orchestrator's protection design decision
- Goal: Verify App Attest from iOS installs (APPLE-11 to APPLE-13) in the chosen design. Proposed: verify when a session starts, then issue a short-lived signed server token for later /v1 requests [ASSUMPTION]. Must land before any public deployment.
- Design note (T-005, docs/decisions.md 2026-10-12): the "attest once per session, then a short-lived server token" design is settled in this ticket together with PRD Q26. T-067 follows the same design.

### T-067 Server: Play Integrity verification
- Milestone: M5 (moves earlier if a deployment happens before M5, PRD Q8)
- Owner: backend-developer
- Status: todo
- Depends on: the same design decision as T-066
- Goal: Verify Play Integrity standard request tokens from Android installs in the same design, within the default quota of 10,000 token requests and 10,000 decodes a day across all installs (GPLAY-07 to GPLAY-09). Must land before any public deployment.

### T-068 App: App Attest on iOS
- Milestone: M5
- Owner: flutter-developer
- Status: todo
- Goal: Generate and attest an App Attest key and attach proof to backend requests as the design requires, with the App Attest entitlement (APPLE-12), skipping gracefully where App Attest is unsupported (APPLE-11).
- Carried forward from T-013 review: on a 401, ApiClient refreshes the server token once and repeats the request once, for GET and POST (the server rejected it before processing it), within the same 20 s call deadline. A second 401 returns AccessDeniedFailure. 403 stays AccessDeniedFailure with no retry. Shared with T-069; whichever lands first builds it in lib/core.

### T-069 App: Play Integrity on Android
- Milestone: M5
- Owner: flutter-developer
- Status: todo
- Goal: Play Integrity standard requests on Android, preparing the token provider no more than 5 times a minute per install (GPLAY-09), with graceful fallback.
- Carried forward from T-013 review: on a 401, ApiClient refreshes the server token once and repeats the request once, for GET and POST (the server rejected it before processing it), within the same 20 s call deadline. A second 401 returns AccessDeniedFailure. 403 stays AccessDeniedFailure with no retry. Shared with T-068; whichever lands first builds it in lib/core.

### T-070 Server: log retention and aggregate counters
- Milestone: M5
- Owner: backend-developer
- Status: todo
- Goal: Delete request logs after 7 days [ASSUMPTION] and keep only aggregate daily counts (no identifiers) for the PRD success measures.

### T-071 Deploy: Oracle VM setup and production Compose runbook
- Milestone: M5
- Owner: backend-developer
- Status: todo
- Goal: A written, reviewed runbook and production Compose and Caddy config for an Ampere A1 VM (linux/arm64) within 2 OCPUs and 12 GB in total (OCI-02), created in the home region (OCI-05), and sized or upgraded per PRD Q20 so Oracle does not reclaim it as idle (OCI-07). Running it needs the user's approval.
- Carried from T-009: the first step on the real VM is `docker run` of the arm64 image plus `curl /health`, before any other setup, because the arm64 binary has only run under QEMU with 4 KB pages. Record the VM kernel's memory page size (`getconf PAGESIZE`). Whether the Oracle Ampere A1 images use 4 KB or 64 KB pages, and whether the Dart AOT runtime supports 64 KB pages, is [UNVERIFIED] and not yet in docs/api-research.md.
- Carried from T-010 (docs/handoffs/T-010.md review R1-S1, R1-G4, R1-G6, R1-G7, and the log retention note), each checked against official Docker, Caddy, PostgreSQL, or systemd docs:
  - Publish Caddy's 80 and 443 on public interfaces only in the VM's production Compose; the local file stays on 127.0.0.1.
  - Set `memswap_limit` equal to `mem_limit` for every service, and re-measure PostgreSQL against its 256 MB limit (default 128 MB shared_buffers) with real queries.
  - Pass the database password with `POSTGRES_PASSWORD_FILE` and a Compose secret, so it does not show in `docker inspect`.
  - Caddy: remove the `Server` response header, set a `request_body` size limit, and set explicit server timeouts.
  - Log retention: Docker's journald driver with journald `MaxRetentionSec=7day` and `MaxFileSec=1day` (docs/decisions.md 2026-10-12).
  - Apply the database collation decided in T-019 before the first database start on the VM.
  - The arm64 page size check above (`getconf PAGESIZE`) also applies to the postgres and caddy images.

### T-072 Deploy: daily backups and tested restore
- Milestone: M5
- Owner: backend-developer
- Status: todo
- Goal: Daily PostgreSQL backups kept 14 days [ASSUMPTION] and copied off the VM [ASSUMPTION] to the place chosen in PRD Q21, with a restore procedure tested against a scratch database.

### T-073 App: offline behavior audit and fixes
- Milestone: M5
- Owner: flutter-developer
- Status: todo
- Goal: Every screen shows cached data with "Last updated" instead of an error screen when offline, except eBay data past its age limit (listings after 6 hours, summaries per PRD section 6 rule 6, EBAY-20), which is hidden and replaced by a plain message.

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
- Goal: Drafts in docs/legal/ that match what the app and backend actually do and meet both stores' content rules (APPLE-02, GPLAY-03). They cover image hosts (none while PRD Q5's no-image answer stands), the App Attest per-install record if adopted (PRD Q26), cached search text, operating system backups (PRD Q38, which absorbs Q13), and opening eBay listings.
- Acceptance criteria (only this one so far; the full set comes when the ticket is scoped):
  1. Given the privacy policy, then it states that on Android the barcode scanner uses Google ML Kit, which processes camera images on the device without sending them to Google, and sends ML Kit usage and performance metrics to Google (MLKIT-02, MLKIT-03, MLKIT-04), and that iOS uses Apple's scanner (MLKIT-05). This disclosure is required because the user approved ML Kit on that condition (docs/decisions.md 2026-10-11) (proved by: manual, PM and user review).

### T-079 App Store privacy label and Google Play Data Safety answers
- Milestone: M5
- Owner: product-manager
- Status: todo
- Goal: Answers in docs/store/ that match the app's real data flows: Apple's privacy details, including third-party SDKs (APPLE-04), and the Google Play Data safety form, which is required even if nothing is collected (GPLAY-06). Includes how cached search text is declared, and whether Android Auto Backup copies app data to the user's Google Drive (PRD Q38, GPLAY-14, GPLAY-15).
- Acceptance criteria (only this one so far; the full set comes when the ticket is scoped):
  1. Given the Google Play Data safety answers, then they account for the data Google ML Kit collects on Android (device information, app package and version, performance metrics, and API configuration, as Google's disclosure page lists, MLKIT-04), consistent with the privacy policy's ML Kit disclosure (MLKIT-03). The Apple privacy details answers state that iOS does not use ML Kit (MLKIT-05). This is required by the user's approval (docs/decisions.md 2026-10-11) (proved by: manual, PM and user review).

### T-080 Store listing text
- Milestone: M5
- Owner: product-manager
- Status: todo
- Goal: App Store and Google Play listing text in docs/store/ with honest pricing claims (asking prices, eBay US, APPLE-09), no "eBay" in the app name without EPN approval (EBAY-82), and the Google Play "Contains ads" answer settled together with PRD Q25 (GPLAY-12).

### T-081 App: Settings about, privacy, licenses, and attributions
- Milestone: M5
- Owner: flutter-developer
- Status: todo
- Goal: About, the privacy policy link inside the app (`settings.privacyPolicy`, APPLE-02, GPLAY-03), open source licenses, the ML Kit notice on Android (`settings.mlKitNote`, MLKIT-03; approved on 2026-10-11), and BGG (`settings.bggCredit`) and eBay attributions in Settings.

### T-082 App: release builds and store submission prep
- Milestone: M5
- Owner: flutter-developer
- Status: todo
- Depends on: PRD Q1b (final store name). The ids are known: `com.bartbasi.boardgamecollection` (Q1 part (a), answered 2026-10-13).
- Goal: Signed release builds for both stores, with final ids, icons, and version numbering, and the official "Powered by BGG" logo from T-087 in every BggAttribution (no placeholders left). Submission needs the user's approval.
- Acceptance criteria (only these so far; the full set comes when the ticket is scoped):
  1. Given a release build of the Android app in CI, then it is signed with the upload key from GitHub Actions secrets, not the Flutter template's debug key: the certificate printed by `apksigner verify --print-certs` (or `keytool -printcert -jarfile`) on the App Bundle or APK is the upload certificate and not "Android Debug" (T-012 review R1-G3) (proved by: manual, run log).
  2. Given the release signing settings are missing (no key file or secrets), when a release build runs, then it fails with a message naming the missing setting and produces no artifact. It never falls back to the debug key. Checked once locally and once in CI on a scratch branch without the secrets, deleted afterward (proved by: manual).
  3. Given PRD Q1b is answered, then every item in the rename checklist below has the final value (ids `com.bartbasi.boardgamecollection`, name from Q1b), and `git grep` over app/ for `com.example`, `boardgamecollector` (outside the Dart package name `board_game_collector`), and the placeholder name "Board Game Collector" finds nothing in tracked files (proved by: manual).
  4. Given the release build, then app_en.arb has no key starting with `dev`, and the strings test fails if one is added (docs/decisions.md 2026-10-12, T-012: `dev*` strings must not ship) (proved by: unit).
- Rename checklist for PRD Q1 (from the T-012 handoff, R1-G6). Applied here, or in T-036 if the first test upload comes first (the id must change before any store upload, and it is permanent after that). The new ids are `com.bartbasi.boardgamecollection` (docs/decisions.md 2026-10-13); the Kotlin folder becomes `com/bartbasi/boardgamecollection/`. The display name is the working title "Board Game Collection" until Q1b gives the final name. All items change together:
  - `app/lib/l10n/app_en.arb`: `shellAppName`, then run `flutter gen-l10n`. docs/ux/copy.md `shell.appName` changes too (ux-designer owns it).
  - `app/android/app/src/main/AndroidManifest.xml`: `android:label`.
  - `app/android/app/build.gradle.kts`: `namespace` and `applicationId`.
  - `app/android/app/src/main/kotlin/com/example/boardgamecollector/MainActivity.kt`: the `package` line, and move the file to the folder that matches the new package.
  - `app/ios/Runner/Info.plist`: `CFBundleDisplayName` and `CFBundleName` (under 16 characters).
  - `app/ios/Runner.xcodeproj/project.pbxproj`: `PRODUCT_BUNDLE_IDENTIFIER` (3 Runner entries and 3 RunnerTests entries).
  - `app/pubspec.yaml`: `description`. The Dart package name `board_game_collector` can stay.
  - `app/README.md`: first paragraph.
  - Outside app/: the BGG application (T-087) and the store listings (T-080) use the same name.

### T-083 README and final assumptions, limitations, and risks
- Milestone: M5
- Owner: orchestrator
- Status: todo
- Goal: README complete per the brief, plus the final list of assumptions, known limitations, and open risks.

### T-093 iOS privacy manifest check
- Milestone: M5
- Owner: flutter-developer
- Status: todo
- Goal: Before App Store upload, make sure the iOS build's `PrivacyInfo.xcprivacy` files (ours and every plugin's) accurately declare collected data and required-reason API use (APPLE-15), consistent with T-079's answers.

---

## User tasks

Tasks only the user can do: accounts, applications, and messages to partners. The orchestrator reminds the user when each is due. PM records the answers in docs/api-research.md. Credentials never go into chat, tickets, or the repo; they go only into the server's git-ignored .env.

### T-087 BGG: register the app and apply for a commercial license
- Milestone: Planning (submitted 2026-10-13, waiting for BGG; approval can take a week or more after submission, BGG-04)
- Owner: user
- Status: in-progress (submitted 2026-10-13, waiting for BGG)
- Depends on: none left; the user submitted the application on 2026-10-13 (docs/decisions.md). If the final app name (PRD Q1b) or the publisher (Q6b) later differs from what the application said, the user tells BGG. Q10 (a) and Q23 were answered on 2026-10-11 (docs/decisions.md); fallback research runs in parallel as T-097.
- Goal: Register at https://boardgamegeek.com/applications and send the commercial license application from docs/api-research.md section 1.6, filled in and approved, including the question about cover images (PRD Q5). Once approved, create the Bearer token and download the official "Powered by BGG" logo files (BGG-01, BGG-02, BGG-41).
- Acceptance criteria:
  1. Given BGG answers, then its written answer is shared with PM and recorded in docs/api-research.md (proved by: manual).
  2. Given approval, then the token is in the server's .env only, and the logo files are handed to the flutter-developer for T-034 (proved by: manual).

### T-088 GameUPC: email the operator
- Milestone: Planning (before M2 backend work)
- Owner: user
- Status: todo
- Depends on: PRD Q10b
- Goal: Send the email in docs/api-research.md section 3.3, asking about commercial use, a production key and base URL, rate limits, availability plans, and how to credit GameUPC (GUPC-04, GUPC-07).
- Acceptance criteria:
  1. Given the operator answers, then the answer is shared with PM and recorded in docs/api-research.md, and any production key goes into the server's .env only (proved by: manual).

### T-089 eBay: ask Developer Support about storing price statistics
- Milestone: before M4
- Owner: user
- Status: todo
- Depends on: T-090 (sent from the eBay developer account), PRD Q24
- Goal: Send the question in docs/api-research.md section 2.12. The written answer decides whether the snapshot and history flag may be turned on (B2).
- Acceptance criteria:
  1. Given eBay answers, then the answer is shared with PM and recorded in docs/api-research.md, and PRD section 6 rules 6 and 9 are updated to match (proved by: manual).

### T-090 eBay: developer account, production keyset, and EPN account
- Milestone: before M4
- Owner: user
- Status: todo
- Depends on: PRD Q15
- Goal: Create the eBay developer account and a production keyset, check in the portal that Browse is listed with its daily limit (docs/api-research.md section 2.1, EBAY-70), read the license clauses listed in docs/api-research.md section 8 before accepting the API License Agreement, and create the EPN account and campaign id. No production eBay call is made until T-084 is live (EBAY-10).
- Acceptance criteria:
  1. Given the accounts exist, then PM is told the Browse daily limit shown in the portal and any license wording that differs from docs/api-research.md, and the credentials and campaign id go into the server's .env only (proved by: manual).

### T-091 Confirm "likely" research facts in a browser
- Milestone: Planning (before each fact drives a decision)
- Owner: user
- Status: todo
- Goal: Read the official pages listed in docs/api-research.md section 8 (BGG terms and commercial use pages, the eBay API License Agreement, the eBay call limits page, the EPN agreement and disclosure FAQ). They blocked our page fetcher. Tell PM what differs so the facts can be marked confirmed or corrected.
- Acceptance criteria:
  1. Given each page is read, then PM updates the confidence of the related facts in docs/api-research.md (proved by: manual).

### T-092 EPN: apply for mobile app approval
- Milestone: M5 (right after the store listing goes live)
- Owner: user
- Status: todo
- Depends on: T-082, T-090
- Goal: Submit EPN's mobile app application with the live store link and test access (EBAY-90). Until EPN approves, app traffic may earn nothing (EBAY-91).
- Acceptance criteria:
  1. Given EPN answers, then the answer is shared with PM and recorded (proved by: manual).

### T-094 App Review: permission proof ready
- Milestone: M5
- Owner: user
- Status: todo
- Depends on: T-087; T-092 if it is answered by then
- Goal: Have the written BGG commercial license, GameUPC's permission, and EPN's approval (or the pending application) ready to show Apple on request (APPLE-08).
- Acceptance criteria:
  1. Given an App Store submission, then the documents are on hand, and a short note for the reviewer is drafted in docs/store/ by PM (proved by: manual).

### T-095 eBay: Application Growth Check, if the budget runs short
- Milestone: after launch (only if needed)
- Owner: user
- Status: todo
- Depends on: T-086 logs showing usage near the daily limit
- Goal: Apply for the free Application Growth Check to raise the 5,000-call daily Browse limit (EBAY-70, EBAY-72, EBAY-73). The backend-developer first prepares the compliance points it reviews (current API versions, at most two retries, no needless calls).
- Acceptance criteria:
  1. Given eBay's decision, then the new limit is recorded in docs/api-research.md and the snapshot budget setting is updated (proved by: manual).
