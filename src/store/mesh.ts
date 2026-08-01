// Live mesh state. Owns the transport and applies the relay rules to anything
// that arrives, so screens only ever read plain data.
import { Platform } from 'react-native';
import { create } from 'zustand';
import { MeshTransport, type PeerInfo } from '../features/messaging/api/transport';
import {
  SeenCache,
  newEnvelope,
  route,
  hopsTaken,
  relayedBy,
  type Envelope,
} from '../utils/relay';
import { threads as seedThreads, type Thread, type Msg, type Hops } from './mock';

/** Per launch. Persisting it needs storage we haven't wired — see notes. */
const deviceId = Math.random().toString(36).slice(2, 8);

/** The phone model, so three demo handsets are told apart on sight. Replace with
 *  a name the user picks once there's somewhere to store it. */
const defaultName = String((Platform.constants as any)?.Model ?? 'Echo phone');

export type MeshStatus = 'off' | 'starting' | 'live' | 'error';

type State = {
  me: { deviceId: string; display: string };
  status: MeshStatus;
  error?: string;
  /** deviceId -> what we know about them right now. */
  peers: Record<string, { display: string; peerId: string; connected: boolean }>;
  threads: Thread[];
  /** Counts for the demo — proof the relay actually did something. */
  stats: { sent: number; delivered: number; relayed: number; dropped: number };

  start: () => Promise<void>;
  stop: () => Promise<void>;
  setName: (display: string) => void;
  send: (threadId: string, body: string, kind?: 'msg' | 'coin') => Promise<void>;
};

const seen = new SeenCache();
let transport: MeshTransport | null = null;

const displayOf = (id: string, peers: State['peers']) =>
  peers[id]?.display ?? seedThreads.find((t) => t.id === id)?.title ?? id;

export const useMesh = create<State>((set, get) => ({
  me: { deviceId, display: defaultName },
  status: 'off',
  peers: {},
  threads: seedThreads,
  stats: { sent: 0, delivered: 0, relayed: 0, dropped: 0 },

  setName: (display) => set((s) => ({ me: { ...s.me, display } })),

  start: async () => {
    if (get().status === 'live' || get().status === 'starting') return;
    set({ status: 'starting', error: undefined });

    transport = new MeshTransport(get().me, {
      onPeer: (peer: PeerInfo, state) => {
        set((s) => {
          const peers = { ...s.peers };
          if (state === 'lost') {
            if (peers[peer.deviceId]) peers[peer.deviceId] = { ...peers[peer.deviceId], connected: false };
          } else {
            peers[peer.deviceId] = {
              display: peer.display,
              peerId: peer.peerId,
              connected: state === 'connected',
            };
          }

          // A phone you can reach has to be a phone you can open a chat with,
          // or the mesh is live and there is nothing to do with it.
          let threads = s.threads;
          if (state === 'connected' && !threads.some((t) => t.id === peer.deviceId)) {
            threads = [
              {
                id: peer.deviceId,
                title: peer.display,
                initials: initialsOf(peer.display),
                preview: 'Connected over the mesh',
                at: 'now',
                hops: 0,
                messages: [],
              },
              ...threads,
            ];
          } else if (threads.some((t) => t.id === peer.deviceId)) {
            threads = threads.map((t) =>
              t.id === peer.deviceId ? { ...t, hops: state === 'connected' ? 0 : null } : t
            );
          }

          return { peers, threads };
        });
      },

      onEnvelope: (envelope, fromPeerId) => {
        const decision = route(envelope, deviceId, seen, fromPeerId);

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
        set((s) => ({
          stats: { ...s.stats, delivered: s.stats.delivered + 1 },
          threads: upsertMessage(s.threads, e.from, {
            id: e.id,
            from: e.from,
            text: e.kind === 'msg' ? e.body : undefined,
            coin: e.kind === 'coin' ? Number(e.body) : undefined,
            at: clock(e.at),
            hops,
            via: relay ? displayOf(relay, s.peers) : undefined,
          }),
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
    set({ status: 'off', peers: {} });
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

    const reachable = peers[threadId]?.connected;
    const fanout = transport ? await transport.broadcast(envelope) : 0;

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
}));

const initialsOf = (name: string) => {
  const parts = name.trim().split(/[\s-]+/).filter(Boolean);
  const letters = parts.length > 1 ? parts[0][0] + parts[1][0] : name.slice(0, 2);
  return letters.toUpperCase();
};

const clock = (ms: number) =>
  new Date(ms).toLocaleTimeString('en-ZA', { hour: '2-digit', minute: '2-digit', hour12: false });

/** Append to a thread, creating one for a sender we've never heard from. */
function upsertMessage(threads: Thread[], threadId: string, msg: Msg): Thread[] {
  const i = threads.findIndex((t) => t.id === threadId);
  if (i < 0) {
    return [
      {
        id: threadId,
        title: threadId,
        initials: threadId.slice(0, 2).toUpperCase(),
        preview: msg.text ?? `${msg.coin?.toFixed(2)} echocoin`,
        at: msg.at,
        hops: msg.hops,
        via: msg.via,
        messages: [msg],
      },
      ...threads,
    ];
  }
  const t = threads[i];
  const next = [...threads];
  next[i] = {
    ...t,
    preview: msg.text ?? `${msg.coin?.toFixed(2)} echocoin`,
    at: msg.at,
    hops: msg.hops,
    via: msg.via,
    messages: [...t.messages, msg],
  };
  return next;
}
