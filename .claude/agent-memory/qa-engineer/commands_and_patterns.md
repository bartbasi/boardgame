
server (from T-008):
- Windows: PATH=/c/dev/flutter/bin/cache/dart-sdk/bin; from server/: `dart analyze`, `dart test`. Linux: from repo root `sh server/tool/test_linux.sh` (prints coverage).
- Real-process tests: spawn `Platform.resolvedExecutable bin/server.dart` with PORT env, wait for "server started" line, use `rawHttp`/`rawBody`/`freePort` from test/support/harness.dart. Test-only child: test/support/guard_server.dart (throwing /v1 guards).
- Use "secret" as the marker in client values and assert it never appears in logs; do not reuse the word in your own thrown messages or the check false-fails.
- Heredocs with many quotes/escapes can break the Bash tool; use the Write tool for Dart test files.
