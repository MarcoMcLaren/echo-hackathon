# Echo — Project Brief (source of truth)

> Read the exact versioned Expo docs at https://docs.expo.dev/versions/v57.0.0/ before writing code. See also [AGENTS.md](AGENTS.md) and the design spec at [docs/superpowers/specs/2026-07-30-echo-blind-navigation-design.md](docs/superpowers/specs/2026-07-30-echo-blind-navigation-design.md).

> **History / scope:** started as *Swarm* (Bluetooth mesh), then narrowed to
> *Echo* (blind-navigation aid). It is now scoped to do **BOTH**, under the Echo
> umbrella: the **navigation aid** *and* **offline mesh messaging**. Bridgefy is
> out (card-gated signup); the mesh transport is still being chosen — see Build
> strategy. **The mesh transport is not in the current build yet.**

## What we're building

**Echo** is an **offline-first, 100%-on-device** app in React Native / TypeScript
with **two capabilities**:

**A. Navigation aid for blind & low-vision users.** Point the phone forward; it
detects obstacles from the camera and warns with **haptics** (stronger/faster as
an object nears) and **spoken labels** ("chair — close — ahead").

**B. Offline mesh messaging.** Phone-to-phone messaging with **no cell and no
wifi** — devices relay for each other, so it works when infrastructure fails
(packed stadiums, protests, disasters, remote areas).

Woven through both: **on-device AI** — OCR ("read that"), scene description
("what's around me?"), and **message-thread summaries** — all offline.

The hackathon thesis: **React Native can do hard, native-grade things** —
real-time computer vision, voice, haptics, peer-to-peer networking, and on-device
LLMs — offline, from one TypeScript codebase.

### The technical pillars

1. **On-device vision** — **react-native-executorch** `useObjectDetection`
   (SSDLite / COCO) on **expo-camera** frame snapshots (~3 fps via
   `forward(imageURI)`). Obstacle detection; bounding-box size ≈ closeness.
2. **Eyes-free feedback** — **expo-haptics** (pulse rate/intensity scales with
   proximity) + **expo-speech** (offline OS text-to-speech).
3. **On-device AI** — **react-native-executorch** `useOCR` ("read that"),
   `useLLM` (scene description **and** message-thread summaries). All offline.
4. **Offline mesh messaging** — phone-to-phone relay with no internet.
   **Transport TBD** (leading candidate: `expo-nearby-connections`; must be
   build-verified on RN 0.86 first). **Not wired into the current APK yet.**

### Honest limitations (say them in the pitch)

- No depth sensor and no depth model → "distance" is inferred from bounding-box
  size. A solid demo heuristic, not true metric depth.
- Google-Nearby-style transport is P2P clustering (mesh-like in a room); true
  multi-hop relay past radio range is app-layer logic we add on top.

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
  any offline demo. Model list + sizes are in [SETUP.md](SETUP.md).
- **Mesh transport is not yet added.** Adding it is a *native* change → a new
  dev-client APK for everyone. Leading candidate: **`expo-nearby-connections`**
  (Expo module; pulls `react-native-nitro-modules`; verify it builds on RN 0.86
  before committing). Bridgefy was dropped (card-gated).
- Only **1–2 people** need the build environment; everyone else installs the
  debug APK and runs `npx expo start --dev-client` to hot-reload JS.

## This is a time-boxed hackathon project (Saturday)

Prefer **simple, working, demoable** solutions over production-grade complexity.
Two capabilities is ambitious for one day — **land the blind-navigation core
first** (it reuses libraries that already build and needs no second device), then
add mesh messaging as the stretch once its transport is proven. When in doubt,
pick the path that gets a live demo running fastest.

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
│   ├── ai/            # OCR "read that" + LLM (describe scene, summarize threads)
│   │   ├── api/  components/  hooks/ (useReadText, useDescribeScene, useSummarize)  types/
│   └── messaging/     # offline mesh messaging (transport + relay + chat UI)
│       ├── api/  components/  hooks/ (useMesh)  types/
├── hooks/             # global hooks used across features
├── screens/           # NavigatorScreen, MessagingScreen
├── services/          # models/ (download + warm-up), shared logic
├── store/             # global state — Zustand (low boilerplate)
├── styles/            # global theme/style constants
├── utils/             # generic helpers (proximity math, direction, message relay)
└── App.tsx            # root component (registered by /index.ts)
```

Rules of thumb:
- Anything used by only one feature lives under that feature's folder.
- Anything shared across features lives in the top-level folder of its kind.
- `index.ts` barrels re-export each folder's public surface.
- Proximity/direction and message-relay (TTL/dedupe) math lives in `utils/` as
  **pure functions** (unit-testable, no native calls).
