// Manual mock for expo-nearby-connections (Jest picks this up automatically
// for any import of the real package — no jest.mock() call needed).
//
// Real Nearby exposes its events as subscribe-and-forget hooks. This fake
// keeps the same shape but also exposes `.emit(...)` on each hook, so a test
// can simulate "a peer connected" or "a message arrived over the air"
// without touching Bluetooth/Wi-Fi Direct.

function makeEventHook<T>() {
  const listeners = new Set<(arg: T) => void>();
  const hook = (cb: (arg: T) => void) => {
    listeners.add(cb);
    return () => listeners.delete(cb);
  };
  hook.emit = (arg: T) => listeners.forEach((cb) => cb(arg));
  return hook;
}

export const onPeerFound = makeEventHook<{ peerId: string; name: string }>();
export const onPeerLost = makeEventHook<{ peerId: string }>();
export const onInvitationReceived = makeEventHook<{ peerId: string }>();
export const onConnected = makeEventHook<{ peerId: string; name: string }>();
export const onDisconnected = makeEventHook<{ peerId: string }>();
export const onTextReceived = makeEventHook<{ peerId: string; text: string }>();

export const Strategy = { P2P_CLUSTER: 'P2P_CLUSTER', P2P_STAR: 'P2P_STAR' } as const;

export const startAdvertise = jest.fn().mockResolvedValue(undefined);
export const stopAdvertise = jest.fn().mockResolvedValue(undefined);
export const startDiscovery = jest.fn().mockResolvedValue(undefined);
export const stopDiscovery = jest.fn().mockResolvedValue(undefined);
export const requestConnection = jest.fn().mockResolvedValue(undefined);
export const acceptConnection = jest.fn().mockResolvedValue(undefined);
export const disconnect = jest.fn().mockResolvedValue(undefined);
export const sendText = jest.fn().mockResolvedValue(undefined);
export const isPlayServicesAvailable = jest.fn().mockResolvedValue(true);

/** Reset call history and listeners between tests. */
export function __reset() {
  [
    startAdvertise,
    stopAdvertise,
    startDiscovery,
    stopDiscovery,
    requestConnection,
    acceptConnection,
    disconnect,
    sendText,
    isPlayServicesAvailable,
  ].forEach((fn) => fn.mockClear());
  startAdvertise.mockResolvedValue(undefined);
  stopAdvertise.mockResolvedValue(undefined);
  startDiscovery.mockResolvedValue(undefined);
  stopDiscovery.mockResolvedValue(undefined);
  requestConnection.mockResolvedValue(undefined);
  acceptConnection.mockResolvedValue(undefined);
  disconnect.mockResolvedValue(undefined);
  sendText.mockResolvedValue(undefined);
  isPlayServicesAvailable.mockResolvedValue(true);
}
