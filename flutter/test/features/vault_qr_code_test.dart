import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/vault/qr_code.dart';

void main() {
  testWidgets('VaultQrCode renders a QR image for a public key', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: VaultQrCode(value: 'mock-pk-12345')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(VaultQrCode), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
