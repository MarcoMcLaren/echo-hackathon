// Shake to take it back.
//
// Every action this triggers must also have a visible control. A shake is
// undiscoverable, and unusable for anyone who cannot shake a phone — it is a
// shortcut for people who already know it exists, never the only way through.
import { useEffect, useRef } from 'react';
import { Accelerometer } from 'expo-sensors';

/** Total g-force. At rest a phone reads ~1g, so this is a deliberate movement. */
const THRESHOLD = 1.7;

/** One shake is many samples over threshold — only act on the first. */
const COOLDOWN_MS = 1500;

export function useShake(onShake: () => void, enabled = true) {
  const fired = useRef(0);
  const handler = useRef(onShake);
  handler.current = onShake;

  useEffect(() => {
    if (!enabled) return;

    // Start the cooldown from the moment we arm, not from the last shake. The
    // ref outlives the unsubscribe, so re-enabling after the listener was off
    // would otherwise let the very first sample through — and whatever made us
    // turn the listener off (raising the phone to dictate) ends with lowering
    // it again, which clears 1.7 g on its own. That fires an unconfirmed
    // revertLastCoin as a side effect of finishing a sentence.
    fired.current = Date.now();

    let sub: { remove: () => void } | null = null;
    let cancelled = false;

    (async () => {
      try {
        if (!(await Accelerometer.isAvailableAsync())) return;
        if (cancelled) return;

        Accelerometer.setUpdateInterval(100);
        sub = Accelerometer.addListener(({ x, y, z }) => {
          const force = Math.sqrt(x * x + y * y + z * z);
          const now = Date.now();
          if (force < THRESHOLD || now - fired.current < COOLDOWN_MS) return;
          fired.current = now;
          handler.current();
        });
      } catch {
        // No accelerometer on this device or in this build. The visible
        // control still does the job.
      }
    })();

    return () => {
      cancelled = true;
      sub?.remove();
    };
  }, [enabled]);
}
