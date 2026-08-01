// Real, on-disk backing for the two things that must outlive a process:
// this phone's identity and its contact list.
//
// Both interfaces (ProfileStore in identity.dart, ContactsStore in
// contacts.dart) previously had only in-memory defaults, so every launch was
// a first launch: the app asked for a name again and minted a *new* device
// id, which silently broke every pairing made before the restart — a peer
// holds the old id and can no longer address you. These back the same
// contracts with flutter_secure_storage, the plugin SecureStorageVault
// already uses, so identity and key material live in the same place.
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'contacts.dart';
import 'identity.dart';

/// The slice of key-value storage these stores need. Depending on this rather
/// than on FlutterSecureStorage directly keeps them testable: the plugin's
/// method channel does not exist under `flutter test`, and its option
/// parameters change shape between major versions.
abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// The real one: the same plugin SecureStorageVault uses.
class KeystoreKeyValueStore implements SecureKeyValueStore {
  KeystoreKeyValueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Keystore-backed [ProfileStore]. A read failure (corrupt or unreadable
/// entry) reports "never set up" rather than throwing — the caller's job is
/// to send someone to the name screen, not to crash.
class SecureStorageProfileStore implements ProfileStore {
  SecureStorageProfileStore({SecureKeyValueStore? storage})
    : _storage = storage ?? KeystoreKeyValueStore();

  static const _key = 'echo.identity.profile';

  final SecureKeyValueStore _storage;

  @override
  Future<Profile?> read() async {
    try {
      final raw = await _storage.read(_key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final id = decoded['id'];
      final name = decoded['name'];
      if (id is! String || name is! String || id.isEmpty) return null;
      return Profile(id: id, name: name);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(Profile profile) async {
    await _storage.write(
      _key,
      jsonEncode({'id': profile.id, 'name': profile.name}),
    );
  }

  @override
  Future<void> delete() async {
    await _storage.delete(_key);
  }
}

/// Keystore-backed [ContactsStore]. Contacts are the allowlist that decides
/// who may message you, so losing them on restart is the same failure as
/// losing the identity.
class SecureStorageContactsStore implements ContactsStore {
  SecureStorageContactsStore({SecureKeyValueStore? storage})
    : _storage = storage ?? KeystoreKeyValueStore();

  static const _key = 'echo.vault.contacts';

  final SecureKeyValueStore _storage;

  @override
  Future<Map<String, Contact>> readAll() async {
    try {
      final raw = await _storage.read(_key);
      if (raw == null) return const {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final out = <String, Contact>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final id = value['id'];
        final name = value['name'];
        final addedAt = value['addedAt'];
        if (id is! String || name is! String || addedAt is! int) continue;
        out[id] = Contact(id: id, name: name, addedAt: addedAt);
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<void> writeAll(Map<String, Contact> contacts) async {
    await _storage.write(
      _key,
      jsonEncode({
        for (final c in contacts.values)
          c.id: {'id': c.id, 'name': c.name, 'addedAt': c.addedAt},
      }),
    );
  }
}
