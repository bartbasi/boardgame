// Unit tests for tool/license-check.mjs. Run: node --test tool/license-check.test.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { gzipSync } from 'node:zlib';
import {
  allowlistProblems,
  checkPackage,
  classify,
  licenseTextsFromArchive,
  parseLockfile,
} from './license-check.mjs';

const fixture = (name) => readFileSync(new URL(`./fixtures/license/${name}`, import.meta.url), 'utf8');

const MIT = fixture('MIT.txt');
const BSD3 = fixture('BSD-3-Clause.txt');
const BSD2 = fixture('BSD-2-Clause.txt');
const APACHE = fixture('Apache-2.0.txt');
const GPL = fixture('GPL-3.0-excerpt.txt');

// Builds a minimal ustar .tar.gz with the given { name: text } files.
function tarGz(files) {
  const blocks = [];
  for (const [name, text] of Object.entries(files)) {
    const body = Buffer.from(text, 'utf8');
    const header = Buffer.alloc(512);
    header.write(name, 0, 'utf8');
    header.write('0000644\0', 100);
    header.write(body.length.toString(8).padStart(11, '0') + '\0', 124);
    header.write('0', 156);
    header.write('ustar\0', 257);
    blocks.push(header, body, Buffer.alloc((512 - (body.length % 512)) % 512));
  }
  blocks.push(Buffer.alloc(1024));
  return gzipSync(Buffer.concat(blocks));
}

const pkg = (name, extra = {}) => ({ name, version: '1.0.0', source: 'hosted', sha256: 'x', ...extra });
const textsFor = (map) => async (p) => map[p.name];

test('parses a lockfile fixture', () => {
  const pkgs = parseLockfile(fixture('pubspec.lock'));
  assert.deepEqual(
    pkgs.map((p) => [p.name, p.source, p.version, p.dependency]),
    [
      ['api_contract', 'path', '0.1.0', 'direct main'],
      ['dio', 'hosted', '5.11.1', 'direct main'],
      ['flutter', 'sdk', '0.0.0', 'direct main'],
      ['meta', 'hosted', '1.18.3', 'transitive'],
    ],
  );
  assert.equal(pkgs[1].sha256, '852ec3b48cc431ac04fff978413c541502b67ffc3e26921e74e3d994694192c1');
  assert.equal(pkgs[1].url, 'https://pub.dev');
});

test('reads top-level license files from an archive only', () => {
  const gz = tarGz({ LICENSE: MIT, 'lib/LICENSE': GPL, 'README.md': 'hi', 'COPYING.txt': BSD3 });
  const texts = licenseTextsFromArchive(gz);
  assert.equal(texts.length, 2);
  assert.deepEqual(classify(texts), { licenses: ['BSD-3-Clause', 'MIT'], other: [] });
});

test('classifies the four allowed licenses', () => {
  assert.deepEqual(classify([MIT]).licenses, ['MIT']);
  assert.deepEqual(classify([BSD3]).licenses, ['BSD-3-Clause']);
  assert.deepEqual(classify([BSD2]).licenses, ['BSD-2-Clause']);
  assert.deepEqual(classify([APACHE]).licenses, ['Apache-2.0']);
});

test('allowed licenses pass', async () => {
  const fetch = textsFor({ a: [MIT], b: [BSD3], c: [BSD2], d: [APACHE], e: [BSD3 + '\n\n' + MIT] });
  for (const name of ['a', 'b', 'c', 'd', 'e']) {
    const r = await checkPackage(pkg(name), [], fetch);
    assert.equal(r.ok, true, name);
  }
});

test('other or unknown licenses fail and name what was found', async () => {
  const fetch = textsFor({ gpl: [GPL], mixed: [MIT, GPL], odd: ['All rights reserved.'], none: [] });
  assert.deepEqual(await checkPackage(pkg('gpl'), [], fetch), { ok: false, license: 'GPL' });
  assert.deepEqual(await checkPackage(pkg('mixed'), [], fetch), { ok: false, license: 'MIT + GPL' });
  assert.deepEqual(await checkPackage(pkg('odd'), [], fetch), { ok: false, license: 'unrecognized text' });
  assert.deepEqual(await checkPackage(pkg('none'), [], fetch), { ok: false, license: 'no license file' });
});

test('fetch errors such as a sha256 mismatch fail', async () => {
  const fetch = async () => {
    throw new Error('sha256 mismatch (lockfile a, archive b)');
  };
  const r = await checkPackage(pkg('x'), [], fetch);
  assert.equal(r.ok, false);
  assert.match(r.license, /sha256 mismatch/);
});

test('allowlisted packages pass only with a decision reference', async () => {
  const fetch = textsFor({ gpl: [GPL] });
  const good = [{ package: 'gpl', license: 'GPL', decision: 'docs/decisions.md 2026-10-12 (user approved)' }];
  const bad = [{ package: 'gpl', license: 'GPL', decision: 'approved in chat' }];
  assert.equal((await checkPackage(pkg('gpl'), good, fetch)).ok, true);
  assert.equal((await checkPackage(pkg('gpl'), bad, fetch)).ok, false);
  assert.deepEqual(allowlistProblems(good), []);
  assert.equal(allowlistProblems(bad).length, 1);
  assert.equal(allowlistProblems([{ license: 'GPL', decision: 'docs/decisions.md 2026-10-12' }]).length, 1);
});

test('a version-pinned allowlist entry does not cover other versions', async () => {
  const fetch = textsFor({ gpl: [GPL] });
  const list = [{ package: 'gpl', version: '2.0.0', license: 'GPL', decision: 'docs/decisions.md 2026-10-12' }];
  assert.equal((await checkPackage(pkg('gpl'), list, fetch)).ok, false);
  assert.equal((await checkPackage(pkg('gpl', { version: '2.0.0' }), list, fetch)).ok, true);
});

test('sdk and path packages pass without a fetch; other sources fail', async () => {
  const fetch = async () => assert.fail('must not fetch');
  assert.equal((await checkPackage(pkg('flutter', { source: 'sdk' }), [], fetch)).ok, true);
  assert.equal((await checkPackage(pkg('api_contract', { source: 'path' }), [], fetch)).ok, true);
  assert.equal((await checkPackage(pkg('g', { source: 'git' }), [], fetch)).ok, false);
});
