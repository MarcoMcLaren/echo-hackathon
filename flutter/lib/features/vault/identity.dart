// This phone's identity: a stable id and the name other people see.
//
// The id is what routing and pairing use — it must survive restarts, or the
// phone you spoke to five minutes ago comes back as a stranger. The name is
// what a human reads on a pairing code, so it is chosen once at first launch
// rather than inferred from the hardware: "SM-S938B" tells nobody anything.
//
// Port intent of src/features/vault/api/identity.ts (expo-file-system). The
// real implementation needs a storage plugin (e.g. path_provider) that isn't
// wired up yet; this defines the contract [ProfileStore] it must satisfy —
// mirroring the SecureVault/AppLock mock-first split elsewhere in this
// feature — plus [IdentityVault], the cached resolver [MeshStore] drives.
// When the vault lands the id should become the public-key fingerprint
// instead of a random string, so identity and key material can't disagree.
import 'dart:math';

class Profile {
  const Profile({required this.id, required this.name});

  final String id;
  final String name;

  Profile withName(String name) => Profile(id: id, name: name);
}

/// Where the profile is read from and written to. A real implementation
/// backs this with a file (or the platform keystore); [InMemoryProfileStore]
/// is the mock-first default and holds it only for the life of the process.
abstract class ProfileStore {
  /// The previously saved profile, or null if nothing has been saved yet (or
  /// the read failed).
  Future<Profile?> read();

  Future<void> write(Profile profile);

  Future<void> delete();
}

/// Mock-first: no disk, no platform channel. Good enough for tests and for a
/// build that hasn't wired up real storage — the cost is that identity does
/// not actually survive a process restart until a real [ProfileStore] does.
class InMemoryProfileStore implements ProfileStore {
  Profile? _saved;

  @override
  Future<Profile?> read() async => _saved;

  @override
  Future<void> write(Profile profile) async {
    _saved = profile;
  }

  @override
  Future<void> delete() async {
    _saved = null;
  }
}

String _mintId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rand = Random();
  return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
}

/// Resolves and mutates this phone's [Profile]. Caches in memory so repeated
/// calls within a run never re-hit the store.
class IdentityVault {
  IdentityVault([ProfileStore? store]) : _store = store ?? InMemoryProfileStore();

  final ProfileStore _store;
  Profile? _cache;

  /// Reads the stored profile. Returns null when this phone has never been
  /// set up, which is what sends someone to the name screen.
  Future<Profile?> loadProfile() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final saved = await _store.read();
      if (saved != null) {
        _cache = saved;
        return saved;
      }
    } catch (_) {
      // Unreadable or from an older build — treat as not set up.
    }
    return null;
  }

  /// First launch, or after a reset. Mints a fresh id to go with the name.
  Future<Profile> createProfile(String name) async {
    final profile = Profile(id: _mintId(), name: name.trim());
    await _write(profile);
    _cache = profile;
    return profile;
  }

  /// Rename without becoming a different phone — the id is untouched.
  Future<Profile?> renameProfile(String name) async {
    final current = await loadProfile();
    if (current == null) return null;
    final next = current.withName(name.trim());
    await _write(next);
    _cache = next;
    return next;
  }

  Future<void> _write(Profile profile) async {
    try {
      await _store.write(profile);
    } catch (_) {
      // Storage refused. The profile still holds for this session; the cost
      // is that a restart looks like a new phone.
    }
  }

  /// Wipe this phone back to factory: no id, no name. The next launch asks
  /// for a name and mints a new id, so to everyone else this becomes a
  /// genuinely different phone rather than the same one with the history
  /// hidden.
  Future<void> resetIdentity() async {
    _cache = null;
    try {
      await _store.delete();
    } catch (_) {
      // Nothing there, or storage refused.
    }
  }
}
