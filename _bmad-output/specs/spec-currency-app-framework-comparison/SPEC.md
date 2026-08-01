---
id: SPEC-currency-app-framework-comparison
companions:
  - ../../../spec/wire.md
  - app-contract.md
  - channels.md
  - measurement.md
  - ../../brainstorming/brainstorm-currency-app-framework-comparison-2026-08-01/hackathon-plan.md
  - ../../brainstorming/brainstorm-currency-app-framework-comparison-2026-08-01/scorecard.md
sources:
  - ../../brainstorming/brainstorm-currency-app-framework-comparison-2026-08-01/brainstorm-intent.md
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. Source documents listed in frontmatter are for traceability only — consult them only if you need narrative rationale or prose color this contract intentionally omits.

# Currency Wallet as a React Native vs Flutter Benchmark

## Why

**An opportunity to capture, under a hard deadline.** A team is choosing between React Native and Flutter and has one hackathon day to answer it with evidence rather than opinion. Both frameworks are equally capable at simple apps; they diverge only at the **native boundary** and **under load**. The real question is therefore not which is prettier but **which stays tractable when you need something the plugin ecosystem has not wrapped** — we are evaluating escape hatches, not frameworks.

A play-currency wallet is the instrument because it forces breadth in one small product: four radically different transfer channels, peer discovery, relay logic, and list rendering. The currency is a costume. The product is the comparison, and the deliverable is a decision table — "if your product needs X, pick Y" — not a verdict on a winner.

## Capabilities

- **CAP-1 — Wallet holds notes**
  - **intent:** A user can see the notes they hold and their total, with no network.
  - **success:** App launches in airplane mode showing preloaded notes; total equals the fold over held notes; state survives a force-quit and relaunch.

- **CAP-2 — Channel driver interface**
  - **intent:** A transfer moves the same bytes over any channel, so adding a channel is writing a driver rather than changing the protocol.
  - **success:** All four channels are implemented against one `send`/`receive` contract; adding the fourth driver requires zero edits to note parsing, serialization or wallet logic.

- **CAP-3 — Static QR channel**
  - **intent:** A user can hand a note to a nearby device by showing a code and having it scanned.
  - **success:** Sender renders a note tip as a static QR; receiver scans it, verifies, and the note appears in the receiver's wallet and disappears from the sender's. Airplane mode.

- **CAP-4 — Nearby Connections channel**
  - **intent:** A user can transfer a note to a discovered nearby device with no network infrastructure.
  - **success:** Two devices discover each other and complete a transfer with wifi and cellular disabled.

- **CAP-5 — Multi-hop relay**
  - **intent:** A device forwards a note addressed to someone else, so value crosses further than one radio hop.
  - **success:** A note travels device A → B → C where A and C are never directly connected; TTL stops propagation and dedupe prevents a note being forwarded twice.

- **CAP-6 — NFC tag channel**
  - **intent:** A user can leave a note on a physical object for someone else to pick up.
  - **success:** A note is written to an NFC tag, the sender's copy is removed, and a second device reads the tag and claims it.

- **CAP-7 — Same-app transfer**
  - **intent:** Each framework's app transfers to another device running that same app.
  - **success:** RN→RN and Flutter→Flutter both pass on every implemented channel, in airplane mode. **This is the baseline deliverable, not a milestone.**

- **CAP-8 — Cross-framework transfer**
  - **intent:** The React Native app and the Flutter app pay each other, proving both implement one wire format.
  - **success:** RN→FL and FL→RN both pass on at least the QR channel; the two directions are tested independently because encode and decode are different code paths. Enabled by one discovery-filter toggle.

- **CAP-9 — Wire conformance**
  - **intent:** Both implementations are proven to follow the same spec rather than the same bug.
  - **success:** Hand-authored vectors in `vectors.json` pass in both projects' unit tests; the Python reference implementation agrees with both. See `wire-format.md`.

- **CAP-10 — Comparison capture**
  - **intent:** The build produces the numbers the comparison exists to generate.
  - **success:** Every row of `scorecard.md` is filled from clean scaffolds, with the base-repo head start printed rather than hidden. See `measurement.md`.

- **CAP-11 — Double-spend detection** — ~~retired, out of scope under trade (B)~~
  - Id retained so it is never reused. See Non-goals.

- **CAP-13 — Send is two-phase; the human is the acknowledgement**
  - **intent:** A sender can hand a note to a one-way channel without risking either losing it or spending it twice.
  - **success:** Selecting a note locks it `IN_FLIGHT` — excluded from the balance fold and unselectable for a second send. **Delivered** deletes it; **Cancel** restores it to `HELD`. A displayed-but-never-scanned QR loses nothing. See `app-contract.md`.

- **CAP-14 — Bearer and directed modes are determined by the channel**
  - **intent:** Each channel uses the only addressing mode physically available to it, rather than a configurable one.
  - **success:** QR and NFC transfers are BEARER (`flags` bit 0 set, `holder` all-zero) because the sender cannot learn the recipient; Nearby is DIRECTED because discovery yields the peer id first. Relay runs over Nearby only. A bearer note offered to the relay driver is rejected, not forwarded.

- **CAP-12 — Agentic Tier A** *(deferred — build after the app is finished; blocked on an endpoint)*
  - **intent:** Both apps stream a response from the same remote endpoint, isolating UI streaming cost with no native code on either side.
  - **success:** Identical prompt and identical frozen endpoint in both apps; time-to-first-token, tokens/sec and jank-while-streaming recorded for each and reported as three separate numbers.

## Constraints

- **The two projects are completely segregated.** No shared code, no shared build, no shared dependency tree. Any native code needed by both is duplicated as byte-identical, checksum-verified copies. Only documents cross the boundary. **No build system may span `currency-rn/` and `currency-flutter/`.**
- **The protocol is one-way, fire-and-forget.** QR, tags and broadcast channels cannot acknowledge, so a transferred note must be a **complete, self-contained, independently verifiable object**. Two-way is an optimization, never an assumption.
- **Notes are framework-blind.** Framework tagging lives in the transport (BLE service UUID, NFC AID), never in the note. This is what makes CAP-8 possible.
- **Airplane mode is the acceptance criterion for every channel**, not a final test. A channel is not done until it works with the radios that channel does not need turned off.
- **Never start channel N+1 until channel N works on real hardware.** If a channel is not working 30 minutes past its slot, cut it. Three solid channels beat four flaky ones.
- **All comparison timings come from clean scaffolds**, never from the `echo-hackathon` base repo — it already ships `expo-nearby-connections` and `react-native-executorch`, which is a head start on the hardest channel. The head start is printed in the write-up.
- **Play currency only**, visually unmistakable as fake. Not real money.
- **The wire spec is frozen 30 minutes in.** After that a change costs two devs, not one.
- **~9.25 hours, 2 devs (one per framework) + 1 floater.** Android, physical devices, arm64.
- **A Path B builder machine is required and is a hard prerequisite.** Building either app needs Java and the Android SDK; the Flutter half additionally needs the Flutter/Dart toolchain; and **every metric in CAP-10 comes from `adb`**. A Path A contributor box (Node and Git only) cannot scaffold, build, or measure anything. Confirm at least one such machine exists *with Flutter installed* before the day — without it there is no comparison, only an RN app.
- **`IN_FLIGHT` locking, not cryptography, is what prevents double-spend in v0.** Notes are unsigned; the lock is the whole defence.
- **Deliberately custom UI — non-Material, non-Cupertino** — so neither framework gets home-field advantage.

## Non-goals

- **Signed notes in v0.** Notes are `{id, value, holder}`, unsigned. Signatures sit behind the version byte as a v1 upgrade. Consequence: **the "forger is proven by their own signature" claim must not appear in the pitch** unless ed25519 lands.
- **NFC Host Card Emulation.** Phone-to-phone NFC needs a native Android service plus AID registration in both frameworks; Android Beam is gone. Tag-based only.
- **SIG Bluetooth Mesh.** Multi-hop relay is app-layer TTL + dedupe + forward over Nearby.
- **Animated QR and fountain coding.** A 96-byte tip fits one static code.
- **A database.** Notes persist as a JSON blob. Any large-list benchmark uses a generated in-memory list.
- **A navigation library.** Three views behind a state enum — `react-navigation` vs `go_router` is not what is being measured.
- **An in-app telemetry screen.** All metrics captured externally via `adb`.
- **Agentic Tiers B and C** (blessed local runtimes; same llama.cpp bridged twice). Post-hackathon.
- **Double-spend detection and the fraud button (retired CAP-11).** Trade (B) bought agentic Tier A, not everything — this was the ~1 h it displaced. Consequence: **the pitch must not claim fraud detection.** The seen-id dedupe in the relay driver is for correctness, not fraud.
- **The three-tier finality state machine** (Accepted → Corroborated → Settled). v0 has relay but no corroboration echoes, so the tiers have nothing to display. A transfer is simply done or not.
- **A threat-model screen.** The three views are Wallet, Send, Receive. "This is a security toy" is said in the pitch, not rendered in the app.
- **A shared E2E suite** (Maestro/Appium) and **pixel-diffing against a shared Figma.** Both were anti-drift mechanisms for a longer project; `vectors.json` is the only cross-project conformance gate that survives the time cut.
- **Wallet export / RN→Flutter migration** as a second interop test. CAP-8 covers interop.
- **Cut channels:** ultrasonic, UWB, satellite, flashlight VLC, SMS, MST.
- **Cut features:** hardware-backed keys, sensor-based minting, endorsement-chain history, change-making, production key recovery, real settlement, custody, any server dependency, iOS.

## Success signal

In airplane mode, on stage, in ninety seconds: an RN phone pays an RN phone and a Flutter phone pays a Flutter phone over QR; **one switch is flipped and the RN phone pays the Flutter phone**; a third phone relays a note to a fourth across the room over Nearby; a note is tapped onto an NFC tag and picked up off the table by another device. Then the filled scorecard goes on screen — per-channel build cost and runtime numbers for both frameworks, with the base-repo head start disclosed.

The comparison succeeds if a reader can point at one row and say *"for the kind of product I build, this one."*

## Assumptions

- ~9.25 hours of build time with 2 devs and 1 floater, per trade (B); the schedule in `hackathon-plan.md` fits that shape.
- Android-only for the day. iOS platform gaps (HCE restrictions, background BLE, programmatic SMS) are reported as findings, not built against.
- `nearby_connections` on the Flutter side is mature enough to match `expo-nearby-connections`; both wrap the same Google Nearby API. Unverified until the day.
- Trade **(B)** chosen: agentic Tier A is in, double-spend detection is out.
- The agentic endpoint work is split — the floater builds and tests the endpoint contract and a reference streaming client during the morning, so each dev integrates in ~30 min rather than an hour. If that split does not happen, add an hour.
- **Two specialists, one per framework** — not one person writing both. Segregation parallelizes perfectly and that parallelism is the only reason 9.25 h is achievable; one person doing both roughly doubles the day. The cost is that dev skill becomes a confound, which the "anything that fought you" scorecard row is there to expose.
- **Unsigned v0 is accepted.** `IN_FLIGHT` locking replaces cryptographic double-spend prevention. The pitch drops every signature and fraud-detection claim.
- **Scenario anchor: a festival with no signal.** Chosen because it justifies all four channels without needing a backstory — QR at a stall, tag on a table, Nearby in a crowd, relay across a field. Purely narrative; changing it costs nothing but a slide.
- `currency-flutter/lib/wire.dart` exists but has **never been executed** — no Dart on the authoring machine. `dart test` passing 9/9 is the gate before any channel work.

## Open Questions

One remains.

1. **Which endpoint and model for CAP-12, and when does it arrive?** No OpenAI-compatible endpoint exists yet, so **CAP-12 is deferred, not cut**: finish the app across all four channels first, then add the agentic part. Epic E8 is gated on this and every story in it is `blocked`. Both apps must hit an **identical frozen endpoint** — URL and model in a shared constant. **If it is still unavailable when the channels are done, agentic becomes a slide** and the write-up says so. Decide the fallback rather than waiting on the datacenter GPU, whose access method is only shared at the event.

*Resolved:* Path B machine with Flutter → **confirmed, the comparison is viable** · scope trade → **(B)** · agentic sequencing → **last, after the app is finished** · who writes each build → **two specialists** · unsigned v0 → **accepted** · scenario anchor → **festival with no signal** · sender-deletion semantics → **CAP-13, the human is the ACK** · bearer-vs-directed → **CAP-14, determined by the channel**.
