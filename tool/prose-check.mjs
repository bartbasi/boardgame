#!/usr/bin/env node
// Prose style check (T-016). Fails on em dashes anywhere, and on double
// hyphens used as dashes outside inline code and fenced code blocks.
// Scans README.md, CLAUDE.md, docs/**/*.md, and app/lib/l10n/*.arb.
// Usage: node tool/prose-check.mjs [file ...]   (no args: tracked files)

import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const EM_DASH = String.fromCharCode(0x2014);
const FENCE = /^\s{0,3}(`{3,}|~{3,})/;

// Replaces inline code spans with spaces so columns stay correct.
export function maskInlineCode(line) {
  let out = '';
  let i = 0;
  while (i < line.length) {
    if (line[i] !== '`') {
      out += line[i++];
      continue;
    }
    let ticks = 0;
    while (line[i + ticks] === '`') ticks++;
    const marker = '`'.repeat(ticks);
    const close = line.indexOf(marker, i + ticks);
    if (close === -1) {
      out += line.slice(i, i + ticks);
      i += ticks;
      continue;
    }
    out += ' '.repeat(close + ticks - i);
    i = close + ticks;
  }
  return out;
}

const isSpace = (c) => c === undefined || /\s/.test(c);
const isWord = (c) => c !== undefined && /[\p{L}\p{N}]/u.test(c);

// Returns 1-based columns of double hyphens used as dashes in one line.
export function findDoubleHyphens(line) {
  const cols = [];
  const re = /-+/g;
  let m;
  while ((m = re.exec(line)) !== null) {
    if (m[0].length !== 2) continue;
    const before = line[m.index - 1];
    const after = line[m.index + 2];
    if ((isSpace(before) && isSpace(after)) || (isWord(before) && isWord(after))) {
      cols.push(m.index + 1);
    }
  }
  return cols;
}

// Returns problems as {line, column, message} for one file's text.
export function checkText(text) {
  const problems = [];
  let fence = null;
  text.split(/\r?\n/).forEach((raw, idx) => {
    const lineNo = idx + 1;
    for (let i = raw.indexOf(EM_DASH); i !== -1; i = raw.indexOf(EM_DASH, i + 1)) {
      problems.push({ line: lineNo, column: i + 1, message: 'em dash (U+2014)' });
    }
    const f = raw.match(FENCE);
    if (fence) {
      if (f && f[1][0] === fence[0] && f[1].length >= fence.length) fence = null;
      return;
    }
    if (f) {
      fence = f[1];
      return;
    }
    for (const col of findDoubleHyphens(maskInlineCode(raw))) {
      problems.push({ line: lineNo, column: col, message: 'double hyphen used as a dash' });
    }
  });
  return problems;
}

export function isScanned(path) {
  return (
    path === 'README.md' ||
    path === 'CLAUDE.md' ||
    (path.startsWith('docs/') && path.endsWith('.md')) ||
    /^app\/lib\/l10n\/[^/]+\.arb$/.test(path)
  );
}

function trackedFiles() {
  return execFileSync('git', ['ls-files', '-z'], { encoding: 'utf8' })
    .split('\0')
    .filter((p) => p && isScanned(p));
}

function main(args) {
  const files = args.length > 0 ? args : trackedFiles();
  let count = 0;
  for (const file of files) {
    for (const p of checkText(readFileSync(file, 'utf8'))) {
      console.log(`${file}:${p.line}:${p.column}: ${p.message}`);
      count++;
    }
  }
  console.log(count === 0 ? `prose check: ${files.length} files clean` : `prose check: ${count} problem(s)`);
  return count === 0 ? 0 : 1;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exitCode = main(process.argv.slice(2));
}
