// Hold-to-talk maths: gesture thresholds, waveform framing, draft merging.
//
// Pure on purpose: no React, no Expo, no executorch, no audio-api.
// `test/dictation.test.ts` runs this under plain node. Only `import type` is
// allowed here — node's type stripping erases those, so nothing is resolved at
// runtime. (This module happens to need none at all.)

/**
 * Whisper's native runner is hard-wired to 16 kHz mono. It does not resample:
 * hand it 44.1 kHz and it transcribes a chipmunk. See
 * `rnexecutorch/models/speech_to_text/whisper/Constants.h`.
 */
export const SAMPLE_RATE = 16000;

/** `kMinChunkSamples` — under one second there is nothing to transcribe. */
export const MIN_SAMPLES = 16000;

/** `kMaxSamples` — 29 s. Whisper cannot see past its 30 s window. */
export const MAX_SAMPLES = 464000;

/**
 * Samples per `onAudioReady` callback — 100 ms. Small enough that the 29 s
 * ceiling lands within a tenth of a second, large enough not to wake JS 160
 * times a second while the user is talking.
 */
export const BUFFER_LENGTH = 1600;

/**
 * Slide the thumb this far *up* from the mic to latch hands-free recording.
 * Negative because React Native measures up and left as negative dy/dx.
 */
export const LOCK_DY = -64;

/** Slide this far *left* to throw the take away. Deliberately further than
 *  the lock: cancelling is destructive, so it should take more intent. */
export const CANCEL_DX = -80;

/**
 * A 0..1 download or load progress as a whole percent, ready to drop into a
 * label. Clamped and NaN-guarded because the number comes from a native
 * fetcher: a response with no content-length reports NaN, and a group of files
 * can briefly overshoot 1 as each one's total lands. "Loading model NaN%" is
 * exactly the kind of thing that ships.
 */
export const progressPercent = (progress: number): number =>
  Number.isFinite(progress) ? Math.min(100, Math.max(0, Math.round(progress * 100))) : 0;

/**
 * What the finger is currently asking for. `armed-` names the request, not a
 * committed state — the component decides what to do with it.
 */
export type GesturePhase = 'recording' | 'armed-lock' | 'armed-cancel';

/**
 * Cancel is tested first so a diagonal slide throws the take away rather than
 * locking it: with a locked take the user has to find a second control to undo
 * a gesture they meant as "no". `locked` suppresses re-locking, but never
 * suppresses cancel — a hands-free take still has to be escapable.
 */
export const gesturePhase = (
  { dx, dy }: { dx: number; dy: number },
  locked: boolean
): GesturePhase =>
  dx < CANCEL_DX ? 'armed-cancel' : !locked && dy < LOCK_DY ? 'armed-lock' : 'recording';

/** A take shorter than this is a fumbled tap, not speech. */
export const isLongEnough = (samples: number): boolean => samples >= MIN_SAMPLES;

/**
 * Flatten the recorder's 100 ms chunks into the single Float32Array Whisper
 * wants, clamped to the 29 s ceiling. Anything past the cap is dropped rather
 * than allocated — the model would ignore it anyway.
 */
export function concatChunks(chunks: Float32Array[]): Float32Array {
  let total = 0;
  for (const chunk of chunks) total += chunk.length;

  const out = new Float32Array(Math.min(total, MAX_SAMPLES));
  let at = 0;
  for (const chunk of chunks) {
    const room = out.length - at;
    if (room <= 0) break;
    out.set(chunk.length <= room ? chunk : chunk.subarray(0, room), at);
    at += Math.min(chunk.length, room);
  }
  return out;
}

/**
 * Put a transcript into the draft field the user is about to edit. One space
 * between what was already there and what was just said — never two, never a
 * leading one. A blank transcript leaves the draft byte-for-byte alone, so
 * "didn't catch that" cannot quietly reformat what the user typed.
 */
export function mergeDraft(draft: string, transcript: string): string {
  const said = transcript.trim();
  if (!said) return draft;

  const head = draft.trimEnd();
  return head ? `${head} ${said}` : said;
}
