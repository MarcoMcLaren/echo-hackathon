// Smoke test: the app boots on the Reach tab and can navigate to Chat and
// back via the stub screens' demo affordances.
import 'package:flutter_test/flutter_test.dart';

import 'package:echo/main.dart';

void main() {
  testWidgets('boots on Reach tab and opens/closes a chat thread', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EchoApp());
    await tester.pumpAndSettle();

    expect(find.text('Reach'), findsOneWidget);
    expect(find.text('REACH'), findsOneWidget);
    expect(find.text('WALLET'), findsOneWidget);
    expect(find.text('MEET'), findsOneWidget);

    await tester.tap(find.text('Open demo thread'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Chat'), findsOneWidget);
    expect(find.text('REACH'), findsNothing);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Reach'), findsOneWidget);
  });
}
