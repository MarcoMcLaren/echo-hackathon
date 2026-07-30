# Echo — Team Setup & Dev Guide

**Echo** is an offline, on-device navigation aid for the blind (see
[CLAUDE.md](CLAUDE.md) and the [design spec](docs/superpowers/specs/2026-07-30-echo-blind-navigation-design.md)).

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

## Runtime notes

- **Models download once over Wi-Fi, then run fully offline.** ExecuTorch fetches
  model binaries on first use. Pre-download before any offline demo.
- **Camera permission** is requested at runtime on first use — grant it.

## Setup conflicts hit + resolutions

| Library | Symptom | Resolution |
|---|---|---|
| `react-native-vision-camera@5` | `expo prebuild` crashed — v5 moved to the Nitro stack, no Expo config plugin, extra bleeding-edge peers | Dropped for MVP; use `expo-camera` snapshots → `useObjectDetection.forward(uri)`. VisionCamera v5 + `runOnFrame` is an optional post-MVP real-time upgrade. |
| ExecuTorch + expo-camera/speech/haptics on RN 0.86 | none — built clean | — |

> Pre-pivot: `bridgefy-react-native` needed `desugar_jdk_libs ≥ 2.1.5`. Bridgefy
> is no longer in the project (Echo replaced the Swarm mesh concept).
