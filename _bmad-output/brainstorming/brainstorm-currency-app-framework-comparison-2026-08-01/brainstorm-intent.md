# Intent — Currency App as React Native vs Flutter Benchmark

Build one play-currency wallet twice — once in React Native, once in Flutter — as **fully segregated projects**, and use it as an instrument to answer which framework stays tractable at the native boundary. The currency is a costume; the product is the comparison. The app is deliberately weighted toward device capabilities that no plugin ecosystem has wrapped yet, because that is where the two frameworks actually diverge. One constraint holds the whole design together: **the transfer protocol is one-way, fire-and-forget**. Three dimensions are measured — **native-capability breadth, rendering under load, and agentic integration**. The deliverable is a decision table, not a winner.

> **Scope note — this document is the full design intent, not the day plan.**
> The build is time-boxed to a single hackathon day, and the adopted cut lives in
> [hackathon-plan.md](hackathon-plan.md): MUST is wire spec + vectors, a wallet of
> preloaded notes, **single static QR** transfer (a 96-byte tip fits one static code —
> animated QR and fountain coding are a stretch, not a foundation), same-app transfer
> both frameworks, cross-framework both directions, and a telemetry screen. Agentic is
> **Tier A only**; Tiers B and C are the post-hackathon continuation. Read this document
> for *what the design is*, and the plan for *what gets built Saturday*.

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
- **Deliberately weight the app toward capabilities with no mature plugin in either ecosystem** — **flashlight VLC, ultrasonic, UWB** — because that is where the answer lives. (Satellite and MST were evaluated on this axis and **cut**; see §9.)
- **Measure time-to-first-working-bridge** for a capability neither developer has done before, with a stopwatch, honestly.
- **Primary metric per capability: glue-LOC × runtime-perf.** Glue-LOC is auditable: `cloc` each repo, subtract the checksum-identical native files, the remainder **is** the bridge cost.
- **The same method extends to the agentic dimension** (§12): same model, same runtime, two bindings. **Hold the runtime constant, vary only the binding.**

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

## 5. Keystone constraint — the protocol is ONE-WAY

**The single most load-bearing decision in the project.**

- QR, ultrasonic chirp, SMS and satellite **cannot ACK**. Therefore the entire protocol is designed **fire-and-forget**; two-way is an optimization, never an assumption.
- Consequence: **the sender must be able to prove they sent, and the receiver must be able to claim without cooperation** ⇒ **a transferred note must be a complete, self-contained, independently verifiable object.**
- This one constraint is why bearer notes are right, and why cross-framework payment is possible at all. **Four decisions collapse into one.**

## 6. Wire format (concrete)

- **A note is a fixed 96-byte TIP** — note id, value, holder pubkey, tip signature — **plus an optional history blob.** The tip alone fits every channel including a BLE extended advert; history gossips separately.
- **Hand-rolled deterministic length-prefixed byte layout, specified byte-by-byte in prose. NOT a schema library.** Canonical-form mismatch between Dart and JS libraries is the **likeliest single cause of a failed cross-framework demo**.
- **One version byte at the head of every note; unknown majors are refused.** A version-skew demo (old app meets new app, degrades gracefully) is a cheap credibility win.
- **The note carries no app identity.** Framework tagging lives in the transport (BLE service UUID, NFC AID). **Notes are framework-blind by design** — that is what makes cross-framework payment work.

**Three wire profiles — every channel declares one; the app picks the richest both support:**

| Profile | Budget | Payload |
|---|---|---|
| **TINY** | ≤31 B | tip hash as a pointer |
| **SMALL** | ≤255 B | full tip |
| **FULL** | unbounded | tip + history |

**This is what turns "use every device capability" from a wish into an engineering interface — adding a channel becomes writing a driver, not redesigning the protocol.**

## 7. Conformance apparatus (keeps segregation honest)

- **Frozen test vectors in `spec/vectors.json`** — input bytes → expected parse/signature result. **Hand-authored from the prose spec, never generated by either implementation**, so "same bug, not same spec" is caught.
- **A small Python reference implementation in `spec/`, depended on by neither app.** It generates and verifies vectors and is **the arbiter when RN and Flutter disagree** — settling arguments in seconds instead of hours.
- Both projects run the vectors in their own unit tests. **This is the structure that makes "segregate implementations, share contracts" real rather than aspirational.**
- Second, quieter interop test: **the wallet EXPORT format must be byte-identical**, so a wallet can migrate RN → Flutter (the DB schemas must not be shared).

## 8. Data model — bearer notes, not balances

- **The atom is a signed note**: a bearer token carrying a value and a **chain of endorsements**. Transfer = append your signature and hand it over. **No global ledger.** Cost of this fork: no cheap balance query — the wallet **folds notes** to display a total.
- **Fixed denominations (1 / 5 / 20 / 100)**; splits produce **child notes**. Exact payment needs change-making — a real algorithm and a genuinely fun UI problem.
- **The SENDER makes change.** A receiver refund would need a second round-trip that half the channels physically cannot do.
- **Double-spend is DETECTED, not prevented.** Accepts a defined window of exposure, stated on the threat-model screen.
- **Conflict resolution: NOBODY resolves.** Both branches are marked **poisoned**, **value is destroyed, not reassigned**, and the forger is identified **by their own signature**. Griefing mitigation: **poison the BRANCH, not the note lineage.**
- Detection requires branches to eventually meet ⇒ devices **gossip note histories over every radio they have**. **The mesh is not a feature — it IS the fraud detector.**
- **Finality is a visible three-tier UI state machine: Accepted (handshake) → Corroborated (one gossip echo) → Settled (N echoes or T elapsed).** Rendering that live transition is itself an excellent animation benchmark.
- "How much do I have" becomes "**which notes am I holding**" — the wallet is a set of **objects**, not a number, with a tactile drag-a-note-in-half split gesture. **Precisely the rendering workload that separates Impeller from Fabric** — data model and benchmark reinforce each other.
- Local storage: **append-only, hash-chained ledger**; chain head signed on every write. **Keys in the enclave, DB encrypted with an enclave-wrapped key** — full-DB encryption would destroy the 100k-row scroll benchmark, so the security and benchmark choices are coupled.

**Keys, clocks, replay:**
- **A hardware device key signs; a separate long-lived user identity key certifies device keys** — so a lost phone revokes **one device, not the wallet**.
- **Logical (Lamport) clocks on the endorsement chain**, not device clocks — offline clocks are trivially wrong and attacker-controlled.
- **Replay protection from an enclave monotonic counter, not nonces** — an offline device cannot bound a nonce set.

## 9. Transfer channels — one abstraction, N drivers

- **A note is ~200 bytes ⇒ any channel that moves bytes is a transfer method.** One uniform transfer interface, N drivers.
- **MATRIX INSIGHT (the empty cell): no channel is strong on BOTH throughput and proximity-proof.** Therefore **every real transfer is a PAIR — a pairing channel to establish trust plus a payment channel to carry the bytes. That pairing IS the architecture.** Split the channel list along that axis.
- **MATRIX INSIGHT: nothing works screen-off / backgrounded except NFC HCE** — which is exactly why **iOS restricting HCE is the most consequential platform gap in the comparison**.

**Two transfer modes:**
- **DIRECTED** — encrypted to the recipient's key, so a relay carrying it through the mesh cannot read value or identity.
- **BEARER** — anyone in range claims, first come. The "throw money in the air" demo, required because broadcast channels have no single recipient.
- **Key discovery: recipients continuously advertise their public key over BLE**, making "being payable" a **passive ambient state** rather than an action.

**Channel verdicts (Solution Matrix):**

| Channel | Verdict |
|---|---|
| **NFC HCE** | **HERO #1** — maximal proximity proof, works low-power and screen-off; iOS heavily restricted |
| **Animated QR** | **HERO #2** — best offline throughput; plugin mature both sides, but the **frame-processing pipeline** is where RN and Flutter diverge most |
| **BLE mesh relay** | **HERO #3** — chosen because **background-execution reliability** is exactly the long-tail cost the Five Whys identified |
| **Flashlight VLC** | **SLEEPER PICK** — 10–50 bps, trivially cheap (torch toggle + luminance sampling), no plugin anywhere, enormous visual wow |
| **Ultrasonic** | High value, high cost — room-bounded proximity, no plugin either side, but substantial audio DSP. Decide by remaining time |
| **UWB** | Highest framework-revealing value, lowest availability — **build only if a UWB phone is physically in the room** |
| **SMS** | **Android-only asterisk** — a platform-gap data point, not a demo |
| **Satellite** | **CUT** — a slide, not a feature. Say so out loud |
| **MST** | **CUT** — hardware effectively dead |

**Pairing channels (not payment channels):** bump-derived key (waveform jointly derived, never self-reported), UWB ranging, ultrasonic time-of-arrival.

## 10. Kill-the-crown-jewel finding — build NFC-OPTIONAL

- **Deleting NFC makes the iOS story BETTER** (HCE was the single biggest iOS blocker) **and the stage demo MORE visible** (a tap is invisible on a projector; flickering frames are not).
- **NFC is the PRODUCT channel; optical is the DEMO channel.** They are different things.
- **Therefore: build the entire system NFC-optional from day one. NFC is a driver, not a foundation** — the strongest architectural consequence of the whole exercise.
- Honest casualty: without NFC there is no low-power path, so **the dead-battery vendor scenario is cut, not faked**.

## 11. Transfer requirement and headline demo

**HARD REQUIREMENT (user): same-app transfer. RN→RN and Flutter→Flutter must both work. Cross-framework is the bonus on top.**

- **The wire format is unchanged** — notes are framework-blind by design. **Only DISCOVERY changes:** the transport advertises a **framework tag** and the app chooses whether to filter on it.
- **That filter is the best demo beat in the project:** same-app transfer first, then **flip one switch to accept any framework** and the RN phone pays the Flutter phone. One toggle turns a normal feature into the headline.
- **The test matrix is FOUR cells, not three: RN→RN, FL→FL, RN→FL, FL→RN.** The cross cells are directionally distinct — **encode and decode are different code paths**; testing one direction proves half the interop.
- **De-risking:** same-app transfer works even if the cross-framework switch fails on stage, so the story survives. Build it first for exactly that reason.
- **Four phones = 2 RN + 2 Flutter**, not four identical handsets. The split is the requirement.
- **Perform the cross-framework payment OPTICALLY (animated QR)** so the audience can watch the bytes move between frameworks.
- **Target finished state:** airplane mode on; two phones exchanging money visibly; a third relaying to a fourth across the room; a deliberate double-spend detected live; a telemetry screen showing the frame-time difference; a one-page decision table closes it.
- Supporting demos: **single-phone loopback mode** for every channel; a **fraud button** that deliberately double-spends.

## 12. Agentic integration (third comparison dimension)

**THE CONFOUND — the whole ballgame:** using **ExecuTorch on one side and llama.cpp on the other compares RUNTIMES, not frameworks**, and would silently invalidate this dimension.

**THE FIX — mirrors the project's founding methodology: same GGUF model, same llama.cpp, Dart FFI on one side and a Nitro module on the other. Runtime constant, binding variable.**

**The three-tier agent test — three numbers, reported separately, NEVER averaged:**

| Tier | Setup | Isolates |
|---|---|---|
| **(a) Control** | remote GPU sidequest, identical HTTP streaming, **no native code either side** | pure UI streaming performance |
| **(b) Blessed** | ExecuTorch (RN) vs MediaPipe / flutter_gemma (Flutter) | **ecosystem convenience** |
| **(c) Matched** | **same llama.cpp both sides** | **pure binding cost** |

**Structural facts (why this dimension may be the most decisive):**
- **Dart FFI and Dart isolates are first-class language features.** RN's JSI/Nitro path needs **C++ glue plus codegen**, and RN needs worklets/threads to keep inference off the UI thread. **Flutter's structural advantage is in the binding.**
- **Agent SDKs and the MCP SDK are TypeScript-first** — a genuine, structural **RN ecosystem advantage**, not a preference.
- **The two structural advantages point in OPPOSITE directions.** That is precisely why this dimension is worth measuring, and why it may decide the comparison.

**What the agent is FOR (Job to Be Done overturned the obvious):**
- **Not a chat box.** It is a **trust oracle** and a **background compressor**: it removes the need to understand the protocol, answers **"can I trust this note?"**, surfaces **the three events that matter out of hundreds**, and **acts when you are not looking**.
- **Therefore TOOL-CALL LATENCY is the headline agentic metric; streaming throughput is secondary.**
- **Keep a chat surface only as an explicitly labelled benchmark harness** — shipped as a benchmark, never sold as a feature.
- Surface pattern: **inline in the transfer sheet, never a chat tab**; speaks up only about exceptions.

**The safety boundary — which is also the testability boundary:**
- **Agents PROPOSE; deterministic code EXECUTES, behind a biometric gate.**
- **The model never touches unverified bytes** — it operates strictly on **already-parsed, already-verified objects**.
- **Spending policy is enforced in the enclave**, outside anything the agent can influence.
- **Render every tool call visibly** — good for trust, and itself a rendering workload worth measuring.
- Conflict UX grafted from a git merge tool: **show the conflict, propose a resolution, never auto-commit.**

**Agent features worth building (mesh intelligence, not chat):**
- **Routing oracle** — given peers in range and a destination, choose who to hand a note to.
- **Fraud narrator** — explain a detected double-spend in plain language. Demo gold, near-zero cost.
- **Stuck-transfer explainer** — "this note's last endorsement was three hops ago and forty minutes stale."
- **Gossip-queue triage** under bandwidth scarcity; **change-making negotiation**; **human-readable receipts** from a raw endorsement chain.
- **Voice: "pay Marco twenty"** — offline speech + offline LLM + offline transfer, airplane mode on.
- **Narrating wallet state for blind users** — closes the loop to Echo's original mission.

**The declarative channel descriptor (build regardless of AI):**
- Describe every channel by **wire profile, throughput, proximity strength, power cost, availability**.
- **Both an LLM and a plain policy function can then select channels.** It pays for itself with no AI involved, and it is what **finally unifies the pairing/payment split** from §9.

**Agentic metrics (its own decision-table section with its own rubric, not a row bolted onto the capability table):** tokens/sec · time to first token · **tool-call latency** · **UI jank during inference, measured during a 60fps scroll** (because "does inference jank the UI" IS the question) · thermal delta · binding LOC · **app size with and without models**.

**Agentic risks:**
- **ExecuTorch is arm64-only with no emulator ⇒ CI cannot exercise the agent path.** Mitigate by **simulating a peer swarm against the deterministic fake-radio mode** and running the agent loop over simulated peers.
- **Background agent loops will be killed by Doze on both platforms.** Plan to **report a null honestly** rather than chase it all day.
- **Freeze ONE small quantised model, checksum it, and refuse to report any number produced by a different one.** The bar is a **small fast model doing narrow things**, not a big model doing everything.
- Model download over wifi before an offline demo is a real fragility — do it early.

## 13. Measurement apparatus

- **One shared spec + one shared E2E suite** (Maestro/Appium) that **both builds must pass identically** — the anti-scope-drift mechanism.
- **In-app Framework Telemetry screen, built EARLY** — cold start, frame drops, memory, APK size — measured live on device, **identical schema** emitted to a local file by both builds so numbers diff from the same phone. Built early every later measurement is free; built late, most never get taken. **It is not a nice-to-have — it IS the deliverable.**
- **Null-app baseline** in both builds (an empty scroll list) to calibrate framework cost vs our code.
- **Interleaved back-to-back runs on the same device**, logging **battery and thermal state per sample**.
- **All timings from release builds, cold, after a reboot.** No hot-reload numbers.
- **APK size reported stripped and full, per ABI.**
- **Torture ledger screen**: 100k transactions, scroll jank measured (FlashList vs ListView.builder).
- Same Figma both sides; **pixel-diff the screenshots** as a fidelity score.

## 14. Deliverable

- **A decision table — "if your product needs X, pick Y" — not a verdict on a winner.** One readable conclusion, not forty metrics.
- **Agentic integration gets its own section in the table with its own rubric** — not a row appended to the capability table.
- The **iOS platform capability gap** (NFC HCE, background BLE, raw wifi, programmatic SMS) and the **arm64-only / no-emulator constraint** are reported as **headline findings**, not blockers.

## 15. Day-one order of work

**The true first move is `spec/wire.md` and `spec/vectors.json`. Not a scaffold, not a plugin spike, not a UI.**

1. **Fork decisions written down** (§5–§9).
2. **`spec/wire.md`** — the prose byte layout; both devs read it.
3. **`spec/vectors.json` + the Python reference implementation.**
4. **Bytes-only RN↔Flutter interop test — hardcoded notes, NO UI** — before either app is built.
5. **Freeze and checksum the one quantised model.**
6. **Timeboxed one-hour plugin-availability spike per capability, both ecosystems**, recorded straight into the decision table. "Does a usable plugin exist" changes the plan more than any other single fact.
7. **Timebox the AGENTIC spike SEPARATELY** from the channel spikes — its failure mode is **model download and memory**, not permissions.
8. **Telemetry screen in both apps** + **the three-tier agent harness**.
9. Then the scope ladder.

Also day one: **four phones (2 RN + 2 Flutter) sourced by a named owner** — a logistics task, not something discovered at 4pm.

## 16. Scope ladder

1. **One-phone loopback QR transfer in both apps** (the 60-minute spine).
2. **RN→RN and Flutter→Flutter — the BASELINE DELIVERABLE, not a milestone.** Required.
3. **RN→FL and FL→RN cross-framework** (the switch) — bonus.
4. NFC as a second driver.
5. BLE mesh relay.
6. Flashlight VLC (cheapest wow).
7. Fraud demo (+ fraud narrator).
8. Agentic tier (c) matched-runtime measurement / exotic #2, only if time remains.

- **HARD RULE: never start rung N+1 until rung N works on real hardware in airplane mode.** Airplane mode is the acceptance criterion for every rung, not a final test.
- **The 60-minute version IS the demo spine.** Everything else is an upgrade to a spine that already works — never invert the order.

## 17. Risks and logistics

- **Rung 3 (cross-framework) is the riskiest and the cheapest to de-risk** — the day-one bytes-only interop test exists for exactly this. Rung 2 standing alone means the demo survives its failure.
- **Build the FRAUD BUTTON before the fraud detection**, so there is always something to show even if detection is half-finished.
- **Hot-reload with radios off must be solved and rehearsed before demo day** — an airplane-mode demo cannot rely on a dev-client reload that needs wifi.
- **A room saturated with hackathon wifi** is the demo environment; plan the mesh demo around it.

## 18. Honest cuts (state out loud, never imply otherwise)

- **Mint is faked**: every wallet preloads 100 notes. Pedometer/geofence/barometer minting is a slide.
- **Mesh relay is labelled a simulation** if only two phones are present.
- **Software key with a visible TODO** if the enclave bridge is not done.
- **Borrow existing QR encode/decode libraries** — do not hand-roll fountain codes early.
- **Keep the wire vectors** (twenty minutes; the only thing making the cross-framework claim credible) **and the telemetry screen** under every cut scenario.

## 19. Bias controls, non-goals and guardrails

**THE LOADED DIE — state it before anyone else finds it.** The hackathon base repo (`echo-hackathon`) is **Expo 57 / RN 0.86.2** with **react-native-executorch 0.9.2** (`useLLM` / `useOCR` / `useObjectDetection`) already wired, plus `expo-nearby-connections`, `react-native-keychain`, `expo-camera`, `expo-haptics`, `expo-speech`, `react-native-nitro-modules`; **arm64-only, physical device only**.

- **RN therefore starts with a working on-device LLM AND a working mesh transport.** **Any time-to-first-working measurement taken from this repo is meaningless.**
- **MITIGATION: measure from CLEAN SCAFFOLDS in BOTH frameworks, and print the head start in the write-up rather than hiding it.** This is the single factor most likely to undermine the result's credibility.
- Also control for: which framework we are secretly hoping wins; **engineers will simply enjoy Dart FFI more than JSI**, and enjoyment shows up in the numbers wearing a disguise.

**Guardrails:**
- **Play currency only.** A hard, loud **"this is not real money"** boundary — keeps clear of e-money licensing and app-store rejection. **Visually unmistakable as fake.**
- **The threat model is a first-class in-app screen.** Say "this is a security toy" first and loudly.
- **Deliberately custom design — non-Material, non-Cupertino** — so neither framework gets home-field advantage.
- **No build system may span `currency-rn/` and `currency-flutter/`.** Any convenience that couples them is out of scope by definition.
- **The sidequest GPU never receives wallet contents** — consent is explicit and scoped to one thing the user is already looking at.
- Not building: production key recovery, real settlement, custody, a chat-assistant product, or anything requiring a server.
- Demo-safety: a **stage mode** disabling every scanning radio except the one being demoed.

## 20. Open questions — must be answered before building

1. **What is the currency FOR** — game token, community credit, payment stand-in, or deliberately abstract? (Everything downstream depends on this.)
2. **Conserved with fixed supply, or freely minted** — and if minted, **who may mint and what stops everyone minting?**
3. **How long may a note stay unreconciled before the app distrusts it, and who enforces that clock offline?** (Settled is defined as N echoes *or* T elapsed — N and T are unset.)
4. **Can a transfer fail AFTER the receiver's phone said "received"?** The Accepted → Settled ladder implies yes; the UI contract for that reversal is undefined.
5. **Lost phone: is the value gone forever?** Device-key revocation saves the identity, not the notes held. **Does adding note recovery destroy the offline story?**
6. **How does a receiver validate a note whose mint it has never seen** — self-anchored from the mint, or is there a root of trust?
7. **Who writes each build** — one person both, or two specialists? Which is more honest, and how do we control for the bias of which framework we are secretly hoping wins?
8. **How much of the measured difference is the platform (Android vs iOS) rather than the framework?** And if a capability has a great plugin on one side and none on the other, is that a framework property or an accident of timing?
9. **Can either app ship a wire-format change unilaterally, or is a version bump a two-project release?**
10. **Which quantised model, and does it fit memory alongside a 100k-row ledger on the demo phones?**

**Scenario anchor still to pick** (festival with no signal / aid camp / school) — every capability needs a story, or the demo is boring.
