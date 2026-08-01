// App unlock, backed by a hardware-backed keystore.
//
// Not a cosmetic prompt over the UI: there is a secret in hardware-backed
// storage whose access policy requires the device owner to authenticate, so
// getting into the app means satisfying the keystore — the same mechanism
// that will guard the E2E message keys.
//
// Port intent of src/features/vault/api/lock.ts (react-native-keychain,
// biometry-or-device-passcode). The real implementation is native platform
// work (Android Keystore); this defines the contract [AppLock] a native
// adapter must satisfy and a headless fake so the lock screen can be built
// and tested without a device.
//
// IMPORTANT: on a phone with nothing enrolled, creating a key that requires
// user authentication makes Android launch its fingerprint-enrollment flow.
// That must never happen as a side effect of opening the app — a real
// adapter's [enable] must only ever run from an explicit opt-in, mirrored
// here by [MockAppLock] never enrolling anything on its own.
enum LockFailureReason { cancelled, unavailable, error }

class LockOutcome {
  const LockOutcome.ok() : ok = true, reason = null, message = null;

  const LockOutcome.failure(this.reason, {this.message}) : ok = false;

  final bool ok;
  final LockFailureReason? reason;
  final String? message;
}

/// Contract a native hardware-backed lock must satisfy.
abstract class AppLock {
  /// Does this phone have biometric hardware at all? Says nothing about
  /// whether anything is actually enrolled.
  Future<bool> hasBiometricHardware();

  /// Has the user already turned the lock on? Does not authenticate or prompt.
  Future<bool> isEnabled();

  /// Turn the lock on. Only call this from a deliberate user action.
  Future<LockOutcome> enable();

  /// Ask the device owner to prove who they are. Only meaningful once enabled.
  Future<LockOutcome> unlock();

  /// Turn the lock off, or recover a demo phone that got into a bad state.
  Future<void> forget();
}

/// Headless fake: no Keystore, no biometric prompt. Behavior is driven by
/// fields tests can flip directly, so every branch of [LockScreen]'s state
/// machine — offered, prompting, locked, error, no hardware — is reachable
/// without a device.
class MockAppLock implements AppLock {
  MockAppLock({
    this._hasHardware = true,
    this._enabled = false,
    this.nextUnlockOutcome = const LockOutcome.ok(),
  });

  final bool _hasHardware;
  bool _enabled;

  /// What [unlock] returns the next time it is called. Defaults to success.
  LockOutcome nextUnlockOutcome;

  @override
  Future<bool> hasBiometricHardware() async => _hasHardware;

  @override
  Future<bool> isEnabled() async => _enabled;

  @override
  Future<LockOutcome> enable() async {
    if (!_hasHardware) {
      return const LockOutcome.failure(LockFailureReason.unavailable);
    }
    _enabled = true;
    return const LockOutcome.ok();
  }

  @override
  Future<LockOutcome> unlock() async {
    if (!_enabled) {
      return const LockOutcome.failure(LockFailureReason.unavailable);
    }
    return nextUnlockOutcome;
  }

  @override
  Future<void> forget() async {
    _enabled = false;
  }
}
