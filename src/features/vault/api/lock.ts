// App unlock, backed by the Android Keystore via react-native-keychain.
//
// Not a cosmetic prompt over the UI: there is a secret in hardware-backed
// storage whose access policy requires the device owner to authenticate, so
// getting into the app means satisfying the Keystore — the same mechanism that
// will guard the E2E message keys.
//
// react-native-keychain is already in the dev-client APK and contributes
// USE_BIOMETRIC to the merged manifest, so this needs no native rebuild.
//
// IMPORTANT: creating a key that requires user authentication on a phone with
// nothing enrolled makes Android launch its fingerprint-enrollment flow. That
// must never happen as a side effect of opening the app, so the key is only
// ever created from an explicit opt-in — see `enableLock`.
import * as Keychain from 'react-native-keychain';

const SERVICE = 'app.echo.unlock';
const ACCOUNT = 'echo';

/** The value is irrelevant; reaching it is the proof. */
const TOKEN = 'unlocked';

export type LockOutcome =
  | { ok: true }
  | { ok: false; reason: 'cancelled' | 'unavailable' | 'error'; message?: string };

const guarded = {
  service: SERVICE,
  // Biometrics first, device PIN as fallback. Biometry-only would shut out a
  // phone whose owner uses a PIN.
  accessControl: Keychain.ACCESS_CONTROL.BIOMETRY_ANY_OR_DEVICE_PASSCODE,
  accessible: Keychain.ACCESSIBLE.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
} as const;

const prompt = {
  title: 'Unlock Echo',
  subtitle: 'Your messages, keys and wallet are on this phone',
  cancel: 'Cancel',
};

const looksCancelled = (e: unknown) => {
  const text = String(e).toLowerCase();
  return text.includes('cancel') || text.includes('code: 13');
};

/** Does this phone have biometric hardware at all? Says nothing about whether
 *  anything is actually enrolled — Android has no such check outside
 *  expo-local-authentication's `isEnrolledAsync`, which needs a native rebuild. */
export async function hasBiometricHardware(): Promise<boolean> {
  try {
    return (await Keychain.getSupportedBiometryType()) !== null;
  } catch {
    return false;
  }
}

/** Has the user already turned the lock on? Does not authenticate or prompt. */
export async function isLockEnabled(): Promise<boolean> {
  try {
    return await Keychain.hasGenericPassword({ service: SERVICE });
  } catch {
    return false;
  }
}

/**
 * Turn the lock on. Only call this from a deliberate user action — on a phone
 * with no fingerprint enrolled, Android may open its enrollment flow here, and
 * that is only acceptable when someone has just asked for exactly this.
 */
export async function enableLock(): Promise<LockOutcome> {
  try {
    await Keychain.setGenericPassword(ACCOUNT, TOKEN, guarded);
    return { ok: true };
  } catch (e) {
    if (looksCancelled(e)) return { ok: false, reason: 'cancelled' };
    return { ok: false, reason: 'error', message: e instanceof Error ? e.message : String(e) };
  }
}

/** Ask the device owner to prove who they are. Only meaningful once enabled. */
export async function unlock(): Promise<LockOutcome> {
  try {
    const held = await Keychain.getGenericPassword({
      ...guarded,
      authenticationPrompt: prompt,
    });
    return held ? { ok: true } : { ok: false, reason: 'cancelled' };
  } catch (e) {
    if (looksCancelled(e)) return { ok: false, reason: 'cancelled' };
    return { ok: false, reason: 'error', message: e instanceof Error ? e.message : String(e) };
  }
}

/** Turn the lock off, or recover a demo phone that got into a bad state. */
export async function forgetLock(): Promise<void> {
  try {
    await Keychain.resetGenericPassword({ service: SERVICE });
  } catch {
    // Nothing stored — already where we wanted to be.
  }
}
