# Decisions

One entry per decision. Newest at the bottom. The orchestrator writes this file; other agents propose entries in their handoff notes.

| Date | Decision | Reason | Decided by |
|---|---|---|---|
| 2026-10-11 | Six project subagents (product-manager, ux-designer, flutter-developer, backend-developer, qa-engineer, code-reviewer) with write access enforced per agent by `.claude/hooks/guard-paths.mjs`. | Keep agents in their lanes; ownership table lives in CLAUDE.md. | User approved |
| 2026-10-11 | code-reviewer keeps `memory: project`; the guard hook limits its writes to docs/handoffs/ and its memory folder. | Claude Code automatically gives Write and Edit to any agent with memory, so read-only has to be enforced by the hook. | User |
| 2026-10-11 | No Mac. iOS builds and signing run on GitHub Actions macOS runners; iOS testing through TestFlight on an iPhone. | Dev machine is Windows 11. | User |
| 2026-10-11 | Models: opus for product-manager, flutter-developer, backend-developer, code-reviewer; sonnet for ux-designer and qa-engineer. | Balance cost and quality. | User |
| 2026-10-11 | Toolchain installed by the orchestrator: Flutter 3.47.7 stable (Dart 3.13.5) at C:\dev\flutter; Android SDK at C:\dev\android-sdk (platform 36, build-tools 36.1.0, platform-tools); ANDROID_HOME and user PATH set; Docker Desktop 29.6.1. | Nothing was installed. The SDK lives outside the user profile because the profile path has a space, which the Android NDK tools do not support. | User |
| 2026-10-11 | Agent worktrees branch from local HEAD (`worktree.baseRef: "head"` in .claude/settings.json). | The default branches from the remote's main, which would miss ticket docs committed locally but not pushed. | Orchestrator |
| 2026-10-11 | During a ticket, its handoff file lives in the developer's worktree. QA, reviewer, UX, and PM work there one at a time. | Code and notes merge into main together; no cross-branch conflicts on handoff files. | Orchestrator |
| 2026-10-11 | packages/api_contract/ (shared request and response DTOs) is owned by backend-developer. | One owner per file; the app requests contract changes through the handoff. | Orchestrator |
| 2026-10-11 | Golden images are rendered only on Linux (CI, or a Docker command fixed in M1). | Font rendering differs between Windows and Linux, so Windows goldens would fail in CI. | Orchestrator (method to be fixed in M1) |
| 2026-10-11 | Ticket ids use the form T-001. | Simple and stable when tickets move between milestones. | Orchestrator |
| 2026-10-11 | Smoke test passed: guard hook allows and blocks the right paths in the main checkout and in worktrees; worktrees branch from local main; Flutter works in worktrees. Worktree agents' memory is written inside the worktree, so developers commit memory changes on their ticket branch. | Verified with code-reviewer and flutter-developer before real work started. | Orchestrator |
| 2026-10-11 | BGG commercial license: the user reviews and submits the application (docs/api-research.md section 1.6) this week (PRD Q10, T-087). The product-manager researches fallback game data sources in parallel (PRD Q23, T-097). | BGG refusal is the largest project risk (R1) and approval can take a week or more. | User |
| 2026-10-11 | GitHub repository bartbasi/boardgame is private. iOS (macOS runner) builds run only on main and on manual runs (PRD Q2). | Commercial code stays private; limits paid macOS minutes. | User |
| 2026-10-11 | Google ML Kit approved on Android through mobile_scanner, with ML Kit's usage metrics disclosed in the privacy policy and the Google Play Data safety form (PRD Q4, MLKIT-01 to MLKIT-08). iOS uses Apple's scanner. | The brief's scanner package has no other Android engine. | User |
| 2026-10-11 | Brief assumptions confirmed: GitHub Actions for CI, minimum Android API 24 and iOS 15, price snapshots for games looked up in the last 90 days (PRD Q3). Remove their [ASSUMPTION] markers. | Confirmed at checkpoint 2. | User |
