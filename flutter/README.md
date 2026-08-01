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
