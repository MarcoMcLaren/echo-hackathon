// App shell — port of src/App.tsx.
//
// Hand-rolled navigation: three tabs and a one-deep stack, same as the RN
// version (see App.tsx for why: it avoids pulling in a navigation package).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'components/chrome.dart' show AppTab, BottomNav;
import 'features/ai/ocr_reader.dart';
import 'features/ai/summarize.dart';
import 'features/feedback/proximity_feedback.dart';
import 'features/feedback/tts_speech_output.dart';
import 'features/messaging/attachments.dart';
import 'features/messaging/events.dart';
import 'features/messaging/mock_transport.dart';
import 'features/messaging/notifier.dart';
import 'features/sidequest/remote_gpu.dart';
import 'features/vault/lock.dart';
import 'features/vault/qr_scanner.dart';
import 'features/vault/vault.dart';
import 'features/vision/obstacle_detector.dart';
import 'screens/chat_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/new_group_screen.dart';
import 'screens/reach_screen.dart';
import 'screens/read_screen.dart';
import 'screens/send_coin_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/tap_screen.dart';
import 'screens/wallet_screen.dart';
import 'services/shake_service.dart';
import 'store/mesh_store.dart';
import 'store/theme_store.dart';
import 'styles/theme.dart' as tokens;

void main() {
  runApp(const EchoApp());
}

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

// Shared so the mesh's arrival narration and ReadScreen's "read that" output
// hit the same TTS engine instance rather than each opening its own.
final _ttsSpeechOutput = TtsSpeechOutput();

class EchoApp extends StatelessWidget {
  const EchoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeStore()),
        // Mock-first adapters: every feature area from the project brief is
        // reachable from the provider tree, even the ones no screen in this
        // pass consumes yet (vision/sidequest), so a later screen never has
        // to instantiate an adapter ad hoc inside a widget.
        ChangeNotifierProvider(
          create: (_) =>
              MeshStore(transport: MockTransport(), notifier: LocalNotificationsMeshNotifier(_scaffoldMessengerKey)),
        ),
        Provider<SecureVault>(create: (_) => SecureStorageVault()),
        Provider<AppLock>(create: (_) => BiometricAppLock()),
        Provider<ThreadSummarizer>(create: (_) => MockThreadSummarizer()),
        Provider<OcrReader>(
          create: (_) => MlkitOcrReader(),
          dispose: (_, reader) => (reader as MlkitOcrReader).dispose(),
        ),
        Provider<ImageSource>(create: (_) => PickerImageSource()),
        Provider<CalendarWriter>(create: (_) => DeviceCalendarWriter()),
        Provider<QrScanner>(create: (_) => MobileScannerQrScanner()),
        Provider<ShakeService>(create: (_) => MockShakeService()),
        Provider<ObstacleDetector>(create: (_) => MockObstacleDetector()),
        Provider<HapticOutput>(create: (_) => SystemHapticOutput()),
        Provider<SpeechOutput>(create: (_) => _ttsSpeechOutput),
        Provider<ProximityFeedback>(
          create: (_) => ProximityFeedback(haptics: SystemHapticOutput(), speech: _ttsSpeechOutput),
        ),
        Provider<RemoteGpuClient>(create: (_) => UnavailableRemoteGpuClient()),
      ],
      child: const _EchoMaterialApp(),
    );
  }
}

class _EchoMaterialApp extends StatefulWidget {
  const _EchoMaterialApp();

  @override
  State<_EchoMaterialApp> createState() => _EchoMaterialAppState();
}

class _EchoMaterialAppState extends State<_EchoMaterialApp> {
  // Once past the door it stays open for the life of the launch —
  // re-prompting every time you glance at another app would make the mesh
  // unusable.
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    // Claim this phone's identity before anything can ask for it — the
    // pairing code has to encode a real device id even if the mesh is never
    // started.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MeshStore>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ThemeStore>().mode;
    final ready = context.watch<MeshStore>().ready;

    // Nothing behind the lock is built until it opens, so a shoulder-surfer
    // can't read a thread off the screen behind a modal. Never set up, or
    // just reset: ask for a name before anything else — this is also what
    // mints the phone's id, so there is no identity to leak beforehand.
    final Widget home;
    if (!_unlocked) {
      home = LockScreen(onUnlocked: () => setState(() => _unlocked = true));
    } else if (!ready) {
      home = const SetupScreen();
    } else {
      home = const AppShell();
    }

    return MaterialApp(
      title: 'Echo',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      themeMode: mode,
      theme: _themeData(tokens.light),
      darkTheme: _themeData(tokens.dark),
      home: home,
    );
  }

  ThemeData _themeData(tokens.Palette c) {
    final brightness = c == tokens.dark ? Brightness.dark : Brightness.light;
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: c.paper,
      colorScheme: ColorScheme.fromSeed(seedColor: c.direct, brightness: brightness),
      useMaterial3: true,
    );
  }
}

enum _RouteName { chat, send, newGroup }

class _Route {
  const _Route(this.name, [this.id = '']);
  final _RouteName name;
  final String id;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppTab _tab = AppTab.reach;
  _Route? _route;

  // Switching tabs mid-read would unmount ReadScreen while a capture is in
  // flight, so the nav locks rather than interrupting it.
  bool _readBusy = false;

  void _back() => setState(() => _route = null);

  @override
  Widget build(BuildContext context) {
    final route = _route;

    final Widget body = switch ((route?.name, _tab)) {
      (_RouteName.chat, _) => ChatScreen(
        threadId: route!.id,
        onBack: _back,
        onSendCoin: (id) => setState(() => _route = _Route(_RouteName.send, id)),
      ),
      (_RouteName.send, _) => SendCoinScreen(
        contactId: route!.id,
        onBack: _back,
        onQueued: (id) => setState(() => _route = _Route(_RouteName.chat, id)),
      ),
      (_RouteName.newGroup, _) => NewGroupScreen(
        onBack: _back,
        onCreated: (id) => setState(() => _route = _Route(_RouteName.chat, id)),
      ),
      (null, AppTab.reach) => ReachScreen(
        onOpen: (id) => setState(() => _route = _Route(_RouteName.chat, id)),
        onNewGroup: () => setState(() => _route = const _Route(_RouteName.newGroup)),
      ),
      (null, AppTab.wallet) => WalletScreen(
        onSend: () => setState(() => _route = const _Route(_RouteName.send, 'naledi')),
        onTap: () => setState(() => _tab = AppTab.tap),
      ),
      (null, AppTab.tap) => const TapScreen(),
      (null, AppTab.read) => ReadScreen(onBusyChange: (busy) => setState(() => _readBusy = busy)),
    };

    return PopScope(
      canPop: route == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && route != null) _back();
      },
      child: Scaffold(
        body: SafeArea(child: body),
        bottomNavigationBar: route == null
            ? BottomNav(tab: _tab, onTab: (t) => setState(() => _tab = t), disabled: _readBusy)
            : null,
      ),
    );
  }
}
