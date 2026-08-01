# Foundation prompt — offline Bluetooth mesh messaging (Echo)

Copy everything in the block below into a fresh Claude Code session in this repo.

---

## THE PROMPT

Implement **offline mesh messaging** for Echo. Read `CLAUDE.md` and `SETUP.md` first. This is **TypeScript-only feature work** — the native layer is already built, verified, and shipped.

### Ground truth — do not re-litigate or re-investigate these

- **Stack:** Expo SDK 57, React Native 0.86.2, TypeScript, custom **Expo dev client** (NOT Expo Go), Android-only, arm64-v8a, physical devices only.
- **Already installed, autolinked, and in the shipped APK:** `expo-nearby-connections@1.1.0` (+ `react-native-nitro-modules`), `react-native-keychain`, `react-native-executorch`, `expo-camera/speech/haptics`, `expo-file-system`.
- **All Nearby permissions are already declared** in `AndroidManifest.xml` by the config plugin (BLUETOOTH_SCAN / _ADVERTISE / _CONNECT, ACCESS_FINE/COARSE_LOCATION, NEARBY_WIFI_DEVICES, ACCESS/CHANGE_WIFI_STATE). You still must **request the runtime permissions** in JS.
- **DO NOT** add native dependencies, run `expo prebuild`, or rebuild the APK. Any native change forces a new APK for the whole team. If you believe a native change is unavoidable, **stop and ask first**.
- Do not modify `android/` (it is git-ignored and regenerated).
- Test with `npx expo start --dev-client` and hot reload on installed dev clients.

### The exact transport API (verified from the installed package — use these names)

```ts
import {
  startAdvertise, stopAdvertise,
  startDiscovery, stopDiscovery,
  requestConnection, acceptConnection, rejectConnection, disconnect,
  sendText,
  onPeerFound, onPeerLost, onInvitationReceived,
  onConnected, onDisconnected, onTextReceived,
  isPlayServicesAvailable,
  Strategy,
} from 'expo-nearby-connections';
```

- `startAdvertise(name, strategy)` / `startDiscovery(name, strategy)` → `Promise<string>` (local peer id)
- `requestConnection(peerId)`, `acceptConnection(peerId)`, `rejectConnection(peerId)`, `disconnect(peerId?)`
- `sendText(peerId, text)` — **text only; the payload is a string. Serialize the envelope to JSON.**
- Every `on*` returns an **`Unsubscribe`** — always clean up in `useEffect`.
- Event payloads: `PeerFound {peerId,name}`, `PeerLost {peerId}`, `InvitationReceived {peerId,name}`, `Connected {peerId,name}`, `Disconnected {peerId}`, `TextReceived {peerId,text}`.
- `Strategy` = `P2P_CLUSTER (1)` | `P2P_STAR (2)` | `P2P_POINT_TO_POINT (3)`. **Use `Strategy.P2P_CLUSTER`** — it allows many-to-many links, which is what makes relaying possible. (The library defaults to `P2P_STAR`; override it.)

### Core requirement: every phone is BOTH a node and a relay

1. On start, each device **advertises AND discovers simultaneously** (this is what forms the mesh-like cluster) and auto-connects to found peers.
2. For the demo, **auto-accept** incoming invitations (`onInvitationReceived` → `acceptConnection`). Keep it simple.
3. **Relaying (this is the actual "mesh" and the thing judges care about):** when a message arrives that is not addressed to me, and its TTL allows, **forward it to every other connected peer except the sender**. That store-and-forward hop is what extends range beyond direct radio contact.

### Message envelope

Define in `src/features/messaging/types/`:

```ts
type MeshEnvelope = {
  id: string;          // unique message id (used for dedupe)
  from: string;        // origin device id (stable per install, NOT the transient peerId)
  to: string | null;   // recipient device id, or null = broadcast
  body: string;        // message text (later: ciphertext — see Encryption seam)
  ttl: number;         // hops remaining; decrement on each forward; drop at 0
  hops: number;        // hops taken (nice for the demo UI: "via 2 hops")
  sentAt: number;      // epoch ms
};
```

### Where code goes (follow this exactly — feature-first, per `CLAUDE.md`)

| Path | Responsibility |
|---|---|
| `src/utils/mesh.ts` | **PURE functions, no native imports** — `createEnvelope()`, `shouldRelay()`, `decrementTtl()`, dedupe (LRU/Set of seen ids), `serialize`/`parse` (safe JSON parse — never trust remote input). Must be unit-testable with plain objects. |
| `src/features/messaging/api/` | Thin wrapper over `expo-nearby-connections` (start/stop, connect, send, subscribe). The **only** place that imports the transport. |
| `src/features/messaging/hooks/useMesh.ts` | Orchestration: lifecycle, peer list, connection state, inbound handling, relay decisions, send. Exposes `{ peers, messages, isReady, myId, sendMessage, start, stop }`. |
| `src/features/messaging/components/` | `PeerList`, `MessageBubble`, `MeshStatusBar` (peer count / advertising+discovering state). |
| `src/screens/MessagingScreen.tsx` | Chat UI: peer list, thread, input, send. |
| `src/store/` | Zustand store if shared state is needed across screens. |

**Keep the relay/TTL/dedupe math as pure functions in `utils/`** — it is the intellectual core, and it must be testable without a device.

### Runtime permissions

Before advertising/discovering, request via `PermissionsAndroid.requestMultiple`: `BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION`, and `NEARBY_WIFI_DEVICES` (Android 13+; guard by API level). Also check `isPlayServicesAvailable()` and surface a clear error if false. Handle denial gracefully with a visible message — do not crash or fail silently.

### Encryption seam (do not implement yet)

`react-native-keychain` is already in the APK and `src/features/vault/` is scaffolded. **Design `body` so it can hold ciphertext later** — relays must never need to read it. Do not build crypto now; just don't design it out.

### Build order (ship each step working — this is a time-boxed hackathon)

1. **Two phones connect.** Advertise + discover + auto-accept; show a live peer list. Verify on 2 real devices.
2. **Direct 1-to-1 text.** Send/receive a JSON envelope via `sendText`; render a thread.
3. **Relay (the money feature).** TTL + dedupe + forward-to-others. Show hop count in the UI.
4. **Polish for demo.** Connection status, "via N hops" badge, empty/error states.

### Definition of done

- Two phones with **wifi and mobile data OFF** exchange messages.
- A message from A reaches C **through B** when A and C are not directly connected (the multi-hop proof — stage it by separating devices or filtering direct links).
- No duplicate messages (dedupe works); messages stop after TTL expires (no infinite loops).
- Subscriptions are cleaned up; no crash on backgrounding or peer disconnect.
- `npx tsc --noEmit` passes.
- Pure relay logic in `utils/` has unit tests.

### Constraints and honest limits (keep these in the pitch)

- Google Nearby is **P2P clustering** — mesh-like within radio range. **True multi-hop past radio range is the app-layer relay logic you are writing.** Do not claim otherwise; the relay code is the honest differentiator.
- `sendText` is string-only — no binary payloads.
- Prefer **simple, working, demoable** over production-grade. Land step 1 before touching step 3.

### Working style

- Verify on **two physical devices** — Nearby does not work on emulators and needs real radios.
- Report honestly: if relaying does not work at range, say so and show the evidence rather than claiming success.
- Do not fabricate API names — the verified surface is listed above.
