// TS interfaces for OCR / scene-description results.

/** Axis-aligned box in the source image's pixel coordinates. */
export type Bbox = { x1: number; y1: number; x2: number; y2: number };

/**
 * One recognized run of text.
 *
 * Structurally identical to executorch's `OCRDetection`, redeclared here on
 * purpose: it lets the pure helpers in `utils/ocr.ts` be unit-tested under
 * plain node, which cannot resolve a native module.
 */
export type TextBox = { bbox: Bbox; text: string; score: number };

/**
 * Where a dictation take is in its life: press → (slide up to lock) → release
 * → transcribe. `locked` is the one phase that outlives the finger.
 */
export type DictationPhase = 'idle' | 'recording' | 'locked' | 'transcribing';

/** What `useDictation` reports to a screen. Same quartet as `ReadTextState`. */
export type DictationState = {
  /** Whisper is loaded, so `transcribe()` will not throw ModuleNotLoaded. */
  isReady: boolean;
  /** A take is being transcribed; a second `transcribe()` would throw. */
  isBusy: boolean;
  /** 0..1 while the model binaries download on first use. */
  downloadProgress: number;
  error: string | null;
};

/** What `useReadText` reports to a screen. */
export type ReadTextState = {
  /** Both detector and recognizer are loaded and can accept a frame. */
  isReady: boolean;
  /** A frame is being processed; a second `forward()` would throw. */
  isBusy: boolean;
  /** 0..1 while the model binaries download on first use. */
  downloadProgress: number;
  error: string | null;
  /** Last successful read. `''` means "ran fine, found nothing". */
  transcript: string | null;
};
