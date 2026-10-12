// Unit tests for tool/prose-check.mjs. Run: node --test tool/prose-check.test.mjs
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { checkText, isScanned } from './prose-check.mjs';

const EM = String.fromCharCode(0x2014);
const cols = (text) => checkText(text).map((p) => [p.line, p.column]);

test('em dash anywhere fails with line and column', () => {
  assert.deepEqual(cols('ok\nan ' + EM + ' dash'), [[2, 4]]);
  assert.deepEqual(cols('```\ncode ' + EM + ' here\n```'), [[2, 6]]);
});

test('double hyphen used as a dash fails', () => {
  assert.deepEqual(cols('word -- word'), [[1, 6]]);
  assert.deepEqual(cols('word--word'), [[1, 5]]);
  assert.deepEqual(cols('word --'), [[1, 6]]);
  assert.deepEqual(cols('-- leading'), [[1, 1]]);
});

test('legitimate hyphens pass', () => {
  const ok = [
    'Use `--coverage` here.',
    'Use ``a -- b`` in code.',
    '```\nflutter test --coverage\nword -- word\n```',
    '~~~sh\nrun -- x\n~~~',
    'run the tests with --coverage',
    '| a | b |\n|---|---|',
    '---\ntitle: x\n---',
    '<!-- note -->',
    'well-known and re-run',
    'a --- b',
  ];
  for (const text of ok) assert.deepEqual(cols(text), [], text);
});

test('fence closes only with the same marker', () => {
  assert.deepEqual(cols('````\n```\na -- b\n````\nc -- d'), [[5, 3]]);
});

test('scanned paths', () => {
  assert.ok(isScanned('README.md'));
  assert.ok(isScanned('CLAUDE.md'));
  assert.ok(isScanned('docs/ux/screens/app-shell.md'));
  assert.ok(isScanned('app/lib/l10n/app_en.arb'));
  assert.ok(!isScanned('app/README.md'));
  assert.ok(!isScanned('docs/notes.txt'));
  assert.ok(!isScanned('app/lib/l10n/sub/x.arb'));
});
