/**
 * Runs the frozen conformance vectors from spec/vectors.json.
 * Both projects must pass all 9 — see spec/wire.md.
 *
 *   node --experimental-strip-types --test currency-rn/test/wire.test.ts
 */

import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

import {
  encode,
  decode,
  toB64url,
  fromB64url,
  wrapRelay,
  parseRelay,
  dedupeKey,
  isBearer,
  WireError,
  NOTE_LEN,
  type Note,
} from '../src/wire.ts';

const here = dirname(fileURLToPath(import.meta.url));
// Local fixture, copied from spec/vectors.json. Copied, never linked — no build
// artefact of this project may reach outside it (spec/wire.md, segregation note).
// Re-copy after any spec change; the freeze makes that a rare event.
const vectors = JSON.parse(readFileSync(resolve(here, 'vectors.json'), 'utf8'));

function bytesToHex(b: Uint8Array): string {
  return [...b].map((x) => x.toString(16).padStart(2, '0')).join('');
}

test('encode vectors', () => {
  for (const c of vectors.encode) {
    const raw = encode(c.note as Note);
    assert.equal(raw.length, NOTE_LEN, `${c.name}: length`);
    assert.equal(bytesToHex(raw), c.expect_hex, `${c.name}: hex`);
    assert.equal(toB64url(raw), c.expect_b64url, `${c.name}: b64url`);
    assert.deepEqual(decode(raw), c.note, `${c.name}: round-trip`);
    assert.deepEqual(
      decode(fromB64url(c.expect_b64url)),
      c.note,
      `${c.name}: b64url round-trip`,
    );
  }
});

test('decode rejections', () => {
  for (const c of vectors.decode) {
    assert.throws(
      () => decode(fromB64url(c.input_b64url)),
      (e: unknown) =>
        e instanceof WireError && e.code === c.expect_error,
      `${c.name}: expected ${c.expect_error}`,
    );
  }
});

test('base64url is 56 chars and unpadded', () => {
  for (const c of vectors.encode) {
    assert.equal(c.expect_b64url.length, 56, c.name);
    assert.ok(!c.expect_b64url.includes('='), c.name);
  }
});

test('bearer flag', () => {
  const bearer = vectors.encode.find((c: any) => c.name === 'bearer-holder-zero');
  assert.ok(isBearer(bearer.note));
  assert.equal(bearer.note.holder, '0'.repeat(32));
});

test('dedupe key is note_id + lamport', () => {
  const a = { ...vectors.encode[0].note, lamport: 1 } as Note;
  const b = { ...vectors.encode[0].note, lamport: 2 } as Note;
  assert.notEqual(dedupeKey(a), dedupeKey(b));
  assert.equal(dedupeKey(a), dedupeKey({ ...a }));
});

test('relay envelope round-trips and decrements', () => {
  const b64 = vectors.encode[0].expect_b64url;
  const env = wrapRelay(b64);
  assert.equal(env, `R|3|${b64}`);

  const parsed = parseRelay(env)!;
  assert.equal(parsed.ttl, 3);
  assert.equal(parsed.b64, b64);

  assert.equal(parseRelay(b64), null, 'direct transfer is not a relay envelope');

  const hop = wrapRelay(parsed.b64, parsed.ttl - 1);
  assert.equal(parseRelay(hop)!.ttl, 2);
});
