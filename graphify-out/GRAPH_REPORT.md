# Graph Report - C:\React-Native-Hackathon  (2026-08-01)

## Corpus Check
- 81 files · ~97,981 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 334 nodes · 451 edges · 57 communities (55 shown, 2 thin omitted)
- Extraction: 77% EXTRACTED · 21% INFERRED · 2% AMBIGUOUS · INFERRED: 93 edges (avg confidence: 0.86)
- Token cost: 366,694 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Project Brief & Design Decisions|Project Brief & Design Decisions]]
- [[_COMMUNITY_App Shell & Screen Navigation|App Shell & Screen Navigation]]
- [[_COMMUNITY_Mesh Store & Wire Protocol|Mesh Store & Wire Protocol]]
- [[_COMMUNITY_Build Strategy, Models & Flutter Setup|Build Strategy, Models & Flutter Setup]]
- [[_COMMUNITY_MeshIdentity Source Modules|Mesh/Identity Source Modules]]
- [[_COMMUNITY_UI Component Source Modules|UI Component Source Modules]]
- [[_COMMUNITY_On-device AI Services|On-device AI Services]]
- [[_COMMUNITY_Pairing, Lock & Coin UI|Pairing, Lock & Coin UI]]
- [[_COMMUNITY_Flutter Welcome App|Flutter Welcome App]]
- [[_COMMUNITY_Biometric Lock Implementation|Biometric Lock Implementation]]
- [[_COMMUNITY_Thread Summary Implementation|Thread Summary Implementation]]
- [[_COMMUNITY_App Bar Component|App Bar Component]]

## God Nodes (most connected - your core abstractions)
1. `useTheme()` - 18 edges
2. `Echo — offline-first, 100%-on-device RN app` - 13 edges
3. `useThreadSummary (on-device "catch me up")` - 12 edges
4. `ChatScreen (thread view, composer, coin cancel window)` - 11 edges
5. `MeshTransport (Nearby wrapper)` - 10 edges
6. `App (root, hand-rolled navigation)` - 10 edges
7. `Echo blind-navigation design spec` - 10 edges
8. `SendCoinScreen (echocoin keypad + queue)` - 9 edges
9. `Echo Team Setup & Dev Guide` - 9 edges
10. `Capability A — navigation aid for blind & low-vision users` - 9 edges

## Surprising Connections (you probably didn't know these)
- `Flutter Development Environment Setup (Windows)` --semantically_similar_to--> `Android SDK via command-line tools (no Android Studio)`  [INFERRED] [semantically similar]
  SETUP_FLUTTER.md → SETUP.md
- `Flutter Development Environment Setup (Windows)` --semantically_similar_to--> `Verified Echo toolchain (JDK 17, Expo 57, RN 0.86.2, NDK 27, AGP 8.12)`  [INFERRED] [semantically similar]
  SETUP_FLUTTER.md → SETUP.md
- `App entry point — registerRootComponent(App)` --conceptually_related_to--> `expo-dev-client (custom dev client APK shell)`  [INFERRED]
  index.ts → CLAUDE.md
- `App entry point — registerRootComponent(App)` --references--> `Feature-first folder structure (src/features/*)`  [EXTRACTED]
  index.ts → CLAUDE.md
- `Flutter WelcomeApp / WelcomeScreen widgets` --semantically_similar_to--> `App entry point — registerRootComponent(App)`  [INFERRED] [semantically similar]
  flutter/lib/main.dart → index.ts

## Hyperedges (group relationships)
- **Inbound envelope pipeline: radio text -> decode -> hop rule -> thread** — transport_MeshTransport, relay_decode, relay_route, mesh_onEnvelope, mesh_upsertMessage [EXTRACTED 1.00]
- **Outbound send path: compose envelope, self-dedupe, encode, fan out** — mesh_send, relay_newEnvelope, relay_SeenCache, relay_encode, transport_broadcast [EXTRACTED 1.00]
- **No-new-dev-client-APK constraint shaping implementation choices** — QrCode_QrCode, ReachMap_ReachMap, identity_deviceIdentity, lock_hasBiometricHardware [INFERRED 0.95]
- **"Catch me up" on-device summarisation pipeline** — mock_Thread, useThreadSummary_transcript, useThreadSummary_SYSTEM_PROMPT, useThreadSummary_useThreadSummary, useThreadSummary_toLines, index_LANGUAGE_MODEL [EXTRACTED 0.95]
- **Blind-navigation loop: models to detection to eyes-free feedback** — index_VISION_MODELS, useObstacles_useObstacles, useProximityFeedback_useProximityFeedback, useReadText_useReadText, useDescribeScene_useDescribeScene [INFERRED 0.85]
- **Three competing paths to thread summaries (shipped on-device, placeholder, online GPU)** — useThreadSummary_useThreadSummary, useSummarize_useSummarize, useRemoteGpu_useRemoteGpu [INFERRED 0.85]
- **Deliberate no-new-dev-client-APK workarounds** — App_App, theme_font, Chrome_bottomInset, useShake_useShake [INFERRED 0.85]
- **Lock gate → tabs → one-deep stack navigation flow** — App_App, LockScreen_LockScreen, ReachScreen_ReachScreen, ChatScreen_ChatScreen, SendCoinScreen_SendCoinScreen, WalletScreen_WalletScreen, TapScreen_TapScreen [EXTRACTED 1.00]
- **Hop-distance signal language (one scale, many surfaces)** — theme_signalScale, mock_Hops, Avatar_Avatar, Chip_HopChip, RouteStrip_RouteStrip, Chrome_MeshStatus, ChatScreen_ReachBar [INFERRED 0.95]
- **All native libraries shipped in one dev-client APK** — claude_react_native_executorch, claude_expo_camera, claude_expo_speech, claude_expo_haptics, claude_expo_nearby_connections, claude_react_native_nitro_modules, claude_react_native_keychain, claude_expo_dev_client [EXTRACTED 1.00]
- **Blind-navigation pipeline: camera → detection → proximity → haptics/speech** — claude_expo_camera, design_snapshot_loop, claude_react_native_executorch, design_proximity_engine, design_feedback_engine, claude_expo_haptics, claude_expo_speech [EXTRACTED 1.00]
- **Mesh relay stack: transport, cluster strategy, envelope, TTL/dedupe relay, encryption seam** — claude_expo_nearby_connections, mesh_p2p_cluster_strategy, mesh_envelope_type, mesh_app_layer_relay_logic, mesh_use_mesh_hook, mesh_runtime_permissions, mesh_encryption_seam [EXTRACTED 1.00]

## Communities (57 total, 2 thin omitted)

### Community 0 - "Project Brief & Design Decisions"
Cohesion: 0.08
Nodes (44): Limitation — proximity inferred from bounding-box size (no depth sensor), E2E-encrypted mesh payloads; keys never leave secure hardware, Echo Project Brief (source of truth), expo-camera (preview + snapshots), expo-haptics (proximity vibration), expo-nearby-connections (Google Nearby: BT + BLE + Wi-Fi Direct), expo-speech (offline OS text-to-speech), Feature-first folder structure (src/features/*) (+36 more)

### Community 1 - "App Shell & Screen Navigation"
Cohesion: 0.08
Nodes (43): App (root, hand-rolled navigation), Route (one-deep modal stack state), Avatar (hop-ringed contact circle), ChatScreen (thread view, composer, coin cancel window), ReachBar (who can hear you, before you type), HopChip (hop state as a pill), BottomNav (Reach / Wallet / Meet tabs), MeshStatus (mesh conditions strip) (+35 more)

### Community 2 - "Mesh Store & Wire Protocol"
Cohesion: 0.11
Nodes (31): MessageBubble (text + coin rows), stateLine (outgoing status text), MapNode (id/name/hops), deviceIdentity (restart-stable device id), cancelPending (pre-send undo), mesh store onEnvelope handler, queueCoin (cancel window), revertLastCoin (post-send take-back) (+23 more)

### Community 3 - "Build Strategy, Models & Flutter Setup"
Cohesion: 0.1
Nodes (31): AGENTS rule — read versioned Expo v57 docs first, Dart analysis options (flutter_lints ruleset), Constraint — Android-only, arm64-v8a, physical device only, Build strategy — custom dev client, local Gradle, not Expo Go / not EAS, Echo — offline-first, 100%-on-device RN app, expo-dev-client (custom dev client APK shell), Models download once over wifi, then run fully offline, Offline-first, 100%-on-device principle (+23 more)

### Community 4 - "Mesh/Identity Source Modules"
Cohesion: 0.1
Nodes (13): deviceIdentity(), mint(), ensurePermissions(), explain(), MeshTransport, packName(), decode(), encode() (+5 more)

### Community 5 - "UI Component Source Modules"
Cohesion: 0.09
Nodes (6): Avatar(), MeshStatus(), Screen(), useShake(), byId(), useTheme()

### Community 6 - "On-device AI Services"
Cohesion: 0.12
Nodes (24): CatchMeUpSheet (on-device thread summary sheet), LANGUAGE_MODEL group (~400 MB, opt-in), ModelGroup type, VISION_MODELS group (~50 MB), ai/api — ExecuTorch OCR + LLM wrappers, downloadGroup() — pre-download to on-device cache, feedback/api — expo-haptics + expo-speech wrappers, Model service bootstrap (initExecutorch + ExpoResourceFetcher) (+16 more)

### Community 7 - "Pairing, Lock & Coin UI"
Cohesion: 0.14
Nodes (18): CoinChip (money pill), LockScreen (biometric door), QrCode (pure-JS run-length QR), ScanMode (camera QR reader + permission gate), ShowMode (display pairing QR + fingerprint), Sonar (three staggered pairing rings), TapMode (NFC back-to-back pairing), TapScreen (Meet a phone — pairing + key swap) (+10 more)

### Community 8 - "Flutter Welcome App"
Cohesion: 0.14
Nodes (12): build, main, MaterialApp, Scaffold, SizedBox, Text, WelcomeApp, WelcomeScreen (+4 more)

### Community 9 - "Biometric Lock Implementation"
Cohesion: 0.39
Nodes (6): enableLock(), hasBiometricHardware(), isLockEnabled(), looksCancelled(), unlock(), turnOn()

## Ambiguous Edges - Review These
- `route() — the whole hop rule` → `isGroup (g: thread prefix)`  [AMBIGUOUS]
  src/utils/relay.ts · relation: conceptually_related_to
- `useRemoteGpu (online GPU offload placeholder)` → `Thread (message thread model)`  [AMBIGUOUS]
  src/features/sidequest/hooks/useRemoteGpu.ts · relation: shares_data_with
- `App (root, hand-rolled navigation)` → `ModelPreloadScreen (first-run model pre-download)`  [AMBIGUOUS]
  src/App.tsx · relation: references
- `Display (signage typeface role)` → `Empty index barrels (components / hooks / screens)`  [AMBIGUOUS]
  src/components/index.ts · relation: conceptually_related_to
- `ModelPreloadScreen (first-run model pre-download)` → `Palette (design token contract)`  [AMBIGUOUS]
  src/screens/ModelPreloadScreen.tsx · relation: conceptually_related_to
- `Sonar (three staggered pairing rings)` → `Coin colour (money-only ultramarine)`  [AMBIGUOUS]
  src/screens/TapScreen.tsx · relation: references
- `Echo Team Setup & Dev Guide` → `expo-nearby-connections (Google Nearby: BT + BLE + Wi-Fi Direct)`  [AMBIGUOUS]
  SETUP.md · relation: conceptually_related_to
- `Echo blind-navigation design spec` → `Capability B — offline mesh messaging (no cell, no wifi)`  [AMBIGUOUS]
  docs/superpowers/specs/2026-07-30-echo-blind-navigation-design.md · relation: conceptually_related_to
- `Echo blind-navigation design spec` → `react-native-keychain (Android Keystore, TEE/StrongBox)`  [AMBIGUOUS]
  docs/superpowers/specs/2026-07-30-echo-blind-navigation-design.md · relation: references
- `Flutter WelcomeApp / WelcomeScreen widgets` → `Flutter counter smoke test (stock scaffold, stale)`  [AMBIGUOUS]
  flutter/test/widget_test.dart · relation: calls

## Knowledge Gaps
- **44 isolated node(s):** `WelcomeApp`, `WelcomeScreen`, `main`, `build`, `MaterialApp` (+39 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `route() — the whole hop rule` and `isGroup (g: thread prefix)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `useRemoteGpu (online GPU offload placeholder)` and `Thread (message thread model)`?**
  _Edge tagged AMBIGUOUS (relation: shares_data_with) - confidence is low._
- **What is the exact relationship between `App (root, hand-rolled navigation)` and `ModelPreloadScreen (first-run model pre-download)`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `Display (signage typeface role)` and `Empty index barrels (components / hooks / screens)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `ModelPreloadScreen (first-run model pre-download)` and `Palette (design token contract)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Sonar (three staggered pairing rings)` and `Coin colour (money-only ultramarine)`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `Echo Team Setup & Dev Guide` and `expo-nearby-connections (Google Nearby: BT + BLE + Wi-Fi Direct)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._