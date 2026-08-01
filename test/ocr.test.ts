/**
 * Pure OCR helpers: reading order, score filter, truncation.
 * No native module is touched, so this runs under plain node.
 *
 *   node --experimental-strip-types --test test/ocr.test.ts
 */

import test from 'node:test';
import assert from 'node:assert/strict';

import {
  composeSpeech,
  sameLine,
  toReadingOrder,
  truncateWords,
  MIN_SCORE,
} from '../src/utils/ocr.ts';
import type { TextBox } from '../src/features/ai/types/index.ts';

const box = (
  text: string,
  x1: number,
  y1: number,
  x2: number,
  y2: number,
  score = 0.9
): TextBox => ({ text, score, bbox: { x1, y1, x2, y2 } });

test('sameLine groups by vertical overlap, not proximity', () => {
  const a = { x1: 0, y1: 0, x2: 10, y2: 20 };
  const sameRow = { x1: 50, y1: 2, x2: 60, y2: 22 };
  const nextRow = { x1: 0, y1: 19, x2: 10, y2: 39 };

  assert.equal(sameLine(a, sameRow), true, 'boxes sharing most of their height');
  assert.equal(sameLine(a, nextRow), false, 'boxes touching by a sliver');
});

test('toReadingOrder sorts lines top-to-bottom and boxes left-to-right', () => {
  // Deliberately scrambled, the way detector output arrives.
  const boxes = [
    box('WORLD', 60, 0, 110, 20),
    box('AGAIN', 60, 40, 110, 60),
    box('HELLO', 0, 2, 50, 22),
    box('READ', 0, 41, 50, 61),
  ];

  assert.deepEqual(
    toReadingOrder(boxes).map((b) => b.text),
    ['HELLO', 'WORLD', 'READ', 'AGAIN']
  );
});

test('composeSpeech joins reading order into one utterance', () => {
  const boxes = [
    box('WORLD', 60, 0, 110, 20),
    box('HELLO', 0, 2, 50, 22),
  ];

  assert.equal(composeSpeech(boxes), 'HELLO WORLD');
});

test('composeSpeech drops detections below the score floor', () => {
  const boxes = [
    box('KEEP', 0, 0, 50, 20, MIN_SCORE),
    box('DROP', 60, 0, 110, 20, MIN_SCORE - 0.01),
  ];

  assert.equal(composeSpeech(boxes), 'KEEP', 'the floor is inclusive');
});

test('composeSpeech returns empty string when nothing survives', () => {
  assert.equal(composeSpeech([]), '');
  assert.equal(composeSpeech([box('noise', 0, 0, 10, 10, 0.1)]), '');
  assert.equal(composeSpeech([box('   ', 0, 0, 10, 10)]), '', 'whitespace-only text');
});

test('composeSpeech collapses stray whitespace inside recognized text', () => {
  assert.equal(composeSpeech([box('  EXIT \n 12  ', 0, 0, 50, 20)]), 'EXIT 12');
});

test('truncateWords cuts on a word boundary', () => {
  assert.equal(truncateWords('one two three', 100), 'one two three', 'under the cap');
  assert.equal(truncateWords('one two three', 9), 'one two', 'boundary before the cap');
  assert.equal(truncateWords('', 10), '');
});

test('truncateWords hard-cuts a single word longer than the cap', () => {
  assert.equal(truncateWords('supercalifragilistic', 5), 'super');
  assert.equal(truncateWords('anything', 0), '', 'a zero cap yields nothing');
});

// Regression: a tall heading used to overlap the rows both above and below it,
// swallow them into one "line", and then x-sort interleaved their words —
// "GATE 18:40 closes" instead of "GATE closes 18:40".
test('a tall heading does not swallow adjacent rows of smaller type', () => {
  const boxes = [
    box('GATE', 0, 0, 120, 60), // one big glyph run, spans both small rows
    box('closes', 300, 2, 380, 14),
    box('18:40', 150, 46, 230, 58),
  ];

  assert.equal(composeSpeech(boxes), 'GATE closes 18:40');
});

test('comparable heights still group into one line', () => {
  const boxes = [
    box('SECOND', 90, 1, 170, 21),
    box('FIRST', 0, 0, 80, 20),
  ];

  assert.equal(composeSpeech(boxes), 'FIRST SECOND');
});

test('an inverted bbox is normalised and still groups with its line', () => {
  // y1/y2 arrive swapped; after normalising it is an ordinary 20px-tall box.
  const upright = box('FIRST', 0, 0, 50, 20);
  const inverted: TextBox = {
    text: 'SECOND',
    score: 0.9,
    bbox: { x1: 60, y1: 20, x2: 110, y2: 0 },
  };

  assert.equal(composeSpeech([inverted, upright]), 'FIRST SECOND');
});

test('a zero-height bbox survives and is ordered by its top edge', () => {
  // Its effective height is 1, so the ratio guard keeps it out of the taller
  // box's line — it still gets spoken, in top-to-bottom position.
  const flat: TextBox = { text: 'FLAT', score: 0.9, bbox: { x1: 0, y1: 10, x2: 50, y2: 10 } };
  const below = box('BELOW', 0, 40, 50, 60);

  assert.equal(composeSpeech([below, flat]), 'FLAT BELOW');
});

test('composeSpeech applies maxChars after ordering', () => {
  const boxes = [
    box('BBBB', 60, 0, 110, 20),
    box('AAAA', 0, 2, 50, 22),
  ];

  assert.equal(composeSpeech(boxes, { maxChars: 6 }), 'AAAA');
});
