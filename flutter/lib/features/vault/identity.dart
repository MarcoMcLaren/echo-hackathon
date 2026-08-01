// This phone's identity: a stable id and the name other people see.
//
// The id is what routing and pairing use — it must survive restarts, or the
// phone you spoke to five minutes ago comes back as a stranger. The name is
// what a human reads on a pairing code, so it is chosen once at first launch
// rather than inferred from the hardware: "SM-S938B" tells nobody anything.
//
// Ported from features/vault/api/identity.ts (post commit ff3f159, "Make
// pairing the only way to become a person you can talk to"). Uses
// path_provider, already in the build — no new native module. When the vault
// lands, the id should become the public-key fingerprint so identity and key
// material cannot disagree.
import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import 'contacts.dart' show clearContacts;

const _filename = 'echo-identity';

class Profile {
  final String id;
  final String name;
  const Profile({required this.id, required this.name});
}

Profile? _cache;

String _mint() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rand = Random();
  return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
}

Future<File> _profileFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/$_filename');
}

/// Reads the stored profile. Returns null when this phone has never been set
/// up, which is what sends someone to the name screen.
Future<Profile?> loadProfile() async {
  final cached = _cache;
  if (cached != null) return cached;

  try {
    final file = await _profileFile();
    if (await file.exists()) {
      final raw = (await file.readAsString()).trim();
      if (raw.isNotEmpty) {
        final parsed = jsonDecode(raw) as Map<String, dynamic>;
        final id = parsed['id'] as String?;
        final name = parsed['name'] as String?;
        if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
          final profile = Profile(id: id, name: name);
          _cache = profile;
          return profile;
        }
      }
    }
  } catch (_) {
    // Unreadable or from an older build — treat as not set up.
  }
  return null;
}

/// First launch, or after a reset. Mints a fresh id to go with the name.
Future<Profile> createProfile(String name) async {
  final profile = Profile(id: _mint(), name: name.trim());
  await _write(profile);
  _cache = profile;
  return profile;
}

/// Rename without becoming a different phone — the id is untouched.
Future<Profile?> renameProfile(String name) async {
  final current = await loadProfile();
  if (current == null) return null;
  final next = Profile(id: current.id, name: name.trim());
  await _write(next);
  _cache = next;
  return next;
}

Future<void> _write(Profile profile) async {
  try {
    final file = await _profileFile();
    await file.writeAsString(jsonEncode({'id': profile.id, 'name': profile.name}));
  } catch (_) {
    // Storage refused. The profile still holds for this session; the cost is
    // that a restart looks like a new phone.
  }
}

/// What the QR code / NFC payload carries — same shape either door into
/// pairing uses, since it's one flow with two ways in.
String pairPayload(String deviceId, String display) =>
    'echo://pair?id=$deviceId&n=${Uri.encodeComponent(display)}';

/// Parses a scanned pairing payload. Returns null if it isn't one.
({String id, String name})? decodePairPayload(String raw) {
  Uri? uri;
  try {
    uri = Uri.parse(raw);
  } catch (_) {
    return null;
  }
  if (uri.scheme != 'echo' || uri.host != 'pair') return null;
  final id = uri.queryParameters['id'];
  final name = uri.queryParameters['n'];
  if (id == null || id.isEmpty || name == null || name.isEmpty) return null;
  return (id: id, name: name);
}

/// A short, human-comparable fingerprint derived from a device id — shown on
/// both phones so the two people can confirm they scanned/tapped the right
/// one. Deterministic (same id always gives the same fingerprint), but
/// otherwise arbitrary — there is no real keypair yet for this to attest to
/// (see the file header: the vault is still to come).
String fingerprintOf(String deviceId) {
  var h1 = 0;
  var h2 = 0;
  for (final unit in deviceId.codeUnits) {
    h1 = (h1 * 31 + unit) & 0xFFFFFF;
    h2 = (h2 * 131 + unit) & 0xFFFFFF;
  }
  final hex = ((h1 << 24) | h2).toUnsigned(48).toRadixString(16).padLeft(12, '0').toUpperCase();
  final safe = hex.length > 12 ? hex.substring(hex.length - 12) : hex;
  return '${safe.substring(0, 4)} ${safe.substring(4, 8)} ${safe.substring(8, 12)}';
}

/// Wipe this phone back to factory: no id, no name, no contacts. The next
/// launch asks for a name and mints a new id, so to everyone else this
/// becomes a genuinely different phone rather than the same one with the
/// history hidden.
void resetIdentity() {
  _cache = null;
  clearContacts();
  () async {
    for (final name in [_filename]) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$name');
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Nothing there, or storage refused. Carry on and clear the rest.
      }
    }
  }();
}
