// Who you can actually talk to.
//
// The radio finds every Echo phone in range, but being in range is not a
// relationship. Those phones are *nodes*: they carry traffic and nothing
// more. Someone becomes a *contact* only through a deliberate physical act —
// a tap or a scanned code — and only contacts get a conversation.
//
// This is an allowlist, which means there is no "block" to maintain: a
// stranger cannot message you because they were never on the list, and
// removing someone puts them back to being just another node.
//
// Port intent of src/features/vault/api/contacts.ts. The real implementation
// needs a storage plugin (e.g. path_provider) that isn't wired up yet; this
// defines the contract [ContactsStore] it must satisfy — mirroring the
// mock-first split in identity.dart — plus [ContactBook], the cached reader
// MeshStore drives.
class Contact {
  const Contact({required this.id, required this.name, required this.addedAt});

  final String id;
  final String name;

  /// millisecondsSinceEpoch. Kept across a name change so re-pairing doesn't
  /// look like a brand new relationship.
  final int addedAt;
}

/// Where the contact list is read from and written to. A real implementation
/// backs this with a file; [InMemoryContactsStore] is the mock-first default
/// and holds it only for the life of the process.
abstract class ContactsStore {
  Future<Map<String, Contact>> readAll();

  Future<void> writeAll(Map<String, Contact> contacts);
}

/// Mock-first: no disk, no platform channel. Good enough for tests and for a
/// build that hasn't wired up real storage.
class InMemoryContactsStore implements ContactsStore {
  Map<String, Contact>? _saved;

  @override
  Future<Map<String, Contact>> readAll() async => _saved ?? const {};

  @override
  Future<void> writeAll(Map<String, Contact> contacts) async {
    _saved = Map.of(contacts);
  }
}

/// Caches the contact list in memory so repeated reads within a run never
/// re-hit the store, mirroring [DeviceIdentity]'s caching in identity.dart.
class ContactBook {
  ContactBook([ContactsStore? store]) : _store = store ?? InMemoryContactsStore();

  final ContactsStore _store;
  Map<String, Contact>? _cache;

  Future<Map<String, Contact>> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final all = await _store.readAll();
      _cache = all;
      return all;
    } catch (_) {
      // Unreadable or malformed — start clean rather than refuse to run.
      _cache = const {};
      return const {};
    }
  }

  /// Called when a tap or a scanned code proves the two phones met.
  Future<Map<String, Contact>> add(String id, String name) async {
    final all = Map<String, Contact>.of(await load());
    // Keep the original addedAt if they were already known, so re-pairing
    // after a name change doesn't look like a brand new relationship.
    all[id] = Contact(id: id, name: name, addedAt: all[id]?.addedAt ?? DateTime.now().millisecondsSinceEpoch);
    await _persist(all);
    return all;
  }

  /// They go back to being a node: still relaying, no longer someone you
  /// chat to.
  Future<Map<String, Contact>> remove(String id) async {
    final all = Map<String, Contact>.of(await load());
    all.remove(id);
    await _persist(all);
    return all;
  }

  /// Forget everyone. Used by a reset; drops the in-memory cache as well as
  /// the file, so nothing survives a wipe.
  Future<void> clear() async {
    _cache = const {};
    await _persist(const {});
  }

  Future<void> _persist(Map<String, Contact> all) async {
    _cache = all;
    try {
      await _store.writeAll(all);
    } catch (_) {
      // Storage refused. The list still holds for this session.
    }
  }
}
