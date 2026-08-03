// Thin wrapper over expo-nearby-connections (Google Nearby: BLE + Wi-Fi Direct).
//
// Nearby gives us P2P *clustering* — everyone in one room can reach everyone
// else. It does not relay past radio range on its own; that is the job of
// utils/relay.ts, which this layer feeds and obeys.
import { Platform, PermissionsAndroid } from 'react-native';
import {
  Strategy,
  startAdvertise,
  stopAdvertise,
  startDiscovery,
  stopDiscovery,
  requestConnection,
  acceptConnection,
  disconnect,
  sendText,
  onPeerFound,
  onPeerLost,
  onInvitationReceived,
  onConnected,
  onDisconnected,
  onTextReceived,
  isPlayServicesAvailable,
  type Unsubscribe,
} from 'expo-nearby-connections';
import { decode, encode, splitBody, type Envelope } from '../../../utils/relay';

/** Nearby only carries a display name, so identity rides along inside it. */
export const packName = (deviceId: string, display: string) => `${deviceId}~${display}`;
export const unpackName = (raw: string): { deviceId: string; display: string } => {
  const i = raw.indexOf('~');
  if (i < 0) return { deviceId: raw, display: raw };
  return { deviceId: raw.slice(0, i), display: raw.slice(i + 1) };
};

export type PeerInfo = { peerId: string; deviceId: string; display: string };

/**
 * Nearby reports failures as a bare ApiException with a numeric status. Showing
 * that to someone mid-demo tells them nothing, so translate the ones we can
 * actually hit into what to do about them.
 */
export function explain(e: unknown): string {
  const text = String(e);
  const code = Number(text.match(/\b(8\d{3})\b/)?.[1]);
  switch (code) {
    case 8003:
    case 8004:
    case 8002:
      return 'The radio was still busy from the last session. Try again.';
    case 8007:
    case 8020:
      return 'Turn Bluetooth off and on again, then retry.';
    case 8001:
      return 'Mesh was started twice. Stop it and start again.';
    default:
      return text.includes('MISSING_PERMISSION')
        ? 'Echo needs Bluetooth and location permission to find phones.'
        : 'Could not start the mesh. Check Bluetooth is on.';
  }
}

export type TransportEvents = {
  onPeer: (peer: PeerInfo, state: 'found' | 'connected' | 'lost') => void;
  onEnvelope: (envelope: Envelope, fromPeerId: string) => void;
  onError: (message: string) => void;
};

/** Every runtime permission Nearby needs, by API level. */
async function ensurePermissions(): Promise<{ ok: boolean; missing: string[] }> {
  if (Platform.OS !== 'android') return { ok: true, missing: [] };
  const api = Number(Platform.Version);
  const need: string[] = ['android.permission.ACCESS_FINE_LOCATION'];
  if (api >= 31) {
    need.push(
      'android.permission.BLUETOOTH_SCAN',
      'android.permission.BLUETOOTH_ADVERTISE',
      'android.permission.BLUETOOTH_CONNECT'
    );
  }
  if (api >= 33) need.push('android.permission.NEARBY_WIFI_DEVICES');

  const result = await PermissionsAndroid.requestMultiple(need as any);
  const missing = need.filter((p) => result[p as keyof typeof result] !== 'granted');
  return { ok: missing.length === 0, missing };
}

export class MeshTransport {
  private subs: Unsubscribe[] = [];
  private peers = new Map<string, PeerInfo>(); // peerId -> info, connected only
  private running = false;

  constructor(
    private me: { deviceId: string; display: string },
    private events: TransportEvents
  ) {}

  get connectedPeers(): PeerInfo[] {
    return [...this.peers.values()];
  }

  async start(): Promise<{ ok: boolean; reason?: string }> {
    if (this.running) return { ok: true };

    const perm = await ensurePermissions();
    if (!perm.ok) {
      return { ok: false, reason: `Missing permission: ${perm.missing.join(', ')}` };
    }

    if (Platform.OS === 'android' && !(await isPlayServicesAvailable())) {
      return { ok: false, reason: 'Google Play services is not available on this phone.' };
    }

    const advertised = packName(this.me.deviceId, this.me.display);

    this.subs.push(
      onPeerFound(({ peerId, name }) => {
        const info = { peerId, ...unpackName(name) };
        // Some devices report their own advertisement back. Never treat that as
        // a peer, or you appear in your own mesh.
        if (info.deviceId === this.me.deviceId) return;
        this.events.onPeer(info, 'found');
        // Both sides discover each other; the lower device id initiates so we
        // don't race into two half-open connections.
        if (this.me.deviceId < info.deviceId) {
          requestConnection(peerId).catch(() => {
            /* the other side may have got there first */
          });
        }
      })
    );

    this.subs.push(
      onPeerLost(({ peerId }) => {
        const info = this.peers.get(peerId);
        this.peers.delete(peerId);
        if (info) this.events.onPeer(info, 'lost');
      })
    );

    this.subs.push(
      // Accept everyone. A phone we have never met is still a node that can
      // carry traffic, and the mesh is stronger for having it. Whether it can
      // put a message in front of the user is a separate question, answered by
      // the contact list.
      onInvitationReceived(({ peerId }) => {
        acceptConnection(peerId).catch((e) => this.events.onError(String(e)));
      })
    );

    this.subs.push(
      onConnected(({ peerId, name }) => {
        const info = { peerId, ...unpackName(name) };
        if (info.deviceId === this.me.deviceId) return;
        this.peers.set(peerId, info);
        this.events.onPeer(info, 'connected');
      })
    );

    this.subs.push(
      onDisconnected(({ peerId }) => {
        const info = this.peers.get(peerId);
        this.peers.delete(peerId);
        if (info) this.events.onPeer(info, 'lost');
      })
    );

    this.subs.push(
      onTextReceived(({ peerId, text }) => {
        const envelope = decode(text);
        // A malformed payload is a peer problem, not ours — drop it quietly.
        if (envelope) this.events.onEnvelope(envelope, peerId);
      })
    );

    // A previous session (or a hot reload that reset our JS state) can leave the
    // radio still advertising, which makes the next start fail. Clear it first.
    await Promise.allSettled([stopAdvertise(), stopDiscovery()]);

    try {
      await startAdvertise(advertised, Strategy.P2P_CLUSTER);
      await startDiscovery(advertised, Strategy.P2P_CLUSTER);
    } catch (e) {
      await this.stop();
      return { ok: false, reason: explain(e) };
    }

    this.running = true;
    return { ok: true };
  }

  /**
   * Send to every connected peer except the one that handed it to us.
   *
   * Nearby's BYTES payload is capped at 32 KiB, so anything bigger goes as
   * parts. Each part is a normal envelope with its own id, which means relays
   * forward them without knowing they belong together — reassembly is purely
   * the recipient's problem.
   */
  async broadcast(envelope: Envelope, excludePeerId?: string): Promise<number> {
    const bodies = splitBody(envelope.body);
    const outgoing: Envelope[] =
      bodies.length === 1
        ? [envelope]
        : bodies.map((body, i) => ({
            ...envelope,
            id: `${envelope.id}#${i}`,
            gid: envelope.gid ?? envelope.id,
            part: { i, n: bodies.length },
            body,
          }));

    const targets = this.connectedPeers.filter((p) => p.peerId !== excludePeerId);
    let delivered = 0;
    for (const part of outgoing) {
      const text = encode(part);
      const results = await Promise.allSettled(targets.map((p) => sendText(p.peerId, text)));
      // Count peers reached, not parts sent.
      delivered = Math.max(delivered, results.filter((r) => r.status === 'fulfilled').length);
    }
    return delivered;
  }


  async stop(): Promise<void> {
    this.subs.forEach((u) => u());
    this.subs = [];
    this.peers.clear();
    this.running = false;
    await Promise.allSettled([stopAdvertise(), stopDiscovery(), disconnect()]);
  }
}
