// Shake to take it back.
//
// STATUS: inert until the next dev-client rebuild.
//
// `expo-sensors` is in package.json so a rebuild links it natively, but its JS
// throws from module scope when the native side is missing — and Metro
// evaluates the module even from inside a guarded `require`, which takes the
// whole app down. So the import is not written yet.
//
// TO ENABLE, after rebuilding the dev client with expo-sensors linked:
//   1. set SHAKE_ENABLED = true
//   2. uncomment the import and the two marked lines below
// Nothing else changes; callers already handle it doing nothing.
//
// Every action this triggers must also have a visible control. A shake is
// undiscoverable, and unusable for anyone who cannot shake a phone.
import { useEffect, useRef } from 'react';
// import { Accelerometer } from 'expo-sensors';

const SHAKE_ENABLED = false;

/** Total g-force above rest. A firm shake clears this; walking does not. */
const THRESHOLD = 1.7;

/** One shake is many samples over threshold — only act on the first. */
const COOLDOWN_MS = 1500;

export function useShake(onShake: () => void, enabled = true) {
  const fired = useRef(0);
  const handler = useRef(onShake);
  handler.current = onShake;

  useEffect(() => {
    if (!SHAKE_ENABLED || !enabled) return;

    // Re-enable body (step 2):
    //
    //   let sub: { remove: () => void } | null = null;
    //   let cancelled = false;
    //   (async () => {
    //     try {
    //       if (!(await Accelerometer.isAvailableAsync())) return;
    //       if (cancelled) return;
    //       Accelerometer.setUpdateInterval(100);
    //       sub = Accelerometer.addListener(({ x, y, z }) => {
    //         const force = Math.sqrt(x * x + y * y + z * z);
    //         const now = Date.now();
    //         if (force < THRESHOLD || now - fired.current < COOLDOWN_MS) return;
    //         fired.current = now;
    //         handler.current();
    //       });
    //     } catch {}
    //   })();
    //   return () => { cancelled = true; sub?.remove(); };
    void fired;
  }, [enabled]);
}

// Referenced only by the commented listener above; kept so the constants don't
// drift from the code that will use them.
void THRESHOLD;
void COOLDOWN_MS;
