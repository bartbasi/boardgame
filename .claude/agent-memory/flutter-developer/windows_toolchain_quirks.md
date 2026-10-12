---
name: windows-toolchain-quirks
description: Windows and agent-tooling pitfalls hit while building app/ (Bash guard, CRLF, Gradle downloads, test font, emulator and disk space)
metadata:
  type: project
---

Learned on T-012 and T-013 (2026-10-12):

- The worktree guard on the Bash tool refuses commands it cannot verify: multi-file heredocs with `cd`, any command containing the word `.gitkeep` (it sees "git"), `cygpath "$VAR"`, and `cd ..` before git. Use the Write tool for new files and keep Bash commands short, one `cd` to an absolute path.
- Bash guard also refuses commands whose program name is a variable (`ADB=...; $ADB ...`); write the full path each time.
- Flutter is not on PATH in Bash: prefix `export PATH="/c/dev/flutter/bin:$PATH";`.
- Python `open(..., 'w')` on Windows writes CRLF; .gitattributes normalizes to LF on commit, but run `sed -i 's/\r$//'` to keep working copies clean.
- Python edits via a Bash heredoc: Windows paths in normal string literals get mangled (`\a`, `\b`, `\3` become control characters). Use raw strings or the Edit/Write tools for text that contains backslashes.
- Docker is usable for throwaway tools (actionlint image, removed after). The Bash guard rejects `docker run --entrypoint sh` and `cd` into computed paths before git.
- Pub cache is `C:\Users\Bart Basi\AppData\Local\Pub\Cache\hosted\pub.dev\<pkg>-<ver>\LICENSE` (path has a space; quote it). Use it to check licenses.
- First `flutter build apk` makes Gradle install NDK r28c and Build-Tools 36.0.0 into C:\dev\android-sdk automatically (about 6 minutes).
- `flutter build apk --release` needs no keystore yet (release uses debug signing). `--target-platform android-x64` makes a small APK for the emulator. `print` shows in release logcat under tag `flutter`. For on-device checks, build a temporary entry point with `-t lib/<name>.dart` and delete it, never commit it.
- `aapt dump permissions` lives at C:\dev\android-sdk\build-tools\36.0.0\aapt.exe.
- Emulators exist since 2026-10-12: AVDs bgc_api24 and bgc_api36 in C:\dev\android-sdk (`emulator\emulator.exe -avd bgc_api36 -no-snapshot -no-window -no-audio -no-boot-anim`). A PHYSICAL phone (adb serial R3CWA0Q2JQP) may be attached: always use `adb -s emulator-5554`, never bare adb.
- Disk: C: is nearly full. Even with -no-snapshot the emulator wrote a 2.6 GB `snapshots/default_boot/ram.img` (T-013), and the permission system refused my deleting it. After T-013 the orchestrator said: no more Gradle or emulator builds in that ticket. Ask before any emulator run or release build.
- Windows Developer Mode was OFF at T-012; plugin packages may need it for symlinks. Raise it in the handoff rather than working around it.
- Widget tests use a font where every glyph is a square, so widths (for example the NavigationRail, 141 dp) are wider than on device.

**Why:** each of these cost a retry or a cleanup during T-012 and T-013.
**How to apply:** check this list before running builds, emulators, writing files via Bash, or judging layout sizes in tests. Related: [[app-conventions]].
