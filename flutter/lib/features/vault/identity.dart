// A device id that survives restarts.
//
// Without this, every app launch mints a new identity, so the phone you were
// talking to five minutes ago comes back as a stranger and the old one
// lingers on the map as a node that will never reconnect.
//
// Port intent of src/features/vault/api/identity.ts (expo-file-system). The
// real implementation needs a storage plugin (e.g. path_provider) that isn't
// wired up yet; this defines the contract [IdentityStore] it must satisfy —
// mirroring the SecureVault/AppLock mock-first split elsewhere in this
// feature — plus [DeviceIdentity], the cached resolver [MeshStore] drives.
// When the vault lands this should become the public-key fingerprint instead
// of a random string, so identity and key material can't disagree.
import 'dart:math';

/// Where a device id is read from and written to. A real implementation
/// backs this with a file (or the platform keystore); [InMemoryIdentityStore]
/// is the mock-first default and holds it only for the life of the process.
abstract class IdentityStore {
  /// The previously saved id, or null if nothing has been saved yet (or the
  /// read failed).
  Future<String?> read();

  Future<void> write(String id);
}

/// Mock-first: no disk, no platform channel. Good enough for tests and for a
/// build that hasn't wired up real storage — the cost is that identity does
/// not actually survive a process restart until a real [IdentityStore] does.
class InMemoryIdentityStore implements IdentityStore {
  String? _saved;

  @override
  Future<String?> read() async => _saved;

  @override
  Future<void> write(String id) async {
    _saved = id;
  }
}

String _mint() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rand = Random();
  return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
}

/// Resolves this device's stable id, minting and persisting one on first use.
/// Caches in memory so repeated calls within a run never re-hit the store.
class DeviceIdentity {
  DeviceIdentity([IdentityStore? store]) : _store = store ?? InMemoryIdentityStore();

  final IdentityStore _store;
  String? _cached;

  /// Stable across calls to this instance. Falls back to a per-call id if
  /// storage refuses to read or write — the only cost is that peers see us as
  /// new after a restart.
  Future<String> resolve() async {
    final cached = _cached;
    if (cached != null) return cached;

    try {
      final saved = await _store.read();
      if (saved != null && saved.isNotEmpty) {
        _cached = saved;
        return saved;
      }
    } catch (_) {
      // Unreadable store — fall through and mint a fresh one.
    }

    final id = _mint();
    try {
      await _store.write(id);
    } catch (_) {
      // Storage refused. A per-call id still works for this session; the
      // only cost is that peers see us as new after a restart.
    }
    _cached = id;
    return id;
  }
}
