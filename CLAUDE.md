# Board Game Collector App

A commercial Flutter app (iOS and Android) for serious board game collectors, plus a small Dart backend. A collector scans a game box barcode or searches by title, sees current used-market value and price history from eBay US, and files the game as Owned, Wanted, or Evaluating.

- US only, eBay US marketplace only, prices in USD.
- No user accounts or cloud sync in v1. The collection lives only on the phone, with export and import for backup.
- Free, no ads. The only revenue is eBay Partner Network commission on "View on eBay" links. Nothing in the app may block, delay, or require a tap to keep using it.
- BGG license is being applied for as Commercial.
- Out of scope for v1: accounts, cloud sync, social features, buying or selling in the app, importing a BGG collection.

Full requirements live in docs/PRD.md.

## Ground rules (everyone)

1. Never invent API endpoints, fields, limits, or terms. Use docs/api-research.md. If a fact is missing there, say so and ask.
2. If a requirement is unclear or conflicts with an API's terms or a store policy, stop and raise it. Subagents: write it under "Open questions" in the handoff file and say so in your report.
3. No secrets in the repo. Secrets live in git-ignored .env files. Commit a matching .env.example with placeholder values.
4. User-facing copy and docs: no em dashes, and no double hyphens used as dashes. Use commas, colons, periods, or parentheses. Command-line flags such as `--coverage` are fine.
5. Items marked [ASSUMPTION] are unconfirmed. Keep the marker until the user confirms, and record confirmations in docs/decisions.md.
6. New dependencies must be MIT, BSD, or Apache 2.0. Any other license, or any paid service, needs the user's approval first.
7. Never deploy, SSH to the server, or touch production. The orchestrator asks the user first.
8. The app talks only to our backend. Only the backend calls BGG, eBay, and GameUPC.

## File ownership

`.claude/hooks/guard-paths.mjs` enforces write access for every subagent. Paths are relative to the checkout root (the main checkout or a ticket worktree).

| Owner | May write |
|---|---|
| product-manager | docs/PRD.md, docs/backlog.md, docs/api-research.md, docs/legal/, docs/store/, docs/handoffs/ |
| ux-designer | docs/ux/, docs/handoffs/ |
| flutter-developer | app/, .github/workflows/app.yml, docs/handoffs/ |
| backend-developer | server/, deploy/, packages/api_contract/, .github/workflows/server.yml, docs/handoffs/ |
| qa-engineer | app/test/, app/integration_test/, server/test/, packages/api_contract/test/, docs/qa/, docs/handoffs/ |
| code-reviewer | docs/handoffs/ |
| orchestrator (main session) | everything else: CLAUDE.md, README.md, docs/decisions.md, root config, .claude/, .github/workflows/repo.yml |

Every agent may also write its own memory folder, `.claude/agent-memory/<agent-name>/`. Memory folders are committed. Developers in worktrees commit their memory changes on the ticket branch; the orchestrator commits memory changes from agents that do not commit. If you need a change in a file you do not own, describe it in the handoff file and tell the orchestrator.

## Shared state

Subagents do not see the orchestrator's conversation. Everything passes through files:

- docs/PRD.md: product requirements
- docs/backlog.md: tickets (format below)
- docs/ux/: user flows, screen specs, component inventory, copy, accessibility checklist
- docs/api-research.md: verified facts about every external API and policy, with source URL and date checked
- docs/decisions.md: one entry per decision: date, decision, reason, who decided. The orchestrator writes it. Others propose entries in their handoff notes.
- docs/handoffs/<ticket-id>.md: notes between agents on one ticket
- docs/qa/: overall test plan and bug reports that outlive a ticket

### Ticket format (docs/backlog.md)

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

### Handoff file format (docs/handoffs/T-012.md)

```
# T-012 Barcode lookup endpoint
Branch: worktree-<name>   Worktree: .claude/worktrees/<name>/

## Round 1
### Developer notes (backend-developer)
### QA (qa-engineer): PASS | FAIL
### Review (code-reviewer): APPROVED | CHANGES REQUIRED
### UX check (ux-designer): PASS | FAIL        (UI tickets only)
### PM sign-off (product-manager): APPROVED | REJECTED

## Open questions
## Proposed decisions
## Research notes for PM
```

Each agent edits only its own sections. Append a new "Round N" block for each round instead of rewriting old ones.

## Work loop (every ticket)

1. product-manager writes the ticket with testable acceptance criteria.
2. ux-designer writes or updates the screen spec if the ticket touches UI.
3. The developer implements it with tests in its own worktree (`.claude/worktrees/<name>/`, branch `worktree-<name>`, created from local main).
4. qa-engineer runs the full suites in that worktree, adds edge case tests, and writes findings to the handoff file.
5. code-reviewer reviews `git diff main...HEAD` in that worktree and writes must fix, should fix, and suggestion findings.
6. Must-fix findings or failing tests go back to the same developer, resumed with SendMessage so it keeps its context. Repeat 3 to 5.
7. UI tickets: ux-designer checks golden images against the spec. product-manager checks every acceptance criterion and signs off.

A ticket is done only when tests pass, review has no must-fix items, UX passes (UI tickets), and PM approves. Maximum 3 rounds, then the orchestrator escalates to the user.

The ticket worktree is the single workspace for the ticket. QA, reviewer, UX, and PM work in it one at a time, and the handoff file lives there, so the code and its notes merge into main together. Never run two agents in the same worktree at once.

Commits are small and start with the ticket id: `T-012: validate EAN-8 checksum`. Developers and QA commit their own work. The orchestrator commits notes from agents that do not commit (PM, UX, reviewer) and merges finished branches into main.

## Stack

- App: latest stable Flutter and Dart 3, Material 3, Riverpod with code generation, Drift, dio, freezed and json_serializable, fl_chart, mobile_scanner. Minimum Android API 24 and iOS 15 [ASSUMPTION].
- App architecture: feature-first clean architecture (`lib/features/<feature>/{data,domain,presentation}`), pure Dart domain, repository interfaces in domain, sealed failure types instead of exceptions across layers.
- Backend: Dart HTTP server with shelf and shelf_router, compiled with `dart compile exe` (decided in T-005), PostgreSQL, Docker Compose with Caddy, on an Oracle Cloud Always Free VM.
- API contract: request and response DTOs in packages/api_contract/, used by the server and by the app's data layer.
- CI: GitHub Actions [ASSUMPTION].

## Environment

- Dev machine is Windows 11. There is no Mac: iOS builds and signing run on GitHub Actions macOS runners, and iOS testing happens through TestFlight on an iPhone.
- Golden images are rendered only on Linux (CI, or the Docker command recorded in docs/decisions.md) so they match CI exactly. Never commit goldens rendered on Windows.
- Hook commands run in Git Bash on Windows.
