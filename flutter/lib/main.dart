import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/read_screen.dart';
import 'screens/reach_screen.dart';
import 'screens/send_coin_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/tap_screen.dart';
import 'screens/wallet_screen.dart';
import 'store/app_store.dart';
import 'store/app_store_scope.dart';
import 'theme/echo_theme.dart';
import 'widgets/chrome.dart';

void main() {
  runApp(const EchoApp());
}

class EchoApp extends StatelessWidget {
  const EchoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Echo',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => EchoThemeScope(child: child!),
      home: const _Root(),
    );
  }
}

/// One-deep stack: three tabs, plus chat/send pushed on top — a direct port
/// of App.tsx's hand-rolled `Route` state machine (no react-navigation there
/// either, so no Flutter Navigator/routes package needed here).
class _AppRoute {
  final String name; // 'chat' | 'send'
  final String id;
  const _AppRoute(this.name, this.id);
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  final _store = AppStore();
  EchoTab _tab = EchoTab.reach;
  _AppRoute? _route;
  // Once past the door it stays open for the life of the launch —
  // re-prompting every time you glance at another app would make the mesh
  // unusable.
  bool _unlocked = false;
  // Set while ReadScreen has an OCR capture in flight — unmounting it
  // mid-capture is not safe, so the bottom nav locks the other tabs until
  // it clears. Mirrors Chrome.tsx's `disabled` prop on BottomNav.
  bool _readBusy = false;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    // Claims identity/contacts regardless of whether the mesh is ever
    // started — this must resolve before the tab UI can render, so a fresh
    // install shows SetupScreen instead of an app with an undefined identity.
    _store.init();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _back() => setState(() => _route = null);

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;

    // Nothing behind the lock is rendered until it opens, so a shoulder-surfer
    // can't read a thread off the screen behind a modal.
    if (!_unlocked) {
      return Scaffold(
        backgroundColor: c.paper,
        body: LockScreen(onUnlocked: () => setState(() => _unlocked = true)),
      );
    }

    if (!_store.ready) {
      return Scaffold(
        backgroundColor: c.paper,
        body: SafeArea(child: SetupScreen(onCreate: _store.createIdentity)),
      );
    }

    final Widget screen = switch (_route?.name) {
      'chat' => ChatScreen(
          threadId: _route!.id,
          onBack: _back,
          onSendCoin: (id) => setState(() => _route = _AppRoute('send', id)),
        ),
      'send' => SendCoinScreen(
          contactId: _route!.id,
          onBack: _back,
          onQueued: (id) => setState(() => _route = _AppRoute('chat', id)),
        ),
      _ => switch (_tab) {
          EchoTab.reach => ReachScreen(onOpen: (id) => setState(() => _route = _AppRoute('chat', id))),
          EchoTab.wallet => WalletScreen(
              // No contact picker exists — go pick a real conversation to
              // send from, same fallback RN's own mock-removal took.
              onSend: () => setState(() => _tab = EchoTab.reach),
              onTap: () => setState(() => _tab = EchoTab.tap),
            ),
          EchoTab.tap => TapScreen(onPaired: (id) => setState(() => _route = _AppRoute('chat', id))),
          EchoTab.read => ReadScreen(onBusyChange: (busy) => setState(() => _readBusy = busy)),
        },
    };

    return AppStoreScope(
      store: _store,
      child: PopScope(
        canPop: _route == null,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _route != null) _back();
        },
        child: Scaffold(
          backgroundColor: c.paper,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(child: screen),
                if (_route == null) BottomNav(tab: _tab, onTab: (t) => setState(() => _tab = t), disabled: _readBusy),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
