---
name: windows-toolchain-quirks
description: Windows and agent-tooling pitfalls hit while building app/ (Bash guard, CRLF, Gradle downloads, test font, no emulator)
metadata:
  type: project
---

Learned on T-012 (2026-10-12):

- The worktree guard on the Bash tool refuses commands it cannot verify: multi-file heredocs with `cd`, any command containing the word `.gitkeep` (it sees "git"), `cygpath "$VAR"`, and `cd ..` before git. Use the Write tool for new files and keep Bash commands short, one `cd` to an absolute path.
- Flutter is not on PATH in Bash: prefix `export PATH="/c/dev/flutter/bin:$PATH";`.
- Python `open(..., 'w')` on Windows writes CRLF; .gitattributes normalizes to LF on commit, but run `sed -i 's/\r$//'` to keep working copies clean.
- Docker is usable for throwaway tools (actionlint image, removed after). The Bash guard rejects `docker run --entrypoint sh` and `cd` into computed paths before git.
- Pub cache is `C:\Users\Bart Basi\AppData\Local\Pub\Cache\hosted\pub.dev\<pkg>-<ver>\LICENSE` (path has a space; quote it). Use it to check licenses.
- First `flutter build apk` makes Gradle install NDK r28c and Build-Tools 36.0.0 into C:\dev\android-sdk automatically (about 6 minutes).
- No Android emulator or system images are installed, so on-device ACs stay "not verified" until the orchestrator installs them.
- Windows Developer Mode was OFF at T-012; plugin packages may need it for symlinks. Raise it in the handoff rather than working around it.
- Widget tests use a font where every glyph is a square, so widths (for example the NavigationRail, 141 dp) are wider than on device.

**Why:** each of these cost a retry during T-012.
**How to apply:** check this list before running builds, writing files via Bash, or judging layout sizes in tests. Related: [[app-conventions]].
