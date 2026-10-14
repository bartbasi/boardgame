# boardgame_server

Backend API for the Board Game Collector app: shelf with shelf_router (docs/decisions.md, T-005), compiled with `dart compile exe`. Response shapes come from `packages/api_contract/`.

## Run locally

Needs Dart 3.13 or later and a PostgreSQL 18 server (for example the throwaway container under "Checks"; point the `DATABASE_*` variables at it).

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
| `DATABASE_HOST` | yes | PostgreSQL host name or IP address (`postgres` in Compose) |
| `DATABASE_PORT` | no, default 5432 | integer from 1 to 65535 |
| `DATABASE_NAME` | yes | database name, at most 63 bytes |
| `DATABASE_USER` | yes | login role, at most 63 bytes; must be allowed to create tables (it runs the migrations) |
| `DATABASE_PASSWORD` | yes | any non-blank text; never logged or printed |
| `DATABASE_POOL_MAX` | no, default 5 [ASSUMPTION] | maximum open connections, 1 to 20 |

If any variable is missing or invalid, the server prints one JSON line to stderr naming every problem (never the values) and exits with code 78 before listening. `server/.env.example` must list exactly the variables the loaders read (`Config.load` and `DatabaseConfig.load`); a test enforces it.

The build version in `GET /health` is a compile-time define: `dart compile exe -DAPP_VERSION=0.1.0+abc1234 bin/server.dart`. Without it the server reports `0.1.0-dev`.

## Routes

| Route | Notes |
|---|---|
| `GET /health` | `HealthResponse` plus `database`, outside /v1 so Compose and Caddy health checks need no attestation. 200 `{"status":"ok","version":"...","database":"ok"}` when PostgreSQL answers; 503 `{"status":"unavailable","version":"...","database":"unavailable"}` otherwise, within 2 s (T-019). |
| anything else | 404 with the `not_found` error envelope. |

Uncaught errors become 500 `internal_error`; the error type, a redacted description, and the stack trace go to the log only.

Add a /v1 endpoint in `buildApp` (lib/src/app.dart) with `v1.get('/games/<bggId>', handler)` and read `request.params['bggId']`. The log template (`/v1/games/{bggId}`) is derived automatically.

Middleware order, outermost first:

1. request log: one line per request, including 401, 429, and 500 responses;
2. error boundary: any throw, including from the /v1 guards, becomes a 500 envelope;
3. root router: `/health`, and `/v1` mounted behind the `v1Middleware` list. Every request under /v1, matched or not, passes through that list: per-IP rate limiting (T-020) first, then attestation (T-066).

## Rate limiting

Every request under /v1 (matched or not) counts against its client's limit; /health and other paths outside /v1 never do (lib/src/http/rate_limit.dart, rate_limiter.dart).

- Limit: `RATE_LIMIT_PER_MINUTE` requests (default 60 [ASSUMPTION]) per client in a fixed one-minute window that starts with the client's first request. Over the limit: 429 with the `rate_limited` envelope and `Retry-After` in whole seconds (rounded up, at least 1) until that window ends. Refused requests do not extend the window.
- Client: the socket peer address. Only when the peer is listed in `TRUSTED_PROXY_ADDRESSES` (Caddy, 10.213.7.10 in deploy/docker-compose.yml) is the client the last X-Forwarded-For entry, the one Caddy added; entries before it are client-supplied and ignored. From any other peer, X-Forwarded-For is ignored. A trusted peer without a valid last entry is limited by its own address.
- Key: IPv4 by full address (IPv4-mapped IPv6 counts as IPv4); IPv6 by its /64 prefix [ASSUMPTION], because one subscriber usually holds a whole /64.
- Privacy: keys live only in the limiter's memory, never in logs or the database, and each is removed once its window has passed. The 429 still writes the normal `request` line (route `<unmatched>`, since routing never ran), with no address.
- Memory: at most `RATE_LIMIT_MAX_TRACKED_IPS` keys (default 100,000 [ASSUMPTION], at most 200,000). When full, the oldest key is evicted, and a warning `rate limiter full, evicting oldest entries` with `maxTracked` is logged at most once a minute. Measured on Windows x64 with an AOT build (2026-10-14): filling 100,000 keys grew RSS by about 10 MB the first time (map resizing) and about 5 MB for a second limiter; 1,000,000 hits with eviction took about 0.3 s.

The error boundary sits outside the /v1 guards on purpose: an exception thrown by a guard must still become our envelope, because anything that escapes to shelf_io is printed as plain text with the raw URL.

## HTTP listener

`bindAndServe` (lib/src/http/serve.dart) binds the `HttpServer` itself instead of using `shelf_io.serve`, because shelf_io 1.4.2 prints the raw URL, query string, and stack trace to stderr when it cannot build a request URL (dart:io builds it from the client's Host, X-Forwarded-Host, and X-Forwarded-Proto headers) and for stray async errors. Our listener checks the URL first and answers a bad one with the 404 `not_found` envelope and one `request` line; stray async errors go through our logger in a guarded zone. Nothing reaches stdout or stderr except our JSON lines (test/process/stray_output_test.dart).

- Idle keep-alive timeout: 65 seconds (`serverIdleTimeout`). Caddy's upstream keep-alive must be shorter; deploy/Caddyfile sets 30 s.
- Request bodies: no route reads a body yet. The first ticket that does must set a body size limit and reject larger bodies before reading them.

## Logs

One JSON object per line on stdout: `ts` (UTC ISO 8601), `level`, `msg`, then fields. Every request writes exactly one `request` line with `method` (standard methods only, anything else is `<other>`), `route` (the template, for example `/v1/games/{bggId}`, or `<unmatched>`), `status`, and `durationMs`. Request lines are `info`, or `error` for status 500 and above.

Never logged: client IP, headers (including User-Agent and X-Forwarded-For), the raw path, query strings, bodies, and non-standard method names.

Errors (`Logger.error`) are written as `errorType` (the runtime type), `error`, and `stack`. The `error` text comes from `describeError` (lib/src/logging/error_description.dart):

- FormatException: only its message, never its source (the raw input).
- HttpException and SocketException: only their message, never the URI or address.
- ArgumentError, RangeError, and IndexError: only the type, `name`, and `message`, never the invalid value (it is often a path parameter, T-020 AC8).
- Anything else: `toString()`.
- In every case, absolute URLs keep only scheme and host: user info, path, query string, and fragment become `<redacted>` (for example `http://localhost/<redacted>?<redacted>`). A query string outside a URL (`?q=...`) is redacted too. A relative path such as shelf's `request.url` (`games/123`) is not recognized, so never put one in an exception message.
- At most 300 characters.

That is a safety net. The rule for new code: never put request data (barcodes, queries, ids from the client), tokens, API keys, or upstream response bodies into exception messages or log fields.

## Database

PostgreSQL 18 through the `postgres` package (BSD-3-Clause), one connection pool per process (lib/src/db/database.dart): at most `DATABASE_POOL_MAX` connections, 5 s to connect (waiting for a free slot included), 10 s per query unless a call passes its own limit. TLS is off because PostgreSQL is reached only over Compose's internal `db` network; the image authenticates network clients with scram-sha-256, so the password is not sent in clear text. A connection that fails is dropped and reopened on next use, so the pool recovers by itself.

Startup order (lib/src/server_runner.dart):

1. Config (exit 78 on any problem).
2. Wait for PostgreSQL: `SELECT 1` every second for up to 30 s, then exit 69 (EX_UNAVAILABLE) with a `database unreachable` line. Settings that retrying cannot fix end this step at once, after the first attempt, with the same exit code and line plus `"permanent":true`: SQLSTATE 28P01 (wrong password), 28000 (role not allowed), and 3D000 (no such database). The log has the SQLSTATE, never the password.
3. One `database ready` line with `serverVersion`, `localeProvider`, `locale`, and `encoding`.
4. Migrations (below). Failure: exit 70 (EX_SOFTWARE).
5. Listen.

A shutdown signal during steps 2 to 4 ends startup after the current step (a running migration finishes) and exits 0.

### Migrations

lib/src/db/migrations.dart lists every migration as a Dart constant (the scratch image has nothing but the executable, so there are no SQL files to read). Each has a `version` (1, 2, 3, ... with no gaps), a snake_case `name`, and `sql`.

- At startup the server takes a PostgreSQL advisory lock (key 7019019), creates `schema_migrations (version, name, checksum, applied_at)` if needed, and checks the recorded history: it must be 1..n with the SHA-256 checksum of each migration's SQL. A database at a version this server does not know, a gap, or an edited migration stops startup (`migrations cannot run`, exit 70).
- Each pending migration runs in its own transaction together with its `schema_migrations` row. If it fails, the transaction rolls back (nothing of it remains), the server logs `migration failed` with `version`, `name`, the SQLSTATE, and PostgreSQL's message about our SQL (`dbMessage`, `position`), and exits 70 without listening. Migrations before it stay applied.
- Rules: append only (never edit, reorder, or remove a merged migration; add a new one); no statements that cannot run in a transaction (`CREATE INDEX CONCURRENTLY`, `VACUUM`); no transaction control (`BEGIN`, `START TRANSACTION`, `COMMIT`, `END`, `ROLLBACK`, `ABORT`, `SAVEPOINT`, `RELEASE`, `PREPARE TRANSACTION`, in any form), because a `COMMIT` would end the migration's transaction and a later failure could no longer roll it back: startup refuses such a migration (exit 70, `migrations cannot run`) before touching the database, while `BEGIN ... END` inside a `$$` PL/pgSQL body or a `BEGIN ATOMIC` body is fine; no parameters (the SQL is sent with the simple query protocol, so several statements may be separated by semicolons); no column for a user id, device id, IP address, or user agent (T-019 AC8; test/db/migrations_test.dart checks the SQL and the migrated schema).
- Keys: every table gets our own surrogate key; external ids such as `bgg_id` are unique columns (docs/decisions.md 2026-10-11). Migration 1 creates `games (id, bgg_id, created_at)`; T-022 adds the cached BGG fields.
- Logs: `migration applied` (`version`, `name`, `durationMs`) for each one, then `database schema up to date` (`version`, `appliedNow`).

### Errors from PostgreSQL in logs

`describeError` logs a PostgreSQL server error as its severity and SQLSTATE only (for example `ServerException: error 23505`), because the message, detail, and hint can quote values from a query ("Key (bgg_id)=(13) already exists"). Other errors of the driver (`PgException`) are logged as type and severity only (for example `PgException: error`), because some of their messages quote a query parameter. Look the code up at https://www.postgresql.org/docs/18/errcodes-appendix.html. Only the migration failure line adds PostgreSQL's message, because it is about our own SQL.

## Shutdown

On SIGTERM (or SIGINT) the server stops accepting connections, lets in-flight requests finish for up to 10 seconds, closes whatever is left, closes the database pool (at most 5 s more), and exits 0. Windows cannot watch SIGTERM, so use Ctrl+C there.

Docker sends SIGKILL 10 seconds after SIGTERM by default, which would cut the drain short and exit 137. deploy/docker-compose.yml sets `stop_grace_period: 15s` on the server service. If the drain time changes, change both numbers together.

## Health check mode

`server --healthcheck` (in the image: `/app/server --healthcheck`) does not serve. It reads PORT through the same config loader, calls `GET http://127.0.0.1:$PORT/health` with a 3 s limit (no proxy, no redirects), and exits:

| Exit code | When |
|---|---|
| 0 | /health answered 200. Prints nothing. |
| 1 | Any other status, timeout, connection refused, malformed response, invalid config, or any other error (logged by type only). Prints one JSON line on stderr with `msg: healthcheck failed` and a fixed `reason` (plus `status` or `timeoutMs`), never a body or config value. |
| 64 | Any other command-line arguments (the server itself takes none). |

It uses 127.0.0.1, not `localhost`, because the server listens on IPv4 and `localhost` can resolve to ::1. Docker keeps the output in `docker inspect` under `State.Health.Log`. Each check also produces one normal `request` line in the server's log.

## Docker image

`server/Dockerfile` builds a `scratch` image with only the AOT executable (`/app/server`) and the official Dart image's `/runtime/` files (glibc, CA certificates) for linux/arm64 and linux/amd64. It runs as user `65532:65532`. The build context is the repo root; `server/Dockerfile.dockerignore` lets in only the two pubspecs, the two lockfiles, `server/bin/`, `server/lib/`, and `packages/api_contract/lib/`, and never `.env` files.

```sh
# from the repo root; passes GIT_SHA so /health reports 0.1.0+<short sha>
sh server/tool/docker_build.sh --platform linux/amd64 --load -t boardgame-server:local
sh server/tool/docker_build.sh --platform linux/arm64,linux/amd64     # both platforms, build only

docker run --rm --env-file server/.env -p 127.0.0.1:8080:8080 boardgame-server:local
```

- The build stage runs on the build machine's own platform and cross-compiles with `dart compile exe --target-os=linux --target-arch=arm64|x64` (Dart 3.8 and later, https://dart.dev/tools/dart-compile), so building arm64 needs no CPU emulation. Cross-compiling downloads extra Dart SDK binaries during the build, so the build needs network access. An early layer compiles an empty program for the target, so that download sits in its own cached layer and is not repeated when the code changes (T-011).
- Smoke test a loaded image: `sh server/tool/image_smoke_test.sh boardgame-server:local linux/amd64 0.1.0+<sha>` checks the platform, user `65532:65532`, unpacked file system size (`docker export`, 100 MB or less; `docker image inspect` .Size is printed too but differs by image store), `GET /health` within 5 s with that version, `docker exec <container> /app/server --healthcheck` (exit 0 with the server up, 1 when nothing listens on PORT, 64 for an unknown argument), exit 0 on `docker stop`, and exit 78 with no environment. CI runs it for both platforms.
- `GIT_SHA` is required (7 to 40 lowercase hex characters); the build fails with a clear message without it. The version is `<pubspec version>+<GIT_SHA>`, and the pubspec version must not have its own `+build` part. The script also passes it as `APP_VERSION`, which the build checks against the pubspec and stores in the `org.opencontainers.image.version` label.
- Uncommitted changes: the script stops if server/ or packages/api_contract/ has uncommitted changes, because the image would carry a commit hash that does not match its code. For a local experiment, run it with `ALLOW_DIRTY=1`; the version then ends in `-dirty` (for example `0.1.0+abc1234-dirty`). Never deploy a `-dirty` image.
- Health checks: the image has no shell and no curl, so the executable has its own probe, `/app/server --healthcheck` (see "Health check mode"). deploy/docker-compose.yml uses it.
- Licenses: the image contains glibc (LGPL) and the Mozilla CA bundle (MPL) under a license exception for running on our own VM only. Publishing it to any public registry needs the user's approval (docs/decisions.md, 2026-10-12).
- Base image: `dart:3.13.5` pinned by its multi-platform index digest in the Dockerfile's `DART_IMAGE` argument. To upgrade, change the tag and digest together (`docker buildx imagetools inspect dart:<version>` prints the digest) and update `IMAGE` in tool/test_linux.sh, which pins the same digest.

## Checks

Every test that starts the server needs PostgreSQL 18, because the server does not start without its database (T-019). The tests never mock the driver. They read `TEST_DATABASE_HOST`, `TEST_DATABASE_PORT` (default 5432), `TEST_DATABASE_USER`, `TEST_DATABASE_PASSWORD`, and `TEST_DATABASE_NAME`; the user must be allowed to create databases and roles (each migration test makes its own scratch database and drops it). Without them those tests fail with a message pointing here. A throwaway local server, same image and settings as Compose:

```sh
docker run -d --name boardgame-test-pg -p 127.0.0.1:55432:5432 \
  -e POSTGRES_USER=boardgame_test -e POSTGRES_PASSWORD=local-test-only \
  -e POSTGRES_DB=boardgame_test \
  -e "POSTGRES_INITDB_ARGS=--locale-provider=builtin --locale=C.UTF-8" \
  postgres:18.6-alpine3.24
export TEST_DATABASE_HOST=127.0.0.1 TEST_DATABASE_PORT=55432 \
  TEST_DATABASE_USER=boardgame_test TEST_DATABASE_PASSWORD=local-test-only \
  TEST_DATABASE_NAME=boardgame_test
# afterwards: docker rm -f boardgame-test-pg
```

The outage tests (test/db/health_test.dart, startup_test.dart) put a small TCP proxy between the server and PostgreSQL and close it, so the real database keeps running.

```sh
dart analyze --fatal-infos            # infos fail CI too
dart format --output=none --set-exit-if-changed .
dart test
dart run coverage:test_with_coverage   # writes coverage/lcov.info
dart run tool/coverage_gate.dart . 80  # the CI coverage gate
```

The coverage gate (tool/coverage_gate.dart) fails below 80% line coverage and also when a file under lib/ is missing from lcov.info, because `test_with_coverage` reports only libraries that some test loaded. Exempt: generated files (`*.g.dart`, `*.freezed.dart`), files marked `// coverage:ignore-file`, and files with only directives (barrels). api_contract uses the same tool: `dart run ../../server/tool/coverage_gate.dart . 80`.

The real-process SIGTERM test runs only on Linux and macOS. On Windows, run every check on Linux in the official Dart image (Docker, repo mounted read-only; the script starts and removes its own PostgreSQL container on a private network):

```sh
sh server/tool/test_linux.sh    # from the repo root
```

CI: `.github/workflows/server.yml` (T-011) runs on every push and pull request that touches server/, packages/api_contract/, deploy/, the root analysis_options.yaml, or the workflow. It runs the checks above for both packages on Dart 3.13.5 with the coverage gate (the server tests against a PostgreSQL service container with the same image and initdb settings as Compose, T-019), fails if the committed api_contract generated files are stale, builds the image for linux/arm64 and linux/amd64 without pushing it, smoke tests both (arm64 under QEMU) with a PostgreSQL container that the script stops and starts again to check /health's 503 and recovery, checks that a build without GIT_SHA fails and that the build context holds only the allowlisted files, and runs `docker compose -f deploy/docker-compose.yml --env-file deploy/.env.example config -q` (T-098), which must pass, and the same with each variable removed in turn, which must fail naming that variable.
