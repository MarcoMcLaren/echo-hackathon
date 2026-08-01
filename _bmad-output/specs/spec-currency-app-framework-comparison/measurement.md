# Measurement

Companion to `SPEC.md` (CAP-10). The comparison exists to produce these numbers.
Record them on `scorecard.md`; `decision-table.md` in the brainstorming folder is the
long-form reference.

## The loaded die — disclose it first

The base repo (`echo-hackathon`, Expo 57 / RN 0.86.2) already ships
`expo-nearby-connections`, `react-native-executorch` and `react-native-keychain`.
**React Native starts with the hardest channel already working.**

> **Every timing is measured from a clean scaffold in both frameworks, and the head start
> is printed in the write-up.** This is the single factor most likely to undermine the
> result's credibility. Naming it first is worth more than any individual metric.

## Protocol

- **Release builds. Cold. After a reboot.** No hot-reload numbers, ever.
- **Both apps on the same phone**, runs interleaved — distinct application ids make this
  possible, which is a direct payoff of the segregation constraint.
- **Log battery % and thermal state beside every sample.**
- Median of 5 for anything timed.

## Captured externally — zero app code

There is no in-app telemetry screen. Everything comes from `adb`, which removes an hour
per framework *and* the observer effect.

```
Cold start   adb shell am start -W -n <pkg>/.MainActivity      → TotalTime
APK size     ls -l app-release.apk                             → bytes, per ABI
Frame times  adb shell dumpsys gfxinfo <pkg> framestats        → jank %, p95
Memory       adb shell dumpsys meminfo <pkg>                   → PSS total
```

## Per-channel build cost — the primary result

Stopwatch each channel **from a clean scaffold**. This table answers the question the
project exists to answer.

| Channel | Time to working | Glue LOC | New deps |
|---|---|---|---|
| Static QR | | | RN 1 · FL 2 |
| Nearby Connections | | | RN 0 ⚠ · FL 1 |
| Multi-hop relay | | | 0 · 0 |
| NFC tag | | | RN 1 · FL 1 |

⚠ RN's zero is the head start, not a result.

**Glue LOC** = `cloc` the app source, excluding generated files and any checksum-identical
native code. In v0 there is no shared native code, so it is simply the driver
implementation.

**"Anything that fought you"** — a free-text row per channel per framework. This is the
most valuable cell on the scorecard and the one most likely to be skipped. Write it while
the frustration is fresh.

## Runtime metrics

| Metric | Notes |
|---|---|
| Cold start (ms) | median of 5, after reboot |
| APK size, stripped (MB) | arm64-v8a |
| Jank %, list scroll | 100k **generated in-memory** rows — no database involved |
| p95 frame time (ms) | same scroll |
| Peak memory PSS (MB) | during scroll |

**Null-app baseline:** an empty scroll list in both frameworks, measured the same way, so
framework cost is separable from our code.

## Agentic Tier A — in scope (trade B)

Identical prompt, identical **frozen** endpoint, no native code either side — this
isolates pure UI streaming. If the two apps hit different endpoints or different models,
the numbers are worthless.

| Metric | Notes |
|---|---|
| Time to first token (ms) | |
| Tokens/sec rendered | |
| Jank % while streaming | the real question is whether streaming janks the UI |
| Glue LOC | |

Tiers B (blessed local runtimes) and C (same llama.cpp bridged twice) are **not
attempted**. Say so — do not present one number as if it were three.

## Bias controls

- Which framework are we hoping wins, and who is checking?
- Same person on both builds, or two specialists? Either is defensible; the choice must
  be stated.
- How much of any measured difference is **Android** rather than the **framework**?
- A capability with a good plugin on one side and none on the other — framework property,
  or accident of timing?
- Engineers enjoy Dart FFI more than JSI. Enjoyment is not a metric but it shows up in
  the numbers wearing a disguise.

## The deliverable

A decision table — **"if your product needs X, pick Y"** — not a winner. Rows:

- needs exotic native integration
- needs heavy custom animation
- needs large-list rendering
- needs on-device AI / agentic *(Tier A evidence only — say so)*
- needs fastest time to a working bridge for an unwrapped capability

Each row gets one line, written **before** presenting. The iOS platform gap and the
arm64-only / no-emulator constraint are reported as **headline findings**, not blockers.
