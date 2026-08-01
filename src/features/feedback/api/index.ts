// Haptics + speech output wrappers (expo-haptics, expo-speech).
//
// Everything here is best-effort: a phone with no vibration motor, or an OS TTS
// engine that is mid-restart, must never take down a read. Failures are
// swallowed on purpose.
import * as Haptics from 'expo-haptics';
import * as Speech from 'expo-speech';

/**
 * Longest utterance the OS will accept. Android reports a real count (~4000);
 * iOS reports `Number.MAX_VALUE`, which is useless as a slice length.
 *
 * Note `Number.isFinite(Number.MAX_VALUE)` is `true` — a finiteness check does
 * not filter that out. Only a safe-integer check does.
 */
const reportedMax: number = Speech.maxSpeechInputLength;
export const maxSpeechChars =
  Number.isSafeInteger(reportedMax) && reportedMax > 0 ? reportedMax : 3900;

async function quietly(run: () => Promise<unknown>): Promise<void> {
  try {
    await run();
  } catch {
    // Feedback is an enhancement, never the reason a read fails.
  }
}

/**
 * Speak one utterance, replacing anything already queued. Echo never lets two
 * announcements overlap — for someone relying on audio alone, overlapping
 * speech is worse than silence.
 */
export async function speak(
  text: string,
  options: Speech.SpeechOptions = {}
): Promise<void> {
  await quietly(async () => {
    await Speech.stop();
    Speech.speak(text, {
      language: 'en-US',
      // Without this the engine can fail silently — missing voice data, engine
      // restarting — while the caller has already fired a success haptic. Buzz
      // the failure so the outcome is never a lie.
      onError: () => {
        void notifyFail();
      },
      ...options,
    });
  });
}

export async function stopSpeaking(): Promise<void> {
  await quietly(() => Speech.stop());
}

/** Shutter confirmation — "the capture happened", felt rather than heard. */
export async function tick(): Promise<void> {
  await quietly(() => Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light));
}

/** The read completed, whether or not it found words. */
export async function notifyOk(): Promise<void> {
  await quietly(() => Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success));
}

/** The read failed — distinct from "no text found". */
export async function notifyFail(): Promise<void> {
  await quietly(() => Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error));
}
