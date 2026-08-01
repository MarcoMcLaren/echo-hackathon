# Flutter Development Environment Setup (Windows)

> **Scope note:** Echo itself is a React Native / Expo app (see [CLAUDE.md](CLAUDE.md) and
> [SETUP.md](SETUP.md)) — Flutter is **not** part of the Echo codebase. This guide documents a
> standalone Flutter dev environment set up on this machine, verified step-by-step. If you're
> working on Echo, use [SETUP.md](SETUP.md) instead.

Audience: developers setting up a Windows machine for Flutter (Android target) from scratch.

Everything below was actually run on this machine — steps, exact commands, and the
**"Caveats hit" callouts** reflect real failures encountered and how they were resolved, not just
the theoretical happy path.

## Software checklist (this machine's state after setup)

| Software | Status | Version |
|---|---|---|
| Git | Already present | 2.47.1 |
| Visual Studio Code | Already present | 1.131.0 |
| JDK 17 (Temurin) | Installed | 17.0.20+8 |
| Flutter SDK | Installed | 3.44.8 (stable channel) |
| Android SDK cmdline-tools | Installed | 13.114758 |
| Android SDK platform / build-tools | Installed | android-36 platform · build-tools 35.0.0 & 28.0.3 |
| Android Emulator (AVD) | Created | `Pixel_8_API_35` — Android 15 (API 35), google_apis, **x86_64** |
| VS Code extensions | Installed | Flutter, Dart, Error Lens, GitLens, Prettier |
| Android Studio | Installed (IDE only) | 2026.1.3.7 — SDK managed via CLI instead, see below |
| Chrome (web target) | **Not installed** | optional — only needed for `flutter run -d chrome` |
| VS "Desktop development with C++" | **Not installed** | optional — only needed for Windows-desktop Flutter target |

The last two are genuinely optional: this setup targets **Android app development**, which is
what the standard Flutter checklist (and this doc) covers. `flutter doctor` will show `Chrome` and
`Visual Studio` as unresolved unless you also want web or Windows-desktop targets.

---

## Step 1 — Git

Already installed on this machine. If starting fresh:

```powershell
winget install --id Git.Git --exact
```

## Step 2 — JDK 17 (Temurin)

```powershell
winget install --id EclipseAdoptium.Temurin.17.JDK --exact --accept-package-agreements --accept-source-agreements
```

Then set `JAVA_HOME` and add its `bin` to `PATH` (User scope, no admin needed):

```powershell
$jdkPath = (Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Directory -Filter "jdk-17*" | Select-Object -First 1).FullName
[Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkPath, "User")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
[Environment]::SetEnvironmentVariable("Path", "$userPath;$jdkPath\bin", "User")
```

> **Caveat hit:** the winget Temurin package does **not** reliably add `java` to `PATH` or set
> `JAVA_HOME` itself — do it manually as above, or `flutter doctor` will not find a JDK.

## Step 3 — Flutter SDK

> **Caveat hit:** there is **no official Flutter SDK package on winget** (`winget search flutter`
> returns unrelated apps tagged "flutter"). Download the SDK zip directly instead:

```powershell
New-Item -ItemType Directory -Force -Path "C:\src" | Out-Null
Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.44.8-stable.zip" -OutFile "C:\src\flutter_sdk.zip"
Expand-Archive -Path "C:\src\flutter_sdk.zip" -DestinationPath "C:\src" -Force
```

> Get the current stable filename/version from
> `https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json`
> (`current_release.stable` → look up that hash in `releases[]` for the exact archive name and
> sha256) rather than assuming `3.44.8` — Flutter ships new stable releases regularly.

Extract to **`C:\src\flutter`** (avoid `Program Files`, `Downloads`, `Desktop` — matches upstream
guidance about paths with spaces/permissions issues). Add to `PATH`:

```powershell
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
[Environment]::SetEnvironmentVariable("Path", "$userPath;C:\src\flutter\bin", "User")
```

Verify (new terminal — see PATH caveat at the bottom):

```powershell
flutter --version
```

## Step 4 — Android Studio

```powershell
winget install --id Google.AndroidStudio --exact --accept-package-agreements --accept-source-agreements
```

This installs the **IDE only**. Its first-run wizard (GUI, downloads the SDK) was **skipped**
here in favor of the scriptable CLI approach below — either works, but the CLI path is what's
verified and is much faster to reproduce.

## Step 5 — Android SDK via command-line tools

Download **"Command line tools only"** and lay it out so `sdkmanager` lives where Android tooling
expects it:

```powershell
$sdkRoot = "$env:LOCALAPPDATA\Android\Sdk"
Invoke-WebRequest -Uri "https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip" -OutFile "C:\src\cmdline-tools.zip"
Expand-Archive -Path "C:\src\cmdline-tools.zip" -DestinationPath "C:\src\cmdline-tools-extracted" -Force
New-Item -ItemType Directory -Force -Path "$sdkRoot\cmdline-tools" | Out-Null
Move-Item -Path "C:\src\cmdline-tools-extracted\cmdline-tools" -Destination "$sdkRoot\cmdline-tools\latest" -Force
```

Set env vars:

```powershell
[Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdkRoot, "User")
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdkRoot, "User")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
foreach ($p in @("$sdkRoot\platform-tools", "$sdkRoot\emulator", "$sdkRoot\cmdline-tools\latest\bin")) {
  if ($userPath -notlike "*$p*") { $userPath = "$userPath;$p" }
}
[Environment]::SetEnvironmentVariable("Path", $userPath, "User")
```

### Accept licenses

> **Caveat hit — the big one:** piping `y` responses into `sdkmanager --licenses` through
> **PowerShell → `sdkmanager.bat` → `java`** does **not** reliably work — the prompt reports
> "Skipping following packages as the license is not accepted" even when `y` lines are piped in
> (tried both a single joined `"y`n"*N` string and an array of separate `"y"` objects — same
> failure both times). Two working alternatives:
>
> 1. **Write the license hash files directly** (what CI systems do — fast, no interactivity):
>    ```powershell
>    $sdkRoot = "$env:LOCALAPPDATA\Android\Sdk"
>    New-Item -ItemType Directory -Force -Path "$sdkRoot\licenses" | Out-Null
>    Set-Content "$sdkRoot\licenses\android-sdk-license" "8933bad161af4178b1185d1a37fbf41ea5269c55`nd56f5187479451eabf01fb78af6dfcb131a6481e`n24333f8a63b6825ea9c5514f83c2829b004d1fee" -Encoding ASCII
>    Set-Content "$sdkRoot\licenses\android-sdk-preview-license" "84831b9409646a918e30573bab4c9c91346d8abd" -Encoding ASCII
>    Set-Content "$sdkRoot\licenses\android-sdk-arm-dbt-license" "859f317696f67ef3d7f30a50a5560e7834b43903" -Encoding ASCII
>    Set-Content "$sdkRoot\licenses\android-googletv-license" "601085b94cd77f0b54ff86406957099ebe79c4d" -Encoding ASCII
>    Set-Content "$sdkRoot\licenses\google-gdk-license" "33b6a2b64607f11b759f320ef9dff4ae5c47d97a" -Encoding ASCII
>    Set-Content "$sdkRoot\licenses\intel-android-extra-license" "d975f751698a77b662f1254ddbeed3901e976f5" -Encoding ASCII
>    Set-Content "$sdkRoot\licenses\mips-android-sysimage-license" "e9acab5b5fbb560a72cfaecce8946896ff6aab9d" -Encoding ASCII
>    ```
> 2. **Or pipe through git-bash's `yes` instead of PowerShell** — this actually worked cleanly:
>    ```bash
>    yes | flutter doctor --android-licenses
>    ```
>    (git-bash ships with Git for Windows and is on `PATH` as `bash`/`sh`.) Do this **after**
>    installing the SDK packages below — `flutter doctor --android-licenses` calls the bundled
>    `sdkmanager` for you once the SDK is present.

### Install packages

```powershell
$sdkmanager = "$sdkRoot\cmdline-tools\latest\bin\sdkmanager.bat"
& $sdkmanager --sdk_root=$sdkRoot "platform-tools" "platforms;android-36" "build-tools;35.0.0" "emulator" "system-images;android-35;google_apis;x86_64"
```

> **Caveat hit:** `flutter doctor` requires **Android SDK 36**, not just whatever `build-tools`
> version you install — install `platforms;android-36` explicitly even if you're targeting an
> older API level in your app; `flutter doctor`'s Android-toolchain check specifically wants it
> present.
>
> **Caveat hit — pick the system image ABI matching your CPU:** this machine is `AMD64`
> (`$env:PROCESSOR_ARCHITECTURE`), so the system image must be **`x86_64`**, not `arm64-v8a`.
> Google's `arm64-v8a` emulator system images only get hardware acceleration on **Apple Silicon
> Macs** — on an Intel/AMD Windows or Linux host they'd run unaccelerated (if they run at all).
> Check your own host arch before choosing.

## Step 6 — Create the emulator (AVD)

```powershell
$env:JAVA_HOME = [Environment]::GetEnvironmentVariable("JAVA_HOME", "User")
$avdmanager = "$sdkRoot\cmdline-tools\latest\bin\avdmanager.bat"
echo "no" | & $avdmanager create avd -n Pixel_8_API_35 -k "system-images;android-35;google_apis;x86_64" -d "pixel_8" --force
```

(The `echo "no"` answers the one prompt `avdmanager` asks — whether you want a custom hardware
profile.) Verify:

```powershell
& $avdmanager list avd
```

Launch it from Android Studio's Device Manager, or headless:

```powershell
& "$sdkRoot\emulator\emulator.exe" -avd Pixel_8_API_35
```

## Step 7 — VS Code extensions

```powershell
code --install-extension Dart-Code.flutter
code --install-extension Dart-Code.dart-code
code --install-extension usernamehw.errorlens
code --install-extension eamodio.gitlens
code --install-extension esbenp.prettier-vscode
```

(`Dart-Code.flutter` pulls in `Dart-Code.dart-code` as a dependency automatically.)

## Step 8 — Verify: `flutter doctor`

```powershell
flutter doctor -v
```

Expected, for an **Android-only** setup:

```
[√] Flutter
[√] Windows Version
[√] Android toolchain - develop for Android devices
[√] Connected device
[√] Network resources
```

`Chrome` and `Visual Studio` will show as `[X]`/`[!]` unless you also install Chrome (web target)
or the Visual Studio "Desktop development with C++" workload (Windows-desktop target) — neither
is needed for Android app development and both were left out here.

## Step 9 — Create and run a project

```powershell
flutter create my_app
cd my_app
flutter pub get
flutter devices
flutter run
```

---

## The PATH caveat that will bite you once

> **Caveat hit:** all of the above sets **User-scope** environment variables via
> `[Environment]::SetEnvironmentVariable(..., "User")`. This writes to the registry
> (`HKCU\Environment`), but **already-running processes — including the terminal/shell you used to
> run these install commands — do not see the change**. A child process spawned from that same
> shell (e.g. `Start-Process powershell`) inherits the *old* environment block, not a fresh
> registry read, and will still fail to find `flutter`/`java`/`adb`.
>
> **Fix: close and reopen your terminal (or VS Code) after running this setup** — a genuinely new
> process (opened via Start Menu, Windows Terminal "new tab" after a restart of the terminal app,
> etc.) reads the registry fresh at startup and will pick everything up. Confirmed working via a
> literal new `flutter.bat`/`java.exe` invocation using their full paths during setup, and via
> `flutter doctor` run with the env vars set explicitly in that process — no reason to expect a
> genuinely fresh terminal to behave differently.

## Toolchain versions (verified working on this machine)

| | |
|---|---|
| JDK | 17.0.20 (Temurin) |
| Flutter | 3.44.8 (stable) · Dart 3.12.2 · DevTools 2.57.0 |
| Android SDK | platform android-36 · build-tools 35.0.0 & 28.0.3 · platform-tools r37.0.1 |
| Emulator | 37.1.11.0, AVD `Pixel_8_API_35` — Android 15 (API 35), google_apis, x86_64 |
| Host | Windows 11 Enterprise 23H2, AMD64 |

## Troubleshooting

Same as upstream Flutter guidance:

```powershell
flutter doctor            # re-check everything
flutter clean; flutter pub get; flutter run   # build problems
adb devices                # device/emulator not found
adb kill-server; adb start-server
```
