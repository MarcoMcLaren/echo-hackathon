import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';
import 'screens/reach_screen.dart';
import 'screens/send_coin_screen.dart';
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

  void _back() => setState(() => _route = null);

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;

    final Widget screen = switch (_route?.name) {
      'chat' => ChatScreen(
          threadId: _route!.id,
          onBack: _back,
          onSendCoin: (id) => setState(() => _route = _AppRoute('send', id)),
        ),
      'send' => SendCoinScreen(contactId: _route!.id, onBack: _back),
      _ => switch (_tab) {
          EchoTab.reach => ReachScreen(onOpen: (id) => setState(() => _route = _AppRoute('chat', id))),
          EchoTab.wallet => WalletScreen(
              onSend: () => setState(() => _route = _AppRoute('send', 'naledi')),
              onTap: () => setState(() => _tab = EchoTab.tap),
            ),
          EchoTab.tap => const TapScreen(),
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
                if (_route == null) BottomNav(tab: _tab, onTab: (t) => setState(() => _tab = t)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
