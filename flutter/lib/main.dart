// App shell — port of src/App.tsx.
//
// Hand-rolled navigation: three tabs and a one-deep stack, same as the RN
// version (see App.tsx for why: it avoids pulling in a navigation package).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'components/chrome.dart' show AppTab, BottomNav;
import 'config.dart';
import 'features/ai/ocr_reader.dart';
import 'features/ai/summarize.dart';
import 'features/feedback/proximity_feedback.dart';
import 'features/messaging/attachments.dart';
import 'features/messaging/events.dart';
import 'features/messaging/mock_transport.dart';
import 'features/messaging/nearby_transport.dart';
import 'features/messaging/notifier.dart';
import 'features/sidequest/remote_gpu.dart';
import 'features/vault/lock.dart';
import 'features/vault/vault.dart';
import 'features/vision/obstacle_detector.dart';
import 'screens/chat_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/new_group_screen.dart';
import 'screens/reach_screen.dart';
import 'screens/read_screen.dart';
import 'screens/send_coin_screen.dart';
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
          create: (_) {
            // NearbyTransport must advertise the exact device id MeshStore
            // resolves for itself, or a peer's message addressed to us never
            // matches and gets relayed past us instead of delivered. It
            // isn't known until MeshStore.start() resolves its persisted
            // identity, so NearbyTransport reads it lazily off the store
            // instead of taking a value at construction.
            late final MeshStore store;
            final transport = useRealTransport
                ? NearbyTransport(deviceId: () => store.me.deviceId, display: () => store.me.display)
                : MockTransport();
            store = MeshStore(transport: transport, notifier: BannerMeshNotifier(_scaffoldMessengerKey));
            return store;
          },
        ),
        Provider<SecureVault>(create: (_) => MockSecureVault()),
        Provider<AppLock>(create: (_) => MockAppLock()),
        Provider<ThreadSummarizer>(create: (_) => MockThreadSummarizer()),
        Provider<OcrReader>(create: (_) => MockOcrReader()),
        Provider<ImageSource>(create: (_) => MockImageSource()),
        Provider<CalendarWriter>(create: (_) => MockCalendarWriter()),
        Provider<ShakeService>(create: (_) => MockShakeService()),
        Provider<ObstacleDetector>(create: (_) => MockObstacleDetector()),
        Provider<HapticOutput>(create: (_) => SystemHapticOutput()),
        Provider<SpeechOutput>(create: (_) => NoOpSpeechOutput()),
        Provider<ProximityFeedback>(
          create: (_) => ProximityFeedback(haptics: SystemHapticOutput(), speech: NoOpSpeechOutput()),
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
  Widget build(BuildContext context) {
    final mode = context.watch<ThemeStore>().mode;
    return MaterialApp(
      title: 'Echo',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      themeMode: mode,
      theme: _themeData(tokens.light),
      darkTheme: _themeData(tokens.dark),
      // Nothing behind the lock is built until it opens, so a shoulder-surfer
      // can't read a thread off the screen behind a modal.
      home: _unlocked ? const AppShell() : LockScreen(onUnlocked: () => setState(() => _unlocked = true)),
    );
  }

  ThemeData _themeData(tokens.Palette c) {
    final brightness = c == tokens.dark ? Brightness.dark : Brightness.light;
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: c.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.direct,
        brightness: brightness,
      ),
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
        onSendCoin: (id) =>
            setState(() => _route = _Route(_RouteName.send, id)),
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
        // Money goes to a conversation, so send starts by choosing one.
        // Reach is that list; there is no separate contact picker.
        onSend: () => setState(() => _tab = AppTab.reach),
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
