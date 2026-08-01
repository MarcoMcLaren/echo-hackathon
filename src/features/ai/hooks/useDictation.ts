// Hold to talk — record 16 kHz PCM, transcribe it on-device, hand back text.
//
// Wraps executorch's useSpeechToText (Whisper tiny.en) over the microphone in
// `messaging/api/recorder`. Loading is gated behind `enabled` so a screen that
// will never dictate does not pull ~222MB of model binaries into RAM. The
// transcript is returned, never sent — the caller stages it in a draft field.
import { useCallback, useEffect, useRef, useState } from 'react';
import { WHISPER_TINY_EN, useSpeechToText } from 'react-native-executorch';
import { DictationRecorder } from '../../messaging/api/recorder';
import { isLongEnough } from '../../../utils/dictation';
import type { DictationPhase, DictationState } from '../types';

export type StartOutcome =
  /** The mic is open. */
  | { status: 'ok' }
  /** The user said no. `blocked` means only Android Settings can undo it. */
  | { status: 'denied'; blocked: boolean }
  /** The mic would not open. */
  | { status: 'failed' }
  /** Refused before doing any work — not ready, or a take is already running. */
  | { status: 'skipped' };

export type StopOutcome =
  /** Whisper heard words. */
  | { status: 'ok'; text: string }
  /** Under a second of audio; `transcribe()` was never called. */
  | { status: 'short' }
  /** Transcribed fine, found nothing to say. */
  | { status: 'empty' }
  /**
   * Real audio was captured and then thrown away, because the model could not
   * take it — unloaded, or still busy with the previous take. Distinct from
   * `skipped` on purpose: something was lost, so the user has to be told.
   */
  | { status: 'discarded' }
  /** `transcribe()` rejected, or the take died mid-recording. */
  | { status: 'failed'; message?: string }
  /** There was no take to stop. Nothing was captured, nothing was lost. */
  | { status: 'skipped' };

/** Nothing to report beyond "it happened" or "there was nothing to do". */
export type DictationAck = { status: 'ok' } | { status: 'skipped' };

function errText(e: unknown): string {
  if (e instanceof Error) return e.message;
  if (typeof e === 'object' && e !== null && 'message' in e) {
    return String((e as { message: unknown }).message);
  }
  return String(e);
}

/** Built on first use, not on mount: most chats never open the microphone. */
const micOf = (ref: { current: DictationRecorder | null }) =>
  (ref.current ??= new DictationRecorder());

export type UseDictation = DictationState & {
  phase: DictationPhase;
  /** Open the mic. Never throws; see `StartOutcome`. */
  start: () => Promise<StartOutcome>;
  /** Latch the take so it survives the finger lifting. */
  lock: () => DictationAck;
  /** Close the mic and transcribe. Never throws; see `StopOutcome`. */
  stop: () => Promise<StopOutcome>;
  /** Close the mic and drop everything. Never throws. */
  cancel: () => Promise<DictationAck>;
};

export function useDictation(
  options: {
    enabled?: boolean;
    /** Fired when the 29 s ceiling ends the take on its own. Nobody is
     *  awaiting `stop()` in that case, so the transcript arrives here. */
    onAutoStop?: (outcome: StopOutcome) => void;
  } = {}
): UseDictation {
  const enabled = options.enabled ?? true;
  const stt = useSpeechToText({ model: WHISPER_TINY_EN, preventLoad: !enabled });

  const [phase, setPhase] = useState<DictationPhase>('idle');
  const [failure, setFailure] = useState<string | null>(null);

  // Backing out of the chat can unmount us while transcribe() is in flight.
  const mounted = useRef(true);
  const recorder = useRef<DictationRecorder | null>(null);
  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
      // Leaving mid-take would otherwise leave the microphone open.
      void recorder.current?.abort();
    };
  }, []);

  // The phase doubles as the re-entrancy latch, so it lives in a ref as well as
  // in state: React commits state a render too late to serialise a release and
  // a ceiling that land in the same event batch. The ref flips synchronously.
  const phaseRef = useRef<DictationPhase>('idle');
  const setPhaseNow = useCallback((next: DictationPhase) => {
    phaseRef.current = next;
    if (mounted.current) setPhase(next);
  }, []);

  const inTake = () => phaseRef.current === 'recording' || phaseRef.current === 'locked';

  const { isReady, isGenerating, transcribe } = stt;

  // Held in a ref so `start` does not have to be rebuilt every time the screen
  // re-renders — the PanResponder below it captures these once.
  const autoStop = useRef(options.onAutoStop);
  autoStop.current = options.onAutoStop;

  const stop = useCallback(async (): Promise<StopOutcome> => {
    if (!inTake()) return { status: 'skipped' };

    // Load-bearing, not defensive: in executorch 0.9.2 transcribe() throws when
    // the model is unloaded (ModuleNotLoaded) or already running
    // (ModelGenerating). Asked here, before the recording is touched — the
    // recorder's stop() both collects and frees the buffers, so learning it
    // afterwards is how twenty seconds of speech disappears with nothing said.
    const usable = isReady && !isGenerating;
    setPhaseNow('transcribing');

    try {
      if (!usable) {
        // Drop it deliberately rather than concatenating half a megabyte we
        // cannot use, and report the loss so the caller can own up to it.
        await micOf(recorder).abort();
        return { status: 'discarded' };
      }

      const waveform = await micOf(recorder).stop();

      // Below kMinChunkSamples there is nothing to transcribe, and the native
      // runner would reject it anyway.
      if (!isLongEnough(waveform.length)) return { status: 'short' };

      // No `language` option: WHISPER_TINY_EN is English-only and throws
      // MultilingualConfiguration if you name a language.
      const result = await transcribe(waveform);
      const text = result.text.trim();
      if (!mounted.current) return { status: 'skipped' };
      return text ? { status: 'ok', text } : { status: 'empty' };
    } catch (e) {
      if (!mounted.current) return { status: 'skipped' };
      setFailure(errText(e));
      return { status: 'failed' };
    } finally {
      // Re-arms the mic whether we transcribed, gave up, or were unmounted.
      setPhaseNow('idle');
    }
  }, [isReady, isGenerating, transcribe, setPhaseNow]);

  const cancel = useCallback(async (): Promise<DictationAck> => {
    if (!inTake()) return { status: 'skipped' };
    setPhaseNow('idle');
    await micOf(recorder).abort();
    return { status: 'ok' };
  }, [setPhaseNow]);

  const start = useCallback(async (): Promise<StartOutcome> => {
    if (phaseRef.current !== 'idle' || !isReady || isGenerating) return { status: 'skipped' };
    // Set before the first await: a release can land before the permission
    // dialog resolves, and it has to find a take in progress.
    setPhaseNow('recording');
    if (mounted.current) setFailure(null);

    const outcome = await micOf(recorder).start({
      onCeiling: () => {
        void stop().then((result) => autoStop.current?.(result));
      },
      onError: (message) => {
        if (mounted.current) setFailure(message);
        // The take died with nobody awaiting stop() — a call stole the mic, or
        // the device delivered the wrong sample rate. Push the outcome the same
        // way the 29 s ceiling does, or the recording just stops and the user
        // is left holding a phone that says nothing.
        void cancel().then((ack) => {
          if (ack.status === 'ok') autoStop.current?.({ status: 'failed', message });
        });
      },
    });

    if (outcome.status === 'recording') {
      // Unmounted while the dialog was up: the cleanup ran before there was a
      // recorder to abort, so close it here instead.
      if (!mounted.current) {
        void micOf(recorder).abort();
        phaseRef.current = 'idle';
        return { status: 'skipped' };
      }
      return { status: 'ok' };
    }

    setPhaseNow('idle');
    if (outcome.status === 'denied') return { status: 'denied', blocked: outcome.blocked };
    if (mounted.current) setFailure(outcome.message);
    return { status: 'failed' };
  }, [isReady, isGenerating, setPhaseNow, stop, cancel]);

  const lock = useCallback((): DictationAck => {
    if (phaseRef.current !== 'recording') return { status: 'skipped' };
    setPhaseNow('locked');
    return { status: 'ok' };
  }, [setPhaseNow]);

  // A load/download failure outlives any single take, so it wins over the
  // per-take message. `||` rather than `??` so an empty message reads as none.
  const hookError = stt.error ? errText(stt.error) : '';

  return {
    isReady,
    isBusy: isGenerating || phase === 'transcribing',
    downloadProgress: stt.downloadProgress,
    error: hookError || failure || null,
    phase,
    start,
    lock,
    stop,
    cancel,
  };
}
