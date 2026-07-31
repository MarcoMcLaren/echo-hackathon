# Echo

**Echo** is an **offline-first, 100%-on-device** app built in **React Native + TypeScript** that does two hard things at once — a **navigation aid for blind & low-vision users** and **infrastructure-free mesh messaging** — to prove one point: **React Native can do native-grade work.** Real-time computer vision, on-device LLMs, Bluetooth/Wi-Fi peer networking, haptics, offline speech, and hardware-backed crypto — all from one TypeScript codebase, hot-reloaded live.

> Android-only, physical device (arm64). Built as a custom **Expo dev client** (local Gradle — no Expo Go, no cloud). See **[SETUP.md](SETUP.md)** to run it and **[CLAUDE.md](CLAUDE.md)** for the full brief.

## Two capabilities

- **👁️ Navigation aid** — point the phone forward; it detects obstacles from the camera and warns with **haptics** (stronger/faster as you near something) and **spoken labels** ("chair — close — ahead").
- **📡 Offline mesh messaging** — phone-to-phone messaging with **no cell and no wifi**; every phone relays for others, so it works where networks fail (stadiums, protests, disasters).

Tied together by **on-device AI**: OCR ("read that"), scene description, and message-thread summaries — all offline.

## Native capabilities (all in one APK)

| Capability | Native libs (all in the APK) |
|---|---|
| On-device AI | `react-native-executorch` (detection · OCR · LLM) |
| Blind-nav feedback | `expo-camera` · `expo-speech` · `expo-haptics` |
| Offline mesh | `expo-nearby-connections` + `react-native-nitro-modules` |
| E2E keys | `react-native-keychain` (hardware-backed) |

## The ideas, the libraries, and how they show off React Native

Every feature reaches through React Native into a different native subsystem. The pattern is always the same: **the heavy lifting is native (C++/Kotlin); the orchestration is TypeScript.**

### 🧠 On-device AI — `react-native-executorch`
Run real ML models on the phone with **no server**. ExecuTorch is PyTorch's on-device inference runtime (C++); the RN wrapper exposes it through **JSI**, so JavaScript calls native inference directly. Models are `.pte` files running on the CPU/NPU via XNNPACK. One hook each: `useObjectDetection` (obstacles), `useOCR` (read signs), `useLLM` (summaries / scene description). This is the "wait — RN can run a whole LLM *offline*?" moment.

### 📷 Camera + vision — `expo-camera`
Native camera access, exposed to JS. We grab frames and feed them straight into ExecuTorch's detector — a TypeScript loop driving a native camera driving a native ML runtime.

### 📳 Eyes-free feedback — `expo-haptics` + `expo-speech`
`expo-haptics` drives the phone's vibration motor (Android `VibrationEffect`); we modulate pulse rate/intensity by proximity — a "Geiger counter for obstacles." `expo-speech` uses the OS text-to-speech engine (offline). RN reaching hardware actuators and the OS speech stack.

### 📡 Offline mesh — `expo-nearby-connections` + `react-native-nitro-modules`
`expo-nearby-connections` wraps Google's **Nearby Connections** API, which forms peer-to-peer links over **Bluetooth + BLE + Wi-Fi Direct** — no internet, no router. It's built on **Nitro Modules** (Margelo's modern native-module framework: type-safe, JSI/C++ codegen — faster than the classic bridge). RN doing genuine peer-to-peer radio networking. *(Nearby is P2P clustering — mesh-like in a room; true multi-hop relay is app-layer logic we add on top.)*

### 🔒 Hardware-backed keys — `react-native-keychain`
Stores crypto keys in the **Android Keystore** — hardware-backed secure storage (TEE / StrongBox). Because mesh relays are strangers' phones, messages are **end-to-end encrypted** and keys **never leave the secure hardware**. RN reaching the phone's secure enclave.

## The big picture — why this is a "true React Native" showcase

React Native once had a reputation for "simple UIs only." This app is the counter-argument, and it works because of RN's modern architecture:

- **JSI (JavaScript Interface)** lets JavaScript call C++/native code **synchronously**, holding direct references instead of serializing messages over the old async "bridge." That's what makes real-time ML inference and high-throughput native modules feasible from JS.
- **The New Architecture** (Fabric + TurboModules, `newArchEnabled=true`) is on — the same foundation ExecuTorch and Nitro build on.
- **Native modules + autolinking** mean each library ships its own Kotlin/C++, and on your side you just `import` a hook. Wrapping native power cleanly *is* RN's superpower — you don't rewrite the camera or the ML runtime, you **drive** them.
- **A custom Expo dev client** gives us all of the above **plus** Expo's developer experience: config plugins and **hot reload** — edit TypeScript, see it live on the phone instantly. (Expo Go can't load custom native code; our own dev client can.)

The result: **one TypeScript codebase** orchestrating the camera, an ML runtime, Bluetooth/Wi-Fi radios, the vibration motor, the OS speech engine, and the hardware keystore — **offline**. The native libraries are the hands; TypeScript is the brain.

## Where the AI models come from

The models are **not** in the APK and **not** pre-installed (that's why the APK stays ~100 MB). They're hosted on **Hugging Face** — the download URLs are baked into `react-native-executorch`'s model constants — and **each phone downloads them once on first use, caches them locally, then runs 100% offline.**

- **Fetching is wired** via `initExecutorch({ resourceFetcher: ExpoResourceFetcher })` in [`src/services/models`](src/services/models/index.ts), using `expo-file-system` to cache to device storage.
- **`ModelPreloadScreen`** (the current home screen) pre-downloads them with a progress bar — run it **on wifi before an offline demo**.
- **Per phone, one-time, needs wifi once.** Sizes: vision (detection + OCR) ≈ **50 MB**; language model (summaries) ≈ **400 MB**. Exact table in [SETUP.md](SETUP.md).

## Getting started

Most contributors don't build anything — install the shared APK and hot-reload your own code on your own phone. See **[SETUP.md → Path A](SETUP.md)**. The 1–2 designated builders use **Path B**.

## Docs

- **[CLAUDE.md](CLAUDE.md)** — project brief / source of truth
- **[SETUP.md](SETUP.md)** — setup + build (contributor & builder paths), model download list + sizes
- **[Design spec](docs/superpowers/specs/2026-07-30-echo-blind-navigation-design.md)** — the blind-navigation design
