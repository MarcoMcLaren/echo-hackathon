import * as Nearby from 'expo-nearby-connections';
import { Platform, PermissionsAndroid } from 'react-native';
import { encode, newEnvelope } from '../../../utils/relay';
import { MeshTransport, explain, packName, unpackName } from './transport';

const nearby = Nearby as unknown as {
  onPeerFound: { emit: (arg: { peerId: string; name: string }) => void };
  onPeerLost: { emit: (arg: { peerId: string }) => void };
  onConnected: { emit: (arg: { peerId: string; name: string }) => void };
  onDisconnected: { emit: (arg: { peerId: string }) => void };
  onTextReceived: { emit: (arg: { peerId: string; text: string }) => void };
  startAdvertise: jest.Mock;
  startDiscovery: jest.Mock;
  stopAdvertise: jest.Mock;
  stopDiscovery: jest.Mock;
  requestConnection: jest.Mock;
  disconnect: jest.Mock;
  sendText: jest.Mock;
  isPlayServicesAvailable: jest.Mock;
  __reset: () => void;
};

beforeEach(() => {
  nearby.__reset();
});

describe('packName / unpackName', () => {
  it('round-trips deviceId and display', () => {
    const packed = packName('device-1', 'Thabo Mokoena');
    expect(unpackName(packed)).toEqual({ deviceId: 'device-1', display: 'Thabo Mokoena' });
  });

  it('falls back to the raw string for both fields when there is no separator', () => {
    expect(unpackName('nodashhere')).toEqual({ deviceId: 'nodashhere', display: 'nodashhere' });
  });
});

describe('explain', () => {
  it('explains busy-radio codes', () => {
    expect(explain(new Error('ApiException: 8003'))).toMatch(/radio was still busy/i);
    expect(explain(new Error('ApiException: 8004'))).toMatch(/radio was still busy/i);
    expect(explain(new Error('ApiException: 8002'))).toMatch(/radio was still busy/i);
  });

  it('explains bluetooth-toggle codes', () => {
    expect(explain(new Error('ApiException: 8007'))).toMatch(/turn bluetooth off/i);
    expect(explain(new Error('ApiException: 8020'))).toMatch(/turn bluetooth off/i);
  });

  it('explains a double-start', () => {
    expect(explain(new Error('ApiException: 8001'))).toMatch(/started twice/i);
  });

  it('explains a missing-permission error', () => {
    expect(explain(new Error('MISSING_PERMISSION: foo'))).toMatch(
      /bluetooth and location permission/i
    );
  });

  it('falls back to a generic message for anything else', () => {
    expect(explain(new Error('boom'))).toMatch(/could not start the mesh/i);
  });
});

describe('MeshTransport', () => {
  const me = { deviceId: 'me', display: 'My Phone' };

  const makeEvents = () => ({
    onPeer: jest.fn(),
    onEnvelope: jest.fn(),
    onError: jest.fn(),
  });

  it('starts by advertising and discovering under our packed name', async () => {
    const events = makeEvents();
    const transport = new MeshTransport(me, events);
    const result = await transport.start();

    expect(result).toEqual({ ok: true });
    expect(nearby.startAdvertise).toHaveBeenCalledWith(packName('me', 'My Phone'), expect.anything());
    expect(nearby.startDiscovery).toHaveBeenCalledWith(packName('me', 'My Phone'), expect.anything());
  });

  it('ignores its own advertisement bouncing back', async () => {
    const events = makeEvents();
    const transport = new MeshTransport(me, events);
    await transport.start();

    nearby.onPeerFound.emit({ peerId: 'p1', name: packName('me', 'My Phone') });

    expect(events.onPeer).not.toHaveBeenCalled();
    expect(nearby.requestConnection).not.toHaveBeenCalled();
  });

  it('reports a found peer and lets the lower deviceId initiate the connection', async () => {
    const events = makeEvents();
    const transport = new MeshTransport(me, events); // me.deviceId = 'me'
    await transport.start();

    // 'me' < 'zephyr' lexicographically, so we should initiate.
    nearby.onPeerFound.emit({ peerId: 'p1', name: packName('zephyr', 'Zephyr Phone') });

    expect(events.onPeer).toHaveBeenCalledWith(
      { peerId: 'p1', deviceId: 'zephyr', display: 'Zephyr Phone' },
      'found'
    );
    expect(nearby.requestConnection).toHaveBeenCalledWith('p1');
  });

  it('does not initiate when our deviceId sorts higher than the peer', async () => {
    const events = makeEvents();
    const transport = new MeshTransport(me, events); // me.deviceId = 'me'
    await transport.start();

    // 'me' > 'aardvark' lexicographically, so the peer should initiate instead.
    nearby.onPeerFound.emit({ peerId: 'p1', name: packName('aardvark', 'Aardvark Phone') });

    expect(events.onPeer).toHaveBeenCalledWith(expect.anything(), 'found');
    expect(nearby.requestConnection).not.toHaveBeenCalled();
  });

  it('tracks a connected peer and reports it lost on disconnect', async () => {
    const events = makeEvents();
    const transport = new MeshTransport(me, events);
    await transport.start();

    nearby.onConnected.emit({ peerId: 'p1', name: packName('zephyr', 'Zephyr Phone') });
    expect(transport.connectedPeers).toEqual([{ peerId: 'p1', deviceId: 'zephyr', display: 'Zephyr Phone' }]);
    expect(events.onPeer).toHaveBeenCalledWith(
      { peerId: 'p1', deviceId: 'zephyr', display: 'Zephyr Phone' },
      'connected'
    );

    nearby.onDisconnected.emit({ peerId: 'p1' });
    expect(transport.connectedPeers).toEqual([]);
    expect(events.onPeer).toHaveBeenCalledWith(
      { peerId: 'p1', deviceId: 'zephyr', display: 'Zephyr Phone' },
      'lost'
    );
  });

  it('decodes an incoming envelope and hands it to onEnvelope', async () => {
    const events = makeEvents();
    const transport = new MeshTransport(me, events);
    await transport.start();

    const envelope = newEnvelope({ id: '1', from: 'zephyr', to: 'me', kind: 'msg', body: 'hi', at: 0 });
    nearby.onTextReceived.emit({ peerId: 'p1', text: encode(envelope) });

    expect(events.onEnvelope).toHaveBeenCalledWith(envelope, 'p1');
  });

  it('drops a malformed payload instead of crashing', async () => {
    const events = makeEvents();
    const transport = new MeshTransport(me, events);
    await transport.start();

    nearby.onTextReceived.emit({ peerId: 'p1', text: 'not an envelope' });

    expect(events.onEnvelope).not.toHaveBeenCalled();
  });

  it('broadcasts to every connected peer except the excluded one', async () => {
    const events = makeEvents();
    const transport = new MeshTransport(me, events);
    await transport.start();

    nearby.onConnected.emit({ peerId: 'p1', name: packName('a', 'A') });
    nearby.onConnected.emit({ peerId: 'p2', name: packName('b', 'B') });

    const envelope = newEnvelope({ id: '1', from: 'me', to: 'b', kind: 'msg', body: 'hi', at: 0 });
    const fanout = await transport.broadcast(envelope, 'p1');

    expect(fanout).toBe(1);
    expect(nearby.sendText).toHaveBeenCalledTimes(1);
    expect(nearby.sendText).toHaveBeenCalledWith('p2', encode(envelope));
  });

  it('stops advertising/discovery and unsubscribes on stop', async () => {
    const events = makeEvents();
    const transport = new MeshTransport(me, events);
    await transport.start();
    await transport.stop();

    expect(nearby.stopAdvertise).toHaveBeenCalled();
    expect(nearby.stopDiscovery).toHaveBeenCalled();
    expect(nearby.disconnect).toHaveBeenCalled();

    // Listeners were torn down, so a stray event after stop() is a no-op.
    nearby.onPeerFound.emit({ peerId: 'p9', name: packName('later', 'Later Phone') });
    expect(events.onPeer).not.toHaveBeenCalled();
  });
});

// jest.setup.js pins Platform.OS to 'ios' for every other test in this file
// (and the rest of the suite) so behaviour is deterministic by default. These
// tests deliberately flip to 'android' to exercise the runtime-permission and
// Play-services branches that are otherwise never reached.
describe('MeshTransport on Android', () => {
  const originalOS = Platform.OS;
  const originalVersion = Platform.Version;
  const originalRequestMultiple = PermissionsAndroid.requestMultiple;

  const me = { deviceId: 'me', display: 'My Phone' };
  const makeEvents = () => ({ onPeer: jest.fn(), onEnvelope: jest.fn(), onError: jest.fn() });

  // Platform.Version is a getter-only property on the real (and jest-mocked)
  // Platform module, so a plain `Platform.Version = x` assignment silently
  // no-ops. Redefining the property is the only way to override it.
  const setVersion = (version: number | string) =>
    Object.defineProperty(Platform, 'Version', { value: version, configurable: true });

  const grantAll = () => {
    const spy = jest.fn(async (perms: string[]) =>
      Object.fromEntries(perms.map((p) => [p, 'granted']))
    );
    (PermissionsAndroid as any).requestMultiple = spy;
    return spy;
  };

  const denyOnly = (denied: string[]) => {
    const spy = jest.fn(async (perms: string[]) =>
      Object.fromEntries(perms.map((p) => [p, denied.includes(p) ? 'denied' : 'granted']))
    );
    (PermissionsAndroid as any).requestMultiple = spy;
    return spy;
  };

  beforeEach(() => {
    (Platform as any).OS = 'android';
  });

  afterEach(() => {
    (Platform as any).OS = originalOS;
    setVersion(originalVersion);
    (PermissionsAndroid as any).requestMultiple = originalRequestMultiple;
  });

  it('starts once all required permissions are granted (API 30)', async () => {
    setVersion(30);
    const spy = grantAll();

    const result = await new MeshTransport(me, makeEvents()).start();

    expect(result).toEqual({ ok: true });
    expect(spy).toHaveBeenCalledWith(
      expect.arrayContaining(['android.permission.ACCESS_FINE_LOCATION'])
    );
    // API 30 predates the split Bluetooth runtime permissions.
    expect(spy.mock.calls[0][0]).not.toContain('android.permission.BLUETOOTH_SCAN');
  });

  it('also requests the split Bluetooth permissions on API 31+', async () => {
    setVersion(31);
    const spy = grantAll();

    await new MeshTransport(me, makeEvents()).start();

    expect(spy.mock.calls[0][0]).toEqual(
      expect.arrayContaining([
        'android.permission.BLUETOOTH_SCAN',
        'android.permission.BLUETOOTH_ADVERTISE',
        'android.permission.BLUETOOTH_CONNECT',
      ])
    );
  });

  it('also requests NEARBY_WIFI_DEVICES on API 33+', async () => {
    setVersion(33);
    const spy = grantAll();

    await new MeshTransport(me, makeEvents()).start();

    expect(spy.mock.calls[0][0]).toContain('android.permission.NEARBY_WIFI_DEVICES');
  });

  it('fails to start and names what is missing when a permission is denied', async () => {
    setVersion(30);
    denyOnly(['android.permission.ACCESS_FINE_LOCATION']);

    const result = await new MeshTransport(me, makeEvents()).start();

    expect(result.ok).toBe(false);
    expect(result.reason).toContain('android.permission.ACCESS_FINE_LOCATION');
  });

  it('fails to start when Google Play services is unavailable', async () => {
    setVersion(30);
    grantAll();
    nearby.isPlayServicesAvailable.mockResolvedValue(false);

    const result = await new MeshTransport(me, makeEvents()).start();

    expect(result).toEqual({
      ok: false,
      reason: 'Google Play services is not available on this phone.',
    });
  });
});
