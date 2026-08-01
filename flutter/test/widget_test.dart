// Smoke test: the app opens behind the lock screen, then boots on the Reach
// tab and can navigate into a real chat thread and back, wired through
// MeshStore's seeded demo data.
import 'package:flutter_test/flutter_test.dart';

import 'package:echo/main.dart';

void main() {
  testWidgets('boots on Reach tab and opens/closes a chat thread', (
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

    await tester.tap(find.text('Thabo Mokoena'));
    await tester.pumpAndSettle();

    expect(find.text('REACH'), findsNothing);
    expect(find.text('Here, for the wood run'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Reach'), findsOneWidget);
  });
}
