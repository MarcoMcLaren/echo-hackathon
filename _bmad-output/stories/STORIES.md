# Echo Currency — RN vs Flutter benchmark — stories

43 stories across 9 epics · 2 done · 36 ready · 5 blocked

Derived from `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md`. Edit `stories.json`, not this file.
Push to GitHub with `node _bmad-output/stories/create-issues.mjs`.

## E1 — Foundations

_Frozen contract and a wallet state layer in both frameworks._

### ✅ E1-01 — Freeze wire format v0 + conformance vectors

**Epic:** E1 — Foundations
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-9**
**Framework:** both · **Size:** M

The byte contract both implementations derive from. Blocks everything.

### Acceptance criteria
- [ ] spec/wire.md specifies all 42 bytes, offsets and endianness
- [ ] spec/vectors.json holds 9 vectors (6 encode, 3 reject)
- [ ] spec/ref.py verifies them: `uv run spec/ref.py` prints OK 9
- [ ] At least one vector cross-checked against a base64 implementation other than ref.py

> Done. Vector 1 cross-checked against coreutils base64.

### ✅ E1-02 — RN — wire codec + vector tests

**Epic:** E1 — Foundations
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-9**
**Framework:** rn · **Size:** M

TypeScript codec. RN has no Buffer, so base64url is hand-rolled.

### Acceptance criteria
- [ ] currency-rn/src/wire.ts implements encode, decode, toB64url, fromB64url, relay helpers
- [ ] No TS parameter properties — must run under `node --experimental-strip-types`
- [ ] test/vectors.json is a COPY of spec/vectors.json, never a link
- [ ] `node --experimental-strip-types --test currency-rn/test/wire.test.ts` passes

> Done. 6/6 tests pass.

### ☐ E1-03 — Flutter — wire codec + vector tests

**Epic:** E1 — Foundations
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-9**
**Framework:** flutter · **Size:** M

Written from the same prose spec but NEVER EXECUTED — authored on a box with no Dart. Expect to fix something on first run.

### Acceptance criteria
- [ ] `cd currency-flutter && dart test` passes all 9 vectors
- [ ] Byte output identical to spec/ref.py for every encode vector
- [ ] Error codes match the RN side verbatim
- [ ] If Dart and RN disagree, ref.py decides and the losing side is fixed

> GATE: no channel work starts in Flutter until this is green. See currency-flutter/STATUS.md.

### ☐ E1-04 — RN — scaffold currency-rn

**Epic:** E1 — Foundations
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-1**
**Framework:** rn · **Size:** S

Expo project, entirely separate from the echo-hackathon base app.

### Acceptance criteria
- [ ] Expo blank-typescript project builds and runs on a physical device
- [ ] applicationId distinct from the Flutter build so both install on one phone
- [ ] No build file references anything outside currency-rn/
- [ ] src/wire.ts and test/ preserved by the scaffold

### ☐ E1-05 — Flutter — scaffold currency-flutter

**Epic:** E1 — Foundations
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-1**
**Framework:** flutter · **Size:** S

flutter create over the existing lib/ and test/.

### Acceptance criteria
- [ ] `flutter create --org com.echo.currency --project-name currency_flutter .` completes
- [ ] lib/wire.dart and test/ survive the scaffold
- [ ] applicationId distinct from the RN build
- [ ] `test: ^1.25.0` added to dev_dependencies
- [ ] Runs on a physical device

### ☐ E1-06 — RN — wallet state layer (device id, storage, preload)

**Epic:** E1 — Foundations
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-1**
**Framework:** rn · **Size:** M

See app-contract.md §3–§5. One JSON blob, no database.

### Acceptance criteria
- [ ] 16-byte random device id generated once and persisted
- [ ] Wallet persists as a single JSON blob in AsyncStorage matching the documented shape
- [ ] First launch preloads exactly 20 notes: 10x1, 6x5, 3x20, 1x100 (total 22500)
- [ ] note_id derived from deviceId + index so devices never mint colliding ids
- [ ] Balance is a fold over HELD notes only
- [ ] State survives force-quit and relaunch

### ☐ E1-07 — Flutter — wallet state layer (device id, storage, preload)

**Epic:** E1 — Foundations
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-1**
**Framework:** flutter · **Size:** M

Same contract as E1-06. SharedPreferences instead of AsyncStorage.

### Acceptance criteria
- [ ] 16-byte random device id generated once and persisted
- [ ] Wallet persists as a single JSON blob matching the documented shape
- [ ] First launch preloads exactly 20 notes: 10x1, 6x5, 3x20, 1x100 (total 22500)
- [ ] note_id derived from deviceId + index
- [ ] Balance is a fold over HELD notes only
- [ ] State survives force-quit and relaunch

## E2 — App shell

_Three views, send state machine, receive pipeline — both frameworks._

### ☐ E2-01 — RN — three views behind a state enum

**Epic:** E2 — App shell
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-1**
**Framework:** rn · **Size:** M

Wallet / Send / Receive. NO navigation library — react-navigation vs go_router is not what we are measuring.

### Acceptance criteria
- [ ] Three views switched by a single state enum, no nav dependency
- [ ] Wallet lists notes grouped by denomination with a total
- [ ] IN_FLIGHT notes render greyed with a Cancel affordance
- [ ] Deliberately custom styling — not Material, not Cupertino

### ☐ E2-02 — Flutter — three views behind a state enum

**Epic:** E2 — App shell
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-1**
**Framework:** flutter · **Size:** M

Same contract as E2-01.

### Acceptance criteria
- [ ] Three views switched by a single state enum, no go_router or Navigator 2
- [ ] Wallet lists notes grouped by denomination with a total
- [ ] IN_FLIGHT notes render greyed with a Cancel affordance
- [ ] Deliberately custom styling — not Material, not Cupertino

### ☐ E2-03 — RN — send state machine (IN_FLIGHT / Delivered / Cancel)

**Epic:** E2 — App shell
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-13**
**Framework:** rn · **Size:** M

Fire-and-forget has no ACK, so the human is the acknowledgement. This lock — not cryptography — is what prevents double-spend in v0.

### Acceptance criteria
- [ ] Selecting a note moves it HELD -> IN_FLIGHT
- [ ] IN_FLIGHT notes are excluded from the balance fold and cannot be selected again
- [ ] Delivered deletes the note; Cancel restores it to HELD
- [ ] Both buttons are equally prominent — no confirm-by-default
- [ ] A QR displayed and never scanned, then cancelled, loses nothing

### ☐ E2-04 — Flutter — send state machine (IN_FLIGHT / Delivered / Cancel)

**Epic:** E2 — App shell
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-13**
**Framework:** flutter · **Size:** M

Same contract as E2-03.

### Acceptance criteria
- [ ] Selecting a note moves it HELD -> IN_FLIGHT
- [ ] IN_FLIGHT notes are excluded from the balance fold and cannot be selected again
- [ ] Delivered deletes the note; Cancel restores it to HELD
- [ ] Both buttons are equally prominent
- [ ] A QR displayed and never scanned, then cancelled, loses nothing

### ☐ E2-05 — RN — receive pipeline + verbatim error codes

**Epic:** E2 — App shell
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-2**
**Framework:** rn · **Size:** M

app-contract.md §2. Error codes are shown literally — they are the fastest debugging tool on the day.

### Acceptance criteria
- [ ] Pipeline: fromB64url -> decode -> dedupe check -> bearer/holder check -> accept
- [ ] Rejections surface unsupported_version, bad_length, bad_flags, duplicate, not_holder VERBATIM
- [ ] On accept, holder is rewritten to this device and lamport incremented before storing
- [ ] seen set keyed on (note_id, lamport), in-memory only

### ☐ E2-06 — Flutter — receive pipeline + verbatim error codes

**Epic:** E2 — App shell
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-2**
**Framework:** flutter · **Size:** M

Same contract as E2-05.

### Acceptance criteria
- [ ] Pipeline: fromB64url -> decode -> dedupe check -> bearer/holder check -> accept
- [ ] Rejections surface the same five codes verbatim
- [ ] On accept, holder rewritten and lamport incremented before storing
- [ ] seen set keyed on (note_id, lamport), in-memory only

## E3 — Channel 1 — QR

_Static QR transfer, same-app then cross-framework._

### ☐ E3-01 — RN — static QR driver (BEARER)

**Epic:** E3 — Channel 1 — QR
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-3**
**Framework:** rn · **Size:** M

QR is BEARER by necessity — the sender cannot learn who will scan. expo-camera already scans, so only an encoder dep is needed.

### Acceptance criteria
- [ ] Implements the ChannelDriver interface, profile SMALL
- [ ] Send renders the 56-char base64url as QR text mode, EC level M, >=240dp
- [ ] Notes sent over QR set flags bit 0 and holder all-zero
- [ ] Receive decodes via expo-camera barcode scanning
- [ ] Works in airplane mode

### ☐ E3-02 — Flutter — static QR driver (BEARER)

**Epic:** E3 — Channel 1 — QR
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-3**
**Framework:** flutter · **Size:** M

qr_flutter to encode, mobile_scanner to decode.

### Acceptance criteria
- [ ] Implements the ChannelDriver interface, profile SMALL
- [ ] Send renders the 56-char base64url as QR text mode, EC level M, >=240dp
- [ ] Notes sent over QR set flags bit 0 and holder all-zero
- [ ] Receive decodes via mobile_scanner
- [ ] Works in airplane mode

### ☐ E3-03 — Same-app QR transfer verified in airplane mode

**Epic:** E3 — Channel 1 — QR
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-7**
**Framework:** both · **Size:** S

The baseline deliverable. Two RN phones, two Flutter phones.

### Acceptance criteria
- [ ] RN -> RN transfer completes with wifi and cellular off
- [ ] Flutter -> Flutter transfer completes with wifi and cellular off
- [ ] Sender's note is gone, receiver's wallet total increases by the right amount
- [ ] Rescanning the same QR is rejected as duplicate

### ☐ E3-04 — Cross-framework QR transfer, both directions

**Epic:** E3 — Channel 1 — QR
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-8**
**Framework:** both · **Size:** S

The riskiest step in the project and the cheapest to test. Do it the moment E3-03 passes.

### Acceptance criteria
- [ ] RN -> Flutter transfer completes
- [ ] Flutter -> RN transfer completes
- [ ] Both directions tested independently — encode and decode are different code paths
- [ ] Airplane mode throughout

## E4 — Channel 2 — Nearby

_Nearby Connections transfer and the cross-framework toggle._

### ☐ E4-01 — RN — Nearby Connections driver (DIRECTED)

**Epic:** E4 — Channel 2 — Nearby
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-4**
**Framework:** rn · **Size:** L

expo-nearby-connections is ALREADY in the base repo — this is the head start. Time it from a clean scaffold or the number is worthless.

### Acceptance criteria
- [ ] serviceId is the constant echo.currency.v0
- [ ] Endpoint name is rn:<first 4 bytes of device id hex>
- [ ] Strategy P2P_CLUSTER, payload type BYTES
- [ ] Directed transfer: holder set to the discovered peer's device id
- [ ] Works with wifi and cellular off

### ☐ E4-02 — Flutter — Nearby Connections driver (DIRECTED)

**Epic:** E4 — Channel 2 — Nearby
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-4**
**Framework:** flutter · **Size:** L

nearby_connections package. Same underlying Google Nearby API as the RN side, which is what makes this a fair binding comparison.

### Acceptance criteria
- [ ] serviceId is the constant echo.currency.v0
- [ ] Endpoint name is fl:<first 4 bytes of device id hex>
- [ ] Strategy P2P_CLUSTER, payload type BYTES
- [ ] Directed transfer: holder set to the discovered peer's device id
- [ ] Works with wifi and cellular off

### ☐ E4-03 — Cross-framework toggle

**Epic:** E4 — Channel 2 — Nearby
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-8**
**Framework:** both · **Size:** S

THE headline demo beat. One boolean, client-side discovery filtering only.

### Acceptance criteria
- [ ] Visible switch in Wallet, persisted — not buried in settings
- [ ] Off (default): Nearby ignores endpoints whose prefix differs from this build
- [ ] On: every endpoint accepted
- [ ] Affects discovery only — QR and NFC are unaffected
- [ ] No re-advertising and no second serviceId

### ☐ E4-04 — Nearby same-app and cross-framework, both directions

**Epic:** E4 — Channel 2 — Nearby
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-7**
**Framework:** both · **Size:** S

Four interop cells over Nearby.

### Acceptance criteria
- [ ] RN->RN and FL->FL pass with the toggle off
- [ ] RN->FL and FL->RN pass with the toggle on
- [ ] Airplane mode throughout

## E5 — Channel 3 — Relay

_App-layer multi-hop relay over Nearby._

### ☐ E5-01 — Relay algorithm — written once by the floater

**Epic:** E5 — Channel 3 — Relay
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-5**
**Framework:** both · **Size:** S

One algorithm, implemented twice independently. TTL and dedupe bugs are invisible until four phones are in a room.

### Acceptance criteria
- [ ] Pseudocode in spec/wire.md reviewed and agreed by both devs before either implements
- [ ] TTL start of 3 and the dedupe key (note_id, lamport) confirmed identical on both sides

### ☐ E5-02 — RN — multi-hop relay driver

**Epic:** E5 — Channel 3 — Relay
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-5**
**Framework:** rn · **Size:** M

Pure TypeScript over the Nearby transport — no native code. Relay is DIRECTED-only.

### Acceptance criteria
- [ ] Parses and emits the R|<ttl>|<base64url> envelope
- [ ] Forwards to all endpoints except the sender
- [ ] Drops at ttl <= 1 and on a dedupe hit
- [ ] Claims the note when holder == own device id
- [ ] A BEARER note offered to the relay driver is rejected, not forwarded

### ☐ E5-03 — Flutter — multi-hop relay driver

**Epic:** E5 — Channel 3 — Relay
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-5**
**Framework:** flutter · **Size:** M

Same algorithm as E5-02, implemented independently in Dart.

### Acceptance criteria
- [ ] Parses and emits the R|<ttl>|<base64url> envelope
- [ ] Forwards to all endpoints except the sender
- [ ] Drops at ttl <= 1 and on a dedupe hit
- [ ] Claims the note when holder == own device id
- [ ] A BEARER note offered to the relay driver is rejected, not forwarded

### ☐ E5-04 — Four-phone multi-hop test

**Epic:** E5 — Channel 3 — Relay
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-5**
**Framework:** both · **Size:** S

A -> B -> C where A and C are never directly connected.

### Acceptance criteria
- [ ] Note travels two hops to a device out of A's radio range
- [ ] TTL stops propagation — no infinite loop with 4 devices in range
- [ ] A note is never forwarded twice by the same device
- [ ] Airplane mode throughout

## E6 — Channel 4 — NFC

_Tag-based NFC transfer._

### ☐ E6-01 — RN — NFC tag driver (BEARER)

**Epic:** E6 — Channel 4 — NFC
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-6**
**Framework:** rn · **Size:** M

Tag-based, NOT Host Card Emulation. HCE needs a native Android service plus AID registration in both frameworks and Android Beam is gone.

### Acceptance criteria
- [ ] Writes the 56-char base64url as an NDEF text record
- [ ] Notes written to a tag set flags bit 0 and holder all-zero
- [ ] Sender's copy is deleted only on Delivered, per CAP-13
- [ ] Reading a tag claims the note and blanks the tag
- [ ] react-native-nfc-manager, no native module written

### ☐ E6-02 — Flutter — NFC tag driver (BEARER)

**Epic:** E6 — Channel 4 — NFC
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-6**
**Framework:** flutter · **Size:** M

nfc_manager package. Same tag semantics as E6-01.

### Acceptance criteria
- [ ] Writes the 56-char base64url as an NDEF text record
- [ ] Notes written to a tag set flags bit 0 and holder all-zero
- [ ] Reading a tag claims the note and blanks the tag
- [ ] nfc_manager, no native module written

### ☐ E6-03 — NFC tag interop — write in one framework, read in the other

**Epic:** E6 — Channel 4 — NFC
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-8**
**Framework:** both · **Size:** S

Tags carry no framework identity, so this should work for free. Prove it.

### Acceptance criteria
- [ ] Tag written by RN is read and claimed by Flutter
- [ ] Tag written by Flutter is read and claimed by RN
- [ ] A blanked tag read again produces a clean error, not a crash

## E7 — Measurement

_The numbers the project exists to produce._

### ☐ E7-01 — RN — 100k-row scroll screen

**Epic:** E7 — Measurement
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-10**
**Framework:** rn · **Size:** S

Generated in-memory list — never the wallet, never a database.

### Acceptance criteria
- [ ] Renders 100k generated rows
- [ ] Reachable from Wallet via a debug affordance
- [ ] Identical row content and layout to the Flutter build

### ☐ E7-02 — Flutter — 100k-row scroll screen

**Epic:** E7 — Measurement
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-10**
**Framework:** flutter · **Size:** S

Same content and layout as E7-01 or the comparison is meaningless.

### Acceptance criteria
- [ ] Renders 100k generated rows
- [ ] Reachable from Wallet via a debug affordance
- [ ] Identical row content and layout to the RN build

### ☐ E7-03 — Null-app baseline in both frameworks

**Epic:** E7 — Measurement
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-10**
**Framework:** both · **Size:** S

An empty scroll list in each, so framework cost is separable from our code.

### Acceptance criteria
- [ ] Empty-list app built in both frameworks
- [ ] Measured with the same adb commands as the real builds

### ☐ E7-04 — adb telemetry capture, both builds

**Epic:** E7 — Measurement
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-10**
**Framework:** both · **Size:** M

No in-app telemetry screen — everything external. Requires a Path B machine with the Android SDK.

### Acceptance criteria
- [ ] Release builds, cold, after a reboot — no hot-reload numbers
- [ ] Both apps on the SAME phone, runs interleaved
- [ ] Battery % and thermal state logged beside every sample
- [ ] Cold start (am start -W), APK size per ABI, jank/p95 (dumpsys gfxinfo), PSS (dumpsys meminfo)
- [ ] Median of 5 for every timing

### ☐ E7-05 — Fill the scorecard and write the read-out

**Epic:** E7 — Measurement
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-10**
**Framework:** both · **Size:** M

The deliverable is a decision table, not a winner.

### Acceptance criteria
- [ ] Every row of scorecard.md filled or explicitly marked not-measured
- [ ] Per-channel build cost recorded from CLEAN SCAFFOLDS
- [ ] The RN head start (expo-nearby-connections, executorch) printed, not hidden
- [ ] 'Anything that fought you' written for every channel in both frameworks
- [ ] Five read-out rows each answered in one line

## E8 — Agentic (gated)

_Tier A streaming comparison. Blocked until an endpoint exists._

### ⛔ E8-01 — BLOCKED — provision and freeze a streaming endpoint

**Epic:** E8 — Agentic (gated)
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-12**
**Framework:** both · **Size:** S

No OpenAI-compatible endpoint is available yet. Nothing else in E8 can start. The whole epic is sequenced AFTER the app is finished.

### Acceptance criteria
- [ ] An endpoint reachable from the demo network is identified and tested
- [ ] URL and model name frozen in a constant shared by both apps
- [ ] Both apps confirmed to hit the IDENTICAL endpoint and model
- [ ] Fallback decided in case the datacenter GPU is unavailable on the day

> Blocks E8-02..E8-05. If this is still blocked when the channels are done, agentic becomes a slide.

### ⛔ E8-02 — Reference streaming client (floater)

**Epic:** E8 — Agentic (gated)
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-12**
**Framework:** both · **Size:** S

Built once by the floater so each dev integrates in ~30 min instead of an hour.

### Acceptance criteria
- [ ] Documented request shape, streaming parse, and error handling
- [ ] Verified against the frozen endpoint before either dev touches it

### ⛔ E8-03 — RN — agent view (Tier A)

**Epic:** E8 — Agentic (gated)
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-12**
**Framework:** rn · **Size:** M

One prompt box, one streamed response. Shipped and labelled as a BENCHMARK HARNESS, not sold as a feature.

### Acceptance criteria
- [ ] Identical prompt and endpoint to the Flutter build
- [ ] Tokens render as they stream
- [ ] No native code — this tier isolates pure UI streaming

### ⛔ E8-04 — Flutter — agent view (Tier A)

**Epic:** E8 — Agentic (gated)
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-12**
**Framework:** flutter · **Size:** M

Same contract as E8-03.

### Acceptance criteria
- [ ] Identical prompt and endpoint to the RN build
- [ ] Tokens render as they stream
- [ ] No native code

### ⛔ E8-05 — Capture Tier A metrics

**Epic:** E8 — Agentic (gated)
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-12**
**Framework:** both · **Size:** S

Report as separate numbers. Tiers B and C are NOT attempted — say so.

### Acceptance criteria
- [ ] Time to first token, tokens/sec, jank while streaming, glue LOC — both frameworks
- [ ] Write-up states plainly that Tiers B and C were not attempted

## E9 — Demo readiness

_Four phones, rehearsed, claims aligned to what shipped._

### ☐ E9-01 — Source four phones — 2 RN, 2 Flutter

**Epic:** E9 — Demo readiness
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md`
**Framework:** both · **Size:** S

A day-zero logistics task with a named owner, not something discovered at 4pm. The 2+2 split IS the requirement.

### Acceptance criteria
- [ ] Four Android devices confirmed, arm64, NFC-capable
- [ ] Named owner assigned
- [ ] Both APKs installed side by side on at least one device

### ☐ E9-02 — Buy NTAG215 stickers

**Epic:** E9 — Demo readiness
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md` · **CAP-6**
**Framework:** both · **Size:** S

Cheap, and they are the entire NFC demo.

### Acceptance criteria
- [ ] A pack of writable NFC tags is physically present on the day

### ☐ E9-03 — Rehearse hot-reload with radios off

**Epic:** E9 — Demo readiness
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md`
**Framework:** both · **Size:** S

You cannot reload in airplane mode. Teams discover this mid-demo.

### Acceptance criteria
- [ ] A working edit-and-see-it loop demonstrated with wifi off, or
- [ ] A documented decision to demo from release builds only

### ☐ E9-04 — Airplane-mode dress rehearsal

**Epic:** E9 — Demo readiness
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md`
**Framework:** both · **Size:** M

A scheduled block, not leftover time. Hackathon demos fail at the demo, not at the build.

### Acceptance criteria
- [ ] Full 90-second sequence run end to end with radios off
- [ ] QR same-app, toggle, cross-framework, Nearby relay across the room, NFC tag off a table
- [ ] Run twice without a reinstall

### ☐ E9-05 — Align the pitch to what actually shipped

**Epic:** E9 — Demo readiness
**Spec:** `_bmad-output/specs/spec-currency-app-framework-comparison/SPEC.md`
**Framework:** both · **Size:** S

An overclaiming pitch is what judges punish. Several claims are already known-false for v0.

### Acceptance criteria
- [ ] No signature or forger-identification claim — v0 notes are unsigned
- [ ] No fraud-detection claim — CAP-11 was cut
- [ ] Agentic claims match the tiers actually run
- [ ] Cut list stated out loud: HCE, SIG mesh, animated QR, ultrasonic, UWB, satellite, VLC, hardware keys
- [ ] The RN head start is disclosed
