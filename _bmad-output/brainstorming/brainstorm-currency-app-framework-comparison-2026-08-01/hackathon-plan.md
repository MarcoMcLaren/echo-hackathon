# Hackathon Plan — four channels, two frameworks

Derived from `.memlog.md` (364 entries, three rounds), cut for time, then realigned to
carry **NFC, QR, BLE and Bluetooth mesh**.

**Assumption: 2 devs (one per framework) + 1 floater.**
Four channels in two frameworks is **~8 hours**, not six. §Trade names what gives.

---

## Four channels = four drivers, not four features

The wire-profile design already absorbs this. One interface, four drivers:

```
interface ChannelDriver {
  profile: TINY | SMALL | FULL
  send(tip: Uint8Array): Promise<void>
  receive(): AsyncIterable<Uint8Array>
}
```

| Channel | Payload ceiling | Profile | Carries |
|---|---|---|---|
| QR (static) | ~2900 B | FULL | tip + history |
| NFC tag / APDU | ~255 B | SMALL | 96-byte tip |
| BLE advert | 31 / 255 B | TINY / SMALL | tip hash / tip |
| Nearby Connections | arbitrary | FULL | tip + history |

Same bytes everywhere. Adding a channel is writing a driver — never touching the
protocol. **This is why cross-framework payment works on every channel for free.**

---

## Three reality checks — read before estimating

**NFC: phone-to-phone needs HCE, and HCE is native work in both frameworks.**
Host Card Emulation means a native Android service plus AID registration in the
manifest — not a plugin call. Android Beam was removed in Android 10, so there is no
easy path. **Ship tag-based NFC** (write a note to a sticker, another phone reads it):
dramatically cheaper, still a genuine NFC demo, and it makes the bearer-note story
*physical*. HCE is the stretch.

**BLE: use Nearby Connections, not raw GATT.**
Raw BLE peripheral/advertising mode is the weak spot in both ecosystems — most libraries
only do central, and you need both phones advertising *and* scanning. The base repo
already has `expo-nearby-connections` working, and Flutter has a mature
`nearby_connections` package wrapping the **same Google Nearby API**. That dodges the
advertising problem entirely and is a *fairer* comparison, because the underlying native
API is identical on both sides.

**Bluetooth mesh: app-layer relay, not SIG Mesh.**
SIG Bluetooth Mesh is not a one-day item. Multi-hop relay over the Nearby/BLE
transport — **TTL + dedupe + forward** — is pure TypeScript/Dart with no native code.
Cheap once the transport works, and being the same algorithm written twice makes it a
clean *language-level* comparison rather than a binding one.

---

## Build order — strictly by risk

| # | Channel | Why here | Est/dev |
|---|---|---|---|
| 1 | **QR (static)** | Cheapest. `expo-camera` already scans; Flutter needs 2 deps | 1.5 h |
| 2 | **Nearby Connections** | The BLE story. Hardest transport — hit it early | 2 h |
| 3 | **Multi-hop relay** | Pure logic on top of #2. TTL + dedupe + forward | 1 h |
| 4 | **NFC (tag)** | Riskiest per unit of value. Last, so it can fail safely | 1.5 h |

**Never start N+1 until N works on real hardware in airplane mode.**

## The app — still three views

**Wallet** (notes + total) · **Send** (pick note → pick channel → go) · **Receive**
(listening on all channels).

The only UI change from the minimal build is a **channel picker** on Send. No settings,
no onboarding, no nav library, no database — notes persist as a JSON blob.

## Dependency delta

| | React Native | Flutter |
|---|---|---|
| QR | 1 (generator; camera already present) | 2 (`qr_flutter`, `mobile_scanner`) |
| BLE | 0 — `expo-nearby-connections` **already in repo** | 1 (`nearby_connections`) |
| Relay | 0 — pure logic | 0 — pure logic |
| NFC | 1 (`react-native-nfc-manager`) | 1 (`nfc_manager`) |

> **The RN head start is now severe.** The hardest channel is already integrated and
> building in the base repo. Measure every timing from a **clean scaffold**, and print
> the head start in the results. Without that, the BLE and mesh numbers are worthless.

---

## The day (~9.25 h) — trade (B)

| Time | Devs (one per framework) | Floater |
|---|---|---|
| 0:00–0:30 | Scaffold both projects | **`spec/wire.md` + `vectors.json`.** Frozen at 0:30 |
| 0:30–2:00 | **Channel 1 — QR.** Wallet + Send + Receive | `ref.py` + vector authoring |
| 2:00–2:30 | Same-app QR, airplane mode | **Cross-framework QR, both directions** |
| 2:30–4:30 | **Channel 2 — Nearby Connections** | Relay algorithm written once; **agentic endpoint + reference streaming client** |
| 4:30–5:00 | Same-app Nearby | **Cross-framework Nearby** |
| 5:00–6:00 | **Channel 3 — multi-hop relay** | 4-phone relay test |
| 6:00–7:30 | **Channel 4 — NFC tag** | Tag prep, interop |
| 7:30–8:00 | 100k-row scroll screen (generated list) | **adb telemetry capture, both builds** |
| 8:00–8:45 | **Rehearsal in airplane mode + scorecard + pitch** | |
| *then, only if unblocked* | **Agentic Tier A** — integrate the floater's client | Verify identical endpoint both sides |

## The trade — locked: (B), with agentic sequenced last

Agentic Tier A is **in scope but deferred**: finish the app across all four channels
first, then add it. **No OpenAI-compatible endpoint exists yet**, so epic E8 is gated —
if it is still unavailable when the channels are done, **agentic becomes a slide** and
the write-up says so plainly.

**Double-spend detection and the fraud button are cut** — that is the hour (B) spent.
The 100k-row benchmark **stays**: a generated in-memory list read via adb, about twenty
minutes, and a core rendering data point.

**When agentic is unblocked, halve it by splitting the work.** The floater builds and
tests the endpoint contract and a reference streaming client, so each dev integrates in
~30 min rather than an hour.

Sequencing agentic last means the day ends on the rehearsal block at 8:45 with a
complete, demoable app — and anything agentic is upside rather than a dependency.

> **Do not claim fraud detection in the pitch.** The seen-id dedupe in the relay driver
> is there for correctness, not fraud.

**(A)** is the strongest demo: four transfer methods across two frameworks with
cross-framework working on each is a more striking result than three channels plus a
chatbot.

## Hard rules

1. **Freeze the spec at 0:30.** After that a change costs two devs.
2. **Airplane mode is the acceptance criterion for every channel**, not a final test.
3. **Cross-framework is tested per channel, immediately** — not once at the end.
4. **If a channel is not working 30 minutes past its slot, cut it and move on.**
   A demo with three solid channels beats one with four flaky ones.
5. **Nothing gets added to the three views.**

## Still cut — say these out loud

HCE phone-to-phone NFC (tag-based instead) · SIG Bluetooth Mesh (app-layer relay
instead) · animated QR · ultrasonic · UWB · satellite · flashlight VLC ·
hardware-backed keys · signatures (v0 notes are unsigned) · sensor minting · in-app
telemetry · database · navigation library.

## Day-zero logistics

- **4 phones — 2 RN, 2 Flutter.** Named owner.
- **NFC tags/stickers** — cheap, buy a pack, they are the NFC demo.
- Both toolchains verified building on the actual machines.
- Hot-reload rehearsed with radios off — **you cannot reload in airplane mode.**

## What "done" looks like — 90 seconds

Airplane mode throughout.

1. **QR** — RN pays RN, Flutter pays Flutter. Show the code, scan it, note moves.
2. **Flip the switch — RN pays Flutter.** Same bytes, different framework.
3. **Nearby** — a third phone relays to a fourth across the room. Multi-hop, no infra.
4. **NFC** — tap a sticker, the note is *on the table*. Tap it with the other phone.
5. The numbers, from adb. One scorecard. Done.
