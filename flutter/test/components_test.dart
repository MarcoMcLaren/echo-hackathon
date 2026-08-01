// Widget tests for lib/components/* — rendering per state, interactions, and
// accessibility semantics. No device/emulator required (headless, Dart VM).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:echo/components/avatar.dart';
import 'package:echo/components/chip.dart';
import 'package:echo/components/chrome.dart';
import 'package:echo/components/route_strip.dart';
import 'package:echo/components/type.dart';
import 'package:echo/store/theme_store.dart';
import 'package:echo/styles/theme.dart' as tokens;

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
  group('Type', () {
    testWidgets('Display/Body/Mono render their text', (tester) async {
      await tester.pumpWidget(
        harness(
          const Column(
            children: [Display('Title'), Body('Sentence'), Mono('HOPS')],
          ),
        ),
      );
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Sentence'), findsOneWidget);
      expect(find.text('HOPS'), findsOneWidget);
    });

    testWidgets('Display dim levels resolve distinct ink shades', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const Column(
            children: [
              Display('a', dim: 2, key: Key('dim2')),
              Display('a', dim: 3, key: Key('dim3')),
            ],
          ),
        ),
      );
      final dim2 = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('dim2')),
          matching: find.byType(Text),
        ),
      );
      final dim3 = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('dim3')),
          matching: find.byType(Text),
        ),
      );
      expect(dim2.style!.color, tokens.light.ink2);
      expect(dim3.style!.color, tokens.light.ink3);
    });

    testWidgets('CoinMark renders the E glyph', (tester) async {
      await tester.pumpWidget(harness(const CoinMark()));
      expect(find.text('E'), findsOneWidget);
    });
  });

  group('Avatar', () {
    testWidgets('direct hop (0) rings in the direct colour', (tester) async {
      await tester.pumpWidget(harness(const Avatar(initials: 'LN', hops: 0)));
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border!.top.color, tokens.light.direct);
      expect(find.text('LN'), findsOneWidget);
    });

    testWidgets('relayed hop (>0) rings in the relay colour', (tester) async {
      await tester.pumpWidget(harness(const Avatar(initials: 'NK', hops: 1)));
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border!.top.color, tokens.light.relay);
    });

    testWidgets('unreachable (null) has no ring and is dimmed', (tester) async {
      await tester.pumpWidget(
        harness(const Avatar(initials: 'SD', hops: null)),
      );
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNull);
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.45);
    });
  });

  group('Chip', () {
    testWidgets('HopChip labels Direct/Via/No route per hop state', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const HopChip(hops: 0)));
      expect(find.text('DIRECT'), findsOneWidget);

      await tester.pumpWidget(harness(const HopChip(hops: 1, via: 'Thabo')));
      expect(find.text('VIA THABO'), findsOneWidget);

      await tester.pumpWidget(harness(const HopChip(hops: null)));
      expect(find.text('NO ROUTE'), findsOneWidget);
    });

    testWidgets('CoinChip uppercases its label', (tester) async {
      await tester.pumpWidget(harness(const CoinChip(label: '+40 echo')));
      expect(find.text('+40 ECHO'), findsOneWidget);
    });
  });

  group('RouteStrip', () {
    testWidgets('shows only two dots when direct, three when relayed', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const RouteStrip(hops: 0)));
      expect(find.byType(Container), findsNWidgets(3)); // dot, seg, dot

      await tester.pumpWidget(harness(const RouteStrip(hops: 1, via: 'thabo')));
      // dot, seg, hollow dot, seg, dot = 5 containers, plus the VIA label.
      expect(find.byType(Container), findsNWidgets(5));
      expect(find.text('VIA THABO'), findsOneWidget);
    });

    testWidgets('unreachable route is dimmed via opacity', (tester) async {
      await tester.pumpWidget(harness(const RouteStrip(hops: null)));
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.45);
    });
  });

  group('Chrome', () {
    testWidgets('Screen paints the paper background behind its child', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const Screen(child: Text('body'))));
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('MeshStatus exposes button semantics when pressable', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var pressed = false;
      await tester.pumpWidget(
        harness(
          MeshStatus(state: MeshState.live, onPress: () => pressed = true),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Mesh live. NO SIM · WI-FI OFF · BLE ON'),
        findsOneWidget,
      );
      tester.widget<GestureDetector>(find.byType(GestureDetector)).onTap!();
      expect(pressed, isTrue);
      handle.dispose();
    });

    testWidgets('EchoAppBar back button meets the 48dp touch minimum', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var back = false;
      await tester.pumpWidget(
        harness(EchoAppBar(title: 'Braai Crew', onBack: () => back = true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Braai Crew'), findsOneWidget);
      final backTarget = find.bySemanticsLabel('Back');
      expect(backTarget, findsOneWidget);
      final size = tester.getSize(backTarget);
      expect(size.width, greaterThanOrEqualTo(tokens.touchMin));
      expect(size.height, greaterThanOrEqualTo(tokens.touchMin));
      await tester.tap(backTarget);
      expect(back, isTrue);
      handle.dispose();
    });

    testWidgets('BottomNav marks the active tab as selected', (tester) async {
      var tab = AppTab.reach;
      await tester.pumpWidget(
        harness(
          StatefulBuilder(
            builder: (context, setState) =>
                BottomNav(tab: tab, onTab: (t) => setState(() => tab = t)),
          ),
        ),
      );
      expect(find.text('REACH'), findsOneWidget);
      expect(find.text('WALLET'), findsOneWidget);
      expect(find.text('MEET'), findsOneWidget);

      await tester.tap(find.text('WALLET'));
      await tester.pump();
      expect(tab, AppTab.wallet);
    });
  });
}
