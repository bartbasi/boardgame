# boardgame_server

Backend API for the Board Game Collector app: shelf with shelf_router (docs/decisions.md, T-005), compiled with `dart compile exe`. Response shapes come from `packages/api_contract/`.

## Run locally

Needs Dart 3.13 or later.

```sh
cd server
dart pub get
cp .env.example .env        # then edit; .env is git-ignored
set -a; . ./.env; set +a    # Git Bash or Linux: export the variables
dart run bin/server.dart
```

The server reads its configuration only from environment variables (Docker Compose passes them with `env_file`). It does not read `.env` by itself.

| Variable | Required | Allowed values |
|---|---|---|
| `PORT` | yes | integer from 1 to 65535 |
| `LOG_LEVEL` | yes | `debug`, `info`, `warning`, `error` |

If any variable is missing or invalid, the server prints one JSON line to stderr naming every problem (never the values) and exits with code 78 before listening. `server/.env.example` must list exactly the variables the loader reads; a test enforces it.

The build version in `GET /health` is a compile-time define: `dart compile exe -DAPP_VERSION=0.1.0+abc1234 bin/server.dart`. Without it the server reports `0.1.0-dev`.

## Routes

| Route | Notes |
|---|---|
| `GET /health` | `HealthResponse`, outside /v1 so Compose and Caddy health checks need no attestation. |
| anything else | 404 with the `not_found` error envelope. |

Uncaught errors become 500 `internal_error`; the error and stack trace go to the log only.

## Logs

One JSON object per line on stdout: `ts` (UTC ISO 8601), `level`, `msg`, then fields. Every request writes exactly one `request` line with `method`, `route` (the template, for example `/v1/games/{bggId}`, or `<unmatched>`), `status`, and `durationMs`. Request lines are `info`, or `error` for status 500 and above.

Never logged: client IP, headers (including User-Agent and X-Forwarded-For), the raw path of unmatched requests, query strings, and bodies.

## Shutdown

On SIGTERM (or SIGINT) the server stops accepting connections, lets in-flight requests finish for up to 10 seconds, closes whatever is left, and exits 0. Windows cannot watch SIGTERM, so use Ctrl+C there.

## Checks

```sh
dart analyze
dart format --output=none --set-exit-if-changed .
dart test
dart run coverage:test_with_coverage   # writes coverage/lcov.info
```

The real-process SIGTERM test runs only on Linux and macOS. On Windows, run every check on Linux in the official Dart image (Docker, repo mounted read-only):

```sh
sh server/tool/test_linux.sh    # from the repo root
```
