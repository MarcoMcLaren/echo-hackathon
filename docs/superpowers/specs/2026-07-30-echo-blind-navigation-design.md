# Echo — On-device navigation aid for the blind (design spec)

> **Status:** approved concept, pending spec review.
> **Supersedes** the Swarm mesh-messaging brief. This is a project pivot.
> Working name **"Echo"** (echolocation-style feedback) — swappable.

## One-liner

Point the phone forward; it detects obstacles from the camera and warns you with
**haptic buzzes** (stronger/faster as you get closer) and **spoken labels**
("chair, close, ahead") — running **100% on-device, offline**, built in React
Native/TypeScript.

## Why this project

- **Social impact + technical depth** in one — the combination judges reward.
- **"React Native superiority" thesis:** a real-time computer-vision + voice +
  haptics assistant, entirely in TS, offline, on a phone. The hard native ML is
  provided by `react-native-executorch`, which already compiles on our device.
- **No network, no accounts, no API keys** — works in airplane mode.

## The demo moment (what judges see)

Phone in airplane mode. Presenter walks the phone toward a chair/person/box:
the on-screen camera draws a live detection box (for the audience), the phone
**buzzes faster as the object nears**, and a voice says **"chair — close —
ahead."** Then: point at a sign → "Read that" → it speaks the text (OCR). Then:
"What's around me?" → a spoken sentence describing the scene (LLM). All offline.

## Goals

- Real-time obstacle detection from the rear camera.
- Eyes-free feedback: haptics for proximity + speech for identity/direction.
- Fully offline after a one-time model download.
- Accessible UI (large targets, TalkBack-friendly, minimal reliance on sight).

## Non-goals (out of scope)

- True metric distance (no depth sensor on the S25; ExecuTorch has no depth
  model). Proximity is inferred from bounding-box size — a demo heuristic.
- iOS. Android-only, physical device only.
- Mesh networking, messaging, encryption, accounts (dropped with the pivot).
- Turn-by-turn GPS navigation. This is close-range obstacle awareness.

## Architecture — the pipeline

```
expo-camera (rear preview)        ← expo-camera
  → snapshot loop (~3 fps): takePictureAsync → file URI
      → useObjectDetection.forward(uri)        ← react-native-executorch (SSDLite, COCO)
          → Detection[] { label, bbox{x1,y1,x2,y2}, score }
  → [JS] proximity engine
      • closeness ≈ bbox area / frame area (bigger = closer)
      • pick highest-priority obstacle (biggest / centered)
      • map bbox center-x → direction (left | ahead | right)
  → feedback engine
      • haptics: pulse loop, interval shrinks + intensity steps up as closeness ↑   ← expo-haptics
      • speech: debounced announce "<label> — <near|close|very close> — <dir>"       ← expo-speech (offline OS TTS)
On-demand actions (buttons / voice):
  • "Read that"  → capture frame → useOCR → speak recognized text                    ← executorch OCR
  • "What's around me?" → detections list → useLLM → speak a natural sentence         ← executorch LLM
```

## Components (isolated units)

- **`features/vision`** — camera + detection. Owns expo-camera setup and the
  snapshot→`forward(uri)` loop. Exposes a `useObstacles()` hook returning the
  current `Detection[]`. Depends on: expo-camera, executorch. Testable via
  fed-in fixtures for the proximity math.
- **`features/feedback`** — turns obstacle state into output. Pure-ish logic:
  `computeProximity(detections, frameSize)` and `computeDirection(bbox)` are
  pure functions (unit-testable, no native). A `useProximityFeedback(obstacle)`
  hook drives haptics + speech. Depends on: expo-haptics, expo-speech.
- **`features/ai`** — on-demand OCR ("read that") and LLM ("describe scene").
  Exposes `useReadText()` and `useDescribeScene(detections)`. Depends on:
  executorch.
- **`screens/NavigatorScreen`** — wires camera preview + detection overlay +
  action buttons + status/among-us text. The only screen for the MVP.
- **`services/models`** — model source constants + a one-time
  download/warm-up flow with progress UI.

## Tech stack + rationale

| Concern | Choice | Why |
|---|---|---|
| On-device ML (detect/OCR/LLM) | `react-native-executorch` | Already builds on the S25; ships the exact hooks; offline |
| Camera frames | `expo-camera` | Expo-native, SDK-57 compatible, reliable; snapshot loop → `forward(uri)`. (VisionCamera v5 deferred: moved to Nitro stack, no Expo config plugin, heavy bleeding-edge peer deps) |
| Spoken feedback | `expo-speech` | OS TTS, offline, no model download, instant — keeps critical path light |
| Haptics | `expo-haptics` | Simple, reliable; modulate pulse *rate* for intensity |
| Language | TypeScript | The whole app brain is JS — the RN-superiority point |

**Dependency changes (done):** removed `react-native-keychain`,
`react-native-ble-plx`, `react-native-ble-advertiser` (Swarm-era). Kept
`react-native-executorch`. Added `expo-camera`, `expo-speech`, `expo-haptics`.
Evaluated then removed `react-native-vision-camera` + `react-native-worklets-core`
(v5 is Nitro-based, no config plugin, bleeding-edge peers). App is `com.echo.app`,
arm64-v8a. Dev client rebuilt after the changes.

## Feedback design (the UX core)

- **Proximity → haptics:** a repeating pulse whose interval shrinks as closeness
  rises (e.g. 700ms → 120ms) and whose style steps `Light → Medium → Heavy`.
  Silence when no obstacle in the near band. This is "Geiger-counter for
  obstacles" and reads instantly.
- **Identity/direction → speech:** debounced (~every 1.5s, or on change of
  nearest label) to avoid chatter: "chair, close, ahead".
- **Priority:** one obstacle at a time — the largest box in the central region.

## Models & the offline caveat

- Detection: `ssdlite-320-mobilenet-v3-large` (small, fast, COCO 80 classes).
- OCR: default English detector+recognizer.
- LLM: a small instruct model (pick smallest that gives a clean sentence).
- **All fetched on first load (needs wifi once), then cached and fully offline.**
  Provide a first-run "Downloading models…" screen with `downloadProgress`.
  **Pre-download before any offline demo.**

## Risks & mitigations

1. **Snapshot-loop frame rate** (chosen path). `expo-camera` `takePictureAsync`
   has per-shot overhead, so detection runs ~2–4 fps, not buttery real-time.
   Mitigation: fine for a walking-pace demo; keep the shutter silent and reuse a
   low-res capture. Optional post-MVP upgrade: VisionCamera v5 (Nitro) +
   `runOnFrame` for true real-time — separate, clearly-risky task.
2. **Inference/heat.** Mitigation: throttle the loop; SSDLite is light; S25 is a
   flagship.
3. **LLM size/RAM/load time.** Mitigation: smallest viable model; lazy-load only
   when "describe scene" is used; it's a stretch beat, not the core.
4. **Proximity heuristic imprecision.** Mitigation: be honest in the pitch; tune
   thresholds per class; center-weighting reduces false alarms.

## Scope

**MVP (must-have):** camera → real-time detection → proximity haptics + spoken
label/direction, offline.
**In scope (approved stretch):** "Read that" (OCR aloud); "What's around me?"
(LLM scene description).
**Later/none:** depth model, GPS, iOS, multi-obstacle soundscape.
