#!/usr/bin/env node
// Dependency license check (T-017). For every package in every tracked
// pubspec.lock, downloads the exact hosted archive from pub.dev, verifies it
// against the lockfile's sha256, reads its license file, and classifies it.
// MIT, BSD-2-Clause, BSD-3-Clause, and Apache-2.0 pass; anything else fails
// unless tool/license-allowlist.json lists it with a docs/decisions.md entry.
// SDK packages come from the Flutter SDK and path packages are ours; both are
// covered by docs/third-party-components.md.
// Usage: node tool/license-check.mjs [pubspec.lock ...]   (no args: tracked lockfiles)
// Env: LICENSE_CACHE_DIR caches license texts between runs.

import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { gunzipSync } from 'node:zlib';

export const ALLOWED = ['MIT', 'BSD-2-Clause', 'BSD-3-Clause', 'Apache-2.0'];
const DECISION_REF = /docs\/decisions\.md \d{4}-\d{2}-\d{2}/;
const LICENSE_FILE = /^(?:\.\/)?(?:licen[cs]e|copying)(?:\.(?:md|txt))?$/i;

// Parses the packages section of a pubspec.lock (the subset pub writes).
export function parseLockfile(text) {
  const packages = [];
  let current = null;
  let inPackages = false;
  for (const line of text.split(/\r?\n/)) {
    if (/^packages:\s*$/.test(line)) {
      inPackages = true;
      continue;
    }
    if (!inPackages) continue;
    if (/^\S/.test(line)) break;
    let m;
    if ((m = line.match(/^ {2}([A-Za-z0-9_]+):\s*$/))) {
      current = { name: m[1] };
      packages.push(current);
    } else if (current && (m = line.match(/^ {4}(dependency|source|version): "?([^"]*)"?\s*$/))) {
      current[m[1]] = m[2];
    } else if (current && (m = line.match(/^ {6}(sha256|url): "?([^"]*)"?\s*$/))) {
      current[m[1]] = m[2];
    }
  }
  return packages;
}

// Returns the text of every top-level license file in a .tar.gz archive.
export function licenseTextsFromArchive(gz) {
  const tar = gunzipSync(gz);
  const texts = [];
  for (let off = 0; off + 512 <= tar.length; ) {
    const header = tar.subarray(off, off + 512);
    if (header.every((b) => b === 0)) break;
    const field = (start, len) => header.subarray(start, start + len).toString('utf8').replace(/\0.*$/s, '');
    const prefix = field(345, 155);
    const name = prefix ? `${prefix}/${field(0, 100)}` : field(0, 100);
    const size = parseInt(field(124, 12).trim() || '0', 8);
    const type = field(156, 1) || '0';
    const body = tar.subarray(off + 512, off + 512 + size);
    if ((type === '0' || type === '') && LICENSE_FILE.test(name)) texts.push(body.toString('utf8'));
    off += 512 + Math.ceil(size / 512) * 512;
  }
  return texts;
}

const OTHER_MARKERS = [
  ['gnu general public license', 'GPL'],
  ['gnu lesser general public license', 'LGPL'],
  ['gnu library general public license', 'LGPL'],
  ['gnu affero general public license', 'AGPL'],
  ['mozilla public license', 'MPL'],
  ['eclipse public license', 'EPL'],
  ['common development and distribution license', 'CDDL'],
  ['creative commons', 'CC'],
  ['server side public license', 'SSPL'],
  ['business source license', 'BUSL'],
];

// Classifies license texts. Returns { licenses: [...], other: [...] }.
export function classify(texts) {
  const licenses = new Set();
  const other = new Set();
  for (const raw of texts) {
    const t = raw.toLowerCase().replace(/\s+/g, ' ');
    if (t.includes('apache license') && t.includes('version 2.0')) licenses.add('Apache-2.0');
    if (t.includes('permission is hereby granted, free of charge, to any person obtaining a copy')) licenses.add('MIT');
    if (t.includes('redistribution and use in source and binary forms, with or without modification, are permitted')) {
      licenses.add(/endorse or promote products/.test(t) ? 'BSD-3-Clause' : 'BSD-2-Clause');
    }
    for (const [marker, id] of OTHER_MARKERS) if (t.includes(marker)) other.add(id);
  }
  return { licenses: [...licenses].sort(), other: [...other].sort() };
}

// Validates allowlist entries; returns a list of problems.
export function allowlistProblems(allowlist) {
  const problems = [];
  for (const e of allowlist) {
    if (!e.package || !e.license) problems.push(`allowlist entry ${JSON.stringify(e)} needs package and license`);
    if (!DECISION_REF.test(e.decision ?? '')) {
      problems.push(`allowlist entry for ${e.package ?? '?'} must cite a "docs/decisions.md YYYY-MM-DD" approval`);
    }
  }
  return problems;
}

// Checks one package. fetchTexts(pkg) returns its license texts.
export async function checkPackage(pkg, allowlist, fetchTexts) {
  if (pkg.source === 'sdk') return { ok: true, license: 'Flutter SDK (BSD-3-Clause), see docs/third-party-components.md' };
  if (pkg.source === 'path') return { ok: true, license: 'repo package' };
  if (pkg.source !== 'hosted') return { ok: false, license: `unsupported source "${pkg.source}"` };
  let texts;
  try {
    texts = await fetchTexts(pkg);
  } catch (err) {
    return { ok: false, license: `could not read license: ${err.message}` };
  }
  const { licenses, other } = classify(texts);
  const found = [...licenses, ...other].join(' + ') || (texts.length ? 'unrecognized text' : 'no license file');
  const clean = licenses.length > 0 && other.length === 0 && licenses.every((l) => ALLOWED.includes(l));
  if (clean) return { ok: true, license: found };
  const entry = allowlist.find((e) => e.package === pkg.name && (!e.version || e.version === pkg.version));
  if (entry && DECISION_REF.test(entry.decision ?? '')) {
    return { ok: true, license: `${found} (allowlisted: ${entry.decision})` };
  }
  return { ok: false, license: found };
}

function cachedFetcher(cacheDir) {
  mkdirSync(cacheDir, { recursive: true });
  return async (pkg) => {
    const file = join(cacheDir, `${pkg.name}-${pkg.version}-${pkg.sha256}.json`);
    if (existsSync(file)) return JSON.parse(readFileSync(file, 'utf8'));
    const base = (pkg.url || 'https://pub.dev').replace(/\/$/, '');
    if (base !== 'https://pub.dev') throw new Error(`unexpected host ${base}`);
    const res = await fetch(`${base}/api/archives/${pkg.name}-${pkg.version}.tar.gz`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const gz = Buffer.from(await res.arrayBuffer());
    const sha = createHash('sha256').update(gz).digest('hex');
    if (sha !== pkg.sha256) throw new Error(`sha256 mismatch (lockfile ${pkg.sha256}, archive ${sha})`);
    const texts = licenseTextsFromArchive(gz);
    writeFileSync(file, JSON.stringify(texts));
    return texts;
  };
}

async function main(args) {
  const lockfiles = args.length > 0
    ? args
    : execFileSync('git', ['ls-files', '-z', '--', '*pubspec.lock'], { encoding: 'utf8' }).split('\0').filter(Boolean);
  const allowlist = JSON.parse(readFileSync(new URL('./license-allowlist.json', import.meta.url), 'utf8'));
  const problems = allowlistProblems(allowlist);
  const fetchTexts = cachedFetcher(process.env.LICENSE_CACHE_DIR || join(homedir(), '.cache', 'boardgame-license-check'));
  for (const lockfile of lockfiles) {
    const packages = parseLockfile(readFileSync(lockfile, 'utf8'));
    console.log(`\n${lockfile}: ${packages.length} packages`);
    const results = [];
    for (let i = 0; i < packages.length; i += 8) {
      const batch = packages.slice(i, i + 8);
      results.push(...(await Promise.all(batch.map((p) => checkPackage(p, allowlist, fetchTexts)))));
    }
    packages.forEach((p, i) => {
      const r = results[i];
      console.log(`  ${r.ok ? 'ok  ' : 'FAIL'} ${p.name} ${p.version} (${p.dependency}): ${r.license}`);
      if (!r.ok) problems.push(`${lockfile}: ${p.name} ${p.version}: ${r.license}`);
    });
  }
  if (problems.length) {
    console.log(`\nlicense check: ${problems.length} problem(s)`);
    for (const p of problems) console.log(`::error::${p}`);
    return 1;
  }
  console.log(`\nlicense check: all packages pass (${ALLOWED.join(', ')})`);
  return 0;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exitCode = await main(process.argv.slice(2));
}
