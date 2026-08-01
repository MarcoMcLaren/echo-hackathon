// A device id that survives restarts.
//
// Without this, every app launch mints a new identity, so the phone you were
// talking to five minutes ago comes back as a stranger and the old one lingers
// on the map as a node that will never reconnect.
//
// Uses expo-file-system, which is already in the build — no new native module.
// When the vault lands this should become the public-key fingerprint instead of
// a random string, so identity and key material can't disagree.
import { File, Paths } from 'expo-file-system';

const FILENAME = 'echo-identity';

let cached: string | null = null;

const mint = () => Math.random().toString(36).slice(2, 8);

/** Stable across launches. Falls back to a per-launch id if storage fails. */
export async function deviceIdentity(): Promise<string> {
  if (cached) return cached;

  const file = new File(Paths.document, FILENAME);

  try {
    if (file.exists) {
      const saved = (await file.text()).trim();
      if (saved) {
        cached = saved;
        return saved;
      }
    }
  } catch {
    // Unreadable file — fall through and replace it.
  }

  const id = mint();
  try {
    file.create({ overwrite: true });
    file.write(id);
  } catch {
    // Storage refused. A per-launch id still works for this session; the only
    // cost is that peers see us as new after a restart.
  }
  cached = id;
  return id;
}
