# Decisions

One entry per decision. Newest at the bottom. The orchestrator writes this file; other agents propose entries in their handoff notes.

| Date | Decision | Reason | Decided by |
|---|---|---|---|
| 2026-10-11 | Six project subagents (product-manager, ux-designer, flutter-developer, backend-developer, qa-engineer, code-reviewer) with write access enforced per agent by `.claude/hooks/guard-paths.mjs`. | Keep agents in their lanes; ownership table lives in CLAUDE.md. | User approved |
| 2026-10-11 | code-reviewer keeps `memory: project`; the guard hook limits its writes to docs/handoffs/ and its memory folder. | Claude Code automatically gives Write and Edit to any agent with memory, so read-only has to be enforced by the hook. | User |
| 2026-10-11 | No Mac. iOS builds and signing run on GitHub Actions macOS runners; iOS testing through TestFlight on an iPhone. | Dev machine is Windows 11. | User |
| 2026-10-11 | Models: opus for product-manager, flutter-developer, backend-developer, code-reviewer; sonnet for ux-designer and qa-engineer. | Balance cost and quality. | User |
| 2026-10-11 | Toolchain installed by the orchestrator: Flutter stable at C:\dev\flutter, Android command-line tools in the default SDK folder. User starts Docker Desktop. | Nothing was installed. | User |
| 2026-10-11 | Agent worktrees branch from local HEAD (`worktree.baseRef: "head"` in .claude/settings.json). | The default branches from the remote's main, which would miss ticket docs committed locally but not pushed. | Orchestrator |
| 2026-10-11 | During a ticket, its handoff file lives in the developer's worktree. QA, reviewer, UX, and PM work there one at a time. | Code and notes merge into main together; no cross-branch conflicts on handoff files. | Orchestrator |
| 2026-10-11 | packages/api_contract/ (shared request and response DTOs) is owned by backend-developer. | One owner per file; the app requests contract changes through the handoff. | Orchestrator |
| 2026-10-11 | Golden images are rendered only on Linux (CI, or a Docker command fixed in M1). | Font rendering differs between Windows and Linux, so Windows goldens would fail in CI. | Orchestrator (method to be fixed in M1) |
| 2026-10-11 | Ticket ids use the form T-001. | Simple and stable when tickets move between milestones. | Orchestrator |
