/**
 * Pure dictation helpers: gesture thresholds, waveform framing, draft merging.
 * No native module is touched, so this runs under plain node.
 *
 *   node --experimental-strip-types --test test/dictation.test.ts
 */

import test from 'node:test';
import assert from 'node:assert/strict';

import {
  BUFFER_LENGTH,
  CANCEL_DX,
  LOCK_DY,
  MAX_SAMPLES,
  MIN_SAMPLES,
  SAMPLE_RATE,
  concatChunks,
  gesturePhase,
  isLongEnough,
  mergeDraft,
  progressPercent,
} from '../src/utils/dictation.ts';

const filled = (length: number, value: number) => new Float32Array(length).fill(value);

// These are not preferences — they are copied out of Whisper's Constants.h.
// Drift here is silent: the model transcribes garbage instead of failing.
test('the waveform contract matches the native runner', () => {
  assert.equal(SAMPLE_RATE, 16000, '16 kHz mono, no resampling on the native side');
  assert.equal(MIN_SAMPLES, 16000, 'kMinChunkSamples — one second');
  assert.equal(MAX_SAMPLES, 464000, 'kMaxSamples — 29 seconds');
  assert.equal(MAX_SAMPLES % BUFFER_LENGTH, 0, 'the ceiling lands on a chunk boundary');
});

test('gesturePhase arms the lock only past the threshold', () => {
  assert.equal(gesturePhase({ dx: 0, dy: 0 }, false), 'recording', 'a still thumb');
  assert.equal(gesturePhase({ dx: 0, dy: LOCK_DY }, false), 'recording', 'exactly at it');
  assert.equal(gesturePhase({ dx: 0, dy: LOCK_DY - 1 }, false), 'armed-lock', 'one past it');
});

test('gesturePhase arms the cancel only past the threshold', () => {
  assert.equal(gesturePhase({ dx: CANCEL_DX, dy: 0 }, false), 'recording', 'exactly at it');
  assert.equal(gesturePhase({ dx: CANCEL_DX - 1, dy: 0 }, false), 'armed-cancel', 'one past it');
});

// A diagonal slide reads as "no", not "hands free" — locking a take the user
// meant to throw away makes them hunt for a second control to undo it.
test('cancel wins when both thresholds are crossed at once', () => {
  assert.equal(
    gesturePhase({ dx: CANCEL_DX - 40, dy: LOCK_DY - 40 }, false),
    'armed-cancel'
  );
});

test('a locked take cannot re-lock but can still be cancelled', () => {
  assert.equal(
    gesturePhase({ dx: 0, dy: LOCK_DY - 200 }, true),
    'recording',
    'sliding further up on an already-locked take is a no-op'
  );
  assert.equal(
    gesturePhase({ dx: CANCEL_DX - 1, dy: LOCK_DY - 200 }, true),
    'armed-cancel',
    'a hands-free take still has to be escapable'
  );
});

test('isLongEnough rejects anything under one second', () => {
  assert.equal(isLongEnough(0), false, 'a tap that captured nothing');
  assert.equal(isLongEnough(MIN_SAMPLES - 1), false, 'one sample short');
  assert.equal(isLongEnough(MIN_SAMPLES), true, 'the floor is inclusive');
});

test('concatChunks joins chunks in arrival order', () => {
  const out = concatChunks([filled(3, 0.5), filled(2, -0.25)]);

  assert.equal(out.length, 5);
  assert.deepEqual(Array.from(out), [0.5, 0.5, 0.5, -0.25, -0.25]);
});

test('concatChunks handles a take that captured nothing', () => {
  assert.equal(concatChunks([]).length, 0);
  assert.equal(concatChunks([new Float32Array(0)]).length, 0);
});

test('concatChunks stops at the 29 second ceiling', () => {
  // 600000 samples offered, 464000 taken — the tail of the second chunk is
  // dropped rather than allocated.
  const out = concatChunks([filled(300_000, 1), filled(300_000, 2)]);

  assert.equal(out.length, MAX_SAMPLES);
  assert.equal(out[299_999], 1, 'the first chunk survives whole');
  assert.equal(out[300_000], 2, 'the second one picks up where it left off');
  assert.equal(out[MAX_SAMPLES - 1], 2, 'and is truncated, not padded');
});

test('concatChunks drops chunks that arrive entirely past the ceiling', () => {
  const out = concatChunks([filled(MAX_SAMPLES, 1), filled(1000, 2)]);

  assert.equal(out.length, MAX_SAMPLES);
  assert.equal(out[MAX_SAMPLES - 1], 1, 'nothing from the late chunk leaked in');
});

test('mergeDraft puts exactly one space between draft and transcript', () => {
  assert.equal(mergeDraft('see you', 'at six'), 'see you at six');
  assert.equal(mergeDraft('see you ', 'at six'), 'see you at six', 'draft already spaced');
  assert.equal(mergeDraft('see you   ', 'at six'), 'see you at six', 'and over-spaced');
  assert.equal(mergeDraft('see you', '  at six  '), 'see you at six', 'padded transcript');
});

test('mergeDraft starts an empty draft with no leading space', () => {
  assert.equal(mergeDraft('', 'at six'), 'at six');
  assert.equal(mergeDraft('   ', 'at six'), 'at six', 'a whitespace-only draft is empty');
  assert.equal(mergeDraft('', '  at six  '), 'at six');
});

// "Didn't catch that" must not quietly reformat what the user already typed.
test('mergeDraft leaves the draft untouched when nothing was heard', () => {
  assert.equal(mergeDraft('see you ', ''), 'see you ');
  assert.equal(mergeDraft('see you ', '   '), 'see you ');
  assert.equal(mergeDraft('', ''), '');
});

test('progressPercent turns 0..1 into a whole percent', () => {
  assert.equal(progressPercent(0), 0);
  assert.equal(progressPercent(0.4237), 42);
  assert.equal(progressPercent(1), 100);
});

// Every one of these reaches a label a blind user has read to them. The
// fetcher is native and reports all three on real downloads.
test('progressPercent survives what a native fetcher actually reports', () => {
  assert.equal(progressPercent(NaN), 0, 'a response with no content-length');
  assert.equal(progressPercent(1.02), 100, 'a multi-file group overshooting');
  assert.equal(progressPercent(-0.1), 0, 'never a negative percent');
  assert.equal(progressPercent(Infinity), 0, 'not 100 — nothing is known yet');
});
