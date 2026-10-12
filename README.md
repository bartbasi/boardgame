# Board Game Collector

A Flutter app (iOS and Android) for board game collectors, with a small Dart backend. Collectors scan a game box or search by title, see current eBay US asking prices, and file games as Owned, Wanted, or Evaluating. Requirements live in [docs/PRD.md](docs/PRD.md).

## Repository layout

- `app/`: Flutter app (T-012)
- `server/`: Dart backend (T-008)
- `packages/api_contract/`: request and response DTOs shared by the app and the server (T-007)
- `deploy/`: Docker Compose, Caddy, and backup setup (T-010, T-071, T-072)
- `docs/`: PRD, backlog, API research, UX specs, decisions, handoffs

## Local setup

Filled in by T-012 (app) and T-008 and T-010 (server and local Docker Compose).

## Registering for BGG, eBay, and GameUPC access

Filled in by T-087 (BGG), T-090 (eBay and eBay Partner Network), and T-088 (GameUPC).

## Environment variables

Filled in by T-008. Secrets live only in git-ignored `.env` files; each has a committed `.env.example`.

## Running tests

Filled in by T-011 and T-014 (server, contract, and app suites) and T-015 (golden images, rendered on Linux only).

## Building releases

Filled in by T-036 (test builds) and T-082 (store release builds, iOS on GitHub Actions macOS runners).

## Deploying to the Oracle VM

Filled in by T-071 (VM setup and production Compose) and T-072 (backups and restore). Deployment is done only with the owner's approval.
