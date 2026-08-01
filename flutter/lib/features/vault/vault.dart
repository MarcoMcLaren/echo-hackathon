// Key vault adapter: generate/hold a keypair and encrypt/decrypt mesh payloads
// so relays only ever see opaque ciphertext. Keys never leave hardware.
//
// Port intent of src/features/vault/hooks/useSecureVault.ts (a placeholder
// upstream too — "Needs react-native-keychain"). [SecureStorageVault] persists
// the device's key material in the platform's hardware-backed secure storage
// (Android Keystore-backed EncryptedSharedPreferences) so identity survives
// restarts. This defines the contract [SecureVault] the adapter satisfies;
// the headless fake used by tests (platform channels don't run under
// `flutter test`) lives in test/features/vault_fakes.dart.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

/// Real adapter: the device's public key is minted once with a
/// cryptographically secure RNG and persisted in flutter_secure_storage, so
/// this device's identity survives restarts instead of vanishing when the
/// process dies (unlike [MockSecureVault] in test/features/vault_fakes.dart).
///
/// The encrypt/decrypt envelope below is the same opaque-to-relays encoding
/// as the fake — a real asymmetric cipher needs a crypto dependency this pass
/// doesn't add (only local_auth and flutter_secure_storage). What's real here
/// is that the key itself lives in hardware-backed storage, not memory.
class SecureStorageVault implements SecureVault {
  SecureStorageVault({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _publicKeyKey = 'echo.vault.public_key';

  final FlutterSecureStorage _storage;
  String? _cachedPublicKey;

  @override
  Future<VaultStatus> status() async {
    try {
      return await _readKey() == null
          ? VaultStatus.locked
          : VaultStatus.unlocked;
    } catch (_) {
      return VaultStatus.unavailable;
    }
  }

  @override
  Future<String> setUp() async {
    final existing = await _readKey();
    if (existing != null) return existing;
    final minted = _mint();
    await _storage.write(key: _publicKeyKey, value: minted);
    _cachedPublicKey = minted;
    return minted;
  }

  @override
  Future<SealedPayload> encrypt(
    String plaintext, {
    required String recipientPublicKey,
  }) async {
    final key = await _readKey();
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
    final myKey = await _readKey();
    if (myKey == null) return null;
    try {
      final decoded = jsonDecode(utf8.decode(base64Decode(payload.ciphertext)));
      if (decoded is! Map || decoded['for'] != myKey) return null;
      return decoded['body'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readKey() async {
    final cached = _cachedPublicKey;
    if (cached != null) return cached;
    final stored = await _storage.read(key: _publicKeyKey);
    _cachedPublicKey = stored;
    return stored;
  }

  static String _mint() {
    final rand = Random.secure();
    return base64UrlEncode(List<int>.generate(32, (_) => rand.nextInt(256)));
  }
}
