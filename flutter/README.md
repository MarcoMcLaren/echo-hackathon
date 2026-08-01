# echo (Flutter port)

The Flutter port of Echo, scaffolded from a basic Flutter app used to verify
the toolchain set up in [SETUP_FLUTTER.md](../SETUP_FLUTTER.md) (see that doc
for prerequisites — JDK, Flutter SDK, Android SDK). The Android
`applicationId` is still `com.echo.hackathon.welcome_app` from that
verification step; the commands below reflect the current, unrenamed value.

## Run it on your phone

Plug your Android phone in via USB with **USB debugging** enabled (Settings →
Developer options → USB debugging), then confirm it's visible:

```powershell
adb devices -l
```

If more than one device/emulator shows up, every command below needs `-s <serial>`
to target the right one (see Troubleshooting).

### Option A — `flutter run` (simplest, live reload)

```powershell
cd flutter
flutter run
```

This builds, installs, launches, and keeps a session attached for hot reload
(press `r`) — pick this for active development.

### Option B — build an APK and install it manually

Useful when you just want the app on the phone without an attached `flutter run`
session (e.g. scripting it, or `flutter run`'s interactive session is awkward
in your terminal):

```powershell
cd flutter
flutter build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb shell am start -n com.echo.hackathon.welcome_app/com.echo.hackathon.welcome_app.MainActivity
```

> **First install on a device:** Android may show an **"Allow installation via
> USB?"** prompt on the phone screen — you have to tap Accept there before
> `adb install` succeeds. If it fails with `INSTALL_FAILED_USER_RESTRICTED`,
> check the phone screen for that prompt, or enable **Install via USB** in
> Developer options.

Verify it actually launched (rather than trusting `am start`'s output, which
succeeds even if the app immediately crashes):

```powershell
adb shell pidof com.echo.hackathon.welcome_app          # should print a PID
adb shell dumpsys window | findstr mCurrentFocus         # should show welcome_app's MainActivity
```

## Mesh transport (Nearby Connections)

`lib/features/messaging/nearby_transport.dart` implements the mesh transport
for real using [`nearby_connections`](https://pub.dev/packages/nearby_connections)
(Android — Google Nearby Connections over BLE + Wi-Fi, `Strategy.P2P_CLUSTER`).
It advertises and discovers simultaneously, so any phones running the app in
the same room can find and connect to each other directly; `MeshStore`'s
relay logic (`lib/utils/relay.dart`) is what extends reach past direct radio
range, same as upstream.

`lib/config.dart`'s `useRealTransport` flag picks it: `true` wires
`NearbyTransport` into the app in `lib/main.dart`, `false` falls back to the
demo `MockTransport`. Every existing automated test still runs against
`MockTransport` directly (or via `EchoApp()` without ever calling
`MeshStore.start()`), since platform channels — what `nearby_connections` and
`permission_handler` are built on — don't run under `flutter test`.

**Permissions.** `android/app/src/main/AndroidManifest.xml` declares
`BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`,
`ACCESS_FINE_LOCATION`, and `NEARBY_WIFI_DEVICES`. All five are requested at
runtime by `lib/features/messaging/nearby_permissions.dart` before
`NearbyTransport.start()` touches the radio; a denial surfaces through the
same `TransportStartResult.failure`/`MeshStore.error` path a radio failure
would, so the UI never crashes on "permission denied" — it just shows the
existing mesh-error state.

**Gradle risk — untested here, no Android SDK in this sandbox.**
`nearby_connections` was last published ~17 months ago and its
`android/build.gradle` uses the old imperative `buildscript { classpath
'com.android.tools.build:gradle:7.4.2' }` style rather than this project's
declarative AGP 9 plugin block in `android/settings.gradle.kts`. It has a
`hasProperty("namespace")` guard, which is a good sign, but a stale plugin
build file conflicting with AGP 9 is a common failure mode. **The first
`flutter build`/`flutter run` on real hardware may fail here.** If it does,
try lowering the AGP version pinned in `android/settings.gradle.kts` before
reaching for anything more invasive (forking the plugin, editing its build
files by hand).

**Honest limit — this could not be verified by CI or in this sandbox.** There
are no Android devices or radios here, so nothing about Bluetooth/Wi-Fi
discovery, connection, or payload delivery has actually been exercised. The
gate for this work is `flutter analyze` + `flutter test` passing (they do)
and the code compiling against the plugin's real, current API — not a live
mesh. **A human must verify the following on two physical phones** before
trusting this in a demo:

1. Build and install the debug APK on both phones (see *Run it on your
   phone* above), with `useRealTransport = true` in `lib/config.dart`.
2. Open the app on both, get past the lock screen, and land on **Reach**.
   Trigger whatever starts the mesh (however `MeshStore.start()` is wired
   into the UI at the time you test — check `ReachScreen`/`TapScreen`).
3. On first start, confirm the OS permission prompts appear (Bluetooth
   nearby devices / location) and that accepting them lets the mesh reach
   `MeshStatus.live` — no error banner.
4. With both phones' screens on and within a few meters, confirm each phone
   shows the other as a connected peer (a new thread appears titled with the
   other phone's display name) within a few seconds.
5. Send a text message from phone A to phone B's thread; confirm it appears
   on B with `hops: 0` and vice versa.
6. Send a photo (large enough to exceed one Nearby payload) and confirm it
   reassembles correctly on the receiving end — this exercises
   `chunkEnvelope`/`Reassembler` over the real wire, not just in tests.
7. Turn off Bluetooth on one phone mid-session; confirm the peer is dropped
   from the other phone's peer list (thread's hop count clears) rather than
   left as a stale "connected" ghost.
8. Deny a permission on a fresh install and confirm the mesh shows a
   readable error instead of crashing.
9. Background and foreground the app on both phones; confirm the mesh either
   stays connected or cleanly reconnects rather than getting stuck in
   `starting`.

## Troubleshooting

- **`adb: more than one device/emulator`** — pass `-s <serial>` (from `adb devices -l`)
  to every `adb` command, e.g. `adb -s 2b4bf8aa install -r ...`.
- **App not coming to the foreground** — if you're actively using the phone at
  the same moment, whatever's on-screen may just be your own foreground app;
  `am start`/`dumpsys` above tell you the real state regardless of what's
  currently visible.
- **`flutter` / `adb` / `java` not found** — see the PATH caveat in
  [SETUP_FLUTTER.md](../SETUP_FLUTTER.md#the-path-caveat-that-will-bite-you-once):
  a new terminal is needed after the initial setup.

## Getting Started (stock Flutter links)

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)
