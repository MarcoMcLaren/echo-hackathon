# Echo — Team Setup & Dev Guide

**Echo** is an offline-first, on-device React Native app with **two
capabilities**: a **navigation aid for blind & low-vision users** (camera →
obstacle detection → haptics + spoken labels) **and offline mesh messaging**
(phone-to-phone, no cell or wifi). All AI runs on the device. See
[CLAUDE.md](CLAUDE.md) and the [design spec](docs/superpowers/specs/2026-07-30-echo-blind-navigation-design.md).
(The mesh-messaging transport is **not in the current build yet** — see App
libraries below.)

This guide has **two paths**. Pick the one that's you:

- **Path A — Contributor (almost everyone).** Get the app on your phone, edit
  code, see it live. **No Android SDK, no long build.** ~10 minutes. Works on
  Windows, macOS, or Linux.
- **Path B — Builder (only 1–2 people).** Produce/update the shared `.apk` when
  **native** dependencies change. Heavier setup. See the bottom of this doc.

### How this works (read once — it explains everything)

The app is an **Expo custom dev client**: the `.apk` is a shell that loads your
JavaScript live from a "Metro" server running on your laptop.

- **A builder makes the `.apk` once.** Everyone installs that same file.
- **You run Metro (`npx expo start --dev-client`) on your laptop.** Your phone
  connects to it and runs your code, hot-reloading on every save.
- **Editing JS/TS = instant reload. No new build needed.**
- **You only need a NEW `.apk` when someone changes NATIVE stuff** — adds a
  native library, or edits `app.json` / permissions. Pure JS/TS changes never
  need a rebuild. (If your app suddenly won't connect after a `git pull`, ask a
  builder whether native deps changed and grab a fresh `.apk`.)

The repo does **not** contain the `.apk` or the `android/` folder (both are
git-ignored). Contributors get the `.apk` from a builder; builders regenerate
`android/` with `expo prebuild`.

---

# Path A — Contributor (get the app + start coding)

## A1. Install prerequisites (one-time)

You only need **Node.js (LTS)** and **Git**. No Java, no Android SDK.

- **Windows:** `winget install OpenJS.NodeJS.LTS Git.Git`
- **macOS:** `brew install node git`
- **Linux:** use your package manager (or [nvm](https://github.com/nvm-sh/nvm)) for Node LTS + `git`

Verify:

```bash
node -v   # expect v20+ (v22 is what the team uses)
git --version
```

## A2. Clone the repo + install JS deps

```bash
git clone <REPO_URL> echo
cd echo
npm install
```

## A3. Put the app on your phone (get the `.apk` from a builder)

1. Ask a builder for **`app-debug.apk`** (they'll drop it in the team's shared
   Drive / chat). It is *not* in the repo.
2. On your Android phone: **Settings → Apps → Special access → Install unknown
   apps** → allow your browser/file manager. (Android will also prompt you when
   you tap the file.)
3. Copy the `.apk` to your phone and **tap it to install**. You now have "Echo".

> The `.apk` is arm64-v8a — fine for essentially every phone from ~2017 on.

## A4. Start the dev server and connect your phone

Same Wi-Fi on laptop + phone is the easy path (no cables, no adb):

```bash
npx expo start --dev-client
```

- Open **Echo** on your phone → it shows a dev launcher.
- **Scan the QR code** in your terminal (or tap the `http://<your-ip>:8081` URL
  shown in the launcher). It loads your code.
- If Wi-Fi blocks the connection (some corporate/guest networks do), use a
  cable: enable **USB debugging** on the phone, plug in, and run
  `npx expo start --dev-client` — or fall back to `npx expo start --tunnel`.

## A5. Code and see it live

Edit anything under `src/` → **save** → the phone reloads instantly (Fast
Refresh). That's the whole loop. Everyone runs their own Metro against their own
phone, independently.

## A6. Contribute your changes (git)

```bash
git checkout -b your-name/feature
# ...edit, test on your phone...
git add -A
git commit -m "what you changed"
git push -u origin your-name/feature
# open a Pull Request for someone to review + merge
```

Keep native changes (new libraries, `app.json`) on their own PR and tell the
team — those are the ones that require a fresh `.apk` for everybody.

**That's it for contributors. Everything below is for builders only.**

---

# Path B — Builder (produce/update the shared `.apk`)

Only **1–2 people** need this. Do it once to create the `.apk`, and again only
when native dependencies change. The verified environment below is **Windows**;
on macOS/Linux the same steps apply (use `brew` / your package manager and the
Linux/Mac `sdkmanager`) — ask Claude to adapt the commands.

> Tip: you can literally tell Claude Code "follow SETUP.md Path B" and approve
> the prompts — it will install the SDK, prebuild, and build for you. You still
> have to enable USB debugging and tap **"authorize this computer"** on the phone
> yourself.

## B1. Prerequisites

| Tool | Version | Install (Windows) |
|---|---|---|
| JDK | **17** (Temurin/Oracle 17.x) | `winget install EclipseAdoptium.Temurin.17.JDK` |
| Node.js | 20+ (team uses 22) | `winget install OpenJS.NodeJS.LTS` |
| Git | any | `winget install Git.Git` |

Set `JAVA_HOME` to the JDK 17 folder if it isn't already.

## B2. Install the Android SDK command-line tools (no Android Studio)

1. Download **"Command line tools only"** for your OS from
   https://developer.android.com/studio#command-line-tools-only
2. Extract so `sdkmanager` lives at
   `%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat`
   (macOS/Linux: `~/Library/Android/sdk/...` or `~/Android/Sdk/...`).
3. Set env vars: `ANDROID_HOME` and `ANDROID_SDK_ROOT` = that `Sdk` folder; add
   `.../cmdline-tools/latest/bin` and `.../platform-tools` to `PATH`.
4. Install packages + accept licenses:

```bash
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" "ndk;27.1.12297006" "cmake;3.22.1"
sdkmanager --licenses
```

## B3. Generate the native project + build

```bash
npm install
npx expo prebuild --clean --platform android
```

Then re-apply the one manual tweak prebuild resets — in
`android/gradle.properties` set:

```
reactNativeArchitectures=arm64-v8a
```

(Required: ExecuTorch ships arm64-v8a/x86_64 only; also keeps builds fast.)
Make sure `android/local.properties` has `sdk.dir=<path to your Sdk>`. Then:

```bash
android\gradlew.bat -p android assembleDebug      # Windows
# ./gradlew -p android assembleDebug               # macOS/Linux
```

First clean build ≈ 15–20 min (NDK/C++); later builds ≈ 1–2 min.
**Output:** `android/app/build/outputs/apk/debug/app-debug.apk` (~97 MB).

## B4. Test on a physical device (required — no emulators)

Enable USB debugging, plug in, authorize the computer on the phone, then:

```bash
npx expo run:android        # builds if needed, installs, launches, starts Metro
```

## B5. Distribute the `.apk` to the team

Upload `android/app/build/outputs/apk/debug/app-debug.apk` to the team's shared
Drive / chat. Contributors follow **Path A step A3**. Re-share a new `.apk`
whenever native deps or `app.json` change (bump a version in the message so
people know to reinstall).

---

## Toolchain versions (verified working — builders)

| | |
|---|---|
| JDK | 17.0.12 LTS · Node 22.13.1 · npm 11.4.2 |
| Android compileSdk/targetSdk | 36 · minSdk 24 · build-tools 36.0.0 |
| NDK 27.1.12297006 · CMake 3.22.1 | AGP 8.12.0 · Kotlin 2.1.20 · Gradle 9.3.1 |
| Expo SDK ~57.0.9 · React Native 0.86.2 · React 19.2.3 | App id `com.echo.app`, arm64-v8a |
| Verified device | Samsung Galaxy SM-S938B (S25 Ultra) |

### App libraries

| Library | Version | Role |
|---|---|---|
| `react-native-executorch` | 0.9.2 | On-device object detection (SSDLite/COCO), OCR, LLM. C++ via CMake; arm64-v8a/x86_64 only. |
| `expo-camera` | ~57.0.3 | Camera preview + snapshots fed to detection. |
| `expo-speech` | ~57.0.1 | Offline text-to-speech for spoken feedback. |
| `expo-haptics` | ~57.0.1 | Proximity haptics. |
| `expo-nearby-connections` | ^1.1.0 | Offline mesh transport (Google Nearby: Bluetooth + Wi-Fi Direct). |
| `react-native-nitro-modules` | ^0.36.5 | Native runtime that `expo-nearby-connections` is built on. |
| `react-native-keychain` | ^10.0.0 | Hardware-backed key storage (Android Keystore) for E2E-encrypted messaging. |
| `react-native-audio-api` | ^0.13.2 | Microphone capture (16 kHz mono Float32 PCM) feeding on-device dictation. |

> **`expo-nearby-connections` needs a shipped-file fix (automatic).** v1.1.0's
> `android/build.gradle` does `apply from: './fix-prefab.gradle'`, but that file
> is missing from the npm tarball → the Android build fails. A **postinstall**
> (`scripts/fix-nearby-prefab.js`, vendoring `scripts/nearby-fix-prefab.gradle`)
> restores it, so `npm install` self-heals — builders don't do anything manual.

> **`react-native-audio-api` needs a Windows build fix (automatic).** Its
> `downloadPrebuiltBinaries` Gradle task runs a bash script through
> `C:\Program Files\Git\usr\bin\bash.exe`. Launched directly like that, bash
> skips the MSYS profile, so `/usr/bin` is never on `PATH` — the script's
> `mkdir -p` fails silently, every `curl -o` into the missing temp dir dies with
> `(23) client returned ERROR on write`, and the task exits **127** on
> `rm: command not found`. A **postinstall**
> (`scripts/fix-audio-api-bash-path.js`) rewrites that one `commandLine` to
> `bash -c 'export PATH=/usr/bin:$PATH; …'`, so `npm install` self-heals.
> Upstream issue [#1012] is closed with no fix shipped. Setting `PATH` via
> Gradle's `environment` does **not** work — on Windows the task's env map is
> seeded from `System.getenv()`, whose key is `Path`, so adding `PATH` just
> leaves two entries and the child keeps the original.
>
> [#1012]: https://github.com/software-mansion/react-native-audio-api/issues/1012

> **Plugin config is deliberate, not default.** `app.json` passes
> `androidPermissions: ["android.permission.RECORD_AUDIO"]` because the plugin's
> default list does **not** include it (it defaults to foreground-service *media
> playback* permissions). We also set `androidForegroundService: false` — Echo
> only records while you hold the button, and the default would declare a
> `mediaPlayback` service we never use — and `disableFFmpeg: true`, since we
> capture raw PCM and never decode audio files.

> **Planned / not in the current build:**
> - **Sidequest (datacenter GPU)** — online-only; **no native lib** (authenticated
>   network calls), so no new APK needed. Breaks the offline story — keep opt-in.

## AI models to download (ExecuTorch)

All models are fetched on **first use** over wifi, cached, then run **fully
offline**. **Pre-download everything on wifi before any offline demo.** Each hook
(`useObjectDetection` / `useOCR` / `useLLM`) exposes `downloadProgress` for a
loading screen. Sizes below are exact (measured from the model host).

**How it's wired:** the host screen is `src/screens/ModelPreloadScreen.tsx`;
fetching is registered in `src/services/models` via
`initExecutorch({ resourceFetcher: ExpoResourceFetcher })` (needs
`expo-file-system` + `expo-asset`). Files download from Hugging Face and cache
**per phone** in app storage — so every teammate's device downloads its own copy
once. Uninstalling / clearing app data wipes the cache (re-download needed).

| Feature | Hook | Model constant | Download |
|---|---|---|---|
| Obstacle detection → haptics | `useObjectDetection` | `SSDLITE_320_MOBILENET_V3_LARGE` | **13.3 MB** |
| OCR "read that" | `useOCR` | `OCR_ENGLISH` (CRAFT detector 19.9 MB + English CRNN 17.5 MB) | **37.4 MB** |
| Read text aloud | — | `expo-speech` (OS TTS) | **0 MB** |
| Dictate a message (hold the mic) | `useSpeechToText` | `WHISPER_TINY_EN` (model 221.8 MB + tokenizer 2.3 MB) | **224.1 MB** |
| Summaries / describe scene | `useLLM` | `QWEN2_5_0_5B_QUANTIZED` (recommended start) | **398 MB** |
| ⤷ better quality | `useLLM` | `LLAMA3_2_1B_SPINQUANT` or `QWEN2_5_1_5B_QUANTIZED` | **~1.08 GB** |

- **Blind-nav core footprint ≈ 50 MB** (detection + OCR; speech needs no model).
  The LLM is the only heavy download.
- Start with **Qwen2.5 0.5B (398 MB)** — low-RAM, fine on any modern phone. Move
  to a 1B–1.5B model only if summaries feel weak (needs ~1–2 GB free RAM at
  runtime). Each LLM also pulls small tokenizer/config files (a few MB).

```ts
import {
  useObjectDetection, SSDLITE_320_MOBILENET_V3_LARGE,
  useOCR, OCR_ENGLISH,
  useLLM, QWEN2_5_0_5B_QUANTIZED,
} from 'react-native-executorch';
// + expo-speech for reading text aloud
```

## Runtime notes

- **Models download once over Wi-Fi, then run fully offline.** ExecuTorch fetches
  model binaries on first use. Pre-download before any offline demo.
- **Camera permission** is requested at runtime on first use — grant it.

## Setup conflicts hit + resolutions

| Library | Symptom | Resolution |
|---|---|---|
| `react-native-vision-camera@5` | `expo prebuild` crashed — v5 moved to the Nitro stack, no Expo config plugin, extra bleeding-edge peers | Dropped for MVP; use `expo-camera` snapshots → `useObjectDetection.forward(uri)`. VisionCamera v5 + `runOnFrame` is an optional post-MVP real-time upgrade. |
| `expo-nearby-connections@1.1.0` | Gradle failed: `Could not read script '.../fix-prefab.gradle'` (missing from npm tarball), cascading to `:expo > SoftwareComponent 'release' not found` | Restored the file (from the lib's repo) via a `postinstall` script. Then builds clean — Nitro C++ compiles on RN 0.86. |
| ExecuTorch + expo-camera/speech/haptics + nearby/nitro on RN 0.86 | none — built clean | — |
| `react-native-audio-api@0.13.2` | Gradle failed: `:react-native-audio-api:downloadPrebuiltBinaries` exit **127**, preceded by `curl: (23) client returned ERROR on write` and `rm: command not found`. Windows-only — `bash.exe` invoked directly has no `/usr/bin` on `PATH`, so the script's `mkdir`/`rm`/`unzip` never resolve and `common/cpp/audioapi/external/android` stays empty | `postinstall` rewrites the task to `bash -c 'export PATH=/usr/bin:$PATH; …'` (`scripts/fix-audio-api-bash-path.js`). Then builds clean on RN 0.86. |

> Mesh history: `bridgefy-react-native` (which needed `desugar_jdk_libs ≥ 2.1.5`)
> was dropped — its SDK signup is card-gated. Mesh messaging is **back in scope**
> with a different, still-to-be-verified transport (see App libraries above).
