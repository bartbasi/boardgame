# deploy/

Docker Compose stack for the backend: Caddy (HTTPS) in front of the server, with PostgreSQL behind it. This version is for local use only (T-010). Production settings (domain, real certificates, restart policy, backups, VM setup) come in T-071 and T-072. Never run anything here against the VM or production data without the user's approval.

| File | Purpose |
|---|---|
| `docker-compose.yml` | The three services, networks, volumes, limits, health checks |
| `Caddyfile` | HTTPS on `localhost` with Caddy's local CA, reverse proxy to `server:8080` |
| `.env.example` | Every variable the stack needs, with placeholders. Copy to `.env` (git-ignored) |
| `compose.sh` | Runs `docker compose` with the server image's build arguments set |

## Run locally

Needs Docker with Compose v2.20.2 or later (health check `start_interval`) and free host ports 80 and 443. Commands run from the repo root in Git Bash or a Linux shell.

```sh
cp deploy/.env.example deploy/.env        # then replace the placeholders
sh deploy/compose.sh up -d --wait         # builds the server image, starts all three
curl -k https://localhost/health          # {"status":"ok","version":"0.1.0+<sha>"}
sh deploy/compose.sh ps
sh deploy/compose.sh logs -f server
sh deploy/compose.sh down                 # stops and removes containers; keeps data
sh deploy/compose.sh down -v              # also deletes the database and Caddy's local CA
```

`-k` is needed because the certificate comes from Caddy's local CA, which is not in your trust store. `http://localhost` redirects to HTTPS (308).

`compose.sh` sets `GIT_SHA` (short hash of HEAD) and `APP_VERSION` (`<server/pubspec.yaml version>+<GIT_SHA>`), the two build arguments server/Dockerfile requires, so `/health` reports the same version as `server/tool/docker_build.sh` would. Like that script, it refuses to build (`up`, `build`, `create`, `run`) while server/ or packages/api_contract/ has uncommitted changes; set `ALLOW_DIRTY=1` for a local experiment (version ends in `-dirty`). Plain `docker compose -f deploy/docker-compose.yml ps|logs|stop|down` also works; a build without the wrapper stops with the Dockerfile's "GIT_SHA is required" message.

The server image is always built from source on `up` (`pull_policy: build`); Compose never pulls `boardgame-server:local` from a registry. The build context is the repo root with `server/Dockerfile`, so `server/Dockerfile.dockerignore` decides what leaves the machine (about 2 kB, no `.env`).

## Configuration

All values come from `deploy/.env` (Compose reads `.env` from the project folder, which is `deploy/`). Variables set in your shell override it, as Compose always does. If a variable is missing or empty, Compose stops before starting anything and names it.

| Variable | Used by | Notes |
|---|---|---|
| `POSTGRES_USER` | postgres, its health check | Superuser created on first start |
| `POSTGRES_PASSWORD` | postgres | Use a long random value even locally |
| `POSTGRES_DB` | postgres, its health check | Database created on first start |
| `LOG_LEVEL` | server | `debug`, `info`, `warning`, `error`; production uses `info` |

The three `POSTGRES_*` values only take effect when the `pgdata` volume is empty (https://hub.docker.com/_/postgres). Changing them later does nothing until `down -v`.

The server gets only `PORT=8080` and `LOG_LEVEL`. It does not use the database yet; when it does (T-017 onward), its connection settings are added to server/.env.example, `Config.load`, and this file together.

## Services

| Service | Image | Memory limit | Published ports | Networks |
|---|---|---|---|---|
| caddy | `caddy:2.11.7-alpine` | 128 MB | 80, 443 (TCP) | web |
| server | `boardgame-server:local` (server/Dockerfile) | 64 MB | none | web, db |
| postgres | `postgres:18.6-alpine3.24` | 256 MB | none | db (internal) |

- Only Caddy publishes ports. PostgreSQL is not published at all; use `sh deploy/compose.sh exec postgres psql -U <user> -d <db>`.
- The `db` network is `internal`, so PostgreSQL has no route to the internet. The server is also on `web` for Caddy and, later, outbound calls to BGG, eBay, and GameUPC.
- Both third-party images are pinned by tag and multi-platform index digest; both indexes contain linux/amd64 and linux/arm64/v8 (checked 2026-10-12 with `docker buildx imagetools inspect`). To upgrade, change tag and digest together.
- Volumes: `pgdata` (PostgreSQL 18 keeps its data in `/var/lib/postgresql/18/docker`, and the image declares the volume at `/var/lib/postgresql`, https://hub.docker.com/_/postgres), `caddy_data` (certificates and local CA), `caddy_config`.

### Health checks and start order

- postgres: `pg_isready -h 127.0.0.1 -p 5432 -U $POSTGRES_USER -d $POSTGRES_DB -t 3`, exit 0 when accepting connections (https://www.postgresql.org/docs/current/app-pg-isready.html). It checks over TCP on purpose: while the image initializes a new data directory it runs a temporary server with `listen_addresses=''` (Unix socket only, docker-entrypoint.sh in the image), so a socket check could pass before the real server is up.
- server: `/app/server --healthcheck`, the server binary's own probe. It calls `GET http://127.0.0.1:$PORT/health`, exits 0 on 200 and 1 otherwise, within 3 s (docs/decisions.md 2026-10-12; the scratch image has no shell or curl). Every check writes one `request` log line (about 2,900 a day at the 30 s interval).
- The server starts only after postgres is healthy (`depends_on: condition: service_healthy`). Caddy starts after the server has started; until the server is ready, Caddy answers 502.
- `start_interval: 1s` makes the first checks run every second during `start_period`, so `up --wait` returns quickly.

### Shutdown

- server: `stop_grace_period: 15s`. On SIGTERM the server drains in-flight requests for up to 10 s and exits 0 with a `shutdown complete` line (server/README.md). Docker's default of 10 s would SIGKILL it before the drain ends. Change both numbers together.
- postgres: `stop_grace_period: 30s`. The image stops with SIGINT (fast shutdown), which may need to write a checkpoint.
- caddy: Docker's default (10 s).

### Hardening

- server: read-only root file system, all capabilities dropped, `no-new-privileges`, user 65532 (from the image). It writes no files, so no tmpfs is mounted (T-010 AC13). If code ever needs a temporary file, add `tmpfs: [/tmp]` to the service.
- caddy: all capabilities dropped except `NET_BIND_SERVICE`, `no-new-privileges`.
- postgres: image defaults (its entrypoint changes file ownership and switches user, which needs capabilities).

## Caddy

- `localhost` gets a certificate from Caddy's local CA. `skip_install_trust` stops Caddy from trying to install that CA in the container's trust store (https://caddyserver.com/docs/caddyfile/options).
- `protocols h1 h2`: HTTP/3 is off because UDP 443 is not published (default `h1 h2 h3`, same page).
- Upstream keep-alive: `transport http { keepalive 30s }`. Caddy's default is 2 minutes (https://caddyserver.com/docs/caddyfile/directives/reverse_proxy, checked 2026-10-12), longer than the server's 65 s idle timeout, so Caddy could reuse a connection the server is closing. 30 s is below 65 s. `caddy adapt` shows it as `"keep_alive":{"idle_timeout":30000000000}`.
- No `log` directive, so no access logs (they would hold client IPs and full URLs with query strings). Caddy still logs its own startup and errors.
- Caddy sets X-Forwarded-For, X-Forwarded-Proto, and X-Forwarded-Host and ignores incoming values of those headers (same page). The server does not log them. Trusting X-Forwarded-For for rate limiting is designed in T-020.
- The two warnings `HTTP/2 skipped because it requires TLS` and `HTTP/3 skipped ...` for `:80` are expected: port 80 only redirects.
- Check formatting with `docker run --rm -v "$PWD/deploy/Caddyfile:/c/Caddyfile:ro" caddy:2.11.7-alpine caddy fmt --diff /c/Caddyfile` (Git Bash: prefix `MSYS_NO_PATHCONV=1`).

## Logs

Every service uses the `json-file` driver with `max-size: 10m` and `max-file: 3`, so each container keeps at most 30 MB of logs (https://docs.docker.com/engine/logging/drivers/json-file/). Logs go to stdout only; the server writes no log files.

The json-file driver rotates by size only and has no time-based option (same page). An idle server writes about 0.4 MB a day (health checks), so 30 MB can hold weeks of history, longer than the 7-day retention target [ASSUMPTION]. Logs are deleted when a container is removed (`down`, or a recreate on upgrade). A time-based rule is needed for production; options are in docs/handoffs/T-010.md and decided in T-071.

## Memory and disk

Idle, measured with `docker stats` on linux/amd64 (Docker Desktop, 2026-10-12): see docs/handoffs/T-010.md. The limits add up to 448 MB.

Image sizes on disk (Docker Desktop, containerd store, amd64): server about 17 MB, Caddy about 93 MB, PostgreSQL about 433 MB. A new database volume (one small test table) is about 66 MB, mostly the initial WAL segments; Caddy's volumes are a few kB.

## Licenses

| Component | License |
|---|---|
| PostgreSQL 18.6 | PostgreSQL License (permissive, BSD/MIT-like) |
| Caddy 2.11.7 | Apache-2.0 (image label `org.opencontainers.image.licenses`) |
| Alpine base packages in both images | mixed; includes GPL-2.0 (busybox, apk-tools), GPL-3.0 (bash, readline, gdbm in the postgres image), LGPL |

Both images are used unmodified from Docker Hub's official images and run only on our machines; we do not redistribute them. The GPL packages are the open question in docs/handoffs/T-010.md.
