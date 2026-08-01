// The regression these cover: identity and contacts used to be held only in
// memory, so a restart asked for a name again and minted a new device id,
// orphaning every pairing. A profile written by one store instance must be
// readable by the next one over the same backing storage.
import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/vault/contacts.dart';
import 'package:echo/features/vault/identity.dart';
import 'package:echo/features/vault/secure_stores.dart';

/// Stands in for the platform keystore: the plugin's method channel does not
/// exist under flutter test, but the persistence contract is the same.
class FakeSecureStorage implements SecureKeyValueStore {
  final Map<String, String> entries = {};

  @override
  Future<String?> read(String key) async => entries[key];

  @override
  Future<void> write(String key, String value) async {
    entries[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    entries.remove(key);
  }
}

void main() {
  group('SecureStorageProfileStore', () {
    test('a profile written in one session is read back by the next', () async {
      final storage = FakeSecureStorage();
      await SecureStorageProfileStore(
        storage: storage,
      ).write(const Profile(id: 'abc123', name: 'Jacques'));

      // A fresh instance, as a relaunch would build.
      final reread = await SecureStorageProfileStore(storage: storage).read();

      expect(reread, isNotNull);
      expect(reread!.id, 'abc123');
      expect(reread.name, 'Jacques');
    });

    test('reads null when nothing was ever written', () async {
      final store = SecureStorageProfileStore(storage: FakeSecureStorage());
      expect(await store.read(), isNull);
    });

    test('a corrupt entry reads as never-set-up rather than throwing', () async {
      final storage = FakeSecureStorage();
      storage.entries['echo.identity.profile'] = 'not json at all';
      final store = SecureStorageProfileStore(storage: storage);
      expect(await store.read(), isNull);
    });

    test('delete sends the phone back to first run', () async {
      final storage = FakeSecureStorage();
      final store = SecureStorageProfileStore(storage: storage);
      await store.write(const Profile(id: 'abc123', name: 'Jacques'));
      await store.delete();
      expect(await store.read(), isNull);
    });
  });

  group('SecureStorageContactsStore', () {
    test('contacts survive into a new store instance', () async {
      final storage = FakeSecureStorage();
      await SecureStorageContactsStore(storage: storage).writeAll({
        'thabo': const Contact(id: 'thabo', name: 'Thabo', addedAt: 1000),
      });

      final reread = await SecureStorageContactsStore(storage: storage).readAll();

      expect(reread, hasLength(1));
      expect(reread['thabo']!.name, 'Thabo');
      expect(reread['thabo']!.addedAt, 1000);
    });

    test('a corrupt entry reads as an empty list rather than throwing', () async {
      final storage = FakeSecureStorage();
      storage.entries['echo.vault.contacts'] = '{{{';
      expect(
        await SecureStorageContactsStore(storage: storage).readAll(),
        isEmpty,
      );
    });
  });
}
