# Scorecard — fill this on the day

One page. Everything else is reference. `decision-table.md` is the full instrument;
this is the subset that fits between builds.

**Protocol:** release builds, cold, after a reboot. Both apps on the **same phone**,
runs interleaved. Log battery % and thermal state next to each sample.

---

## Captured externally — no app code

```
Cold start   adb shell am start -W -n <pkg>/.MainActivity     → TotalTime
APK size     ls -l app-release.apk                            → bytes, per ABI
Frame times  adb shell dumpsys gfxinfo <pkg> framestats       → jank %, p95
Memory       adb shell dumpsys meminfo <pkg>                  → PSS total
```

| Metric | RN | Flutter | Notes |
|---|---|---|---|
| Cold start (ms) | | | median of 5, after reboot |
| APK size, stripped (MB) | | | arm64-v8a |
| Jank % — wallet scroll | | | 100k generated rows |
| p95 frame time (ms) | | | same scroll |
| Peak memory PSS (MB) | | | during scroll |

## Build cost per channel — the number that answers the real question

Stopwatch each one **from a clean scaffold**. This table is the deliverable.

| Channel | Time to working — RN | Time to working — FL | Glue LOC RN | Glue LOC FL | Deps RN | Deps FL |
|---|---|---|---|---|---|---|
| QR (static) | | | | | 1 | 2 |
| Nearby Connections | | | | | 0 ⚠ | 1 |
| Multi-hop relay (pure logic) | | | | | 0 | 0 |
| NFC (tag) | | | | | 1 | 1 |

⚠ **`expo-nearby-connections` is already integrated in the RN base repo** — the hardest
channel. Time it from a clean scaffold or the number is meaningless.

| Item | RN | Flutter |
|---|---|---|
| Anything that fought you | | |

*That last row is the most valuable cell on the page. Write freely.*

> **Bias flag, state it in the write-up:** the RN base repo already shipped
> `expo-nearby-connections`, `react-native-executorch` and `react-native-keychain`.
> All timings are from **clean scaffolds**, not this repo. Print the head start.

> **Bias flag, state it in the write-up:** the RN base repo already shipped
> `react-native-executorch` and a working mesh transport. All timings above are from
> **clean scaffolds**, not this repo. Print the head start; do not hide it.

## Interop — four cells **per channel**, all must pass

Test cross-framework immediately after each channel works, not once at the end.

| Channel | RN→RN | FL→FL | RN→FL | FL→RN |
|---|---|---|---|---|
| QR (static) | ☐ | ☐ | ☐ | ☐ |
| Nearby Connections | ☐ | ☐ | ☐ | ☐ |
| Multi-hop relay | ☐ | ☐ | ☐ | ☐ |
| NFC (tag) | ☐ | ☐ | ☐ | ☐ |

Encode and decode are different code paths — proving one direction proves half.
All in **airplane mode**.

## Agentic Tier A only (remote GPU, no native either side)

| Metric | RN | Flutter |
|---|---|---|
| Time to first token (ms) | | |
| Tokens/sec rendered | | |
| Jank % while streaming | | |
| Glue LOC | | |

Tiers B and C not attempted — post-hackathon. Say so.

---

## Read-out — one line each, written before you present

- **Needs exotic native integration →** _______
- **Needs heavy custom animation →** _______
- **Needs large-list rendering →** _______
- **Needs on-device AI / agentic →** _______ *(Tier A evidence only — say so)*
- **Fastest to a working bridge for an unwrapped capability →** _______

## What we did not build

_List it here before the pitch. Judges reward the team that names its own boundary._
