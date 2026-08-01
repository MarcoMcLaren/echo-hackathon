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

  testWidgets('App opens on Reach and can open a conversation', (WidgetTester tester) async {
    sizeLikeAPhone(tester);
    await tester.pumpWidget(const EchoApp());
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thabo Mokoena'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Howzit');
    await tester.tap(find.text('↑'));
    await tester.pumpAndSettle();

    expect(find.text('Howzit'), findsOneWidget);
    expect(find.textContaining('QUEUED'), findsOneWidget);
  });
}
