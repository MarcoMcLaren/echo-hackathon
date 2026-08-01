import * as FS from 'expo-file-system';
import * as Nearby from 'expo-nearby-connections';
import { packName } from '../features/messaging/api/transport';
import { encode, newEnvelope } from '../utils/relay';
import { CANCEL_WINDOW_MS, useMesh } from './mesh';

const nearby = Nearby as unknown as {
  onConnected: { emit: (arg: { peerId: string; name: string }) => void };
  onDisconnected: { emit: (arg: { peerId: string }) => void };
  onTextReceived: { emit: (arg: { peerId: string; text: string }) => void };
  sendText: jest.Mock;
  __reset: () => void;
};

// Snapshot of the pristine store, taken before any test mutates it.
const initialState = useMesh.getState();

beforeEach(() => {
  nearby.__reset();
  (FS as any).__reset();
  useMesh.setState(initialState, true);
});

afterEach(async () => {
  // Tears down the previous test's transport (and its event subscriptions)
  // before the next test starts a fresh one against the same mock event bus.
  await useMesh.getState().stop();
});

describe('start', () => {
  it('goes live and settles on a stable deviceId', async () => {
    await useMesh.getState().start();
    const state = useMesh.getState();
    expect(state.status).toBe('live');
    expect(state.me.deviceId).not.toBe('pending');
  });
});

describe('peer lifecycle', () => {
  it('creates a thread the first time a peer connects', async () => {
    await useMesh.getState().start();
    nearby.onConnected.emit({ peerId: 'p1', name: packName('zephyr', 'Zephyr Phone') });

    const state = useMesh.getState();
    expect(state.peers.zephyr).toEqual({ display: 'Zephyr Phone', peerId: 'p1' });
    expect(state.threads.find((t) => t.id === 'zephyr')?.preview).toBe('Connected over the mesh');
  });

  it('marks a known thread unreachable when its peer disconnects', async () => {
    await useMesh.getState().start();
    nearby.onConnected.emit({ peerId: 'p1', name: packName('zephyr', 'Zephyr Phone') });
    nearby.onDisconnected.emit({ peerId: 'p1' });

    const state = useMesh.getState();
    expect(state.peers.zephyr).toBeUndefined();
    expect(state.threads.find((t) => t.id === 'zephyr')?.hops).toBeNull();
  });
});

describe('send', () => {
  it('sends to a connected peer as delivered', async () => {
    await useMesh.getState().start();
    nearby.onConnected.emit({ peerId: 'p1', name: packName('zephyr', 'Zephyr Phone') });

    await useMesh.getState().send('zephyr', 'Howzit');

    expect(nearby.sendText).toHaveBeenCalledTimes(1);
    const thread = useMesh.getState().threads.find((t) => t.id === 'zephyr');
    expect(thread?.messages.find((m) => m.text === 'Howzit')).toMatchObject({
      from: 'me',
      hops: 0,
      state: 'delivered',
    });
    expect(useMesh.getState().stats.sent).toBe(1);
  });

  it('marks a send to an unreachable peer as queued', async () => {
    await useMesh.getState().start();
    await useMesh.getState().send('nobody-connected', 'hello');

    const thread = useMesh.getState().threads.find((t) => t.id === 'nobody-connected');
    expect(thread?.messages.find((m) => m.text === 'hello')).toMatchObject({
      hops: null,
      state: 'queued',
    });
    expect(nearby.sendText).not.toHaveBeenCalled();
  });
});

describe('incoming envelopes', () => {
  it('delivers an incoming message to the sender\'s thread', async () => {
    await useMesh.getState().start();
    const me = useMesh.getState().me;

    const envelope = newEnvelope({
      id: 'inbound-1',
      from: 'zephyr',
      to: me.deviceId,
      kind: 'msg',
      body: 'Hey there',
      at: 0,
    });
    nearby.onTextReceived.emit({ peerId: 'p1', text: encode(envelope) });

    const state = useMesh.getState();
    expect(state.stats.delivered).toBe(1);
    expect(state.threads.find((t) => t.id === 'zephyr')?.messages.some((m) => m.text === 'Hey there')).toBe(
      true
    );
  });

  it('drops a duplicate envelope instead of delivering it twice', async () => {
    await useMesh.getState().start();
    const me = useMesh.getState().me;
    const envelope = newEnvelope({
      id: 'dup-1',
      from: 'zephyr',
      to: me.deviceId,
      kind: 'msg',
      body: 'Hey',
      at: 0,
    });

    nearby.onTextReceived.emit({ peerId: 'p1', text: encode(envelope) });
    nearby.onTextReceived.emit({ peerId: 'p1', text: encode(envelope) });

    const state = useMesh.getState();
    expect(state.stats.delivered).toBe(1);
    expect(state.stats.dropped).toBe(1);
  });

  it('relays an envelope addressed to someone else, excluding the sender', async () => {
    await useMesh.getState().start();
    nearby.onConnected.emit({ peerId: 'p1', name: packName('hopper', 'Hopper') });
    nearby.onConnected.emit({ peerId: 'p2', name: packName('other', 'Other') });

    const envelope = newEnvelope({
      id: 'relay-1',
      from: 'origin',
      to: 'final-destination',
      kind: 'msg',
      body: 'pass it on',
      at: 0,
      ttl: 2,
    });
    nearby.onTextReceived.emit({ peerId: 'p1', text: encode(envelope) });

    expect(useMesh.getState().stats.relayed).toBe(1);
    expect(nearby.sendText).toHaveBeenCalledTimes(1);
    expect(nearby.sendText).toHaveBeenCalledWith('p2', expect.any(String));
  });
});

describe('coin cancel window', () => {
  beforeEach(() => jest.useFakeTimers());
  afterEach(() => jest.useRealTimers());

  it('holds a queued coin as pending, then sends it once the window elapses', async () => {
    await useMesh.getState().start();

    nearby.onConnected.emit({ peerId: 'p1', name: packName('zephyr', 'Zephyr Phone') });
    useMesh.getState().queueCoin('zephyr', 20);
    let thread = useMesh.getState().threads.find((t) => t.id === 'zephyr');
    expect(thread?.messages.some((m) => m.pending && m.coin === 20)).toBe(true);
    expect(nearby.sendText).not.toHaveBeenCalled();

    await jest.advanceTimersByTimeAsync(CANCEL_WINDOW_MS);

    thread = useMesh.getState().threads.find((t) => t.id === 'zephyr');
    expect(thread?.messages.some((m) => m.pending)).toBe(false);
    expect(thread?.messages.some((m) => m.coin === 20)).toBe(true);
    expect(nearby.sendText).toHaveBeenCalledTimes(1);
  });

  it('cancels a pending coin before it is sent', async () => {
    await useMesh.getState().start();

    useMesh.getState().queueCoin('zephyr', 20);
    useMesh.getState().cancelPending();

    await jest.advanceTimersByTimeAsync(CANCEL_WINDOW_MS);

    const thread = useMesh.getState().threads.find((t) => t.id === 'zephyr');
    expect(thread?.messages.some((m) => m.coin === 20)).toBe(false);
    expect(nearby.sendText).not.toHaveBeenCalled();
  });
});

describe('revertLastCoin', () => {
  it('marks the last coin reverted and sends a revert envelope', async () => {
    await useMesh.getState().start();
    nearby.onConnected.emit({ peerId: 'p1', name: packName('zephyr', 'Zephyr Phone') });
    await useMesh.getState().send('zephyr', '20', 'coin');

    const sent = useMesh.getState().threads.find((t) => t.id === 'zephyr')?.messages.find((m) => m.coin === 20);
    expect(sent).toBeDefined();

    const reverted = await useMesh.getState().revertLastCoin('zephyr');

    expect(reverted).toBe(true);
    const original = useMesh
      .getState()
      .threads.find((t) => t.id === 'zephyr')
      ?.messages.find((m) => m.id === sent!.id);
    expect(original?.reverted).toBe(true);
    expect(nearby.sendText).toHaveBeenCalledTimes(2); // the coin send + the revert send
  });

  it('returns false when there is nothing to revert', async () => {
    await useMesh.getState().start();
    const reverted = await useMesh.getState().revertLastCoin('nobody-home');
    expect(reverted).toBe(false);
  });
});
