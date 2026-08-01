// Widget tests for lib/features/messaging/event_composer.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:echo/features/messaging/event_composer.dart';
import 'package:echo/features/messaging/events.dart';
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

void main() {
  testWidgets('renders the three time presets and blocks sending without a title', (tester) async {
    final handle = tester.ensureSemantics();
    MeshEvent? sent;
    await tester.pumpWidget(harness(EventComposer(onCancel: () {}, onSend: (e) => sent = e)));
    await tester.pump();

    expect(find.text('TONIGHT 18:00'), findsOneWidget);
    expect(find.text('TOMORROW 14:00'), findsOneWidget);
    expect(find.text('SATURDAY 14:00'), findsOneWidget);

    expect(find.bySemanticsLabel('Send event'), findsOneWidget);
    await tester.tap(find.text('Send event'));
    await tester.pump();

    expect(sent, isNull);
    handle.dispose();
  });

  testWidgets('sends the typed title, chosen slot and optional location', (tester) async {
    MeshEvent? sent;
    await tester.pumpWidget(harness(EventComposer(onCancel: () {}, onSend: (e) => sent = e)));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'Braai');
    await tester.enterText(find.byType(TextField).last, "Lerato's place");
    await tester.tap(find.text('TOMORROW 14:00'));
    await tester.pump();
    await tester.tap(find.text('Send event'));
    await tester.pump();

    expect(sent, isNotNull);
    expect(sent!.title, 'Braai');
    expect(sent!.location, "Lerato's place");
  });

  testWidgets('Cancel calls onCancel', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(harness(EventComposer(onCancel: () => cancelled = true, onSend: (_) {})));
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    expect(cancelled, isTrue);
  });
}
