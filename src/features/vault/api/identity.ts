// This phone's identity: a stable id and the name other people see.
//
// The id is what routing and pairing use — it must survive restarts, or the
// phone you spoke to five minutes ago comes back as a stranger. The name is
// what a human reads on a pairing code, so it is chosen once at first launch
// rather than inferred from the hardware: "SM-S938B" tells nobody anything.
//
// Uses expo-file-system, already in the build — no new native module. When the
// vault lands, the id should become the public-key fingerprint so identity and
// key material cannot disagree.
import { File, Paths } from 'expo-file-system';
import { clearContacts } from './contacts';

const PROFILE = 'echo-identity';
const CONTACTS = 'echo-contacts';

export type Profile = { id: string; name: string };

let cache: Profile | null = null;

const profileFile = () => new File(Paths.document, PROFILE);

const mintId = () => Math.random().toString(36).slice(2, 10);

/**
 * Reads the stored profile. Returns null when this phone has never been set up,
 * which is what sends someone to the name screen.
 */
export async function loadProfile(): Promise<Profile | null> {
  if (cache) return cache;
  try {
    const f = profileFile();
    if (f.exists) {
      const raw = (await f.text()).trim();
      if (raw) {
        const parsed = JSON.parse(raw) as Partial<Profile>;
        if (parsed?.id && parsed?.name) {
          cache = { id: parsed.id, name: parsed.name };
          return cache;
        }
      }
    }
  } catch {
    // Unreadable or from an older build — treat as not set up.
  }
  return null;
}

/** First launch, or after a reset. Mints a fresh id to go with the name. */
export async function createProfile(name: string): Promise<Profile> {
  const profile: Profile = { id: mintId(), name: name.trim() };
  write(profile);
  cache = profile;
  return profile;
}

/** Rename without becoming a different phone — the id is untouched. */
export async function renameProfile(name: string): Promise<Profile | null> {
  const current = await loadProfile();
  if (!current) return null;
  const next = { ...current, name: name.trim() };
  write(next);
  cache = next;
  return next;
}

function write(profile: Profile): void {
  try {
    const f = profileFile();
    f.create({ overwrite: true });
    f.write(JSON.stringify(profile));
  } catch {
    // Storage refused. The profile still holds for this session; the cost is
    // that a restart looks like a new phone.
  }
}

/**
 * Wipe this phone back to factory: no id, no name, no contacts. The next launch
 * asks for a name and mints a new id, so to everyone else this becomes a
 * genuinely different phone rather than the same one with the history hidden.
 */
export function resetIdentity(): void {
  cache = null;
  clearContacts();
  for (const name of [PROFILE, CONTACTS]) {
    try {
      const f = new File(Paths.document, name);
      if (f.exists) f.delete();
    } catch {
      // Nothing there, or storage refused. Carry on and clear the rest.
    }
  }
}
