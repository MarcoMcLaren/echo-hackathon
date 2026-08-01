import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/vault/identity.dart';

void main() {
  group('InMemoryProfileStore', () {
    test('read returns null until something has been written', () async {
      final store = InMemoryProfileStore();
      expect(await store.read(), isNull);

      await store.write(const Profile(id: 'abc123', name: 'Reon'));
      expect((await store.read())?.id, 'abc123');
    });

    test('delete clears a previously written profile', () async {
      final store = InMemoryProfileStore();
      await store.write(const Profile(id: 'abc123', name: 'Reon'));

      await store.delete();

      expect(await store.read(), isNull);
    });
  });

  group('IdentityVault.loadProfile', () {
    test('returns null when nothing has been set up', () async {
      final vault = IdentityVault(InMemoryProfileStore());
      expect(await vault.loadProfile(), isNull);
    });

    test('returns the persisted profile once created', () async {
      final store = InMemoryProfileStore();
      final vault = IdentityVault(store);
      final created = await vault.createProfile('Reon Fourie');

      final loaded = await IdentityVault(store).loadProfile();

      expect(loaded?.id, created.id);
      expect(loaded?.name, 'Reon Fourie');
    });

    test('caches in memory — repeated calls return the same profile', () async {
      final vault = IdentityVault(InMemoryProfileStore());
      await vault.createProfile('Reon');

      final first = await vault.loadProfile();
      final second = await vault.loadProfile();

      expect(second?.id, first?.id);
    });
  });

  group('IdentityVault.createProfile', () {
    test('mints an id and trims the given name', () async {
      final vault = IdentityVault(InMemoryProfileStore());

      final profile = await vault.createProfile('  Reon Fourie  ');

      expect(profile.id, isNotEmpty);
      expect(profile.name, 'Reon Fourie');
    });

    test('each vault defaults to its own unshared store', () async {
      final a = await IdentityVault().createProfile('A');
      final b = await IdentityVault().createProfile('B');
      expect(a.id, isNot(b.id));
    });
  });

  group('IdentityVault.renameProfile', () {
    test('changes the name without changing the id', () async {
      final vault = IdentityVault(InMemoryProfileStore());
      final created = await vault.createProfile('Old Name');

      final renamed = await vault.renameProfile('New Name');

      expect(renamed?.id, created.id);
      expect(renamed?.name, 'New Name');
    });

    test('returns null when no profile exists yet', () async {
      final vault = IdentityVault(InMemoryProfileStore());
      expect(await vault.renameProfile('Someone'), isNull);
    });
  });

  group('IdentityVault.resetIdentity', () {
    test('clears the cache and the store', () async {
      final store = InMemoryProfileStore();
      final vault = IdentityVault(store);
      await vault.createProfile('Reon');

      await vault.resetIdentity();

      expect(await vault.loadProfile(), isNull);
      expect(await store.read(), isNull);
    });
  });

  group('a storage failure', () {
    test('loadProfile() surviving a throwing read returns null rather than throwing', () async {
      final vault = IdentityVault(_ThrowingProfileStore());
      expect(await vault.loadProfile(), isNull);
    });

    test('createProfile() still resolves a usable profile when write() throws', () async {
      final vault = IdentityVault(_WriteThrowingProfileStore());
      final profile = await vault.createProfile('Reon');
      expect(profile.name, 'Reon');
    });
  });
}

class _ThrowingProfileStore implements ProfileStore {
  @override
  Future<Profile?> read() async => throw StateError('disk unavailable');

  @override
  Future<void> write(Profile profile) async {}

  @override
  Future<void> delete() async {}
}

class _WriteThrowingProfileStore implements ProfileStore {
  @override
  Future<Profile?> read() async => null;

  @override
  Future<void> write(Profile profile) async => throw StateError('disk full');

  @override
  Future<void> delete() async {}
}
