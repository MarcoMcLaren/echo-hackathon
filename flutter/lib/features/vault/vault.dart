// Key vault adapter: generate/hold a keypair and encrypt/decrypt mesh payloads
// so relays only ever see opaque ciphertext. Keys never leave hardware.
//
// Port intent of src/features/vault/hooks/useSecureVault.ts (a placeholder
// upstream too — "Needs react-native-keychain"). The real implementation is
// native platform work (Android Keystore via a hardware-backed keystore
// plugin); this defines the contract it must satisfy and a fake that lets
// the messaging UI and encryption call sites be built and tested headlessly
// today.
import 'dart:convert';

/// Whether the hardware-backed keystore is ready to use.
enum VaultStatus {
  /// No keypair yet; [SecureVault.setUp] has not run.
  locked,

  /// A keypair exists and is ready for [SecureVault.encrypt]/[decrypt].
  unlocked,

  /// The hardware keystore isn't available on this device — mesh payloads
  /// would have to travel unencrypted, so callers should refuse to send
  /// rather than silently downgrade.
  unavailable,
}

/// A payload plus enough metadata for the other side to prove who sent it.
class SealedPayload {
  const SealedPayload({
    required this.ciphertext,
    required this.senderPublicKey,
  });

  final String ciphertext;
  final String senderPublicKey;
}

/// Contract a native hardware-backed keystore must satisfy. All methods are
/// async because a real implementation crosses a platform channel.
abstract class SecureVault {
  Future<VaultStatus> status();

  /// Generates (if needed) and returns this device's public key, shareable
  /// over QR/NFC for pairing. Never returns the private key.
  Future<String> setUp();

  /// Opaque to relays — only the holder of [recipientPublicKey]'s matching
  /// private key can [decrypt] it.
  Future<SealedPayload> encrypt(
    String plaintext, {
    required String recipientPublicKey,
  });

  /// Returns null for a payload not addressed to this device's key, or one
  /// that fails to authenticate — never throws on untrusted input.
  Future<String?> decrypt(SealedPayload payload);
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
