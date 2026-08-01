// App unlock — ported from features/vault/api/lock.ts.
//
// Not a cosmetic prompt over the UI: `local_auth` asks the OS to verify the
// device owner (biometric, falling back to PIN/pattern/password), and only on
// success do we flip the flag `flutter_secure_storage` holds in the Android
// Keystore. Getting into the app means satisfying that check.
//
// IMPORTANT: creating the enrolment prompt on a phone with nothing enrolled
// launches Android's own enrollment flow. That must never happen as a side
// effect of opening the app, so the flag is only ever set from an explicit
// opt-in — see `enableLock`.
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

const _storageKey = 'echo_unlock_enabled';

/// A hung platform call must never hold the door shut forever — fail closed
/// after a few seconds rather than leave the app stuck on "checking".
Future<T> _guarded<T>(Future<T> future) => future.timeout(const Duration(seconds: 6));

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

final _auth = LocalAuthentication();

enum LockFailReason { cancelled, unavailable, error }

class LockOutcome {
  final bool ok;
  final LockFailReason? reason;
  final String? message;
  const LockOutcome.success()
      : ok = true,
        reason = null,
        message = null;
  const LockOutcome.failure(this.reason, [this.message]) : ok = false;
}

LockFailReason _reasonFor(Object e) {
  if (e is PlatformException) {
    switch (e.code) {
      case 'NotAvailable':
      case 'NotEnrolled':
      case 'PasscodeNotSet':
        return LockFailReason.unavailable;
      case 'LockedOut':
      case 'PermanentlyLockedOut':
        return LockFailReason.error;
    }
  }
  return LockFailReason.error;
}

/// Does this phone have biometric hardware (or at least a device
/// PIN/pattern) at all? Says nothing about whether it's actually enrolled —
/// `authenticate()` is what surfaces that, via `NotEnrolled`.
Future<bool> hasBiometricHardware() async {
  try {
    return await _guarded(_auth.isDeviceSupported());
  } catch (_) {
    return false;
  }
}

/// Has the user already turned the lock on? Does not authenticate or prompt.
Future<bool> isLockEnabled() async {
  try {
    return (await _guarded(_storage.read(key: _storageKey))) == 'true';
  } catch (_) {
    return false;
  }
}

/// Turn the lock on. Only call this from a deliberate user action — on a
/// phone with nothing enrolled, Android may open its enrollment flow here,
/// and that is only acceptable when someone has just asked for exactly this.
Future<LockOutcome> enableLock() async {
  try {
    final authenticated = await _guarded(_auth.authenticate(
      localizedReason: "Confirm it's you to turn on Echo's lock",
      options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
    ));
    if (!authenticated) return const LockOutcome.failure(LockFailReason.cancelled);
    await _guarded(_storage.write(key: _storageKey, value: 'true'));
    return const LockOutcome.success();
  } catch (e) {
    return LockOutcome.failure(_reasonFor(e), e.toString());
  }
}

/// Ask the device owner to prove who they are. Only meaningful once enabled.
Future<LockOutcome> unlock() async {
  try {
    final authenticated = await _guarded(_auth.authenticate(
      localizedReason: 'Unlock Echo — your messages, keys and wallet are on this phone',
      options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
    ));
    return authenticated ? const LockOutcome.success() : const LockOutcome.failure(LockFailReason.cancelled);
  } catch (e) {
    return LockOutcome.failure(_reasonFor(e), e.toString());
  }
}

/// Turn the lock off, or recover a demo phone that got into a bad state.
Future<void> forgetLock() async {
  try {
    await _guarded(_storage.delete(key: _storageKey));
  } catch (_) {
    // Nothing stored — already where we wanted to be.
  }
}
