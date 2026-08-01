import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/vault/contacts.dart';

void main() {
  group('InMemoryContactsStore', () {
    test('readAll returns empty until something has been written', () async {
      final store = InMemoryContactsStore();
      expect(await store.readAll(), isEmpty);

      await store.writeAll({'thabo': const Contact(id: 'thabo', name: 'Thabo', addedAt: 1)});
      expect((await store.readAll())['thabo']?.name, 'Thabo');
    });
  });

  group('ContactBook.add', () {
    test('adds a new contact, keyed by id', () async {
      final book = ContactBook(InMemoryContactsStore());

      final all = await book.add('thabo', 'Thabo Mokoena');

      expect(all['thabo']?.name, 'Thabo Mokoena');
    });

    test('re-pairing keeps the original addedAt rather than a new one', () async {
      final book = ContactBook(InMemoryContactsStore());
      final first = await book.add('thabo', 'Thabo');
      final firstAddedAt = first['thabo']!.addedAt;

      final second = await book.add('thabo', 'Thabo Mokoena');

      expect(second['thabo']?.addedAt, firstAddedAt);
      expect(second['thabo']?.name, 'Thabo Mokoena');
    });

    test('persists across a fresh ContactBook sharing the same store', () async {
      final store = InMemoryContactsStore();
      await ContactBook(store).add('thabo', 'Thabo Mokoena');

      final loaded = await ContactBook(store).load();

      expect(loaded['thabo']?.name, 'Thabo Mokoena');
    });
  });

  group('ContactBook.remove', () {
    test('drops a contact, leaving the rest', () async {
      final book = ContactBook(InMemoryContactsStore());
      await book.add('thabo', 'Thabo');
      await book.add('naledi', 'Naledi');

      final all = await book.remove('thabo');

      expect(all.containsKey('thabo'), isFalse);
      expect(all.containsKey('naledi'), isTrue);
    });
  });

  group('ContactBook.clear', () {
    test('empties the list and the underlying store', () async {
      final store = InMemoryContactsStore();
      final book = ContactBook(store);
      await book.add('thabo', 'Thabo');

      await book.clear();

      expect(await book.load(), isEmpty);
      expect(await store.readAll(), isEmpty);
    });
  });

  group('a storage failure', () {
    test('load() surviving a throwing read returns empty rather than throwing', () async {
      final book = ContactBook(_ThrowingContactsStore());
      expect(await book.load(), isEmpty);
    });

    test('add() still resolves usable contacts when write() throws', () async {
      final book = ContactBook(_WriteThrowingContactsStore());
      final all = await book.add('thabo', 'Thabo');
      expect(all['thabo']?.name, 'Thabo');
    });
  });
}

class _ThrowingContactsStore implements ContactsStore {
  @override
  Future<Map<String, Contact>> readAll() async => throw StateError('disk unavailable');

  @override
  Future<void> writeAll(Map<String, Contact> contacts) async {}
}

class _WriteThrowingContactsStore implements ContactsStore {
  @override
  Future<Map<String, Contact>> readAll() async => const {};

  @override
  Future<void> writeAll(Map<String, Contact> contacts) async => throw StateError('disk full');
}
