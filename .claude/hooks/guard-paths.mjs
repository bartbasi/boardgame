#!/usr/bin/env node
// PreToolUse guard for Write, Edit, and NotebookEdit in project subagents.
// Usage (from agent frontmatter): node guard-paths.mjs <agent-name>
//
// Paths are checked relative to the root of whichever checkout holds the
// target file (the main checkout or a ticket worktree), so the same rules
// apply inside .claude/worktrees/<name>/. Exit code 2 blocks the tool call
// and sends stderr back to the agent.

import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';

// Keep in sync with the ownership table in CLAUDE.md.
// Entries ending in "/" are directories; anything else is an exact file.
const OWNERSHIP = {
  'product-manager': [
    'docs/PRD.md',
    'docs/backlog.md',
    'docs/api-research.md',
    'docs/legal/',
    'docs/store/',
    'docs/handoffs/',
  ],
  'ux-designer': ['docs/ux/', 'docs/handoffs/'],
  'flutter-developer': ['app/', '.github/workflows/app.yml', 'docs/handoffs/'],
  'backend-developer': [
    'server/',
    'deploy/',
    'packages/api_contract/',
    '.github/workflows/server.yml',
    'docs/handoffs/',
  ],
  'qa-engineer': [
    'app/test/',
    'app/integration_test/',
    'server/test/',
    'packages/api_contract/test/',
    'docs/qa/',
    'docs/handoffs/',
  ],
  'code-reviewer': ['docs/handoffs/'],
};

function block(message) {
  process.stderr.write(`${message}\n`);
  process.exit(2);
}

const agent = process.argv[2];
if (!agent || !Object.hasOwn(OWNERSHIP, agent)) {
  block(`guard-paths: unknown agent "${agent}". Fix the hook in .claude/agents/.`);
}

let input;
try {
  input = JSON.parse(readFileSync(0, 'utf8'));
} catch {
  block('guard-paths: could not read hook input, so the write was blocked.');
}

const target = input?.tool_input?.file_path ?? input?.tool_input?.notebook_path;
if (!target) process.exit(0);

const absolute = path.resolve(input.cwd ?? process.cwd(), target);

// The checkout root is the nearest ancestor holding a .git entry. In a
// worktree, .git is a file, which existsSync also matches.
function findCheckoutRoot(file) {
  let dir = path.dirname(file);
  for (;;) {
    if (existsSync(path.join(dir, '.git'))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
}

const root = findCheckoutRoot(absolute) ?? process.env.CLAUDE_PROJECT_DIR;
if (!root) block(`guard-paths: no repository root found for ${absolute}.`);

const relative = path.relative(root, absolute).split(path.sep).join('/');
if (!relative || relative.startsWith('../') || path.isAbsolute(relative)) {
  block(`Blocked: ${agent} may not write outside the repository (${absolute}).`);
}

const fold = (s) => (process.platform === 'win32' ? s.toLowerCase() : s);
const allowed = [...OWNERSHIP[agent], `.claude/agent-memory/${agent}/`];
const permitted = allowed.some((entry) =>
  entry.endsWith('/')
    ? fold(relative).startsWith(fold(entry))
    : fold(relative) === fold(entry),
);
if (permitted) process.exit(0);

block(
  `Blocked by the file ownership policy in CLAUDE.md: ${agent} may write only to ` +
    `${allowed.join(', ')}. Target was ${relative}. If that file needs a change, ` +
    `describe it in docs/handoffs/<ticket-id>.md and tell the orchestrator.`,
);
