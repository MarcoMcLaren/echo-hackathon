# RN vs Flutter — Decision Table

**Project:** currency app built twice (`currency-rn/` and `currency-flutter/`), fully segregated
**Deliverable framing (from the session):** *"the deliverable is not a winner, it is a decision table — if your product needs X, pick Y."* [log:112]
**Status:** empty instrument, ready to score. No results have been recorded yet.

> Every capability and metric below traces to the brainstorming memlog in this folder.
> `[log:N]` = line N of `.memlog.md`. Anything the log does not settle is marked **TBD** — do not fill it from memory or vendor docs, fill it from a measurement.

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

**Legend**
- **Plugin maturity** — fill only from hands-on experience in this build. Allowed values: `none` / `abandoned` / `partial` / `maintained` / `first-party`. Pre-filled **only** where the session log states something definite; every other cell is `TBD`.
- **Glue LOC** — cloc of the bridge only, native duplicates subtracted (P8).
- **TTFB** — time to first working bridge, stopwatched (P9), in hours:minutes.
- **Android OK / iOS OK** — `yes` / `partial` / `BLOCKED` / `TBD`.
- **Verdict** — one line, written only after both sides of the row are done.

| Capability | Plugin maturity RN | Plugin maturity Flutter | Glue LOC RN | Glue LOC Flutter | TTFB RN | TTFB Flutter | Android OK | iOS OK | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| NFC host card emulation (tap-to-pay phone→phone) [log:12] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | **BLOCKED** — iOS restricts HCE [log:100] | — |
| NFC tag read/write (bearer-note sticker, one-time key burn) [log:13–15] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| BLE advertisement payloads (micro-transfer in the advert) [log:42] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | **partial** — iOS restricts background BLE [log:100] | — |
| BLE mesh relay (TTL + dedupe gossip of signed notes) [log:43], [log:81] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | **partial** — background BLE restricted [log:100] | — |
| Wi-Fi Direct / Nearby | TBD | TBD | TBD | TBD | TBD | TBD | TBD | **BLOCKED** — iOS restricts raw wifi [log:100] | — |
| UWB ranging (~10cm proximity proof) [log:25] | **none mature** [log:110] | **none mature** [log:110] | TBD | TBD | TBD | TBD | TBD (device-dependent [log:26]) | TBD | — |
| Camera QR decode via frame processors [log:19], [log:64] | TBD — approach: Vision Camera frame-processor plugin, pixels never cross the bridge | TBD — approach: camera + MLKit | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Animated-QR optical streaming (~10fps fountain-coded frames) [log:18], [log:20] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Ultrasonic audio data transfer (chirp broadcast) [log:22], [log:23] | **none mature** [log:110] | **none mature** [log:110] | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Microphone time-of-arrival ranging (who is really in the room) [log:24] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Flashlight visible-light comms (strobed payload) [log:46] | **none mature** [log:110] | **none mature** [log:110] | TBD | TBD | TBD | TBD | TBD | TBD | — |
| MST (magnetic secure transmission) [log:110] | **none mature** [log:110] | **none mature** [log:110] | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Accelerometer bump detection (dual spike <50ms, seeds session key) [log:26], [log:27] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Pedometer step minting [log:37] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Barometer altitude (minting rate scales with climb) [log:38] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| GPS geofenced faucets [log:39] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Ambient light + mic noise entropy pool [log:40] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Wearable heart-rate liveness gate [log:41] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Hardware keystore (StrongBox / Secure Enclave) [log:28], [log:34] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Biometric gating (incl. two-phone co-signed transfer) [log:29], [log:30] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Device attestation (Play Integrity / App Attest) [log:57] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| FLAG_SECURE screenshot/record blocking on vault screen [log:56] | TBD — log flags this as differing *sharply* between frameworks; verify | TBD — same | TBD | TBD | TBD | TBD | TBD | TBD (iOS has no FLAG_SECURE equivalent — verify) | — |
| SMS transport (base64 payload, works on 2G) [log:44] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Satellite messaging (iPhone 14+ / Pixel) [log:45] | **none mature** [log:110] | **none mature** [log:110] | TBD | TBD | TBD | TBD | TBD (Pixel only [log:45]) | TBD (iPhone 14+ only [log:45]) | — |
| Screen pinning / kiosk mode (vendor receive-only; Guided Access on iOS) [log:60] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Background execution surviving Doze [log:109] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Watch companion app (Wear OS; Shamir share holder; small-spend authorizer) [log:35], [log:36], [log:66] | TBD | TBD — Flutter dev claims one widget tree drives phone + watch face [log:66]; verify | TBD | TBD | TBD | TBD | TBD | TBD | — |
| AR coin visualization (pile of coins on the table) [log:72] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Share-sheet signed CSV export (audit trail) [log:59] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Haptic amount encoding (transfer completes with zero visual feedback) [log:53] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |
| Screen-reader accessibility (announce counterparty; bump-to-pay as the most accessible method) [log:53], [log:54] | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | — |

**Hero vs novelty.** The session decided three channels must be **bulletproof** and the rest are **clearly labelled demo-grade novelties**: heroes = **NFC, animated-QR, BLE mesh**. [log:90], [log:140] Mark each row `HERO` or `NOVELTY` in review — a novelty row scoring badly is not evidence against a framework.

**Also required per capability (tick when done, from [log:93]):** every method ships a **single-phone loopback demo mode**, so a dead or NFC-less second phone cannot kill the demo.

| Capability | HERO / NOVELTY | Loopback demo RN | Loopback demo Flutter | Passes shared E2E (P6) |
|---|---|---|---|---|
| *(mirror the rows above as they land)* | TBD | ☐ | ☐ | ☐ |

---

## 4. Runtime performance

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
| Broadest team hireability | TBD | **Not measurable from this build** — no row above produces evidence for it. Either answer from hiring data outside this project or state plainly that the comparison does not address it. |

**One-verdict discipline:** the hackathon judge wants *one readable verdict, not forty metrics* [log:73]. This section is that verdict. The tables above are its evidence, not its substitute.
Open question worth answering on the way: *what is the ONE screen we could build that would settle the argument on its own?* [log:131]

---

## 7. Bias controls

Work this checklist before publishing any verdict. Each item is a question the session raised and did not answer.

| ☐ | Control | The question, as asked | Source |
|---|---|---|---|
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

---

### Framing reminder

> *"This is not a currency app that happens to compare frameworks, it is a **framework benchmark wearing a currency app as a costume**. Every design choice should be judged by what it reveals about RN vs Flutter."* [log:134]

> *"The cost of a mobile framework is paid entirely in the long tail — the capability with no plugin, the background job that must survive Doze, the one 120fps screen. We are really evaluating **escape hatches**, not frameworks."* [log:109]
