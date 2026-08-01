// Who you can actually talk to.
//
// The radio finds every Echo phone in range, but being in range is not a
// relationship. Those phones are *nodes*: they carry traffic and nothing more.
// Someone becomes a *contact* only through a deliberate physical act — a tap or
// a scanned code — and only contacts get a conversation.
//
// This is an allowlist, which means there is no "block" to maintain: a stranger
// cannot message you because they were never on the list, and removing someone
// puts them back to being just another node.
import { File, Paths } from 'expo-file-system';

const FILENAME = 'echo-contacts';

export type Contact = { id: string; name: string; addedAt: number };

let cache: Record<string, Contact> | null = null;

const file = () => new File(Paths.document, FILENAME);

export async function loadContacts(): Promise<Record<string, Contact>> {
  if (cache) return cache;
  try {
    const f = file();
    if (f.exists) {
      const raw = (await f.text()).trim();
      cache = raw ? (JSON.parse(raw) as Record<string, Contact>) : {};
      return cache;
    }
  } catch {
    // Unreadable or malformed — start clean rather than refuse to run.
  }
  cache = {};
  return cache;
}

function persist(all: Record<string, Contact>): void {
  try {
    const f = file();
    f.create({ overwrite: true });
    f.write(JSON.stringify(all));
  } catch {
    // Storage refused. The list still holds for this session.
  }
}

/** Called when a tap or a scanned code proves the two phones met. */
export async function addContact(id: string, name: string): Promise<Record<string, Contact>> {
  const all = await loadContacts();
  // Keep the original addedAt if they were already known, so re-pairing after
  // a name change doesn't look like a brand new relationship.
  all[id] = { id, name, addedAt: all[id]?.addedAt ?? Date.now() };
  persist(all);
  return { ...all };
}

/** They go back to being a node: still relaying, no longer someone you chat to. */
export async function removeContact(id: string): Promise<Record<string, Contact>> {
  const all = await loadContacts();
  delete all[id];
  persist(all);
  return { ...all };
}

/** Forget everyone. Used by the reset; drops the in-memory cache as well as
 *  the file, so nothing survives a wipe. */
export function clearContacts(): void {
  cache = {};
  persist({});
}
