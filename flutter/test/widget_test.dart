import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:welcome_app/main.dart';

void main() {
  // Default test surface is a tiny 800x600 window — nothing like the tall
  // phone viewport these screens are built for. Size it like a real phone.
  void sizeLikeAPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  // The test harness has no local_auth/flutter_secure_storage platform
  // channels, so their calls hang until lock.dart's own 6s guard timeout
  // fires, then LockScreen fails closed to its "offer, no hardware" phase —
  // tap through it the same way a phone with no fingerprint/PIN set up would.
  // Uses bounded pump() rather than pumpAndSettle(): the "checking"/"prompting"
  // phases loop a pulse animation that never settles on its own, and
  // AutomatedTestWidgetsFlutterBinding fakes the clock, so pumping past 6s of
  // virtual time is what actually fires the timeout — not wall-clock waiting.
  Future<void> pumpUntilSettled(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> skipLockScreen(WidgetTester tester) async {
    await pumpUntilSettled(tester);
    final continueButton = find.text('Continue without a lock');
    if (continueButton.evaluate().isNotEmpty) {
      await tester.tap(continueButton);
      await pumpUntilSettled(tester);
    }
  }

  testWidgets('App opens on Reach and can open a conversation', (WidgetTester tester) async {
    sizeLikeAPhone(tester);
    await tester.pumpWidget(const EchoApp());
    await skipLockScreen(tester);

    expect(find.text('Reach'), findsOneWidget);
    expect(find.text('Braai Crew'), findsOneWidget);

    await tester.tap(find.text('Braai Crew'));
    await tester.pumpAndSettle();

    expect(find.text('Naledi: someone bring tongs'), findsNothing); // Chat view, not the list preview
    expect(find.text('TODAY'), findsOneWidget);
  });

  testWidgets('Wallet screen shows balance and can open Send', (WidgetTester tester) async {
    sizeLikeAPhone(tester);
    await tester.pumpWidget(const EchoApp());
    await skipLockScreen(tester);

    await tester.tap(find.text('WALLET'));
    await tester.pumpAndSettle();

    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('148.25'), findsOneWidget);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Send echocoin'), findsOneWidget);
  });

  testWidgets('Sending a chat message appends a queued bubble', (WidgetTester tester) async {
    sizeLikeAPhone(tester);
    await tester.pumpWidget(const EchoApp());
    await skipLockScreen(tester);

    await tester.tap(find.text('Thabo Mokoena'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Howzit');
    await tester.tap(find.text('↑'));
    await tester.pumpAndSettle();

    expect(find.text('Howzit'), findsOneWidget);
    expect(find.textContaining('QUEUED'), findsOneWidget);
  });
}
