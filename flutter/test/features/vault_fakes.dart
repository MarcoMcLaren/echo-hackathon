// Headless fakes for [AppLock] and [SecureVault], moved out of lib/ now that
// lib/features/vault/lock.dart and lib/features/vault/vault.dart carry real,
// platform-channel-backed implementations (BiometricAppLock,
// SecureStorageVault). Platform channels don't run under `flutter test`, so
// the test suite keeps exercising these fakes instead of the real adapters.
import 'dart:convert';

import 'package:echo/features/vault/lock.dart';
import 'package:echo/features/vault/vault.dart';

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

/// Headless fake: keys are plain random strings held in memory (NOT hardware,
/// NOT real cryptography) and "encryption" is a reversible encoding tagged
/// with the recipient key, so tests can assert who a payload was sealed for
/// without a real cipher. Never ship this as the production vault.
class MockSecureVault implements SecureVault {
  MockSecureVault({String? seedPublicKey}) : _publicKey = seedPublicKey;

  String? _publicKey;

  @override
  Future<VaultStatus> status() async =>
      _publicKey == null ? VaultStatus.locked : VaultStatus.unlocked;

  @override
  Future<String> setUp() async {
    _publicKey ??= 'mock-pk-${DateTime.now().microsecondsSinceEpoch}';
    return _publicKey!;
  }

  @override
  Future<SealedPayload> encrypt(
    String plaintext, {
    required String recipientPublicKey,
  }) async {
    final key = _publicKey;
    if (key == null) {
      throw StateError('SecureVault.setUp() must run before encrypt()');
    }
    final envelope = jsonEncode({'for': recipientPublicKey, 'body': plaintext});
    return SealedPayload(
      ciphertext: base64Encode(utf8.encode(envelope)),
      senderPublicKey: key,
    );
  }

  @override
  Future<String?> decrypt(SealedPayload payload) async {
    final myKey = _publicKey;
    if (myKey == null) return null;
    try {
      final decoded = jsonDecode(utf8.decode(base64Decode(payload.ciphertext)));
      if (decoded is! Map || decoded['for'] != myKey) return null;
      return decoded['body'] as String?;
    } catch (_) {
      return null;
    }
  }
}
