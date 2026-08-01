// Widget tests for lib/features/messaging/message_bubble.dart — the photo
// and event variants added alongside groups. No device/emulator required.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:echo/features/messaging/events.dart';
import 'package:echo/features/messaging/message_bubble.dart';
import 'package:echo/store/mock.dart' as mock;
import 'package:echo/store/theme_store.dart';

Widget harness(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => ThemeStore(),
    child: MaterialApp(
      theme: ThemeData(brightness: Brightness.light),
      home: Scaffold(body: child),
    ),
  );
}

const _fakeDataUri = 'data:image/jpeg;base64,ZmFrZQ==';

void main() {
  group('MessageBubble · photo', () {
    testWidgets('renders an image with accessible "Photo" semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          const MessageBubble(
            msg: mock.Msg(id: 'i1', from: 'thabo', image: _fakeDataUri, at: '09:00', hops: 0),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(find.bySemanticsLabel('Photo'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('falls back to a placeholder for undecodable image data', (tester) async {
      await tester.pumpWidget(
        harness(
          const MessageBubble(
            msg: mock.Msg(id: 'i2', from: 'thabo', image: 'not a data uri', at: '09:00', hops: 0),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('MessageBubble · event', () {
    const event = MeshEvent(title: 'Braai', startsAt: 1735660800000, location: "Lerato's place");

    testWidgets('renders the event card and calls onSaveEvent', (tester) async {
      final handle = tester.ensureSemantics();
      MeshEvent? saved;
      await tester.pumpWidget(
        harness(
          MessageBubble(
            msg: const mock.Msg(id: 'e1', from: 'thabo', event: event, at: '09:00', hops: 0),
            onSaveEvent: (e) => saved = e,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Braai'), findsOneWidget);
      expect(find.text("Lerato's place"), findsOneWidget);
      expect(find.bySemanticsLabel('Add to calendar'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Add to calendar'));
      expect(saved, event);
      handle.dispose();
    });

    testWidgets('the calendar button is inert without an onSaveEvent handler', (tester) async {
      await tester.pumpWidget(
        harness(const MessageBubble(msg: mock.Msg(id: 'e2', from: 'me', event: event, at: '09:00', hops: 0))),
      );
      await tester.pump();

      await tester.tap(find.text('Add to calendar'));
      expect(tester.takeException(), isNull);
    });
  });
}
