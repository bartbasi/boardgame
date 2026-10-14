---
name: postgres-access-notes
description: T-019 PostgreSQL facts (postgres 3.5.x driver behavior, migrations design, test DB setup, TCP proxy outage tests, gitleaks on test passwords, collation choice, measured memory)
metadata:
  type: project
---

Learned on T-019 (2026-10-13), driver `postgres` 3.5.20 (BSD-3, isoos):

- Pool: `Pool<void>.withEndpoints([Endpoint(...)], settings: PoolSettings(maxConnectionCount, connectTimeout, queryTimeout, sslMode: SslMode.disable, applicationName))`. `connectTimeout` also bounds the wait for a free slot. A failed connection is dropped (reuse only for non-fatal PgException), so the pool recovers by itself.
- Multi-statement SQL works with `execute(sql, queryMode: QueryMode.simple)` (no parameters), also inside `connection.runTx`.
- `ServerException.toString()` includes `detail` (row values, e.g. "Key (bgg_id)=(13) already exists"); describeError now logs only severity + SQLSTATE.
- Migrations are Dart consts (scratch image has no files); const-only file needs `// coverage:ignore-file`.
- Every test that starts the server needs a real DB: `TEST_DATABASE_*` env, helper `withTestDatabase()` in server/test/support/database.dart; migration tests create/drop scratch databases; outages via an in-test `TcpProxy` (down/hang/up) so the real DB keeps running.
- Windows: a refused loopback TCP connect takes ~2 s (SYN retries); outage tests must not assume fast refusal.
- In Compose, a stopped postgres container makes name resolution on the internal network hang for seconds; /health must not wait per request (answer 503 at once while a probe hangs).
- gitleaks (repo.yml, generic-api-key) flags password-like string literals in tests (entropy ~3.9). Build fake passwords at run time (`fakePassword(tag)`). A flagged commit on a pushed branch must be rewritten, because merging scans it again.
- Collation: `--locale-provider=builtin --locale=C.UTF-8` (Alpine default is libc en_US.utf8 with empty datcollversion under musl).
- Memory: postgres idle 41 MiB, 5 clients ~87 MiB, 20 clients ~124 MiB, no OOM in 256 MB; shared_buffers 128 MB default.

**Why:** these cost a round or a CI failure to find; T-021 to T-025 and T-072 build on the DB layer.
**How to apply:** reuse the test helpers, put new tables in a new migration, keep request data out of SQL literals, and check repo.yml (gitleaks) on the first push.

Related: [[compose-stack-notes]], [[server-skeleton-patterns]], [[ci-server-workflow]]
