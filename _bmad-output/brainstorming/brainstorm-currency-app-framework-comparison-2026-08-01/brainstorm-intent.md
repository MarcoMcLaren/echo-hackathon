# Intent — Currency App as React Native vs Flutter Benchmark

Build one play-currency wallet twice — once in React Native, once in Flutter — as **fully segregated projects**, and use it as an instrument to answer which framework stays tractable at the native boundary. The currency is a costume; the product is the comparison. The app is deliberately weighted toward device capabilities that no plugin ecosystem has wrapped yet, because that is where the two frameworks actually diverge. The deliverable is a decision table, not a winner.

---

## 1. Core reframe

- **This is a framework benchmark wearing a currency app as a costume.**
- Every design decision is judged by one criterion: **what does it reveal about RN vs Flutter?**
- Features that do not discriminate between the frameworks are not worth building.

## 2. Root cause (Five Whys)

- Why a currency app: it forces **breadth** — radios, sensors, secure hardware, background work, heavy list rendering — in one product.
- Why breadth: **both frameworks are equally fine at simple apps.** They diverge only at the **native boundary** and **under load**.
- **ROOT CAUSE: the cost of a mobile framework is paid entirely in the long tail** — the capability with no plugin, the background job that must survive Doze, the one 120fps screen.
- **We are evaluating ESCAPE HATCHES, not frameworks.**

## 3. Methodology (the only honest measurement)

- **Write the native code ONCE per platform (Kotlin/Swift). Bridge it TWICE. Stopwatch the bridge.** This isolates the actual variable under test.
- **Deliberately weight the app toward capabilities with no mature plugin in either ecosystem** — UWB, ultrasonic, satellite messaging, flashlight VLC — because that is where the answer lives.
- **Measure time-to-first-working-bridge** for a capability neither developer has done before, with a stopwatch, honestly.
- **Primary metric per capability: glue-LOC × runtime-perf.** Glue-LOC is auditable: `cloc` each repo, subtract the checksum-identical native files, the remainder **is** the bridge cost.

## 4. Hard constraint and adopted resolution

**Constraint (user, non-negotiable):** the Flutter project and the RN project are **COMPLETELY SEGREGATED** — no shared code, no shared build, no shared dependency tree.

**ADOPTED: segregate implementations, share contracts.**

- Native Kotlin/Swift is duplicated into each project as **byte-identical copies, checksum-verified in CI** — never a shared Gradle module or CocoaPod.
- **Duplicated:** source, build config, dependency tree, CI pipeline, app id, signing.
- **Shared as documents only (never as code):** wire-format spec, shared E2E suite (Maestro/Appium), telemetry schema, Figma, threat model.

**Repo shape:**

```
currency-rn/       # fully independent project
currency-flutter/  # fully independent project
spec/              # documents + shared E2E suite only — no build system spans the boundary
```

**Consequences that pay for themselves:**
- Distinct applicationId/bundleId ⇒ **both apps install on one phone simultaneously** ⇒ interleaved benchmarking on identical hardware and thermal state.
- Both coexisting on one device ⇒ they need **distinct BLE service UUIDs and NFC AIDs**, so the wire spec must define a **framework-agnostic app identity separate from the transport identifier**.

## 5. Data model — bearer notes, not balances

- **The atom is a signed note**: a bearer token carrying a value and a **chain of endorsements**. Transfer = append your signature and hand it over. **No global ledger.**
- **Double-spend is DETECTED, not prevented.** Two conflicting endorsements on one note **provably identify the forger by their own signature**.
- Detection requires branches to eventually meet ⇒ devices **gossip note histories over every radio they have**. **The mesh is not a feature — it IS the fraud detector.**
- "How much do I have" becomes "**which notes am I holding**" — the wallet is a set of **objects**, not a number.
- Notes **split and merge**, driving a tactile drag-a-note-in-half gesture.
- **Why this matters to the benchmark:** notes-as-objects makes the UI a physical, animatable, splittable thing — **precisely the rendering workload that separates Impeller from Fabric**. Data model and benchmark reinforce each other.
- Local storage is an **append-only, hash-chained ledger**; the chain head is **signed by the hardware keystore on every write** (StrongBox vs Secure Enclave — itself a bridging comparison).

## 6. Transfer channels — one abstraction, N drivers

- **A note is ~200 bytes ⇒ any channel that moves bytes is a transfer method.** The capability sprawl collapses into **one uniform transfer interface with N drivers behind it**.
- Rank every channel on two axes: **bytes/sec** and **strength-of-proximity-proof** — producing a map of which channels are for **payment** and which are for **pairing**.

**Three hero channels — must be bulletproof:**
1. **NFC** tap-to-pay (Host Card Emulation), phone-to-phone.
2. **Animated QR** — fountain-coded frame stream, camera-decoded live; completes when enough frames land, no handshake.
3. **BLE mesh** — signed transfers relayed by strangers with TTL and dedupe.

**Novelty channels — build, but clearly labelled demo-grade:** ultrasonic chirp, SMS base64 payload, satellite messaging, flashlight VLC, NFC-sticker cash drop.

**Proximity proofs — one unified interface, not a pile of gimmicks:**
- **Bump-derived key** (both accelerometers spike within 50ms; the waveform itself seeds the session key — jointly derived, never self-reported).
- **UWB ranging** (~10cm, physical presence as a settlement rule).
- **Ultrasonic time-of-arrival** (who is genuinely in the room).

**Hardening baked in:** replay protection from an enclave-anchored monotonic counter; chirps carry a nonce and short expiry; biometrics as a **transfer gate**, not a login.

## 7. Headline demo — cross-framework payment

- **The RN app pays the Flutter app.**
- It is simultaneously the **headline demo** and **the strictest possible conformance test**: it proves both builds implement the same wire format rather than merely looking alike.
- Supporting demos: **single-phone loopback mode** for every channel (no second device required); a **fraud-demo button** that deliberately double-spends and shows detection firing.

## 8. Measurement apparatus

- **One shared spec + one shared E2E suite** (Maestro/Appium) that **both builds must pass identically** — the anti-scope-drift mechanism.
- **In-app Framework Telemetry screen** — cold start, frame drops, memory, APK size — measured live on device, **identical schema** emitted to a local file by both builds so numbers diff from the same phone.
- **Null-app baseline** in both builds (an empty scroll list) to calibrate framework cost vs our code.
- **Interleaved back-to-back runs on the same device**, logging **battery and thermal state per sample**.
- **All timings from release builds, cold, after a reboot.** No hot-reload numbers.
- **APK size reported stripped and full, per ABI.**
- **Torture ledger screen**: 100k transactions, scroll jank measured (FlashList vs ListView.builder).
- Same Figma both sides; **pixel-diff the screenshots** as a fidelity score.

## 9. Deliverable

- **A decision table — "if your product needs X, pick Y" — not a verdict on a winner.**
- The **iOS platform capability gap** (NFC HCE, background BLE, raw wifi) is reported as a **headline finding**, not treated as a blocker.
- One readable conclusion, not forty metrics.

## 10. Non-goals and guardrails

- **Play currency only.** A hard, loud **"this is not real money"** boundary — keeps clear of e-money licensing and app-store rejection. The currency must be **visually unmistakable as fake**.
- **The threat model is a first-class in-app screen.** Say "this is a security toy" first and loudly, before anyone else does.
- **Deliberately custom design — non-Material, non-Cupertino** — so neither framework gets home-field advantage.
- **No shared build system, ever.** Any convenience that couples the two repos is out of scope by definition.
- Not building: production key recovery, real settlement, custody, or anything requiring a server.
- Demo-safety: a **stage mode** disabling every scanning radio except the one being demoed.

## 11. Open questions — must be answered before building

1. **What is the currency FOR** — game token, community credit, payment stand-in, or deliberately abstract? (Everything downstream depends on this.)
2. **Conserved with fixed supply, or freely minted** — and if minted, **who may mint and what stops everyone minting?**
3. **Do we need identity at all, or just keys?**
4. **When is a transfer final** — at handshake, or at first gossip confirmation? Can it fail **after** the receiver's phone said "received"?
5. **What is the smallest unit, and does divisibility break the bearer-note model?**
6. **Lost phone: is the currency gone forever?** Should recovery exist at all — **or does adding it destroy the offline story?**
7. **Who writes each build** — one person both, or two specialists? Which makes the comparison more honest, and how do we control for the bias of which framework we are secretly hoping wins?
8. **How much of the measured difference is the platform (Android vs iOS) rather than the framework?** And if a capability has a great plugin on one side and none on the other, is that a framework property or an accident of timing?

**Scenario anchor still to pick** (festival with no signal / aid camp / school) — every capability needs a story, or the demo is boring.
