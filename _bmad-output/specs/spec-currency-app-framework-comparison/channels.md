# Channels — four drivers, one interface

Companion to `SPEC.md` (CAP-2 … CAP-6). Build order is **strictly by risk**.

## The interface

```
ChannelDriver {
  id: 'qr' | 'nearby' | 'relay' | 'nfc'
  profile: TINY | SMALL | FULL
  available(): boolean          // hardware present + permission granted
  send(payload: string): Promise<void>      // base64url note, 56 chars
  receive(): AsyncIterable<string>
}
```

Every channel moves the **same 56-character base64url string**. Adding a driver must
require zero edits to note parsing, serialization or wallet logic — that is CAP-2's
success criterion.

## Wire profiles

| Profile | Budget | v0 note (42 B → 56 chars) |
|---|---|---|
| TINY | ≤31 B | does not fit — unused in v0 |
| SMALL | ≤255 B | fits |
| FULL | unbounded | fits |

v0 needs only SMALL. TINY and FULL exist for v1 (history blobs) and are specified so
adding them later is not a redesign.

## Build order

### 1. Static QR — SMALL — ~1.5 h/dev

Cheapest and highest certainty. Do it first; it is the demo spine.

| | React Native | Flutter |
|---|---|---|
| Encode | 1 new dep (QR generator) | `qr_flutter` |
| Decode | **`expo-camera`, already in base repo** | `mobile_scanner` |

QR **text mode, error correction M**. Render at ≥ 240 dp. No animation, no fountain
coding — the note fits one static code.

### 2. Nearby Connections — FULL — ~2 h/dev

The BLE story, and the hardest transport. Hit it early enough to fail safely.

| | React Native | Flutter |
|---|---|---|
| Package | **`expo-nearby-connections`, already in base repo ⚠** | `nearby_connections` |

Both wrap the **same Google Nearby API** (BLE + Wi-Fi Direct), which makes this a fair
binding comparison rather than a library comparison.

**Why not raw BLE GATT:** peripheral/advertising mode is the weak spot in both
ecosystems — most libraries only do central, and both phones must advertise *and* scan.
Nearby removes that problem entirely.

- `serviceId`: `echo.currency.v0` (constant)
- Endpoint name: `<framework>:<device-id-hex-8>` — see `wire-format.md`
- Strategy: `P2P_CLUSTER`
- Payload type: `BYTES`

> ⚠ **`expo-nearby-connections` is already integrated and building in the base repo — on
> the hardest channel.** Time this from a clean scaffold or the number is worthless.

### 3. Multi-hop relay — ~1 h/dev

Pure TypeScript / Dart on top of #2. **No native code**, which makes it a clean
*language-level* comparison rather than a binding one.

The algorithm — floater writes it once, both devs implement it independently:

```
on receive(envelope):
  if not envelope.startsWith('R|'): handle as direct transfer; return
  (ttl, note) = parse(envelope)
  if seen.has(note.note_id, note.lamport): return          // dedupe
  seen.add(note.note_id, note.lamport)
  if note.holder == myDeviceId: claim(note); return
  if ttl <= 1: return                                       // expire
  broadcast(`R|${ttl - 1}|${note}`) to all endpoints except sender
```

TTL starts at **3**. `seen` is an in-memory set — it does not need to survive restart.

**Not SIG Bluetooth Mesh.** That is not a one-day item and is explicitly out of scope.

### 4. NFC tag — SMALL — ~1.5 h/dev

Riskiest per unit of value, so it goes last and can fail without hurting the demo.

| | React Native | Flutter |
|---|---|---|
| Package | `react-native-nfc-manager` | `nfc_manager` |

**Tag-based, not Host Card Emulation.** HCE needs a native Android service plus AID
registration in the manifest in *both* frameworks, and Android Beam was removed in
Android 10 — there is no cheap phone-to-phone path.

Write an **NDEF text record** containing the base64url string. On successful write the
sender deletes its copy; the note now lives on the tag. Any device reading the tag claims
it and blanks the tag.

This makes the bearer-note story *physical*: money sitting on the table. It is also the
only channel where the "leave value on an object" demo works.

**Buy a pack of NTAG215 stickers before the day.** They are the entire NFC demo.

## Cut channels

Ultrasonic · UWB · satellite · flashlight VLC · SMS · MST · animated QR · NFC HCE ·
SIG Bluetooth Mesh.

Each was evaluated and cut for time, platform restriction, or dead hardware. Say so out
loud rather than implying they exist.

## Per-channel acceptance

A channel is **done** when all four interop cells pass **in airplane mode**:

| | RN→RN | FL→FL | RN→FL | FL→RN |
|---|---|---|---|---|

Test cross-framework **immediately after** each channel works — not once at the end.
Encode and decode are different code paths; proving one direction proves half.

**If a channel is not working 30 minutes past its slot, cut it and move on.** Three solid
channels beat four flaky ones.
