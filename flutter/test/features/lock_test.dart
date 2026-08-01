// Unit tests for lib/features/vault/lock.dart's headless fake, covering the
// state machine LockScreen drives: no hardware, offer/enable, unlock success,
// cancelled, and error paths.
import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/vault/lock.dart';

void main() {
  group('MockAppLock', () {
    test('starts disabled and reports biometric hardware presence', () async {
      final lock = MockAppLock();
      expect(await lock.isEnabled(), isFalse);
      expect(await lock.hasBiometricHardware(), isTrue);
    });

    test('enable() turns the lock on, then unlock() succeeds', () async {
      final lock = MockAppLock();

      final enabled = await lock.enable();
      expect(enabled.ok, isTrue);
      expect(await lock.isEnabled(), isTrue);

      final unlocked = await lock.unlock();
      expect(unlocked.ok, isTrue);
    });

    test(
      'unlock() before enable() is unavailable rather than a crash',
      () async {
        final lock = MockAppLock();
        final result = await lock.unlock();
        expect(result.ok, isFalse);
        expect(result.reason, LockFailureReason.unavailable);
      },
    );

    test('enable() refuses when there is no biometric hardware', () async {
      final lock = MockAppLock(hasHardware: false);
      final result = await lock.enable();
      expect(result.ok, isFalse);
      expect(result.reason, LockFailureReason.unavailable);
      expect(await lock.isEnabled(), isFalse);
    });

    test(
      'unlock() surfaces a cancelled outcome without treating it as an error',
      () async {
        final lock = MockAppLock(
          enabled: true,
          nextUnlockOutcome: const LockOutcome.failure(
            LockFailureReason.cancelled,
          ),
        );
        final result = await lock.unlock();
        expect(result.ok, isFalse);
        expect(result.reason, LockFailureReason.cancelled);
      },
    );

    test('forget() turns the lock back off', () async {
      final lock = MockAppLock(enabled: true);
      await lock.forget();
      expect(await lock.isEnabled(), isFalse);
      final result = await lock.unlock();
      expect(result.ok, isFalse);
    });
  });
}
