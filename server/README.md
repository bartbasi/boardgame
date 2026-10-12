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

Uncaught errors become 500 `internal_error`; the error type, a redacted description, and the stack trace go to the log only.

Add a /v1 endpoint in `buildApp` (lib/src/app.dart) with `v1.get('/games/<bggId>', handler)` and read `request.params['bggId']`. The log template (`/v1/games/{bggId}`) is derived automatically.

Middleware order, outermost first:

1. request log: one line per request, including 401, 429, and 500 responses;
2. error boundary: any throw, including from the /v1 guards, becomes a 500 envelope;
3. root router: `/health`, and `/v1` mounted behind the `v1Middleware` list. Every request under /v1, matched or not, passes through that list. Per-IP rate limiting (T-020) and then attestation (T-066) go there.

The error boundary sits outside the /v1 guards on purpose: an exception thrown by a guard must still become our envelope, because anything that escapes to shelf_io is printed as plain text with the raw URL.

## HTTP listener

`bindAndServe` (lib/src/http/serve.dart) binds the `HttpServer` itself instead of using `shelf_io.serve`, because shelf_io 1.4.2 prints the raw URL, query string, and stack trace to stderr when it cannot build a request URL (dart:io builds it from the client's Host, X-Forwarded-Host, and X-Forwarded-Proto headers) and for stray async errors. Our listener checks the URL first and answers a bad one with the 404 `not_found` envelope and one `request` line; stray async errors go through our logger in a guarded zone. Nothing reaches stdout or stderr except our JSON lines (test/process/stray_output_test.dart).

- Idle keep-alive timeout: 65 seconds (`serverIdleTimeout`). Caddy's upstream keep-alive (T-010) must be shorter.
- Request bodies: no route reads a body yet. The first ticket that does must set a body size limit and reject larger bodies before reading them.

## Logs

One JSON object per line on stdout: `ts` (UTC ISO 8601), `level`, `msg`, then fields. Every request writes exactly one `request` line with `method` (standard methods only, anything else is `<other>`), `route` (the template, for example `/v1/games/{bggId}`, or `<unmatched>`), `status`, and `durationMs`. Request lines are `info`, or `error` for status 500 and above.

Never logged: client IP, headers (including User-Agent and X-Forwarded-For), the raw path, query strings, bodies, and non-standard method names.

Errors (`Logger.error`) are written as `errorType` (the runtime type), `error`, and `stack`. The `error` text comes from `describeError` (lib/src/logging/error_description.dart):

- FormatException: only its message, never its source (the raw input).
- HttpException and SocketException: only their message, never the URI or address.
- Anything else: `toString()` with URL query strings and URL user info replaced by `<redacted>`.
- At most 300 characters.

That is a safety net. The rule for new code: never put request data (barcodes, queries, ids from the client), tokens, API keys, or upstream response bodies into exception messages or log fields.

## Shutdown

On SIGTERM (or SIGINT) the server stops accepting connections, lets in-flight requests finish for up to 10 seconds, closes whatever is left, and exits 0. Windows cannot watch SIGTERM, so use Ctrl+C there.

Docker sends SIGKILL 10 seconds after SIGTERM by default, which would cut the drain short and exit 137. Docker Compose (T-010) must set `stop_grace_period: 15s` on the server service. If the drain time changes, change both numbers together.

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
