---
name: server-skeleton-patterns
description: Non-obvious shelf/dart:io behaviors found building server/ in T-008 (shutdown drain, route templates, Linux test script, private named params)
metadata:
  type: project
---

Learned on T-008 (2026-10-12), server package `boardgame_server`:

- `HttpServer.close()` (non-force) completes when the listening socket closes, NOT when in-flight connections finish. To drain, poll `server.connectionsInfo().total` until 0 or the grace period ends, then `close(force: true)`.
- shelf_router does not expose the matched route template. Pattern used: request log middleware puts a mutable `RouteSlot` in the request context; the `Routes` registrar wraps each handler to fill in the template. Handlers take only `Request`; shelf_router calls them directly when `_handler is Handler`, and params come from `request.params` (needs `import 'package:shelf_router/shelf_router.dart'`).
- `shelf_io.serve(..., poweredByHeader: null)` removes the X-Powered-By framework header.
- Windows cannot `ProcessSignal.sigterm.watch()`; real SIGTERM tests use `testOn: 'linux || mac-os'` and run via `sh server/tool/test_linux.sh` (Docker, repo mounted read-only, tar-copies server/ and packages/api_contract/). The container has no git, so git-based tests must skip on ProcessException.
- Start the server as `Platform.resolvedExecutable bin/server.dart` (not `dart run`) so the child pid receives signals.
- Dart 3.13 supports private named initializing formals (`required this._sink`, callers pass `sink:`); the `prefer_initializing_formals` lint asks for it.
- `dart compile exe -o build/x.exe` fails if build/ does not exist.

**Why:** these cost time to discover and will recur in T-009 to T-020.
**How to apply:** reuse `Routes` for every new endpoint; keep env reading in bin/server.dart only (a test enforces it); add new config vars to `Config.load` and server/.env.example together.

Related: [[backend-framework-choice]], [[docker-dart-aot-notes]], [[worktree-shell-limits]]
