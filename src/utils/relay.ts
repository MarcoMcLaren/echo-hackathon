// Message relay: the app-layer hop logic that turns Nearby's one-room P2P
// clustering into something that reaches past a single radio range.
//
// Pure functions only — no native calls, no store access — so the hop rules can
// be reasoned about and tested on their own. This is the part that decides
// whether A -> B -> C works, so it stays boring and inspectable.

/** What actually travels between phones. Kept small; Nearby sends it as text. */
export type Envelope = {
  /** Unique per original message. Dedupe key — survives every hop unchanged. */
  id: string;
  /** Device id of whoever composed it. Never rewritten by a relay. */
  from: string;
  /** Device id of the intended reader, or a thread id for a group. */
  to: string;
  /**
   * `revert` carries the id of an earlier coin message to undo.
   * `image` carries base64 image data, split across parts.
   * `event` carries a calendar event as JSON.
   */
  kind: 'msg' | 'coin' | 'revert' | 'image' | 'event';
  /** Opaque to relays. Ciphertext once the vault lands. */
  body: string;
  /** Set on every part of a split payload. Shared by all parts of one message. */
  gid?: string;
  /** Which part this is, and how many there are. Absent means a whole message. */
  part?: { i: number; n: number };
  /** Hops remaining. A relay forwards only while this is above zero. */
  ttl: number;
  /** Device ids this has already passed through, in order. Builds the route strip. */
  path: string[];
  /** Composed-at, from the sender's clock. Display only — never trusted for ordering. */
  at: number;
};

export const DEFAULT_TTL = 3;

export const newEnvelope = (
  args: Pick<Envelope, 'id' | 'from' | 'to' | 'kind' | 'body' | 'at'> & { ttl?: number }
): Envelope => ({
  ...args,
  ttl: args.ttl ?? DEFAULT_TTL,
  path: [],
});

/** Hops taken so far. 0 means it arrived directly from the sender. */
export const hopsTaken = (e: Envelope): number => e.path.length;

/** The device that handed it to us, if anyone relayed it. */
export const relayedBy = (e: Envelope): string | undefined => e.path[e.path.length - 1];

/**
 * Fixed-size ring of message ids we've already handled. A plain Set would grow
 * without bound over a long demo; this forgets the oldest instead.
 */
export class SeenCache {
  private order: string[] = [];
  private set = new Set<string>();
  constructor(private limit = 512) {}

  /** True if this id was already seen. Records it either way. */
  check(id: string): boolean {
    if (this.set.has(id)) return true;
    this.set.add(id);
    this.order.push(id);
    if (this.order.length > this.limit) {
      const oldest = this.order.shift()!;
      this.set.delete(oldest);
    }
    return false;
  }

  get size() {
    return this.set.size;
  }
}

export type Decision =
  | { action: 'drop'; why: 'duplicate' | 'expired' | 'loop' }
  | { action: 'deliver'; envelope: Envelope }
  | { action: 'relay'; envelope: Envelope; excludePeer?: string };

/**
 * The whole hop rule, in one place.
 *
 * `me` is this device's id, `from` the peer that handed it over (undefined if we
 * composed it). Returns what to do — the caller performs the side effects.
 */
export function route(
  envelope: Envelope,
  me: string,
  seen: SeenCache,
  fromPeer?: string
): Decision {
  if (seen.check(envelope.id)) return { action: 'drop', why: 'duplicate' };

  // Our own id already in the path means it came back around to us.
  if (envelope.path.includes(me)) return { action: 'drop', why: 'loop' };

  if (envelope.to === me) return { action: 'deliver', envelope };

  if (envelope.ttl <= 0) return { action: 'drop', why: 'expired' };

  // Carry it on: burn a hop and record that we touched it, so the recipient can
  // see the route it took.
  return {
    action: 'relay',
    envelope: { ...envelope, ttl: envelope.ttl - 1, path: [...envelope.path, me] },
    excludePeer: fromPeer,
  };
}

/** Group messages are delivered to everyone AND relayed onward. */
export const isGroup = (to: string) => to.startsWith('g:');

/**
 * Nearby sends a BYTES payload, which Google caps at 32 KiB. Anything larger —
 * an image, realistically — has to travel as parts and be put back together at
 * the far end. Relays forward parts individually and never need to understand
 * them.
 */
export const MAX_PAYLOAD = 32 * 1024;

/** Leaves room for the JSON envelope wrapped around each part. */
export const CHUNK_CHARS = 24_000;

export function splitBody(body: string, size = CHUNK_CHARS): string[] {
  if (body.length <= size) return [body];
  const parts: string[] = [];
  for (let i = 0; i < body.length; i += size) parts.push(body.slice(i, i + size));
  return parts;
}

/**
 * Collects parts until a message is whole. Incomplete groups are dropped once
 * the cache is full rather than held forever — a sender that walks away
 * mid-image must not leak memory.
 */
export class Reassembler {
  private groups = new Map<string, { parts: (string | undefined)[]; n: number }>();
  constructor(private limit = 16) {}

  /** Returns the full body once every part has arrived, otherwise null. */
  add(e: Envelope): string | null {
    if (!e.part || !e.gid) return e.body;

    let group = this.groups.get(e.gid);
    if (!group) {
      // Filled, not sparse: `.some` skips holes in a sparse array, which would
      // report a transfer complete on its first part.
      group = { parts: new Array(e.part.n).fill(undefined), n: e.part.n };
      this.groups.set(e.gid, group);
      // Evict the oldest partial group if we're tracking too many.
      if (this.groups.size > this.limit) {
        const oldest = this.groups.keys().next().value;
        if (oldest !== undefined) this.groups.delete(oldest);
      }
    }

    group.parts[e.part.i] = e.body;
    if (group.parts.some((p) => p === undefined)) return null;

    this.groups.delete(e.gid);
    return group.parts.join('');
  }

  get pending() {
    return this.groups.size;
  }
}

export const encode = (e: Envelope): string => JSON.stringify(e);

/** Never throws — a malformed payload from another build must not crash the app. */
export function decode(text: string): Envelope | null {
  try {
    const e = JSON.parse(text);
    if (
      typeof e?.id !== 'string' ||
      typeof e?.from !== 'string' ||
      typeof e?.to !== 'string' ||
      typeof e?.body !== 'string' ||
      typeof e?.ttl !== 'number' ||
      !Array.isArray(e?.path)
    ) {
      return null;
    }
    return e as Envelope;
  } catch {
    return null;
  }
}
