// "Read that" — OCR a captured frame and hand back one speakable string.
//
// Wraps executorch's useOCR, which loads the detector + recognizer on mount and
// deletes them on unmount. Loading is gated behind `enabled` so a screen that
// cannot use the camera never pulls ~50MB of model binaries into RAM.
import { useCallback, useEffect, useRef, useState } from 'react';
import { OCR_ENGLISH, useOCR } from 'react-native-executorch';
import { composeSpeech } from '../../../utils/ocr';
import type { ReadTextState, TextBox } from '../types';

export type ReadResult = { text: string; boxes: TextBox[] };

export type ReadOutcome =
  /** A read ran. `text` is `''` when it found nothing. */
  | { status: 'ok'; result: ReadResult }
  /** forward() rejected, or the models are not usable. */
  | { status: 'failed' }
  /** Refused before doing any work — not ready, or one already in flight. */
  | { status: 'skipped' };

function errText(e: unknown): string {
  if (e instanceof Error) return e.message;
  if (typeof e === 'object' && e !== null && 'message' in e) {
    return String((e as { message: unknown }).message);
  }
  return String(e);
}

export type UseReadText = ReadTextState & {
  /** OCR the image at `uri`. Never throws; see `ReadOutcome`. */
  read: (uri: string) => Promise<ReadOutcome>;
  clear: () => void;
};

export function useReadText(
  maxChars?: number,
  options: { enabled?: boolean } = {}
): UseReadText {
  const enabled = options.enabled ?? true;
  const ocr = useOCR({ model: OCR_ENGLISH, preventLoad: !enabled });

  const [transcript, setTranscript] = useState<string | null>(null);
  const [failure, setFailure] = useState<string | null>(null);

  // Leaving the tab can unmount us while forward() is still in flight.
  const mounted = useRef(true);
  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);

  // React state is committed a render too late to serialise two taps that land
  // in the same event batch. A ref flips synchronously, so it actually holds.
  const inFlight = useRef(false);

  const { isReady, isGenerating, forward } = ocr;

  const read = useCallback(
    async (uri: string): Promise<ReadOutcome> => {
      // Load-bearing, not defensive: in executorch 0.9.2 forward() throws when
      // the models are unloaded (ModuleNotLoaded) or already processing
      // another image (ModelGenerating).
      if (inFlight.current || !isReady || isGenerating) return { status: 'skipped' };

      inFlight.current = true;
      setFailure(null);
      // Drop the previous read straight away — leaving it on screen under a
      // "LAST READ" heading during the next capture is a lie.
      setTranscript(null);
      try {
        const detections = await forward(uri);
        const boxes = detections as TextBox[];
        const text = composeSpeech(boxes, { maxChars });
        if (!mounted.current) return { status: 'skipped' };
        setTranscript(text);
        return { status: 'ok', result: { text, boxes } };
      } catch (e) {
        if (!mounted.current) return { status: 'skipped' };
        setFailure(errText(e));
        return { status: 'failed' };
      } finally {
        inFlight.current = false;
      }
    },
    [isReady, isGenerating, forward, maxChars]
  );

  const clear = useCallback(() => {
    setTranscript(null);
    setFailure(null);
  }, []);

  // A load/download failure outlives any single read, so it wins over the
  // per-read message. `||` rather than `??` so an empty message reads as none.
  const hookError = ocr.error ? errText(ocr.error) : '';

  return {
    isReady,
    isBusy: isGenerating,
    downloadProgress: ocr.downloadProgress,
    error: hookError || failure || null,
    transcript,
    read,
    clear,
  };
}
