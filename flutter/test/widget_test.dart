// Smoke test: the app opens behind the lock screen, then boots on the Reach
// tab. There is no seed data any more (see lib/store/mesh_store.dart), so a
// fresh boot has no conversations — pairing one, and opening it, is exercised
// in the pairing-ux screens rather than here.
import 'package:flutter_test/flutter_test.dart';

import 'package:echo/main.dart';

void main() {
  testWidgets('boots on Reach tab with no conversations yet', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EchoApp());
    await tester.pumpAndSettle();

    // Nothing behind the lock renders until it opens — the demo phone has no
    // lock enabled yet, so this is the "offer" phase's decline path.
    expect(find.text('Lock Echo to this phone'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.text('Reach'), findsOneWidget);
    expect(find.text('REACH'), findsOneWidget);
    expect(find.text('WALLET'), findsOneWidget);
    expect(find.text('MEET'), findsOneWidget);
    expect(find.text('READ'), findsOneWidget);

    // Real data only — nobody is paired on a fresh boot.
    expect(find.text('Thabo Mokoena'), findsNothing);
  });

  testWidgets('switching to the READ tab and back does not crash the shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EchoApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('READ'));
    await tester.pumpAndSettle();
    expect(find.text('Read that'), findsWidgets);

    // ReadScreen unmounts here — regression: its dispose() used to call the
    // parent's setState synchronously, which crashes while the framework is
    // mid-build tearing down the old tab.
    await tester.tap(find.text('REACH'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Reach'), findsOneWidget);
  });
}
