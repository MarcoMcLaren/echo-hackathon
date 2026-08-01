// App unlock, backed by a hardware-backed keystore.
//
// Not a cosmetic prompt over the UI: there is a secret in hardware-backed
// storage whose access policy requires the device owner to authenticate, so
// getting into the app means satisfying the keystore — the same mechanism
// that will guard the E2E message keys.
//
// Port of src/features/vault/api/lock.ts (react-native-keychain,
// biometry-or-device-passcode) onto local_auth + flutter_secure_storage:
// [BiometricAppLock] drives the real BiometricPrompt, gated by an "enabled"
// flag persisted in the platform's secure storage so it survives restarts.
// This defines the contract [AppLock] the adapter satisfies; the headless
// fake used by tests (platform channels don't run under `flutter test`)
// lives in test/features/vault_fakes.dart.
//
// IMPORTANT: on a phone with nothing enrolled, creating a key that requires
// user authentication makes Android launch its fingerprint-enrollment flow.
// That must never happen as a side effect of opening the app — [enable] must
// only ever run from an explicit opt-in, never from [hasBiometricHardware] or
// [isEnabled].
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

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

/// Real adapter: BiometryAny-or-device-passcode via local_auth, gated by an
/// "enabled" flag persisted in flutter_secure_storage (Android
/// Keystore-backed EncryptedSharedPreferences) so the lock stays on across
/// restarts. `biometricOnly: false` mirrors the upstream RN adapter's
/// `BIOMETRY_ANY_OR_DEVICE_PASSCODE`: biometrics first, device PIN/pattern as
/// fallback, so a phone whose owner uses a PIN isn't shut out.
class BiometricAppLock implements AppLock {
  BiometricAppLock({LocalAuthentication? auth, FlutterSecureStorage? storage})
    : _auth = auth ?? LocalAuthentication(),
      _storage = storage ?? const FlutterSecureStorage();

  static const _enabledKey = 'echo.vault.lock_enabled';

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  @override
  Future<bool> hasBiometricHardware() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isEnabled() async {
    try {
      return await _storage.read(key: _enabledKey) == 'true';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<LockOutcome> enable() async {
    if (!await hasBiometricHardware()) {
      return const LockOutcome.failure(LockFailureReason.unavailable);
    }
    try {
      await _storage.write(key: _enabledKey, value: 'true');
      return const LockOutcome.ok();
    } catch (e) {
      return LockOutcome.failure(
        LockFailureReason.error,
        message: e.toString(),
      );
    }
  }

  @override
  Future<LockOutcome> unlock() async {
    if (!await isEnabled()) {
      return const LockOutcome.failure(LockFailureReason.unavailable);
    }
    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Unlock Echo',
      );
      return didAuthenticate
          ? const LockOutcome.ok()
          : const LockOutcome.failure(LockFailureReason.cancelled);
    } on LocalAuthException catch (e) {
      return LockOutcome.failure(
        _reasonFor(e.code),
        message: e.description ?? e.code.name,
      );
    } catch (e) {
      return LockOutcome.failure(
        LockFailureReason.error,
        message: e.toString(),
      );
    }
  }

  @override
  Future<void> forget() async {
    try {
      await _storage.delete(key: _enabledKey);
    } catch (_) {
      // Nothing stored — already where we wanted to be.
    }
  }

  static LockFailureReason _reasonFor(LocalAuthExceptionCode code) =>
      switch (code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.userRequestedFallback =>
          LockFailureReason.cancelled,
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable =>
          LockFailureReason.unavailable,
        _ => LockFailureReason.error,
      };
}
