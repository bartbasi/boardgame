---
name: worktree-shell-limits
description: Bash commands in an isolated worktree get refused when they chain mkdir/heredoc/loops; use Write for files and simple commands
metadata:
  type: feedback
---

The worktree isolation check refuses Bash commands it cannot verify stay inside the worktree, for example `mkdir -p ... && cd ... && cat > file <<EOF` or for-loops that write files.

**Why:** observed on T-007 (2026-10-12); several compound commands were rejected outright.

**How to apply:** create files with the Write tool (it creates parent folders), and keep Bash to plain commands such as `cd <worktree path> && dart ...` or `git ...`. Read-only loops and Docker runs with a read-only mount worked. The pub cache path contains a space (`C:\Users\Bart Basi\...`), so always quote `$LOCALAPPDATA` paths.
