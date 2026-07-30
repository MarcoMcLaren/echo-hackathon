# Echo — Project Brief (source of truth)

> Read the exact versioned Expo docs at https://docs.expo.dev/versions/v57.0.0/ before writing code. See also [AGENTS.md](AGENTS.md) and the design spec at [docs/superpowers/specs/2026-07-30-echo-blind-navigation-design.md](docs/superpowers/specs/2026-07-30-echo-blind-navigation-design.md).

> **Pivot note:** this project began as *Swarm* (Bluetooth mesh messaging). It has
> pivoted to **Echo**. Mesh / Bridgefy / encryption are no longer in scope.

## What we're building

**Echo** is an **offline, on-device navigation aid for blind and low-vision
users**. Point the phone forward; it detects obstacles from the camera and warns
the user with **haptic feedback** (stronger/faster as an object gets closer) and
**spoken labels** ("chair — close — ahead"). It runs **100% on the phone, with no
internet**, built in React Native / TypeScript.

The thesis for the hackathon: **React Native can do hard, native-grade things** —
real-time computer vision + voice + haptics, offline — from one TypeScript
codebase.

### The three technical pillars

1. **On-device vision (core)** — **react-native-executorch**
   `useObjectDetection` (SSDLite / COCO) run on **expo-camera** frame snapshots
   (~3 fps loop via `forward(imageURI)`). Detects obstacles; bounding-box size
   approximates closeness. Fully offline. (VisionCamera v5 was evaluated for
   buttery real-time but it moved to the Nitro stack and pulls bleeding-edge
   peer deps — deferred as an optional post-MVP upgrade.)
2. **Eyes-free feedback** — **expo-haptics** (pulse rate/intensity scales with
   proximity, "Geiger counter for obstacles") + **expo-speech** (offline OS
   text-to-speech announcing the nearest obstacle and its direction).
3. **On-device AI extras** — **react-native-executorch** `useOCR` ("Read that" →
   speaks a sign/label) and `useLLM` ("What's around me?" → speaks a natural
   sentence describing the scene). All offline.

### Honest limitation (say it in the pitch)

No depth sensor on the device and no depth model in ExecuTorch → "distance" is
inferred from bounding-box size. A solid demo heuristic, not true metric depth.

## Build strategy (shapes everything)

- **Expo with a custom dev client** (`expo-dev-client`), **not Expo Go** — Expo
  Go cannot load these native libraries.
- Build the dev client **locally with Gradle**, **not EAS cloud**.
- **Android only** for now. **Physical device only** (ExecuTorch ships arm64-v8a
  only; also does not run on emulators).
- Native builds are restricted to **arm64-v8a** (`android/gradle.properties`) —
  required by ExecuTorch and keeps builds fast. Exact toolchain versions live in
  [SETUP.md](SETUP.md).
- **Models download once over wifi, then run fully offline.** Pre-download before
  any offline demo.
- Only **1–2 people** need the build environment; everyone else installs the
  debug APK and runs `npx expo start --dev-client` to hot-reload JS.

## This is a time-boxed hackathon project (Saturday)

Prefer **simple, working, demoable** solutions over production-grade complexity.
When in doubt, pick the path that gets a live demo running fastest. De-risk plan:
prove detect → feedback with a simple frame loop before chasing smooth real-time.

## Folder structure convention

Feature-first. New code lands here:

```
src/
├── assets/            # images, icons, fonts
├── components/        # reusable UI (Button, Card)
├── features/
│   ├── vision/        # camera + object detection (executorch + expo-camera)
│   │   ├── api/  components/  hooks/ (useObstacles)  types/
│   ├── feedback/      # proximity → haptics + speech
│   │   ├── api/  components/  hooks/ (useProximityFeedback)  types/
│   └── ai/            # OCR "read that" + LLM "describe scene"
│       ├── api/  components/  hooks/ (useReadText, useDescribeScene)  types/
├── hooks/             # global hooks used across features
├── screens/           # NavigatorScreen (the single MVP screen)
├── services/          # models/ (download + warm-up), shared logic
├── store/             # global state — Zustand (low boilerplate)
├── styles/            # global theme/style constants
├── utils/             # generic helpers (proximity math, direction)
└── App.tsx            # root component (registered by /index.ts)
```

Rules of thumb:
- Anything used by only one feature lives under that feature's folder.
- Anything shared across features lives in the top-level folder of its kind.
- `index.ts` barrels re-export each folder's public surface.
- Proximity/direction math lives in `utils/` as **pure functions** (unit-testable,
  no native calls).
