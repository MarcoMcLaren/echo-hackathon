// App shell — port of src/App.tsx.
//
// Hand-rolled navigation: three tabs and a one-deep stack, same as the RN
// version (see App.tsx for why: it avoids pulling in a navigation package).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'components/chrome.dart' show AppTab, BottomNav;
import 'screens/chat_screen.dart';
import 'screens/reach_screen.dart';
import 'screens/send_coin_screen.dart';
import 'screens/tap_screen.dart';
import 'screens/wallet_screen.dart';
import 'store/theme_store.dart';
import 'styles/theme.dart' as tokens;

void main() {
  runApp(const EchoApp());
}

class EchoApp extends StatelessWidget {
  const EchoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeStore(),
      child: const _EchoMaterialApp(),
    );
  }
}

class _EchoMaterialApp extends StatelessWidget {
  const _EchoMaterialApp();

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ThemeStore>().mode;
    return MaterialApp(
      title: 'Echo',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: _themeData(tokens.light),
      darkTheme: _themeData(tokens.dark),
      home: const AppShell(),
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

enum _RouteName { chat, send }

class _Route {
  const _Route(this.name, this.id);
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
      ),
      (null, AppTab.reach) => ReachScreen(
        onOpen: (id) => setState(() => _route = _Route(_RouteName.chat, id)),
      ),
      (null, AppTab.wallet) => WalletScreen(
        onSend: () =>
            setState(() => _route = const _Route(_RouteName.send, 'naledi')),
        onTap: () => setState(() => _tab = AppTab.tap),
      ),
      (null, AppTab.tap) => const TapScreen(),
    };

    return PopScope(
      canPop: route == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && route != null) _back();
      },
      child: Scaffold(
        body: SafeArea(child: body),
        bottomNavigationBar: route == null
            ? BottomNav(tab: _tab, onTab: (t) => setState(() => _tab = t))
            : null,
      ),
    );
  }
}
