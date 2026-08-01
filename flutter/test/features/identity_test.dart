import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/vault/identity.dart';

void main() {
  group('InMemoryIdentityStore', () {
    test('read returns null until something has been written', () async {
      final store = InMemoryIdentityStore();
      expect(await store.read(), isNull);

      await store.write('abc123');
      expect(await store.read(), 'abc123');
    });
  });

  group('DeviceIdentity', () {
    test('mints and persists an id on first resolve', () async {
      final store = InMemoryIdentityStore();
      final identity = DeviceIdentity(store);

      final id = await identity.resolve();
      expect(id, isNotEmpty);
      expect(await store.read(), id);
    });

    test('caches in memory — repeated calls return the same id', () async {
      final identity = DeviceIdentity(InMemoryIdentityStore());
      final first = await identity.resolve();
      final second = await identity.resolve();
      expect(second, first);
    });

    test(
      'a fresh DeviceIdentity backed by the same store resolves to the '
      'previously persisted id, not a new one',
      () async {
        final store = InMemoryIdentityStore();
        final first = await DeviceIdentity(store).resolve();

        final second = await DeviceIdentity(store).resolve();

        expect(second, first);
      },
    );

    test('defaults to a private in-memory store when none is given', () async {
      final a = await DeviceIdentity().resolve();
      final b = await DeviceIdentity().resolve();
      expect(a, isNot(b), reason: 'each defaults to its own unshared store');
    });
  });

  group('a storage failure', () {
    test('read() throwing still resolves a usable (per-call) id', () async {
      final identity = DeviceIdentity(_ThrowingIdentityStore());
      final id = await identity.resolve();
      expect(id, isNotEmpty);
    });

    test('write() throwing still resolves a usable (per-call) id', () async {
      final identity = DeviceIdentity(_WriteThrowingIdentityStore());
      final id = await identity.resolve();
      expect(id, isNotEmpty);
    });
  });
}

class _ThrowingIdentityStore implements IdentityStore {
  @override
  Future<String?> read() async => throw StateError('disk unavailable');

  @override
  Future<void> write(String id) async {}
}

class _WriteThrowingIdentityStore implements IdentityStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String id) async => throw StateError('disk full');
}
