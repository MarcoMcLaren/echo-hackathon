// Widget tests for lib/screens/* — each screen renders against the mock
// stores/adapters (MeshStore + MockTransport, MockSecureVault,
// MockThreadSummarizer, MockOcrReader, MockAppLock, MockShakeService),
// matching the same headless, no-device-required approach as the rest of the
// suite.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:echo/features/ai/ocr_reader.dart';
import 'package:echo/features/ai/summarize.dart';
import 'package:echo/features/feedback/proximity_feedback.dart';
import 'package:echo/features/messaging/attachments.dart';
import 'package:echo/features/messaging/events.dart';
import 'package:echo/features/messaging/mock_transport.dart';
import 'package:echo/features/vault/lock.dart';
import 'package:echo/features/vault/vault.dart';
import 'package:echo/screens/catch_me_up_sheet.dart';
import 'package:echo/screens/chat_screen.dart';
import 'package:echo/screens/model_preload_screen.dart';
import 'package:echo/screens/lock_screen.dart';
import 'package:echo/screens/new_group_screen.dart';
import 'package:echo/screens/reach_screen.dart';
import 'package:echo/screens/read_screen.dart';
import 'package:echo/screens/send_coin_screen.dart';
import 'package:echo/screens/tap_screen.dart';
import 'package:echo/screens/wallet_screen.dart';
import 'package:echo/services/shake_service.dart';
import 'package:echo/store/mesh_store.dart';
import 'package:echo/store/theme_store.dart';
import 'package:echo/store/types.dart';

import 'support/demo_data.dart';

Widget harness(Widget child, {MeshStore? mesh}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeStore()),
      ChangeNotifierProvider(create: (_) => mesh ?? MeshStore(transport: MockTransport())),
      Provider<SecureVault>(create: (_) => MockSecureVault()),
      Provider<AppLock>(create: (_) => MockAppLock()),
      Provider<ThreadSummarizer>(create: (_) => MockThreadSummarizer()),
      Provider<OcrReader>(create: (_) => MockOcrReader()),
      Provider<ImageSource>(create: (_) => MockImageSource()),
      Provider<CalendarWriter>(create: (_) => MockCalendarWriter()),
      Provider<ShakeService>(create: (_) => MockShakeService()),
      Provider<HapticOutput>(create: (_) => _NoOpHaptics()),
      Provider<SpeechOutput>(create: (_) => NoOpSpeechOutput()),
    ],
    child: MaterialApp(
      theme: ThemeData(brightness: Brightness.light),
      home: Scaffold(body: child),
    ),
  );
}

class _NoOpHaptics implements HapticOutput {
  @override
  Future<void> pulse(double intensity) async {}
}

class _FailingOcrReader implements OcrReader {
  @override
  Future<ReadOutcome> read(String uri) async => const ReadFailed();
}

/// Errors once, then succeeds — for exercising CatchMeUpSheet's retry path.
class _FlakyOnceSummarizer implements ThreadSummarizer {
  int calls = 0;

  @override
  Stream<SummaryState> summarize(Thread thread, int unread) async* {
    calls++;
    if (calls == 1) {
      yield const SummaryState(
        lines: [],
        isReady: false,
        isGenerating: false,
        downloadProgress: 0,
        done: false,
        error: 'boom',
      );
      return;
    }
    yield const SummaryState(lines: [], isReady: false, isGenerating: false, downloadProgress: 0, done: false);
  }
}

void main() {
  testWidgets('ReachScreen renders paired conversations and mesh status', (tester) async {
    await tester.pumpWidget(harness(ReachScreen(onOpen: (_) {}, onNewGroup: () {}), mesh: demoStore()));
    await tester.pump();

    expect(find.text('Reach'), findsOneWidget);
    expect(find.text('MESH OFF · TAP TO START'), findsOneWidget);
    expect(find.text('Braai Crew'), findsOneWidget);
  });

  testWidgets('ReachScreen new-group button calls onNewGroup', (tester) async {
    final handle = tester.ensureSemantics();
    var tapped = false;
    await tester.pumpWidget(harness(ReachScreen(onOpen: (_) {}, onNewGroup: () => tapped = true)));
    await tester.pump();

    final target = find.bySemanticsLabel('New group');
    expect(target, findsOneWidget);
    await tester.tap(target);
    expect(tapped, isTrue);
    handle.dispose();
  });

  testWidgets('ChatScreen renders thread title and messages', (tester) async {
    await tester.pumpWidget(
      harness(ChatScreen(threadId: 'thabo', onBack: () {}, onSendCoin: (_) {}), mesh: demoStore()),
    );
    await tester.pump();

    expect(find.text('Thabo Mokoena'), findsOneWidget);
    expect(find.text('Here, for the wood run'), findsOneWidget);
  });

  testWidgets('ChatScreen opens the CatchMeUpSheet once unread crosses the summary threshold', (tester) async {
    await tester.pumpWidget(
      harness(ChatScreen(threadId: 'braai', onBack: () {}, onSendCoin: (_) {}), mesh: demoStore()),
    );
    await tester.pump();

    expect(find.text('Catch me up · 11 unread'), findsOneWidget);
    await tester.tap(find.text('Catch me up · 11 unread'));
    await tester.pump();
    expect(find.byType(CatchMeUpSheet), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.textContaining('messages while you were out of range'), findsOneWidget);
  });

  testWidgets('CatchMeUpSheet retry clears the stale error before the new stream emits', (tester) async {
    final summarizer = _FlakyOnceSummarizer();
    final thread = demoThreads.firstWhere((t) => t.id == 'braai');
    await tester.pumpWidget(
      harness(
        Provider<ThreadSummarizer>.value(
          value: summarizer,
          child: CatchMeUpSheet(thread: thread, unread: thread.unread, onClose: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The summary did not finish. Every message is still in the thread above.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump(); // one frame: before the retried stream's first event lands

    expect(find.text('The summary did not finish. Every message is still in the thread above.'), findsNothing);
  });

  testWidgets('ChatScreen sends a picked photo as an image bubble', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(ChatScreen(threadId: 'thabo', onBack: () {}, onSendCoin: (_) {}), mesh: demoStore()),
    );
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Attach a photo or an event'));
    await tester.pump();
    expect(find.text('Choose photo'), findsOneWidget);

    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();

    expect(find.text('SENDING PHOTO IN 1 PARTS'), findsOneWidget);
    // The bubble it just sent — a widget-tree lookup rather than a semantics
    // one, since it may land past the scroll viewport in this short thread.
    expect(find.byType(Image), findsOneWidget);
    handle.dispose();
  });

  testWidgets('ChatScreen composes and sends an event, then saves it to the calendar', (tester) async {
    final handle = tester.ensureSemantics();
    final calendar = MockCalendarWriter();
    await tester.pumpWidget(
      harness(
        Provider<CalendarWriter>.value(
          value: calendar,
          child: ChatScreen(threadId: 'thabo', onBack: () {}, onSendCoin: (_) {}),
        ),
        mesh: demoStore(),
      ),
    );
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Attach a photo or an event'));
    await tester.pump();
    await tester.tap(find.text('Event'));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'Braai');
    await tester.pump();
    await tester.tap(find.text('Send event'));
    await tester.pumpAndSettle();

    expect(find.text('Braai'), findsOneWidget);
    expect(find.text('Add to calendar'), findsOneWidget);

    await tester.tap(find.text('Add to calendar'));
    await tester.pumpAndSettle();

    expect(find.text('ADDED TO YOUR CALENDAR'), findsOneWidget);
    expect(calendar.saved, hasLength(1));
    expect(calendar.saved.single.title, 'Braai');
    handle.dispose();
  });

  group('NewGroupScreen', () {
    testWidgets('shows the empty state before the mesh is started', (tester) async {
      await tester.pumpWidget(harness(NewGroupScreen(onBack: () {}, onCreated: (_) {})));
      await tester.pump();

      expect(find.text('New group'), findsOneWidget);
      expect(find.text('NOBODY REACHABLE'), findsOneWidget);
      expect(find.textContaining('Start the mesh from the Reach screen first'), findsOneWidget);
    });

    testWidgets('creates a group from picked peers and calls onCreated', (tester) async {
      final mesh = MeshStore(transport: MockTransport(), deviceId: 'me');
      mesh.peers = {'thabo': const MeshPeer(display: 'Thabo Mokoena', peerId: 'p-thabo')};
      String? created;

      await tester.pumpWidget(
        harness(NewGroupScreen(onBack: () {}, onCreated: (id) => created = id), mesh: mesh),
      );
      await tester.pump();

      expect(find.text('1 REACHABLE NOW'), findsOneWidget);
      expect(find.text('Thabo Mokoena'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Braai Crew');
      await tester.tap(find.text('Thabo Mokoena'));
      await tester.pump();

      await tester.tap(find.textContaining('Create with 1'));
      await tester.pumpAndSettle();

      expect(created, isNotNull);
      expect(mesh.threads.firstWhere((t) => t.id == created).title, 'Braai Crew');
    });
  });

  testWidgets('WalletScreen renders balance and ledger', (tester) async {
    await tester.pumpWidget(harness(WalletScreen(onSend: () {}, onTap: () {}), mesh: demoStore()));
    await tester.pump();

    expect(find.text('Wallet'), findsOneWidget);
    // Opening 100 + 12.50 from Thabo − 20 sent to Naledi, from the seeded
    // coin messages — the balance is derived, not a stored number.
    expect(find.text('92.50'), findsOneWidget);
    expect(find.text('Naledi Khumalo'), findsOneWidget);
  });

  testWidgets('SendCoinScreen renders the contact and keypad', (tester) async {
    await tester.pumpWidget(
      harness(SendCoinScreen(contactId: 'naledi', onBack: () {}, onQueued: (_) {}), mesh: demoStore()),
    );
    await tester.pump();

    expect(find.text('Send echocoin'), findsOneWidget);
    expect(find.text('20.00'), findsOneWidget);

    await tester.tap(find.text('5'));
    await tester.pump();
    expect(find.text('20.005'), findsOneWidget);
  });

  testWidgets('SendCoinScreen queues a coin send and calls onQueued', (tester) async {
    String? queuedFor;
    await tester.pumpWidget(
      harness(
        SendCoinScreen(contactId: 'naledi', onBack: () {}, onQueued: (id) => queuedFor = id),
        mesh: demoStore(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Send 20.00'));
    await tester.pump();

    expect(queuedFor, 'naledi');
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

  group('ReadScreen', () {
    testWidgets('renders with nothing read yet, no camera plugin on this build', (tester) async {
      await tester.pumpWidget(harness(const ReadScreen()));
      await tester.pump();

      expect(find.text('Read that'), findsWidgets); // title + button
      expect(find.text('NO CAMERA ON THIS BUILD'), findsOneWidget);
      expect(find.text('NOTHING READ YET'), findsOneWidget);
    });

    testWidgets('tapping Read that shows the transcript and reports busy then idle', (tester) async {
      final busyStates = <bool>[];
      await tester.pumpWidget(harness(ReadScreen(onBusyChange: busyStates.add)));
      await tester.pump();

      await tester.tap(find.text('Read that').last); // title + button share the label
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('LAST READ'), findsOneWidget);
      expect(find.text('EXIT'), findsOneWidget);
      expect(busyStates, [true, false]);
    });

    testWidgets('a failed read flips the status bar into the error state', (tester) async {
      await tester.pumpWidget(
        harness(Provider<OcrReader>.value(value: _FailingOcrReader(), child: const ReadScreen())),
      );
      await tester.pump();

      await tester.tap(find.text('Read that').last);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('ERROR'), findsOneWidget);
      expect(find.text("Couldn't read that."), findsOneWidget);
      expect(find.text('READER UNAVAILABLE'), findsOneWidget);
      // The button stays enabled so tapping again retries.
      expect(find.text('Read that'), findsWidgets);
    });
  });

  group('LockScreen', () {
    testWidgets('offers to turn the lock on when nothing is enabled yet', (tester) async {
      await tester.pumpWidget(harness(LockScreen(onUnlocked: () {})));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Lock Echo to this phone'), findsOneWidget);
      expect(find.text('Turn on unlock'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('Not now continues without enabling the lock', (tester) async {
      var unlocked = false;
      await tester.pumpWidget(harness(LockScreen(onUnlocked: () => unlocked = true)));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Not now'));
      await tester.pump();

      expect(unlocked, isTrue);
    });

    testWidgets('turning the lock on then unlocks through it', (tester) async {
      var unlocked = false;
      await tester.pumpWidget(harness(LockScreen(onUnlocked: () => unlocked = true)));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Turn on unlock'));
      // Bounded pumps, not pumpAndSettle: once unlocked the real app swaps
      // this screen out, but here it stays mounted mid-"prompting" pulse
      // (by design — the pulse only stops once a settled phase is reached),
      // which would make pumpAndSettle hang waiting for an animation that
      // this harness has no reason to stop.
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      expect(unlocked, isTrue);
    });
  });
}
