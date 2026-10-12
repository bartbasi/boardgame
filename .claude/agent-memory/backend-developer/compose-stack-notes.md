---
name: compose-stack-notes
description: T-010 local Compose stack facts (pinned images, PG18 volume path, pg_isready TCP reason, Caddy keepalive, log retention gap, measured memory)
metadata:
  type: project
---

T-010 (2026-10-12) built deploy/ with postgres:18.6-alpine3.24 and caddy:2.11.7-alpine pinned by index digest (digests in deploy/docker-compose.yml). Run through `sh deploy/compose.sh` (sets GIT_SHA/APP_VERSION build args).

**Why:** facts that cost time to find and will matter for T-017 (DB access), T-071 (VM), T-072 (backups).

**How to apply:**
- PostgreSQL 18 image: PGDATA=/var/lib/postgresql/18/docker, volume must mount at /var/lib/postgresql (not .../data as in <=17).
- pg_isready must use `-h 127.0.0.1`: the entrypoint's init-time temp server has listen_addresses='' so a socket check passes too early.
- Caddy `transport http { keepalive 30s }` (default 2m > server's 65 s idle); `caddy adapt` shows keep_alive.idle_timeout. `caddy fmt` wants no blank line between top comments and the global `{` block. Warnings "HTTP/2/3 skipped ... :80" are expected.
- Caddy with cap_drop ALL + cap_add NET_BIND_SERVICE works; server works read_only with cap_drop ALL (writes no files).
- json-file logging has no time-based retention; 7-day target needs journald MaxRetentionSec (open question to user, T-071).
- Measured idle (amd64, docker stats): postgres ~26 MiB, caddy ~12 MiB, server ~4.4 MiB (cgroup), total ~43 MiB. pgdata ~66 MB fresh.
- Official postgres/caddy images contain GPL OS packages (busybox, bash...); approval asked as open question in T-010 handoff.
- Dart HttpClient honors HTTP_PROXY from Platform.environment with no loopback bypass (proved in T-010 round 2: removing `findProxy = DIRECT` made a real-process test fail). Proxy tests must set env on Process.run, not pass a map to our code.
- Round 2 (reviewer asks): local Caddy ports bound to 127.0.0.1; cold build context is ~92 kB, warm ~2 kB; Caddy runs read_only with tmpfs /tmp; start_interval needs Engine 25.0+.
- `docker compose stop server` idle: exit 0 with `shutdown complete` (stop_grace_period 15s).

Related: [[docker-dart-aot-notes]], [[server-skeleton-patterns]], [[worktree-shell-limits]]
