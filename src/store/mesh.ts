// Live mesh state. Owns the transport and applies the relay rules to anything
// that arrives, so screens only ever read plain data.
import { Platform } from 'react-native';
import { create } from 'zustand';
import { MeshTransport, type PeerInfo } from '../features/messaging/api/transport';
import { deviceIdentity } from '../features/vault/api/identity';
import { SeenCache, newEnvelope, route, hopsTaken, relayedBy } from '../utils/relay';
import { threads as seedThreads, type Thread, type Msg, type Hops } from './mock';

/** The phone model, so demo handsets are told apart on sight. Replace with a
 *  name the user picks once there's a settings screen. */
const defaultName = String((Platform.constants as any)?.Model ?? 'Echo phone');

/** Under this many unread, you can just read them yourself. */
export const SUMMARY_THRESHOLD = 5;

export type MeshStatus = 'off' | 'starting' | 'live' | 'error';

type State = {
  me: { deviceId: string; display: string };
  status: MeshStatus;
  error?: string;
  /**
   * Only phones reachable right now. A peer that goes away is removed rather
   * than kept as a disconnected entry — a ghost node on the map that will never
   * reconnect reads as a bug, and it makes the peer count disagree with the
   * conversation list.
   */
  peers: Record<string, { display: string; peerId: string }>;
  threads: Thread[];
  /** Counts for the demo — proof the relay actually did something. */
  stats: { sent: number; delivered: number; relayed: number; dropped: number };

  /** A coin send held in its cancel window. One at a time, deliberately. */
  pending: { msgId: string; threadId: string; amount: number; until: number } | null;

  start: () => Promise<void>;
  stop: () => Promise<void>;
  setName: (display: string) => void;
  send: (threadId: string, body: string, kind?: 'msg' | 'coin' | 'revert') => Promise<void>;
  markRead: (threadId: string) => void;
  /** Show it in the thread, but hold it back for CANCEL_WINDOW_MS first. */
  queueCoin: (threadId: string, amount: number) => void;
  cancelPending: () => void;
  /** Take back the most recent coin already sent in this thread. */
  revertLastCoin: (threadId: string) => Promise<boolean>;
};

/** Long enough to catch a mistake, short enough not to feel broken. */
export const CANCEL_WINDOW_MS = 5000;

const seen = new SeenCache();
let transport: MeshTransport | null = null;
let cancelTimer: ReturnType<typeof setTimeout> | null = null;

export const useMesh = create<State>((set, get) => ({
  // Replaced with the persisted id the first time the mesh starts.
  me: { deviceId: 'pending', display: defaultName },
  status: 'off',
  peers: {},
  threads: seedThreads,
  stats: { sent: 0, delivered: 0, relayed: 0, dropped: 0 },
  pending: null,

  setName: (display) => set((s) => ({ me: { ...s.me, display } })),

  markRead: (threadId) =>
    set((s) => ({
      threads: s.threads.map((t) => (t.id === threadId ? { ...t, unread: 0 } : t)),
    })),

  start: async () => {
    if (get().status === 'live' || get().status === 'starting') return;
    set({ status: 'starting', error: undefined });

    // Stable across restarts, so the phone you spoke to earlier is still the
    // same phone and doesn't come back as a stranger.
    const me = { deviceId: await deviceIdentity(), display: get().me.display };
    set({ me });

    transport = new MeshTransport(me, {
      onPeer: (peer: PeerInfo, state) => {
        set((s) => {
          const peers = { ...s.peers };
          if (state === 'lost') {
            delete peers[peer.deviceId];
          } else if (state === 'connected') {
            peers[peer.deviceId] = { display: peer.display, peerId: peer.peerId };
          }

          // A phone you can reach has to be a phone you can open a chat with,
          // or the mesh is live and there is nothing to do with it.
          let threads = s.threads;
          const known = threads.some((t) => t.id === peer.deviceId);
          if (state === 'connected' && !known) {
            threads = [
              {
                id: peer.deviceId,
                title: peer.display,
                initials: initialsOf(peer.display),
                preview: 'Connected over the mesh',
                at: 'now',
                hops: 0,
                messages: [],
                unread: 0,
              },
              ...threads,
            ];
          } else if (known) {
            threads = threads.map((t) =>
              t.id === peer.deviceId ? { ...t, hops: state === 'connected' ? 0 : null } : t
            );
          }

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

        // Delivered to us.
        const e = decision.envelope;
        const hops = hopsTaken(e) as Hops;
        const relay = relayedBy(e);

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
            e.from,
            {
              id: e.id,
              from: e.from,
              text: e.kind === 'msg' ? e.body : undefined,
              coin: e.kind === 'coin' ? Number(e.body) : undefined,
              at: clock(e.at),
              hops,
              via: relay ? s.peers[relay]?.display ?? relay : undefined,
            },
            { unread: true }
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
      to: threadId,
      kind,
      body,
      at: Date.now(),
    });
    seen.check(envelope.id); // never relay our own message back to ourselves

    const reachable = Boolean(peers[threadId]);
    const fanout = transport ? await transport.broadcast(envelope) : 0;

    // A revert is bookkeeping on an existing message, not a new one in the
    // thread — revertLastCoin has already struck the original through.
    if (kind === 'revert') {
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
  opts?: { unread?: boolean }
): Thread[] {
  const preview = msg.text ?? `${msg.coin?.toFixed(2)} echocoin`;
  const i = threads.findIndex((t) => t.id === threadId);

  if (i < 0) {
    return [
      {
        id: threadId,
        title: threadId,
        initials: threadId.slice(0, 2).toUpperCase(),
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
