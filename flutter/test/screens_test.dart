// Widget tests for lib/screens/* — each screen renders against the mock
// stores/adapters (MeshStore + MockTransport, MockSecureVault,
// MockThreadSummarizer), matching the same headless, no-device-required
// approach as the rest of the suite.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:echo/features/ai/summarize.dart';
import 'package:echo/features/messaging/mock_transport.dart';
import 'package:echo/features/vault/vault.dart';
import 'package:echo/screens/catch_me_up_sheet.dart';
import 'package:echo/screens/chat_screen.dart';
import 'package:echo/screens/model_preload_screen.dart';
import 'package:echo/screens/reach_screen.dart';
import 'package:echo/screens/send_coin_screen.dart';
import 'package:echo/screens/tap_screen.dart';
import 'package:echo/screens/wallet_screen.dart';
import 'package:echo/store/mesh_store.dart';
import 'package:echo/store/mock.dart' as mock;
import 'package:echo/store/theme_store.dart';

Widget harness(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeStore()),
      ChangeNotifierProvider(create: (_) => MeshStore(transport: MockTransport())),
      Provider<SecureVault>(create: (_) => MockSecureVault()),
      Provider<ThreadSummarizer>(create: (_) => MockThreadSummarizer()),
    ],
    child: MaterialApp(
      theme: ThemeData(brightness: Brightness.light),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('ReachScreen renders the demo threads and mesh status', (tester) async {
    await tester.pumpWidget(harness(ReachScreen(onOpen: (_) {})));
    await tester.pump();

    expect(find.text('Reach'), findsOneWidget);
    expect(find.text('MESH OFF · TAP TO START'), findsOneWidget);
    expect(find.text('Braai Crew'), findsOneWidget);
  });

  testWidgets('ChatScreen renders thread title and messages', (tester) async {
    await tester.pumpWidget(harness(ChatScreen(threadId: 'thabo', onBack: () {}, onSendCoin: (_) {})));
    await tester.pump();

    expect(find.text('Thabo Mokoena'), findsOneWidget);
    expect(find.text('Here, for the wood run'), findsOneWidget);
  });

  testWidgets('ChatScreen opens the CatchMeUpSheet for a group thread', (tester) async {
    await tester.pumpWidget(harness(ChatScreen(threadId: 'braai', onBack: () {}, onSendCoin: (_) {})));
    await tester.pump();

    expect(find.text('Catch me up · 41 new'), findsOneWidget);
    await tester.tap(find.text('Catch me up · 41 new'));
    await tester.pump();
    expect(find.byType(CatchMeUpSheet), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.textContaining('messages while you were out of range'), findsOneWidget);
  });

  testWidgets('WalletScreen renders balance and ledger', (tester) async {
    await tester.pumpWidget(harness(WalletScreen(onSend: () {}, onTap: () {})));
    await tester.pump();

    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text(mock.balance.toStringAsFixed(2)), findsOneWidget);
    expect(find.text('Naledi Khumalo'), findsOneWidget);
  });

  testWidgets('SendCoinScreen renders the contact and keypad', (tester) async {
    await tester.pumpWidget(harness(SendCoinScreen(contactId: 'naledi', onBack: () {})));
    await tester.pump();

    expect(find.text('Send echocoin'), findsOneWidget);
    expect(find.text('20.00'), findsOneWidget);

    await tester.tap(find.text('5'));
    await tester.pump();
    expect(find.text('20.005'), findsOneWidget);
  });

  testWidgets('TapScreen renders NFC mode by default and switches to Show code', (tester) async {
    await tester.pumpWidget(harness(const TapScreen()));
    await tester.pump();

    expect(find.text('Hold the phones back to back'), findsOneWidget);

    await tester.tap(find.text('SHOW CODE'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Let the other phone scan this'), findsOneWidget);
  });

  testWidgets('ModelPreloadScreen auto-downloads vision models and offers the LLM download', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ModelPreloadScreen()));
    await tester.pump();

    expect(find.text('Echo'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget); // language model is opt-in

    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('✓ Ready — offline'), findsOneWidget);
  });
}
