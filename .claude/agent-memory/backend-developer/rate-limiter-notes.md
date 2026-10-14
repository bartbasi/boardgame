---
name: rate-limiter-notes
description: T-020 per-IP limiter design facts: int keys for memory, measured RSS, trusted-proxy rule via pinned Caddy IP, describeError AC8 changes, test pitfalls
metadata:
  type: project
---

Learned on T-020 (2026-10-14):

- Memory in the 64 MB server container is the binding constraint. String keys plus an object per entry cost about 13.5 MB RSS per 100k IPv4 keys (AOT, Windows x64); `Map<int,int>` (packed endsAt<<14 | count) plus `ListQueue<int>` cost about 5 MB (10 MB on first fill due to resize garbage). Measure with a throwaway `dart compile exe` probe and `ProcessInfo.currentRss`; delete the probe.
- Do not use LinkedHashMap insertion order as an expiry queue with repeated `keys.first` + remove: deleted slots stay at the front until rehash, so scanning is O(holes). Keep a separate ListQueue in window order (fixed equal windows + monotonic clock = insertion order is expiry order).
- Client IP: XFF trusted only from exact addresses in TRUSTED_PROXY_ADDRESSES; use the LAST entry. Caddy is pinned to 10.213.7.10 on web subnet 10.213.7.0/24 in docker-compose.yml; a server test parses compose to keep the three values in sync. shelf_io puts HttpConnectionInfo in `request.context['shelf.io.connection_info']`.
- IPv6 keyed by /64 prefix [ASSUMPTION, open question to PM in T-020].
- describeError since T-020: ArgumentError family -> type, name, message only; absolute URLs reduced to scheme+host. QA test in errors_test needs `ArgumentError(msg)` message kept, and `/srv/app/secret.dart` (a bare path) kept, so only scheme URLs are redacted.
- Test pitfall: `await controller.close()` on a StreamController nobody listened to never completes (runServer returns before listening on config errors). Use `unawaited(...)` or do not close.

**Why:** these cost time and constrain T-066 (attestation goes after the limiter) and T-071 (VM IPv6, subnet overlap).
**How to apply:** reuse int keys for any per-client in-memory table; check memory against the 64 MB limit; keep the limiter first in v1Middleware.

Related: [[server-skeleton-patterns]], [[compose-stack-notes]], [[worktree-shell-limits]]
