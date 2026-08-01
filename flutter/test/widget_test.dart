// Smoke test: the app opens behind the lock screen, then boots on the Reach
<<<<<<< HEAD
// tab. There is no seed data any more (see lib/store/mesh_store.dart), so a
// fresh boot has no conversations — pairing one, and opening it, is exercised
// in the pairing-ux screens rather than here.
=======
// tab and can navigate into a real chat thread and back, wired through
// MeshStore's seeded demo data.
//
// main.dart wires the real BiometricAppLock (local_auth) and
// SecureStorageVault (flutter_secure_storage) adapters, and LockScreen probes
// them as soon as EchoApp mounts. Their platform channels never resolve
// under `flutter test` without a mock handler, so this stubs both to answer
// immediately — simulating a phone with a fingerprint enrolled but the lock
// not yet turned on, matching this test's "offer" phase / "Not now" path.
import 'package:flutter/services.dart';
>>>>>>> 2ef58f0077ac9afdde4f59f2c8d2e17f0459f1b3
import 'package:flutter_test/flutter_test.dart';

import 'package:echo/main.dart';

const _localAuthChannel = MethodChannel('plugins.flutter.io/local_auth');
const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
<<<<<<< HEAD
  testWidgets('boots on Reach tab with no conversations yet', (
=======
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_localAuthChannel, (call) async {
          switch (call.method) {
            case 'getAvailableBiometrics':
              return <String>['fingerprint'];
            case 'isDeviceSupported':
              return true;
            default:
              return null;
          }
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_localAuthChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  testWidgets('boots on Reach tab and opens/closes a chat thread', (
>>>>>>> 2ef58f0077ac9afdde4f59f2c8d2e17f0459f1b3
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
