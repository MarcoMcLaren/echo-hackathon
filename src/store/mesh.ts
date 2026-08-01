// Live mesh state. Owns the transport and applies the relay rules to anything
// that arrives, so screens only ever read plain data.
import { create } from 'zustand';
import { MeshTransport, type PeerInfo } from '../features/messaging/api/transport';
import {
  loadProfile,
  createProfile,
  renameProfile,
  resetIdentity,
} from '../features/vault/api/identity';
import {
  loadContacts,
  addContact as persistContact,
  removeContact as forgetContact,
  type Contact,
} from '../features/vault/api/contacts';
import { prepareNotifications, notifyMessage } from '../features/messaging/api/notify';
import { decodeEvent } from '../features/messaging/api/events';
import {
  SeenCache,
  Reassembler,
  newEnvelope,
  route,
  hopsTaken,
  relayedBy,
  isGroup,
  newGroupId,
} from '../utils/relay';
import type { Thread, Msg, Hops, Entry } from './types';

/**
 * What every phone starts with. There is no issuer and no ledger server — this
 * is a demo currency, and pretending otherwise would be dishonest. Everything
 * after this point is real: the balance is opening minus what you sent plus
 * what you received.
 */
export const OPENING_BALANCE = 100;

/**
 * The wallet, derived from coin messages rather than stored separately. One
 * source of truth means the balance can never disagree with the thread it came
 * from. Reverted transfers stay visible but do not count.
 */
export function walletFrom(threads: Thread[]): { balance: number; entries: Entry[] } {
  const entries: Entry[] = [];
  for (const t of threads) {
    for (const m of t.messages) {
      if (m.coin == null || m.pending) continue;
      entries.push({
        id: m.id,
        amount: m.from === 'me' ? -m.coin : m.coin,
        who: t.title,
        hops: m.hops,
        via: m.via,
        note: m.state === 'queued' ? `WAITING FOR A ROUTE · ${m.at}` : m.at,
        reverted: m.reverted,
      });
    }
  }
  const net = entries.filter((e) => !e.reverted).reduce((sum, e) => sum + e.amount, 0);
  return { balance: OPENING_BALANCE + net, entries: entries.reverse() };
}

/** Under this many unread, you can just read them yourself. */
export const SUMMARY_THRESHOLD = 5;

export type MeshStatus = 'off' | 'starting' | 'live' | 'error';

type State = {
  me: { deviceId: string; display: string };
  status: MeshStatus;
  error?: string;
  /**
   * Every Echo phone in range right now — nodes, not friends. Most of these are
   * strangers whose only job is carrying traffic. A node that goes away is
   * removed rather than kept as a disconnected entry, since a ghost on the map
   * that will never reconnect reads as a bug.
   */
  peers: Record<string, { display: string; peerId: string }>;
  /**
   * The people you have actually met, by tap or by scanned code. Only these get
   * a conversation, and only these can put a message in front of you.
   */
  contacts: Record<string, Contact>;
  threads: Thread[];
  /** Counts for the demo — proof the relay actually did something. */
  stats: { sent: number; delivered: number; relayed: number; dropped: number };

  /** A coin send held in its cancel window. One at a time, deliberately. */
  pending: { msgId: string; threadId: string; amount: number; until: number } | null;

  /**
   * Claim this phone's identity and load its contacts. Called once at launch,
   * not when the mesh starts — your identity is who you are, not something that
   * only exists while the radio is on. Without this the pairing code would read
   * "pending" until you happened to start the mesh.
   */
  init: () => Promise<void>;
  /** False until a name has been chosen. Drives the first-run screen. */
  ready: boolean;
  /** First launch: pick a name, get an id. */
  createIdentity: (name: string) => Promise<void>;
  /** Wipe everything and go back to first launch, with a brand new id. */
  resetApp: () => Promise<void>;
  start: () => Promise<void>;
  stop: () => Promise<void>;
  setName: (display: string) => Promise<void>;
  send: (
    threadId: string,
    body: string,
    kind?: 'msg' | 'coin' | 'revert' | 'invite' | 'image' | 'event'
  ) => Promise<void>;
  markRead: (threadId: string) => void;
  /** Make a group from peers you can currently reach, and tell them about it. */
  createGroup: (name: string, memberIds: string[]) => Promise<string>;
  /** A tap or a scanned code proved you met. Creates the conversation. */
  pair: (deviceId: string, name: string) => Promise<void>;
  /**
   * Remove someone. They go back to being a node — still relaying for the mesh,
   * no longer able to reach you. No block needed: the contact list is an
   * allowlist, so being off it is enough.
   */
  unpair: (deviceId: string) => Promise<void>;
  /** Forget a conversation that has no contact behind it, such as a group. */
  forgetThread: (threadId: string) => void;
  /** Show it in the thread, but hold it back for CANCEL_WINDOW_MS first. */
  queueCoin: (threadId: string, amount: number) => void;
  cancelPending: () => void;
  /** Take back the most recent coin already sent in this thread. */
  revertLastCoin: (threadId: string) => Promise<boolean>;
};

/** Long enough to catch a mistake, short enough not to feel broken. */
export const CANCEL_WINDOW_MS = 5000;

const seen = new SeenCache();
const inbound = new Reassembler();
let transport: MeshTransport | null = null;
let cancelTimer: ReturnType<typeof setTimeout> | null = null;

export const useMesh = create<State>((set, get) => ({
  // Replaced by init() at launch, or by createIdentity() on first run.
  me: { deviceId: 'pending', display: '' },
  ready: false,
  status: 'off',
  peers: {},
  // Empty. Conversations appear when a phone connects or a message arrives.
  threads: [],
  stats: { sent: 0, delivered: 0, relayed: 0, dropped: 0 },
  pending: null,
  contacts: {},

  createIdentity: async (name) => {
    const profile = await createProfile(name);
    set({ ready: true, me: { deviceId: profile.id, display: profile.name }, contacts: {} });
  },

  resetApp: async () => {
    await get().stop();
    resetIdentity();
    // Back to the state of a phone that has never been opened. The next launch
    // asks for a name and mints a new id, so to everyone else this is a
    // different phone rather than the same one with its history hidden.
    set({
      ready: false,
      me: { deviceId: 'pending', display: '' },
      contacts: {},
      threads: [],
      peers: {},
      pending: null,
      stats: { sent: 0, delivered: 0, relayed: 0, dropped: 0 },
      error: undefined,
    });
  },

  setName: async (display) => {
    const profile = await renameProfile(display);
    if (profile) set((s) => ({ me: { ...s.me, display: profile.name } }));
  },

  markRead: (threadId) =>
    set((s) => ({
      threads: s.threads.map((t) => (t.id === threadId ? { ...t, unread: 0 } : t)),
    })),

  pair: async (deviceId, name) => {
    const all = await persistContact(deviceId, name);
    set((s) => ({
      contacts: all,
      threads: s.threads.some((t) => t.id === deviceId)
        ? s.threads.map((t) => (t.id === deviceId ? { ...t, title: name, initials: initialsOf(name) } : t))
        : [
            {
              id: deviceId,
              title: name,
              initials: initialsOf(name),
              preview: 'Paired — say something',
              at: 'now',
              hops: s.peers[deviceId] ? 0 : null,
              messages: [],
              unread: 0,
            },
            ...s.threads,
          ],
    }));
  },

  unpair: async (deviceId) => {
    const all = await forgetContact(deviceId);
    // The connection stays up: they are still a useful node for the mesh.
    // Only the relationship goes.
    set((s) => ({
      contacts: all,
      threads: s.threads.filter((t) => t.id !== deviceId),
    }));
  },

  forgetThread: (threadId) =>
    set((s) => ({ threads: s.threads.filter((t) => t.id !== threadId) })),

  createGroup: async (name, memberIds) => {
    const id = newGroupId();
    const me = get().me;
    const members = [me.deviceId, ...memberIds];

    set((s) => ({
      threads: [
        {
          id,
          title: name,
          initials: initialsOf(name),
          group: true,
          members,
          preview: `${members.length} people`,
          at: 'now',
          hops: 0,
          messages: [],
          unread: 0,
        },
        ...s.threads,
      ],
    }));

    // Addressed to the group, so it fans out to everyone in range. Phones not
    // named in it forward the invite without joining.
    await get().send(id, JSON.stringify({ id, name, members }), 'invite');
    return id;
  },

  init: async () => {
    if (get().ready) return;
    const profile = await loadProfile();
    // Never set up. The first-run screen asks for a name, and only then does
    // this phone get an id.
    if (!profile) {
      set({ ready: false });
      return;
    }
    // Contacts survive restarts; their conversations are rebuilt from them.
    const contacts = await loadContacts();
    set((s) => ({
      ready: true,
      me: { deviceId: profile.id, display: profile.name },
      contacts,
      threads: s.threads.length
        ? s.threads
        : Object.values(contacts).map((k) => ({
            id: k.id,
            title: k.name,
            initials: initialsOf(k.name),
            preview: 'Paired',
            at: '',
            hops: null as Hops,
            messages: [],
            unread: 0,
          })),
    }));
  },

  start: async () => {
    if (get().status === 'live' || get().status === 'starting') return;
    set({ status: 'starting', error: undefined });

    // Identity and contacts are claimed at launch, but starting the mesh
    // without them would advertise as "pending", so make sure they are in.
    await get().init();
    const me = get().me;

    // Asked for here rather than at launch: the permission makes sense to
    // someone who has just turned the mesh on, and nowhere else.
    prepareNotifications();

    transport = new MeshTransport(me, {
      onPeer: (peer: PeerInfo, state) => {
        set((s) => {
          const peers = { ...s.peers };
          if (state === 'lost') {
            delete peers[peer.deviceId];
          } else if (state === 'connected') {
            peers[peer.deviceId] = { display: peer.display, peerId: peer.peerId };
          }

          // Connecting to a node does NOT create a conversation. Being in range
          // of a stranger is not a relationship — it just means they can carry
          // traffic. Conversations come from pairing, nowhere else.
          //
          // What a connection does do is update the route on a conversation you
          // already have with this person.
          const route: Hops = state === 'connected' ? 0 : null;
          const threads = s.threads.map((t) =>
            t.id === peer.deviceId ? { ...t, hops: route } : t
          );

          return { peers, threads };
        });
      },

      onEnvelope: (envelope, fromPeerId) => {
        const decision = route(envelope, get().me.deviceId, seen, fromPeerId);

        if (decision.action === 'drop') {
          set((s) => ({ stats: { ...s.stats, dropped: s.stats.dropped + 1 } }));
          return;
        }

        if (decision.action === 'relay') {
          set((s) => ({ stats: { ...s.stats, relayed: s.stats.relayed + 1 } }));
          transport?.broadcast(decision.envelope, decision.excludePeer);
          return;
        }

        // Group traffic: carry it on regardless, then show it only if this
        // phone is actually in the group.
        if (decision.action === 'fanout') {
          if (decision.envelope.ttl > 0) {
            set((s) => ({ stats: { ...s.stats, relayed: s.stats.relayed + 1 } }));
            transport?.broadcast(decision.envelope, decision.excludePeer);
          }
          const member = get().threads.some((t) => t.id === decision.envelope.to);
          if (!member && decision.envelope.kind !== 'invite') return;
        }

        // Delivered to us. A split payload only becomes a message once every
        // part has landed; until then there is nothing to show.
        const partial = decision.envelope;
        const whole = inbound.add(partial);
        if (whole === null) return;
        const e = { ...partial, body: whole };

        // Only people you have met can put something in front of you. A
        // stranger's message is still relayed onward for whoever it is for —
        // we just do not show it. This is the difference between being a node
        // in someone's mesh and being in their contacts.
        const known = get().contacts[e.from] || isGroup(e.to);
        if (!known) {
          set((s) => ({ stats: { ...s.stats, dropped: s.stats.dropped + 1 } }));
          return;
        }

        const hops = hopsTaken(e) as Hops;
        const relay = relayedBy(e);

        // An invite creates the group locally — but only from someone you have
        // met, and only if you are actually named in it. Group messages are
        // exempt from the contact check above, because the group itself is the
        // trust boundary: two people in Alice's group need not have paired with
        // each other. An invite is what draws that boundary, so it cannot come
        // from a stranger — otherwise anyone in radio range could put a group on
        // your phone and talk to you through it.
        if (e.kind === 'invite') {
          if (!get().contacts[e.from]) {
            set((s) => ({ stats: { ...s.stats, dropped: s.stats.dropped + 1 } }));
            return;
          }
          try {
            const g = JSON.parse(e.body) as { id: string; name: string; members: string[] };
            const meId = get().me.deviceId;
            if (!g.members?.includes(meId)) return;
            set((s) =>
              s.threads.some((t) => t.id === g.id)
                ? s
                : {
                    threads: [
                      {
                        id: g.id,
                        title: g.name,
                        initials: initialsOf(g.name),
                        group: true,
                        members: g.members,
                        preview: `${g.members.length} people`,
                        at: clock(e.at),
                        hops,
                        via: relay ? s.peers[relay]?.display ?? relay : undefined,
                        messages: [],
                        unread: 0,
                      },
                      ...s.threads,
                    ],
                  }
            );
          } catch {
            // A malformed invite from another build is not our problem.
          }
          return;
        }

        if (e.kind === 'msg' || e.kind === 'coin') {
          notifyMessage({
            from: e.fromName ?? get().peers[e.from]?.display ?? e.from,
            body: e.kind === 'coin' ? `Sent you ${Number(e.body).toFixed(2)} echocoin` : e.body,
            threadId: e.from,
            hops,
          });
        }

        // A take-back references an earlier message rather than adding one.
        // The row stays on screen marked reverted — money that quietly
        // disappears is worse than money you can see was returned.
        if (e.kind === 'revert') {
          set((s) => ({
            stats: { ...s.stats, delivered: s.stats.delivered + 1 },
            threads: s.threads.map((t) =>
              t.id !== e.from
                ? t
                : {
                    ...t,
                    messages: t.messages.map((m) =>
                      m.id === e.body ? { ...m, reverted: true } : m
                    ),
                  }
            ),
          }));
          return;
        }

        set((s) => ({
          stats: { ...s.stats, delivered: s.stats.delivered + 1 },
          threads: upsertMessage(
            s.threads,
            // A group message belongs to the group, not to whoever sent it.
            isGroup(e.to) ? e.to : e.from,
            {
              id: e.id,
              from: e.from,
              // So a group bubble can name the sender without a lookup that
              // would fail for anyone reached through a relay.
              fromName: e.fromName,
              text: e.kind === 'msg' ? e.body : undefined,
              coin: e.kind === 'coin' ? Number(e.body) : undefined,
              image: e.kind === 'image' ? e.body : undefined,
              event: e.kind === 'event' ? decodeEvent(e.body) ?? undefined : undefined,
              at: clock(e.at),
              hops,
              via: relay ? s.peers[relay]?.display ?? relay : undefined,
            },
            // Name the thread from the envelope, not the peer list — a relayed
            // sender is not a peer here.
            { unread: true, title: e.fromName }
          ),
        }));
      },

      onError: (message) => set({ error: message }),
    });

    const result = await transport.start();
    if (!result.ok) {
      set({ status: 'error', error: result.reason });
      return;
    }
    set({ status: 'live' });
  },

  stop: async () => {
    await transport?.stop();
    transport = null;
    // Peers are session state. Conversations stay, but nothing has a route.
    set((s) => ({
      status: 'off',
      peers: {},
      threads: s.threads.map((t) => (s.peers[t.id] ? { ...t, hops: null } : t)),
    }));
  },

  send: async (threadId, body, kind = 'msg') => {
    const { me, peers } = get();
    const envelope = newEnvelope({
      id: `${me.deviceId}-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
      from: me.deviceId,
      // Travels with the message so a relayed sender still has a name at the
      // far end, where they are not a peer and cannot be looked up.
      fromName: me.display,
      to: threadId,
      kind,
      body,
      at: Date.now(),
    });
    seen.check(envelope.id); // never relay our own message back to ourselves

    // A group has no single peer to be "in range of" — it is reachable if
    // anyone is, and the delivery line says how many actually got it.
    const reachable = isGroup(threadId) ? Object.keys(peers).length > 0 : Boolean(peers[threadId]);
    const fanout = transport ? await transport.broadcast(envelope) : 0;

    // Neither a revert nor an invite is a message in the thread. Both are
    // bookkeeping the UI has already reflected.
    if (kind === 'revert' || kind === 'invite') {
      set((s) => ({ stats: { ...s.stats, sent: s.stats.sent + 1 } }));
      return;
    }

    set((s) => ({
      stats: { ...s.stats, sent: s.stats.sent + 1 },
      threads: upsertMessage(s.threads, threadId, {
        id: envelope.id,
        from: 'me',
        text: kind === 'msg' ? body : undefined,
        coin: kind === 'coin' ? Number(body) : undefined,
        image: kind === 'image' ? body : undefined,
        event: kind === 'event' ? decodeEvent(body) ?? undefined : undefined,
        at: clock(envelope.at),
        hops: reachable ? 0 : fanout > 0 ? 1 : null,
        // No peer at all means it waits — never show it as sent.
        state: fanout === 0 ? 'queued' : reachable ? 'delivered' : 'sent',
      }),
    }));
  },

  queueCoin: (threadId, amount) => {
    // One at a time: a queue of pending payments is a queue of things you
    // can't cancel individually under pressure.
    get().cancelPending();

    const msgId = `${get().me.deviceId}-${Date.now()}-p`;
    set((s) => ({
      pending: { msgId, threadId, amount, until: Date.now() + CANCEL_WINDOW_MS },
      threads: upsertMessage(s.threads, threadId, {
        id: msgId,
        from: 'me',
        coin: amount,
        at: clock(Date.now()),
        hops: s.peers[threadId] ? 0 : null,
        pending: true,
      }),
    }));

    cancelTimer = setTimeout(() => {
      const held = get().pending;
      if (!held || held.msgId !== msgId) return;
      // Drop the placeholder, then send for real.
      set((s) => ({
        pending: null,
        threads: s.threads.map((t) =>
          t.id !== threadId
            ? t
            : { ...t, messages: t.messages.filter((m) => m.id !== msgId) }
        ),
      }));
      get().send(threadId, String(amount), 'coin');
    }, CANCEL_WINDOW_MS);
  },

  cancelPending: () => {
    if (cancelTimer) clearTimeout(cancelTimer);
    cancelTimer = null;
    const held = get().pending;
    if (!held) return;
    set((s) => ({
      pending: null,
      threads: s.threads.map((t) =>
        t.id !== held.threadId
          ? t
          : { ...t, messages: t.messages.filter((m) => m.id !== held.msgId) }
      ),
    }));
  },

  revertLastCoin: async (threadId) => {
    const thread = get().threads.find((t) => t.id === threadId);
    const target = [...(thread?.messages ?? [])]
      .reverse()
      .find((m) => m.from === 'me' && m.coin != null && !m.reverted && !m.pending);
    if (!target) return false;

    // Mark it here first so the gesture feels immediate; the peer honours the
    // revert when the message reaches them, or when a route opens.
    set((s) => ({
      threads: s.threads.map((t) =>
        t.id !== threadId
          ? t
          : { ...t, messages: t.messages.map((m) => (m.id === target.id ? { ...m, reverted: true } : m)) }
      ),
    }));

    await get().send(threadId, target.id, 'revert');
    return true;
  },
}));

const initialsOf = (name: string) => {
  const parts = name.trim().split(/[\s-]+/).filter(Boolean);
  const letters = parts.length > 1 ? parts[0][0] + parts[1][0] : name.slice(0, 2);
  return letters.toUpperCase();
};

const clock = (ms: number) =>
  new Date(ms).toLocaleTimeString('en-ZA', { hour: '2-digit', minute: '2-digit', hour12: false });

/** Append to a thread, creating one for a sender we've never heard from. */
function upsertMessage(
  threads: Thread[],
  threadId: string,
  msg: Msg,
  opts?: { unread?: boolean; title?: string }
): Thread[] {
  const preview =
    msg.text ??
    (msg.image ? 'Photo' : undefined) ??
    (msg.event ? msg.event.title : undefined) ??
    `${msg.coin?.toFixed(2)} echocoin`;
  const i = threads.findIndex((t) => t.id === threadId);

  if (i < 0) {
    const title = opts?.title ?? threadId;
    return [
      {
        id: threadId,
        title,
        initials: initialsOf(title),
        preview,
        at: msg.at,
        hops: msg.hops,
        via: msg.via,
        messages: [msg],
        unread: opts?.unread ? 1 : 0,
      },
      ...threads,
    ];
  }

  const t = threads[i];
  const next = [...threads];
  next[i] = {
    ...t,
    preview,
    at: msg.at,
    hops: msg.hops,
    via: msg.via,
    messages: [...t.messages, msg],
    unread: (t.unread ?? 0) + (opts?.unread ? 1 : 0),
  };
  return next;
}
