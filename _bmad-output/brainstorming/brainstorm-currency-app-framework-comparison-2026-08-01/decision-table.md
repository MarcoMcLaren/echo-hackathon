# RN vs Flutter — Decision Table

**Project:** currency app built twice (`currency-rn/` and `currency-flutter/`), fully segregated
**Deliverable framing (from the session):** *"the deliverable is not a winner, it is a decision table — if your product needs X, pick Y."* [log:112]
**Status:** empty instrument, ready to score. No results have been recorded yet.

**Operational cut:** see **[hackathon-plan.md](hackathon-plan.md)** in this folder. **That file is the schedule; this file is the measurement instrument.**

> Every capability and metric below traces to the brainstorming memlog in this folder.
> `[log:N]` = line N of `.memlog.md`. Anything the log does not settle is marked **TBD** — do not fill it from memory or vendor docs, fill it from a measurement.

---

## 0. Day-one scope — this is a hackathon

> ### ⚡ A 96-byte note tip fits in a SINGLE STATIC QR CODE.
>
> **Animated QR and fountain coding are only required for the FULL wire profile carrying endorsement history.** So the minimum viable transfer is **render a QR / scan a QR** — no frame streaming, no live decode pipeline, no fountain codes. **This removes the single largest build item from the plan.** [log:353]
>
> **The day-one optical channel is therefore STATIC QR (wire profile SMALL). Animated QR is a stretch upgrade to a working spine, not a foundation.**

Every capability row below carries a **Day-one scope** column: **MUST / SHOULD / COULD / WON'T**, per the adopted timeboxed plan [log:356]. **Rows marked WON'T keep their scoring columns as TBD — they stay in this table as documented scope decisions, not deletions.** Saying the WON'Ts out loud is part of the deliverable.

| Day-one scope | Items |
|---|---|
| **MUST** | Wire spec + frozen vectors (§8) · wallet of **preloaded notes** · **single static QR transfer** in both apps · **same-app transfer RN→RN and FL→FL** · **cross-framework interop, both directions** (§8a) · **telemetry screen** — cold start, frame time, APK size (§4) |
| **SHOULD** | **Double-spend detection + the fraud button** · **agentic Tier A** (remote GPU, no native code either side) |
| **COULD** | **NFC HCE** as a second driver · **flashlight VLC** · **animated-QR upgrade** · **BLE mesh relay** |
| **WON'T** (said out loud) | **Agentic Tier B and Tier C** · ultrasonic · UWB · satellite · MST · SMS · **hardware keystore** (software key with a visible TODO instead) · sensor-based minting · multi-hop relay |

**Why building twice in one day is feasible at all:** segregation is also a **time strategy** — two devs, one per framework, working from one frozen spec, **zero shared build and therefore zero merge conflicts**. The comparison **parallelises perfectly**. [log:354]

**Rehearsal in airplane mode is a SCHEDULED BLOCK, not leftover time. Hackathon demos fail at the demo, not at the build.** [log:357]

---

## 1. How to use this

1. Score each capability row **the day its bridge lands**, not at the end — retrofitted numbers are guesses. [log:111]
2. Every timing comes from a **release build, cold, after a device reboot**. [log:103]
3. Run RN and Flutter **interleaved back-to-back on the same physical device**, logging **battery % and thermal state alongside each sample**. [log:94]
4. Both apps are installed on that one phone simultaneously (segregation forces distinct app ids, which is what makes this possible). [log:144]
5. If a cell cannot be measured honestly, write **TBD** or **BLOCKED** with a reason. Never estimate.

---

## 2. The measurement protocol

These are the rules that make the numbers mean anything. Breaking one invalidates the row it touches.

| # | Rule | Why | Source |
|---|------|-----|--------|
| P1 | **Native code written ONCE per platform** (Kotlin/Swift), **bridged twice**. Only the bridge differs between the two builds. | Isolates the actual variable under test — this is the sharpest methodology finding in the session. | [log:92], [log:138] |
| P2 | **Complete segregation** of the two projects: no shared code, build, or dependency tree. Native sources are duplicated as **byte-identical copies, checksum-verified in CI**. | Satisfies the hard segregation constraint without losing P1. Segregate implementations, share contracts. | [log:141], [log:142], [log:149] |
| P3 | What crosses the boundary is **documents only**: wire-format spec, shared E2E suite, telemetry schema, Figma, threat model. No build system spans the two repos. | Keeps the comparison clean and auditable. | [log:143], [log:148] |
| P4 | **Both apps installed on one phone**, benchmarks run interleaved on identical hardware and thermal state. | Kills thermal-throttling noise. | [log:94], [log:144] |
| P5 | **Null-app baseline in both builds** — an empty scroll list — to calibrate framework floor vs our code. Every perf number is also reported as a delta to its own baseline. | Separates "the framework costs this" from "we wrote it badly". | [log:96] |
| P6 | **One shared E2E suite** (Maestro/Appium) that both builds must pass **identically**. | Stops the two apps drifting in scope. | [log:91] |
| P7 | **Deliberately custom, non-Material non-Cupertino design**, same Figma for both. | Neither framework gets home-field advantage; enables an honest pixel-fidelity score. | [log:95], [log:51] |
| P8 | **Glue-LOC = cloc(repo) − checksum-identical native files.** What remains IS the bridge cost. | Makes the headline metric trivially auditable. | [log:147], [log:50] |
| P9 | **Time-to-first-working-bridge is stopwatched honestly**, for capabilities neither dev has done before. | The long tail is what we are actually evaluating. [log:109] | [log:111] |
| P10 | Both builds emit the **same telemetry schema** to a local file, so the numbers diff from the same phone. | One source of truth for the perf table. | [log:47], [log:48] |
| P11 | Report **stripped and full APK size, per ABI**. | One build may bundle ML models; unqualified size is meaningless. | [log:102] |
| P12 | The honest per-capability score is **glue-LOC × runtime-perf**, not either alone. | Session bedrock for the comparison. | [log:88] |

**Deliberate weighting:** the app is skewed on purpose toward capabilities with **no mature plugin in either ecosystem** — UWB, MST, ultrasonic, satellite, flashlight VLC — because that is where the answer lives. [log:110]

**Cross-check available to us:** because the two apps are segregated and coexist, **the RN app can pay the Flutter app**. Treat a passing cross-framework transfer as the strictest conformance test that both builds really implement the same wire format. [log:145] They need distinct BLE service UUIDs / NFC AIDs so they do not intercept each other. [log:146]

---

## 3. The capability table

> **Wide table — scroll horizontally.** On a narrow viewport this table extends past the right edge; scroll the table container rather than wrapping it.

**The organising axis (round 2).** The Solution Matrix found an empty cell: **no channel scores high on both throughput and proximity-proof strength**. Therefore every real transfer is a **PAIR** — a *pairing* channel that establishes trust, plus a *payment* channel that carries the bytes. **That pairing IS the architecture** [log:208], and splitting the channel list along that axis dissolves most of the build-order argument [log:248]. A second empty cell: **nothing works screen-off and backgrounded except NFC HCE** [log:210].

The table below is therefore split into three groups:

- **3a. PAIRING channels** — scored on **proximity-proof strength**, not throughput [log:209].
- **3b. PAYMENT channels** — scored on throughput and bridge cost.
- **3c. Non-channel capabilities** — everything else, unchanged.

**Legend**
- **Plugin maturity** — fill only from hands-on experience in this build (or the timeboxed spike, §8). Allowed values: `none` / `abandoned` / `partial` / `maintained` / `first-party`. Pre-filled **only** where the session log states something definite; every other cell is `TBD`.
- **Wire profile** — which of the three profiles the channel can carry: **TINY** (≤31B, tip *hash* as a pointer), **SMALL** (≤255B, the full 96-byte tip), **FULL** (unbounded, tip + history). Each channel declares a profile and the app picks the richest one it supports. [log:174], [log:175] Size ceilings named in the log: BLE legacy advert ~31B, BLE extended ~255B, NFC APDU ~255B, QR frame ~2900B [log:160].
- **Build verdict** — the round-2 decision on whether to build it at all. Pre-filled from the Solution Matrix and Kill-the-Crown-Jewel passes.
- **Glue LOC** — cloc of the bridge only, native duplicates subtracted (P8).
- **TTFB** — time to first working bridge, stopwatched (P9), in hours:minutes.
- **Android OK / iOS OK** — `yes` / `partial` / `BLOCKED` / `TBD`.
- **Verdict** — one line of measured conclusion, written only after both sides of the row are done. Distinct from **Build verdict**, which is a scope decision made before any measurement.

### 3a. PAIRING channels — score on proximity-proof strength, not throughput

> Wide table — scroll horizontally.

| Capability | Day-one scope | Wire profile | Build verdict | Plugin maturity RN | Plugin maturity Flutter | Glue LOC RN | Glue LOC Flutter | TTFB RN | TTFB Flutter | Android OK | iOS OK | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| UWB ranging (~10cm) [log:25] | **WON'T** [log:356] | n/a — pairing only | **CONDITIONAL** — highest framework-revealing value, lowest device availability; build **only if a UWB-capable phone is physically in the room** [log:203] | **none mature** [log:110], essentially no cross-platform plugin [log:203] | **none mature** [log:110], essentially no cross-platform plugin [log:203] | TBD | TBD | TBD | TBD | TBD (hardware rare [log:203]) | TBD | — |
| Microphone ultrasonic time-of-arrival ranging (who is really in the room) [log:24] | **WON'T** — ultrasonic is cut [log:356] | n/a — pairing only | **PROMOTED** — load-bearing if NFC is dropped [log:215]; otherwise rides on the ultrasonic build decision | **none mature** [log:110] | **none mature** [log:110] | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Accelerometer bump detection (dual spike <50ms; waveform seeds the session key) [log:26], [log:27] | **WON'T** — by omission from the adopted cut [log:356] | n/a — pairing only | **PAIRING channel, not a payment channel** — score on proximity proof [log:209]; **promoted** to load-bearing without NFC [log:215] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| BLE continuous public-key advertisement (key discovery — "being payable" as a passive ambient state) [log:193] | **COULD** — rides on the BLE relay COULD [log:356] | TINY (legacy ~31B) [log:160] | Build — required for DIRECTED mode key discovery | TBD | TBD | TBD | TBD | TBD | TBD | TBD | **partial** — iOS restricts background BLE [log:100] | — |
| Biometric co-sign as a transfer gate (two thumbs, two phones, large amounts) [log:29], [log:30] | **WON'T** — by omission; keystore is cut to a software key with a TODO [log:356] | n/a — pairing only | TBD — scope decision not settled in round 2 | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |

**Proximity-proof strength** is its own scored axis for this group. Record it as `maximal / strong / room-bounded / weak / none`, with evidence. Pre-filled where the log is definite: NFC HCE = **maximal (physical contact)** [log:199]; UWB = **unmatched precision** [log:203]; ultrasonic = **room-bounded** [log:202]; animated QR = **weak** [log:200]; SMS = **zero** [log:206].

### 3b. PAYMENT channels — score on throughput and bridge cost

> Wide table — scroll horizontally.

| Capability | Day-one scope | Wire profile | Build verdict | Plugin maturity RN | Plugin maturity Flutter | Glue LOC RN | Glue LOC Flutter | TTFB RN | TTFB Flutter | Android OK | iOS OK | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Static QR transfer (render a QR / scan a QR — the 96-byte tip fits in ONE code)** [log:353], [log:174] | **MUST** [log:356] | **SMALL** (≤255B, full 96-byte tip) [log:175] | **THE DAY-ONE OPTICAL CHANNEL.** No frame streaming, no live decode pipeline, no fountain codes — this removes the single largest build item from the plan [log:353]. It needs only a camera and a screen: no pairing, no radios, no permissions theatre [log:234] | TBD — QR encode/decode libraries exist in both ecosystems; **borrow them** [log:238] | TBD — same [log:238] | TBD | TBD | TBD | TBD | TBD | TBD | — |
| NFC host card emulation (tap-to-pay phone→phone) [log:12] | **COULD** — second driver [log:356] | SMALL (APDU ~255B [log:160]) | **HERO #1** — proximity proof **maximal (physical contact)**; the **only** capability that works **screen-off and backgrounded** [log:210]; iOS heavily restricted [log:199]. Build the system **NFC-optional from day one** — NFC is a driver, not a foundation [log:218] | TBD — large plugin gap both sides [log:199] | TBD — large plugin gap both sides [log:199] | TBD | TBD | TBD | TBD | TBD | **BLOCKED** — iOS restricts HCE [log:100]; single most consequential platform gap in the comparison [log:210] | — |
| Animated-QR optical streaming (~10fps fountain-coded frames) [log:18], [log:20] | **COULD** — a **stretch upgrade to a working static-QR spine, not a foundation**; only required for the **FULL** profile carrying endorsement history [log:353], [log:356] | FULL (QR frame ~2900B [log:160]) | **HERO #2** — best real offline throughput; chosen **precisely because camera plugins are mature on BOTH sides while the frame-processing pipeline is where RN and Flutter diverge most** [log:200]. Becomes **hero #1 and the on-stage demo channel** if NFC is dropped [log:214], [log:219] | TBD — camera plugin mature [log:200]; approach: Vision Camera frame-processor plugin, pixels never cross the bridge [log:64] | TBD — camera plugin mature [log:200]; approach: camera + MLKit [log:19] | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Camera QR decode via frame processors [log:19], [log:64] | **COULD** — the frame-processor pipeline is only needed for the animated upgrade; a plain single-shot QR scan is part of the MUST row above [log:353], [log:356] | FULL (receive side of the above) | Build — the divergence surface of HERO #2 [log:200] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| BLE mesh relay (TTL + dedupe gossip of signed notes) [log:43], [log:81] | **COULD** — single-hop only; **multi-hop relay is WON'T** [log:356] | SMALL (extended advert ~255B [log:160]); FULL over a connection — TBD | **HERO #3** — chosen because **background-execution reliability is exactly the long-tail cost the Five Whys identified as the real decision** [log:201], [log:109] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | **partial** — background BLE restricted [log:100], [log:201] | — |
| BLE advertisement payloads (micro-transfer in the advert itself) [log:42] | **COULD** — rides on the BLE relay COULD [log:356] | TINY (legacy ~31B) → SMALL (extended ~255B) [log:160] | Build — carrier for the mesh; TINY profile ships the tip **hash as a pointer** [log:175] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | **partial** — iOS restricts background BLE [log:100] | — |
| Flashlight visible-light comms (strobed payload, 10–50bps) [log:46] | **COULD** [log:356] | TINY [log:175] | **SLEEPER PICK** — cheapest exotic channel per unit of wow (torch toggle + camera luminance sampling), **genuinely no plugin on either side**, so it also scores on the root-cause metric [log:205]. Rung 6 of the scope ladder [log:242] | **none** [log:205], [log:110] | **none** [log:205], [log:110] | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Ultrasonic audio data transfer (chirp broadcast, 100–500bps) [log:22], [log:23] | **WON'T** [log:356] | TINY [log:175] | **HIGH VALUE / HIGH COST** — no mature plugin either side; room-bounded proximity genuinely useful; **audio DSP is a substantial build. Decide by remaining time** [log:202] | **none mature** [log:110], [log:202] | **none mature** [log:110], [log:202] | TBD | TBD | TBD | TBD | TBD | TBD | — |
| NFC tag read/write (bearer-note sticker, one-time key burn) [log:13–15] | **WON'T** — by omission from the adopted cut [log:356] | TBD — tag capacity not costed in the log | TBD — not re-scoped in round 2; rides on the NFC-optional decision [log:218] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD (iOS tag support ≠ HCE — verify) | — |
| Wi-Fi Direct / Nearby | **WON'T** — by omission from the adopted cut [log:356] | FULL (no ceiling named in log) | TBD — not scored in the Solution Matrix | TBD | TBD | TBD | TBD | TBD | TBD | TBD | **BLOCKED** — iOS restricts raw wifi [log:100] | — |
| SMS transport (base64 payload, works on 2G) [log:44] | **WON'T** [log:356] | SMALL — TBD (SMS length limit not costed in the log) | **ANDROID-ONLY ASTERISK** — iOS **forbids programmatic send outright**; keep as a **platform-gap data point**, not a demo. Zero proximity proof [log:206] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | **BLOCKED** — no programmatic send [log:206] | — |
| Satellite messaging (iPhone 14+ / Pixel) [log:45] | **WON'T** [log:356] | n/a — cut | **CUT** — enormous narrative wow, near-zero throughput, **no third-party API access on either platform. It is a slide, not a feature** — say so out loud rather than fake it [log:204] | **none mature** [log:110] | **none mature** [log:110] | n/a | n/a | n/a | n/a | n/a | n/a | Cut before measurement |
| MST (magnetic secure transmission) [log:110] | **WON'T** [log:356] | n/a — cut | **CUT** — hardware effectively dead in current phones [log:207] | **none mature** [log:110] | **none mature** [log:110] | n/a | n/a | n/a | n/a | n/a | n/a | Cut before measurement |

**Transfer modes.** Every payment channel must declare which it supports: **DIRECTED** (encrypted to a recipient key, so a mesh relay cannot read value or identity) or **BEARER** (anyone in earshot claims, first come — the "throw money in the air" demo). Broadcast channels have no single recipient, which is what forces the two modes. [log:191], [log:192]

**One-way is mandatory.** The entire protocol is designed **fire-and-forget** because QR, chirp, SMS and satellite physically cannot ACK — which forces the note to be a complete, self-contained, independently verifiable object. This is the keystone constraint of the whole design. [log:189], [log:190], [log:245]

### 3c. Non-channel capabilities

> Wide table — scroll horizontally.

| Capability | Day-one scope | Build verdict | Plugin maturity RN | Plugin maturity Flutter | Glue LOC RN | Glue LOC Flutter | TTFB RN | TTFB Flutter | Android OK | iOS OK | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Telemetry screen (cold start, frame time, APK size)** [log:47], [log:356] | **MUST** [log:356] | Build early — once it exists every later measurement is free [log:232]; **it IS the deliverable** [log:240] | n/a — no native bridge | n/a — no native bridge | TBD | TBD | TBD | TBD | TBD | TBD | — |
| **Wallet of preloaded notes** [log:235], [log:356] | **MUST** [log:356] | Build — replaces all minting for day one | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | — |
| **Double-spend detection + fraud button** [log:99], [log:231] | **SHOULD** [log:356] | Build the **fraud button before the detection**, so there is always something to show [log:231] | n/a | n/a | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Hardware keystore (StrongBox / Secure Enclave) [log:28], [log:34] | **WON'T** — **software key with a visible TODO instead**, said out loud in the pitch [log:356], [log:237] | Build — but the spine **fakes** it with a software key and a visible TODO, stated out loud [log:237] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Biometric gating (wallet unlock as a transfer gate) [log:29] | **WON'T** — by omission [log:356] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Device attestation (Play Integrity / App Attest) [log:57] | **WON'T** — by omission [log:356] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| FLAG_SECURE screenshot/record blocking on the vault screen [log:56] | **WON'T** — by omission [log:356] | TBD | TBD — log flags this as differing *sharply* between frameworks; verify | TBD — same | TBD | TBD | TBD | TBD | TBD | TBD (no FLAG_SECURE equivalent on iOS — verify) | — |
| Background execution surviving Doze [log:109] | **WON'T** — by omission; would ride on the COULD BLE relay [log:356] | Build — this is the long-tail cost the Five Whys named as the real decision, and the reason HERO #3 exists [log:109], [log:201] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Screen pinning / kiosk mode (vendor receive-only; Guided Access on iOS) [log:60] | **WON'T** — by omission [log:356] | TBD — the dead-battery vendor scenario is **cut honestly** if NFC goes, since there is then no low-power path [log:216] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Watch companion app (Wear OS; Shamir share holder; small-spend authorizer) [log:35], [log:36] | **WON'T** — by omission [log:356] | TBD | TBD | TBD — Flutter dev claims one widget tree drives phone + watch face [log:66]; verify | TBD | TBD | TBD | TBD | TBD | TBD | — |
| AR coin visualization (pile of coins on the table) [log:72] | **WON'T** — by omission [log:356] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Share-sheet signed CSV export (audit trail) [log:59] | **WON'T** — by omission [log:356] | Build — the **export format must be byte-identical across both apps** (see §8, second interop test) [log:197] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Haptic amount encoding (transfer completes with zero visual feedback) [log:53] | **WON'T** — by omission [log:356] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Screen-reader accessibility (announce counterparty; bump-to-pay as the most accessible method) [log:53], [log:54] | **WON'T** — by omission [log:356] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Pedometer step minting [log:37] | **WON'T** — sensor-based minting cut [log:356] | **FAKED in the spine** — every wallet starts with 100 preloaded notes; minting becomes a slide [log:235] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Barometer altitude (minting rate scales with climb) [log:38] | **WON'T** — sensor-based minting cut [log:356] | **FAKED in the spine** [log:235] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| GPS geofenced faucets [log:39] | **WON'T** — sensor-based minting cut [log:356] | **FAKED in the spine** [log:235] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Ambient light + mic noise entropy pool [log:40] | **WON'T** — sensor-based minting cut [log:356] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Wearable heart-rate liveness gate [log:41] | **WON'T** — by omission [log:356] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |

**Also required per capability (tick when done, from [log:93]):** every method ships a **single-phone loopback demo mode**, so a dead or NFC-less second phone cannot kill the demo. **Airplane mode is the acceptance criterion for every rung, not a final test** — never start rung N+1 until rung N works on real hardware with the radios off [log:243].

| Capability | Scope-ladder rung [log:242] | Day-one scope | Loopback demo RN | Loopback demo Flutter | Passes shared E2E (P6) | Passes frozen wire vectors (§8) |
|---|---|---|---|---|---|---|
| **Static QR** — one-phone loopback | 1 | **MUST** | ☐ | ☐ | ☐ | ☐ |
| **Static QR** — RN→RN / Flutter→Flutter | 2 | **MUST** — now a hard requirement [log:252], [log:257] | ☐ | ☐ | ☐ | ☐ |
| **Static QR** — **RN→Flutter and Flutter→RN cross-framework** (riskiest rung; de-risk day one with a bytes-only test, no UI [log:244]) | 3 | **MUST** — both directions [log:261], [log:356] | ☐ | ☐ | ☐ | ☐ |
| NFC as a second driver | 4 | **COULD** [log:356] | ☐ | ☐ | ☐ | ☐ |
| BLE mesh relay (single hop) | 5 | **COULD** [log:356] | ☐ | ☐ | ☐ | ☐ |
| Flashlight VLC (cheapest wow) | 6 | **COULD** [log:356] | ☐ | ☐ | ☐ | ☐ |
| Fraud / double-spend demo (build the **fraud button before the detection** [log:231]) | 7 | **SHOULD** [log:356] | ☐ | ☐ | ☐ | ☐ |
| Animated-QR upgrade / exotic #2 — only if time remains | 8 | **COULD** [log:356] | ☐ | ☐ | ☐ | ☐ |

### 3d. Declarative channel descriptor

Each channel is described **declaratively** — wire profile, throughput, proximity strength, power cost, availability — so that channel selection is a *lookup*, not hard-coded branching. The descriptor is consumed by **both an agent and a plain policy function**; **build it either way, it pays for itself with no AI involved** [log:322], [log:323]. It is also what finally unifies the pairing/payment split from round 2 into one interface [log:347].

This table is the descriptor's contents, filled in as each channel lands. Same values feed §10's agentic routing oracle and the non-AI fallback policy.

> Wide table — scroll horizontally.

| Channel | Day-one scope | Wire profile | Throughput (measured) | Proximity strength | Power cost | Availability (runtime check) | Modes (DIRECTED / BEARER) | Descriptor implemented RN | Descriptor implemented Flutter |
|---|---|---|---|---|---|---|---|---|---|
| **Static QR** | **MUST** | **SMALL** — one code carries the 96-byte tip [log:353] | TBD — one note per scan | **weak** (line of sight, same room) | TBD | TBD | TBD | ☐ | ☐ |
| NFC HCE | **COULD** | SMALL | TBD | **maximal — physical contact** [log:199] | TBD — works at low power [log:199] | TBD | TBD | ☐ | ☐ |
| Animated QR | **COULD** | FULL | TBD — best real offline throughput [log:200] | **weak** [log:200] | TBD | TBD | TBD | ☐ | ☐ |
| BLE mesh relay | **COULD** | SMALL / FULL — TBD | TBD — low [log:201] | TBD — moderate range [log:201] | TBD | TBD | TBD | ☐ | ☐ |
| BLE advert payload | **COULD** | TINY → SMALL | TBD | TBD | TBD | TBD | BEARER (no single recipient) [log:192] | ☐ | ☐ |
| Flashlight VLC | **COULD** | TINY | TBD — 10–50bps [log:205] | TBD — line of sight | TBD | TBD | TBD | ☐ | ☐ |
| Ultrasonic chirp | **WON'T** | TINY | TBD — 100–500bps [log:202] | **room-bounded** [log:202] | TBD | TBD | BEARER — pay the whole room [log:23], [log:192] | ☐ | ☐ |
| SMS | **WON'T** | SMALL — TBD | TBD | **zero** [log:206] | TBD | Android only [log:206] | DIRECTED | ☐ | ☐ |
| UWB (pairing) | **WON'T** | n/a | n/a | **unmatched precision** [log:203] | TBD | Hardware rare [log:203] | n/a | ☐ | ☐ |
| Bump (pairing) | **WON'T** | n/a | n/a | TBD | TBD | TBD | n/a | ☐ | ☐ |
| Ultrasonic ToA (pairing) | **WON'T** | n/a | n/a | **room-bounded** [log:202] | TBD | TBD | n/a | ☐ | ☐ |

---

## 4. Runtime performance

**Day-one scope:** the **MUST** subset is what the minimal telemetry screen reports — **cold start, frame time, APK size** [log:356]. The remaining rows (100k-row jank, shimmer under load, memory, null-app baselines) are **COULD/post-hackathon**; leave them TBD rather than rushing a dishonest number.

All from release builds, cold, after reboot, interleaved on one device (P4, P4/P5, [log:94], [log:103]). Log battery % and thermal state per sample. Numbers come from the shared telemetry schema written to a local file by both builds [log:47], [log:48].

| Metric | RN | Flutter | Baseline delta | Notes |
|---|---|---|---|---|
| Cold start time (ms, release, post-reboot) | TBD | TBD | TBD | Median of N≥10; record battery/thermal per run |
| Null-app baseline — cold start (ms) | TBD | TBD | — | Empty scroll list, both builds [log:96] |
| 100k-transaction ledger scroll jank (dropped frames / p99 frame time) | TBD | TBD | TBD | **FlashList vs ListView.builder** [log:49] |
| Null-app baseline — scroll jank (empty list) | TBD | TBD | — | Calibration floor [log:96] |
| Escrow shimmer animation under load (fps, jank) | TBD | TBD | TBD | **Reanimated vs AnimationController** [log:17]; Flutter dev predicts Impeller wins [log:65] — record the prediction, then the result |
| Null-app baseline — idle/animation floor | TBD | TBD | — | [log:96] |
| Memory footprint (MB, steady state + peak) | TBD | TBD | TBD | Same screens, same data set [log:47] |
| Null-app baseline — memory (MB) | TBD | TBD | — | [log:96] |
| Stripped APK size per ABI (MB) | TBD | TBD | TBD | Per ABI, stripped [log:102], [log:47] |
| Full APK size per ABI (MB) | TBD | TBD | TBD | Note which build bundles ML models [log:102] |
| Null-app baseline — APK size per ABI | TBD | TBD | — | [log:96], [log:102] |

**Notes-as-objects caveat:** the wallet renders a set of splittable note objects rather than a balance number [log:82], [log:83] — the session flagged this as *precisely* the workload that separates Impeller from Fabric [log:139]. Keep the note-grid screen in the animation benchmark, not just the shimmer.

---

## 5. Developer experience

| Dimension | RN | Flutter | How it is judged | Source |
|---|---|---|---|---|
| Hot reload quality (state preservation, native-change reload cost, failure rate) | TBD | TBD | Log every full-rebuild-required event during the build week; hot reload must never be the source of a timing number | [log:103] |
| Type safety at the bridge | TBD — Nitro/Turbo module with **codegen'd TS types** | TBD — **Pigeon**-generated platform channels + **FFI** on the hot path | Count type-related bridge defects; note whether a wire-format change is caught at compile time on both sides | [log:63], [log:65] |
| Testability — deterministic **fake-radio mode** for CI | TBD | TBD | Can CI exercise transfers with **no physical second phone**? What % of the shared E2E suite runs headless? | [log:71], [log:91] |
| Build times (clean / incremental / native-change, release + debug) | TBD | TBD | Same machine, same day, cache state recorded | (harness intent [log:47]) |
| Pixel fidelity against the same Figma | TBD | TBD | Screenshot pixel-diff score against the Figma, on the deliberately custom non-Material non-Cupertino design | [log:51], [log:95] |

---

## 6. The read-out — "if your product needs X, pick Y"

Leave blank until the tables above are filled. One line per row, and it must cite the rows that settle it.

| If your product needs… | Pick | Evidence that settles it |
|---|---|---|
| Heavy exotic native integration (capabilities nobody has wrapped yet) | TBD | Compare **TTFB** and **glue-LOC** across the `none mature` rows only — UWB, MST, ultrasonic, satellite, flashlight VLC. This is the long-tail question the whole project exists to answer. [log:109], [log:110] |
| Heavy custom animation | TBD | Escrow shimmer + note-grid fps and jank, minus each build's own animation baseline. Reanimated vs AnimationController/Impeller. [log:17], [log:65], [log:139] |
| Large-list rendering | TBD | 100k-transaction ledger scroll jank, minus the empty-list baseline. FlashList vs ListView.builder. [log:49], [log:96] |
| Strict background reliability | TBD | Does a queued transfer survive **Doze**, and does background BLE relay keep running? Note how much of any gap is iOS policy rather than framework. [log:109], [log:100] |
| Fastest time to a working bridge for an unwrapped capability | TBD | Stopwatched TTFB, restricted to capabilities **neither dev had done before**, honestly reported. [log:111] |
| Heavy on-device AI / agentic integration | TBD | **Tier C binding cost** (§10 — same GGUF, same llama.cpp, Dart FFI vs Nitro module), plus which structural advantage dominates *in practice*: the **TypeScript-first agent/MCP SDK ecosystem** (RN) or the **first-class FFI + isolate ergonomics** (Flutter). They point in opposite directions, which is why this may be the most decisive dimension. [log:342], [log:348] **Day-one caveat: only Tier A is in scope, so this row cannot be answered from the hackathon build alone — Tier C is post-hackathon work.** [log:355], [log:356] |
| Broadest team hireability | TBD | **Not measurable from this build** — no row above produces evidence for it. Either answer from hiring data outside this project or state plainly that the comparison does not address it. |

**One-verdict discipline:** the hackathon judge wants *one readable verdict, not forty metrics* [log:73]. This section is that verdict. The tables above are its evidence, not its substitute.
Open question worth answering on the way: *what is the ONE screen we could build that would settle the argument on its own?* [log:131]

---

## 7. Bias controls

Work this checklist before publishing any verdict. Each item is a question the session raised and did not answer.

| ☐ | Control | The question, as asked | Source |
|---|---|---|---|
| ☐ | **⚠ THE LOADED DIE — single largest threat to this comparison's credibility** | The base repo (**echo-hackathon: Expo 57 / RN 0.86.2**) **already ships `react-native-executorch` 0.9.2 with `useLLM` / `useOCR` / `useObjectDetection` wired, AND a working mesh transport via `expo-nearby-connections`** (plus `react-native-keychain`, `expo-camera`, `expo-haptics`, `expo-speech`, `react-native-nitro-modules`). RN therefore has a **substantial head start**, and **any time-to-first-working-bridge or time-to-first-working-agent measurement taken from this repo is INVALID.** **Mitigation:** measure TTFB from **clean scaffolds in BOTH frameworks**, and **print the head start in the write-up rather than hiding it**. The head start feels like cheating and will undermine the result more than any other single factor. | [log:254], [log:255], [log:294], [log:300], [log:303], [log:344] |
| ☐ | **Declared favourite** | Which framework are we *secretly hoping* wins, and how do we control for that? Write the prediction down **before** measuring, then check it against results. | [log:125] |
| ☐ | **Who writes the builds** | Same person for both, or two specialists — which makes it more honest? Record the choice and its bias direction (one person = uneven skill; two specialists = uneven standards). | [log:126] |
| ☐ | **Platform vs framework** | How much of the measured difference is Android-vs-iOS rather than RN-vs-Flutter? Any row where iOS is BLOCKED is a **platform** finding — do not score it against a framework. | [log:127], [log:100] |
| ☐ | **Property or timing** | If a capability has a great plugin in one ecosystem and none in the other, is that a framework property or an accident of timing? Note plugin age and maintenance status when the answer matters. | [log:128] |
| ☐ | **Third build?** | Would a pure-native Kotlin build make this meaningful, or just triple the work? Decide explicitly; if skipped, say what that costs the conclusion. | [log:130] |
| ☐ | **Abort criteria** | What would make us abandon this comparison as unanswerable? Define it **now**, before results exist, so it cannot be rationalised away later. | [log:129] |
| ☐ | **Home-field advantage** | Confirm the design is genuinely non-Material and non-Cupertino, and that both builds worked from the identical Figma. | [log:95], [log:51] |
| ☐ | **Scope drift** | Confirm both builds pass the same shared E2E suite identically; a row where one build does less work is not a comparison. | [log:91] |
| ☐ | **Segregation integrity** | Confirm CI checksum-verified that the native Kotlin/Swift copies are byte-identical across the two repos. If they drifted, P1 is broken and the glue-LOC numbers are void. | [log:142], [log:149] |
| ☐ | **Equal-outcome story** | Decide in advance what we say if both frameworks turn out to be equally good — that is a legitimate result, not a failure. | [log:133] |
| ☐ | **Demo appeal ≠ framework difficulty** | The most counterintuitive round-2 finding: **killing NFC makes the iOS story BETTER and the stage demo MORE visible**, because **NFC is invisible to an audience** — nobody watching can see a tap work. Optical is the *demo* channel; NFC is the *product* channel. Guard against scoring a capability on demo appeal when the metric is framework difficulty. **They are different axes and this project conflates them easily.** Before every scope call, state which axis you are scoring on. | [log:213], [log:217], [log:247] |
| ☐ | **Cut vs measured** | A capability marked **CUT** (satellite, MST) contributes **no evidence** to any verdict. Never let a cut row imply a framework weakness — it was never built in either. | [log:204], [log:207] |

---

## 8. Conformance — proving same spec, not same bug

Two segregated builds can agree with each other and both be wrong. The question the session asked directly — *"how do we prove both builds implement the same SPEC rather than the same BUG?"* [log:169] — is answered by three artifacts that live in `spec/` and are depended on by **neither** app [log:148].

| Artifact | What it is | Rule | Source |
|---|---|---|---|
| `spec/wire.md` | The byte-by-byte wire format **in prose**. Hand-rolled deterministic length-prefixed layout — deliberately **not** a schema library, because canonical-form mismatches between Dart and JS libraries are the single most likely cause of a failed cross-framework demo. | Prose is normative. A note is a fixed **96-byte TIP** (note id, value, holder pubkey, tip signature) plus an optional history blob. | [log:173], [log:174] |
| `spec/vectors.json` | **Frozen test vectors** — input bytes → expected parse/signature result. **Hand-authored from the prose spec, never generated by either implementation.** | **Both projects' unit tests run the vectors.** A vector may only change by editing the prose spec first. | [log:176] |
| `spec/` **Python reference implementation** | A tiny third-language implementation, depended on by neither app, purely to generate and verify vectors. | It is the **arbiter** when RN and Flutter disagree — it settles arguments in seconds instead of hours, and it is the only structure that keeps "segregate implementations, share contracts" honest rather than aspirational. | [log:177], [log:250] |

### 8a. The four-cell transfer matrix (round-3 hard requirement)

**Same-app transfer is now REQUIRED; cross-framework is the bonus on top.** [log:252] Scope-ladder rung 2 is promoted from milestone to hard requirement: **RN→RN and Flutter→Flutter must both work** [log:257]. This also de-risks the demo — if cross-framework breaks on stage, same-app transfer still works and the story survives, so **build it first for exactly that reason** [log:262].

**The matrix is FOUR cells, not three**, because **encode and decode are different code paths** — both directions must be proven independently or you have only proven half the interop [log:261].

> Wide table — scroll horizontally.

| # | Cell | Required / Bonus | Airplane-mode pass | Passes frozen vectors | Notes |
|---|---|---|---|---|---|
| 1 | **RN → RN** | **REQUIRED** [log:252], [log:257] | ☐ | ☐ | TBD |
| 2 | **Flutter → Flutter** | **REQUIRED** [log:252], [log:257] | ☐ | ☐ | TBD |
| 3 | **RN → Flutter** | Bonus / stretch | ☐ | ☐ | Distinct code path: RN encode, Flutter decode [log:261] |
| 4 | **Flutter → RN** | Bonus / stretch | ☐ | ☐ | Distinct code path: Flutter encode, RN decode [log:261] |

- **Four phones means 2 RN + 2 Flutter — not four identical handsets. The split IS the requirement.** [log:258]
- **The wire format is unchanged.** Notes remain **framework-blind by design** [log:178]. **Only DISCOVERY changes:** the transport advertises a **framework tag**, and the app **chooses whether to filter on it** [log:259].
- That filter is the best demo beat in the project: same-app transfer first, then **flip a switch** to accept any framework, and the RN phone pays the Flutter phone. One toggle turns a normal feature into the headline. [log:260], [log:349]

### 8b. Conformance gates

| ☐ | Conformance gate | Source |
|---|---|---|
| ☐ | RN unit tests pass all frozen vectors | [log:176] |
| ☐ | Flutter unit tests pass all frozen vectors | [log:176] |
| ☐ | Python reference agrees with both, byte for byte | [log:177] |
| ☐ | All **four** transfer cells pass (§8a) — same-app first, then both cross directions | [log:261] |
| ☐ | **Bytes-only cross-framework interop test** run on day one with hardcoded notes and **no UI at all**, before either app is built — this is the riskiest rung and it is cheap to de-risk early | [log:244] |
| ☐ | **Wallet EXPORT format is byte-identical across both apps**, so a wallet migrates **RN → Flutter** — a second, quieter interop test. The two apps must NOT share a DB schema (segregation), but the export must match exactly. | [log:197] |
| ☐ | Spec version byte at the head of every note; each app refuses unknown majors; version-skew demo (old app meets new app, degrades gracefully) | [log:182] |
| ☐ | Notes carry **no app identity** — the framework tag lives in the BLE service UUID and NFC AID only, so notes are framework-blind by design, which is precisely what makes cross-framework payment work | [log:178], [log:146] |

## 9. Measurement sequencing

Two ordering rules decide whether this document ends up filled in or empty.

1. **Build the telemetry screen EARLY, in both apps.** Once it exists **every later measurement is free**. Built late, every measurement is manual and **most never get taken**. [log:232] It is not a nice-to-have — **it IS the deliverable** [log:240]. It sits at step 6 of the day-one order of work, before the scope ladder starts [log:251].
2. **Timebox the plugin-availability spike to ONE HOUR per ecosystem, per capability**, and record the result **straight into this table** (the maturity columns in §3). *"Does a usable plugin exist"* changes the plan more than any other single fact — and an untimeboxed spike quietly eats the build day. [log:228]
3. **Timebox the AGENTIC spike separately from the channel spikes** — it has a different failure mode (model download and memory, not permissions). [log:316] Freeze and checksum the model before any Tier B or Tier C number is recorded (§10.6). [log:317], [log:350]

Day-one order of work, for reference [log:251], [log:227]:

| # | Step | Note |
|---|---|---|
| 1 | Fork decisions written down | Decision Tree Mapping outputs [log:226] |
| 2 | `spec/wire.md` prose written; both devs have read it | The **true first move** — not a scaffold, not a plugin spike, not a UI [log:227], [log:224] |
| 3 | `spec/vectors.json` + Python reference implementation | [log:223] |
| 4 | Bytes-only RN↔Flutter interop test, no UI | [log:244] |
| 5 | **Timeboxed plugin-availability spike → straight into §3** | 1h per ecosystem per capability [log:228] |
| 6 | **Telemetry screen in both apps** | Everything after this is measured for free [log:232] |
| 7 | Then the scope ladder (§3c) | [log:242] |
| — | Four phones sourced by a **named owner** on day one | Logistics task, not a 4pm discovery [log:229] |
| — | Dev-client reload workflow with radios off, **rehearsed before the demo** | Airplane-mode demo means no hot reload over wifi [log:230] |

---

## 10. Agentic integration — the third comparison dimension

Round 3 added **agentic integration** alongside the device-capability and rendering dimensions [log:253]. It gets **its own section and its own rubric — not a row bolted onto the capability table** [log:315], because it fails differently (model download and memory, not permissions) and must be timeboxed separately from the channel spikes [log:316].

### 10.0 What is actually being measured

**Measure INTEGRATION, not intelligence.** With the same model on both sides, output quality is constant by construction, so it is not a variable. [log:331]

**Headline metric is TOOL-CALL LATENCY, not streaming throughput.** Job-to-be-Done overturned the obvious agentic UI: the agent is not a chat box, it is a **trust oracle** and a **background compressor**, so the primary surface is a single "what should I do?" affordance plus background actions. [log:290], [log:291], [log:345] Keep a chat surface anyway — **shipped and explicitly labelled as a benchmark harness, not sold as a feature** [log:292].

**Safety boundary = testability boundary.** Agents **PROPOSE**; deterministic code **EXECUTES** behind a biometric gate; the model **never touches unverified bytes** — it operates strictly on already-parsed, already-verified objects. That makes the agent safe *and* makes the executing half deterministic enough to unit-test. [log:329], [log:330], [log:346]

---

### 10.1 ⚠ CONFOUND WARNING — read before recording a single number

> **THE BIGGEST CONFOUND IN THIS DIMENSION:** running **ExecuTorch on the RN side and llama.cpp on the Flutter side compares RUNTIMES, not frameworks** — and it would **silently invalidate the entire agentic dimension**. [log:306], [log:342]
>
> **Tier C exists specifically to neutralise it:** the **same GGUF model** via the **same llama.cpp** on both sides — **Dart FFI** on one side, a **Nitro module** on the other. **Runtime constant, binding variable.** This is the agentic-dimension equivalent of the project's founding methodology, *write native once, bridge twice*. [log:311], [log:342]
>
> A Tier B number is **not** a framework verdict. A Tier C number is. Never quote one as the other.

**The three tiers are reported as THREE NUMBERS and NEVER AVERAGED** — they answer three genuinely different questions. [log:314], [log:343]

---

### 10.1b ⚠ SCOPE REALITY — only Tier A fits a hackathon day

> **Tier C** (same llama.cpp bridged twice, Dart FFI vs Nitro module) is **roughly a week of work, not a hackathon task**. **Tier B** is **roughly a day per side**. **Only TIER A fits.** [log:355]
>
> **Tier A still yields a genuinely comparable number** — it isolates **pure UI streaming with zero native code on either side** — and shipping it is the honest thing to do. [log:355], [log:299], [log:313]
>
> **Tiers B and C stay fully specified below as the post-hackathon continuation, clearly marked WON'T for day one.** [log:356] Do not quote a Tier A number as if it settled the binding question — it does not; only Tier C does (§10.1).

| Tier | What it isolates | Day-one scope | Effort estimate | Source |
|---|---|---|---|---|
| **A** — remote GPU sidequest | Pure UI streaming; **zero native code either side** | **SHOULD** [log:356] | Fits the day | [log:299], [log:313], [log:355] |
| **B** — each framework's blessed runtime | Ecosystem convenience (**not** a framework verdict) | **WON'T** — post-hackathon [log:356] | ~**a day per side** [log:355] | [log:312], [log:355] |
| **C** — same GGUF via same llama.cpp | **Pure binding cost** — the actual framework verdict | **WON'T** — post-hackathon [log:356] | ~**a week** [log:355] | [log:311], [log:342], [log:355] |

Metrics are identical across all three tiers so the tables can be read side by side:

| Metric | Definition / how measured |
|---|---|
| Tokens/sec | Sustained generation rate, release build, cold, post-reboot (P4/P5 rules apply) |
| Time to first token (ms) | From user intent to first rendered token |
| Tool-call latency (µs) | **JS function invoked from native** vs **Dart function invoked from native** — measured in **microseconds** [log:310] |
| UI jank during inference | Measured **DURING a 60fps scroll** — *"does inference jank the UI"* IS the question; never benchmark with the screen off [log:333] |
| Thermal delta | Device thermal state change across the run, logged per sample |
| Memory peak (MB) | Peak RSS during inference |
| Binding LOC | Glue only, per P8 — the FFI / Nitro layer, not the model or runtime |
| App size **with** model (MB) | Per ABI |
| App size **without** model (MB) | Per ABI — **model files distort APK and download comparisons, so both must be reported** [log:305] |

---

### 10.2 Tier A — remote GPU sidequest (the CONTROL) — **Day-one scope: SHOULD** [log:356]

**No native code in either framework**, so the two sit on **perfectly equal footing** — identical HTTP streaming, isolating **pure UI streaming performance** from everything else. [log:299], [log:313], [log:314]

> Wide table — scroll horizontally.

| Metric | RN | Flutter | Baseline delta | Notes |
|---|---|---|---|---|
| Tokens/sec (as rendered) | TBD | TBD | TBD | Network-bound; the variable under test is rendering, not inference |
| Time to first token (ms) | TBD | TBD | TBD | TBD |
| Tool-call latency (µs) | TBD | TBD | TBD | TBD |
| UI jank during inference (60fps scroll) | TBD | TBD | TBD | Streaming tokens into a scrolling list is a cheap, endlessly repeatable rendering benchmark [log:309] |
| Thermal delta | TBD | TBD | TBD | TBD |
| Memory peak (MB) | TBD | TBD | TBD | TBD |
| Binding LOC | **0 by construction** [log:299] | **0 by construction** [log:299] | — | If either is non-zero, Tier A is contaminated |
| App size with / without model | n/a — no local model | n/a — no local model | — | TBD |

**Caveat carried forward:** this is the ONLINE path and it conflicts with the E2E-encryption goal. Consent must be explicit and scoped to the single thread the user is already looking at. [log:328]

---

### 10.3 Tier B — each framework's blessed runtime (ECOSYSTEM CONVENIENCE) — **Day-one scope: WON'T** (~a day per side; post-hackathon) [log:355], [log:356]

**RN: ExecuTorch. Flutter: MediaPipe GenAI / `flutter_gemma`.** [log:295], [log:312] This tier measures **ecosystem convenience, not binding cost** — different runtimes on each side is *the point here*, and precisely why it cannot be read as a framework verdict (see §10.1).

> Wide table — scroll horizontally.

| Metric | RN (ExecuTorch) | Flutter (MediaPipe / flutter_gemma) | Notes |
|---|---|---|---|
| Tokens/sec | TBD | TBD | Different runtimes — not comparable as a framework result |
| Time to first token (ms) | TBD | TBD | TBD |
| Tool-call latency (µs) | TBD | TBD | TBD |
| UI jank during inference (60fps scroll) | TBD | TBD | TBD |
| Thermal delta | TBD | TBD | TBD |
| Memory peak (MB) | TBD | TBD | TBD |
| Binding LOC | TBD | TBD | Flutter has **no one blessed runtime** — its options are FFI-based [log:295]; record which was chosen and why |
| App size with model | TBD | TBD | Per ABI [log:305] |
| App size without model | TBD | TBD | Per ABI [log:305] |

**Bias note:** TTFB for this tier is **invalid if measured from the base repo** — RN already ships `react-native-executorch` 0.9.2 with `useLLM`/`useOCR`/`useObjectDetection` wired. Measure from a clean scaffold; see the loaded-die entry in §7. [log:254], [log:255], [log:344]

---

### 10.4 Tier C — same GGUF, same llama.cpp, both sides (PURE BINDING COST) — **Day-one scope: WON'T** (~a week; post-hackathon) [log:355], [log:356]

**Runtime constant, binding variable: Dart FFI vs Nitro module.** [log:311], [log:342] **This is the tier that produces the framework verdict.**

> Wide table — scroll horizontally.

| Metric | RN (llama.cpp via Nitro module) | Flutter (llama.cpp via Dart FFI) | Notes |
|---|---|---|---|
| Tokens/sec | TBD | TBD | Same model file, checksum-verified (§10.6) |
| Time to first token (ms) | TBD | TBD | TBD |
| Tool-call latency (µs) | TBD | TBD | **JS-function-from-native vs Dart-function-from-native** [log:310] |
| UI jank during inference (60fps scroll) | TBD | TBD | RN needs worklets/threads to keep inference off the UI thread; Flutter has isolates [log:297] |
| Thermal delta | TBD | TBD | TBD |
| Memory peak (MB) | TBD | TBD | TBD |
| Binding LOC | TBD | TBD | **The headline number of this tier** — glue only, per P8 |
| App size with model | TBD | TBD | Per ABI |
| App size without model | TBD | TBD | Per ABI |

---

### 10.5 Structural facts — context, NOT measurements

Record these as **framing**. They are properties of the languages and ecosystems, not results of this build. Do not score them; use them to interpret the numbers.

| Structural fact | Favours | Source |
|---|---|---|
| **Dart FFI is a first-class language feature.** RN's JSI/Nitro path requires **C++ glue plus codegen**. This is a structural difference, not an ecosystem accident. | Flutter | [log:296] |
| **Dart isolates are a first-class concurrency primitive.** RN needs **worklets, threads or native threading** to keep inference off the UI thread. | Flutter | [log:297] |
| **Agent SDKs and the MCP SDK are TypeScript-first** — a genuine RN ecosystem advantage rather than a preference. | RN | [log:298] |
| The remote-GPU sidequest needs **no native code in either framework**, so Tier A sits on equal footing. | Neither | [log:299] |

> **The two structural advantages point in OPPOSITE directions** — Flutter owns the binding, RN owns the agent-SDK ecosystem. That opposition is exactly what makes this dimension worth measuring, and why it may turn out to be **the most decisive dimension in the whole comparison**. [log:308], [log:348]
>
> Soft factor to declare, not score: engineers will simply **enjoy Dart FFI more than JSI**. Enjoyment is not a metric, but it drives velocity, and **velocity will show up in the numbers wearing a disguise**. [log:301]

---

### 10.6 Constraints and honest null results

| Constraint | Consequence | Mitigation / rule | Source |
|---|---|---|---|
| **ExecuTorch is arm64-only with no emulator support** | **CI cannot exercise the agent path at all** — a real, reportable constraint | **Simulate a peer swarm against the deterministic fake-radio mode** and let the agent loop run over simulated peers. This is what makes the agent path CI-testable despite arm64-only hardware. | [log:294], [log:304], [log:325], [log:350], [log:71] |
| **Background agent loops will likely be killed by Doze on both platforms** | This sub-test may produce a **null result** | **Report the null honestly rather than chasing it all day.** Plan for the null before starting. Result: **TBD (null expected)**. | [log:307] |
| **Model choice distorts everything** | Numbers from different model files are not comparable | **ONE small quantised model, decided up front, FROZEN and CHECKSUMMED, used identically everywhere. Refuse to report any number produced by a different file.** Record the checksum here: `TBD`. | [log:317], [log:332] |
| Model must be downloaded over wifi before an offline demo | Fragile on demo day; everyone will be quietly nervous about it | Pre-download and verify the checksum before going to airplane mode; rehearse it | [log:302] |
| The bar is a **small fast model doing narrow things**, not a big model doing everything | Settles the model-size decision | Keyboard-autocomplete standard: offline, sub-100ms, tiny | [log:339] |

**Frozen model record**

| Field | Value |
|---|---|
| Model name / quantisation | TBD |
| File size (MB) | TBD |
| SHA-256 checksum | TBD |
| Frozen on (date) | TBD |
| Used identically in Tier B? | Tier B uses each framework's blessed runtime — record whether the *same weights* were achievable; if not, say so, because it further limits Tier B's comparability |
| Used identically in Tier C? | ☐ required — Tier C is void otherwise |

---

### 10.7 Agent workloads under test

The agent is aimed at the **mesh, not the UI** — *"use the agent to make the MESH smarter rather than the UI chattier"*, because every other framing produces a chatbot and this one produces something that **only exists because the app is offline and peer-to-peer** [log:274].

| Workload | What it does | Day-one scope | Notes |
|---|---|---|---|
| **Chat surface** | **Benchmark harness only**, shipped labelled as such [log:292] | **SHOULD** — it is the Tier A streaming benchmark [log:356] | Streaming-token rendering benchmark [log:309] |
| **Fraud narrator** | Explains a detected double-spend in plain language — turns a hash comparison into a story [log:277] | **COULD** — only reachable via Tier A on day one; the detection itself is SHOULD | *"Demo gold and costs almost nothing"* [log:277] |
| **Routing oracle** | Given peers in range and a destination, decide which peer to hand a note to — an on-device LLM making relay decisions [log:275] | **WON'T** — needs an on-device model (Tier B/C) [log:355], [log:356] | Consumes the §3d declarative channel descriptor; **a plain policy function does the same job with no AI** [log:323] |
| **Stuck-transfer explainer** | *"This note's last endorsement was three hops ago and forty minutes stale"* [log:276] | **WON'T** — by omission [log:356] | Turns opaque protocol state into a sentence |
| **Gossip-queue triage** | Which of 200 pending notes to relay first when the channel carries 31 bytes at a time [log:278] | **WON'T** — by omission [log:356] | TINY-profile pressure |
| **Change-making negotiator** | Proposes splits and counter-splits against fixed denominations [log:279] | **WON'T** — by omission [log:356] | [log:187], [log:188] |
| **Trust oracle / anomaly surfacing** | Evaluates every incoming note and **speaks up only about the suspicious ones** — spam-filter model [log:286], [log:337] | **WON'T** — by omission [log:356] | The agent should only surface what you could **not** have read off the screen yourself [log:327] |
| **Narrator for blind users** | Describes wallet state aloud — closes the loop back to Echo's original mission [log:283], [log:340] | **WON'T** — by omission [log:356] | TBD |
| **Voice: "pay Marco twenty"** | Offline speech + offline LLM + offline transfer, whole stack with airplane mode on [log:282] | **WON'T** — needs an on-device model [log:355], [log:356] | TBD |
| **Visible tool-call rendering** | Render every tool call as it happens — good for trust, and itself a rendering workload worth measuring [log:334] | **COULD** — rides on Tier A | TBD |

**Hard policy line:** if the agent may ever influence spending, the **spending limit is enforced in the ENCLAVE, outside anything the agent can influence** [log:319].

---

### Framing reminder

> *"This is not a currency app that happens to compare frameworks, it is a **framework benchmark wearing a currency app as a costume**. Every design choice should be judged by what it reveals about RN vs Flutter."* [log:134]

> *"The cost of a mobile framework is paid entirely in the long tail — the capability with no plugin, the background job that must survive Doze, the one 120fps screen. We are really evaluating **escape hatches**, not frameworks."* [log:109]
