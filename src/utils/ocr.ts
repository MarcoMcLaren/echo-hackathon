// Turning OCR detections into one speakable sentence.
//
// Pure on purpose: no React, no Expo, no executorch. `test/ocr.test.ts` runs
// this under plain node. Only `import type` is allowed here — node's type
// stripping erases those, so nothing is resolved at runtime.
import type { Bbox, TextBox } from '../features/ai/types';

/** Below this the recognizer is guessing at noise rather than reading text. */
export const MIN_SCORE = 0.5;

/**
 * Fallback cap for one utterance. Android's TextToSpeech rejects anything
 * longer than `getMaxSpeechInputLength()` (~4000); callers should pass the real
 * `Speech.maxSpeechInputLength` instead of relying on this.
 */
export const DEFAULT_MAX_CHARS = 3900;

/**
 * Beyond this ratio two boxes are different type sizes — a heading next to body
 * text — rather than one line. Without the check a tall box overlaps rows both
 * above and below it, swallows them into one "line", and the left-to-right sort
 * then interleaves their words.
 */
export const MAX_LINE_HEIGHT_RATIO = 2.5;

/** Detectors occasionally emit inverted or zero-height boxes; make them sane. */
function norm(b: Bbox): Bbox {
  return {
    x1: Math.min(b.x1, b.x2),
    x2: Math.max(b.x1, b.x2),
    y1: Math.min(b.y1, b.y2),
    y2: Math.max(b.y1, b.y2),
  };
}

// Floor of 1 keeps a zero-height box from producing a divide-by-zero ratio.
const heightOf = (b: Bbox) => Math.max(b.y2 - b.y1, 1);

/**
 * Two boxes sit on the same visual line when they are comparable in height and
 * their vertical extents overlap by more than half the shorter one. Both tests
 * are height-relative rather than a fixed pixel slack, so they hold at whatever
 * resolution the capture came in at.
 */
export function sameLine(a: Bbox, b: Bbox): boolean {
  const na = norm(a);
  const nb = norm(b);
  const ha = heightOf(na);
  const hb = heightOf(nb);

  if (Math.max(ha, hb) / Math.min(ha, hb) > MAX_LINE_HEIGHT_RATIO) return false;

  const overlap = Math.min(na.y2, nb.y2) - Math.max(na.y1, nb.y1);
  return overlap > 0.5 * Math.min(ha, hb);
}

/**
 * Detections arrive in model order, which reads as gibberish when spoken.
 * Group them into lines, then order lines top-to-bottom and boxes within a line
 * left-to-right.
 *
 * Each line is anchored on its first (topmost) box — input is sorted by `y1`
 * first, so the anchor never drifts downward as boxes are added.
 */
export function toReadingOrder(boxes: TextBox[]): TextBox[] {
  const byTop = [...boxes].sort((a, b) => norm(a.bbox).y1 - norm(b.bbox).y1);

  const lines: TextBox[][] = [];
  for (const box of byTop) {
    const line = lines.find((l) => sameLine(l[0].bbox, box.bbox));
    if (line) line.push(box);
    else lines.push([box]);
  }

  return lines.flatMap((line) =>
    [...line].sort((p, q) => norm(p.bbox).x1 - norm(q.bbox).x1)
  );
}

/** Cut at the last word boundary that fits, so TTS never clips mid-word. */
export function truncateWords(text: string, maxChars: number): string {
  if (maxChars <= 0) return '';
  if (text.length <= maxChars) return text;

  const cut = text.slice(0, maxChars);
  const lastSpace = cut.lastIndexOf(' ');
  // A single word longer than the cap has no boundary to fall back on.
  return (lastSpace > 0 ? cut.slice(0, lastSpace) : cut).trimEnd();
}

export type ComposeOptions = { minScore?: number; maxChars?: number };

/**
 * Drop noise, put what's left in reading order, join it into one utterance.
 * Returns `''` when nothing survives — the caller says "No text found."
 */
export function composeSpeech(boxes: TextBox[], opts: ComposeOptions = {}): string {
  const minScore = opts.minScore ?? MIN_SCORE;
  const maxChars = opts.maxChars ?? DEFAULT_MAX_CHARS;

  const kept = boxes.filter((b) => b.score >= minScore && b.text.trim() !== '');

  const text = toReadingOrder(kept)
    .map((b) => b.text.trim())
    .join(' ')
    .replace(/\s+/g, ' ')
    .trim();

  return truncateWords(text, maxChars);
}
