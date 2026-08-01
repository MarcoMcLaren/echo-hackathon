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
// Ported from features/vault/api/contacts.ts. Uses path_provider, the same
// pattern as identity.dart.
import 'dart:io';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';

const _filename = 'echo-contacts';

class Contact {
  final String id;
  final String name;
  final int addedAt;
  const Contact({required this.id, required this.name, required this.addedAt});
}

Map<String, Contact>? _cache;

Future<File> _contactsFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/$_filename');
}

Future<Map<String, Contact>> loadContacts() async {
  final cached = _cache;
  if (cached != null) return cached;

  try {
    final file = await _contactsFile();
    if (await file.exists()) {
      final raw = (await file.readAsString()).trim();
      final all = <String, Contact>{};
      if (raw.isNotEmpty) {
        final parsed = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in parsed.entries) {
          final v = entry.value as Map<String, dynamic>;
          all[entry.key] = Contact(
            id: v['id'] as String,
            name: v['name'] as String,
            addedAt: (v['addedAt'] as num).toInt(),
          );
        }
      }
      _cache = all;
      return all;
    }
  } catch (_) {
    // Unreadable or malformed — start clean rather than refuse to run.
  }
  _cache = {};
  return _cache!;
}

Future<void> _persist(Map<String, Contact> all) async {
  try {
    final file = await _contactsFile();
    final json = {
      for (final entry in all.entries)
        entry.key: {'id': entry.value.id, 'name': entry.value.name, 'addedAt': entry.value.addedAt},
    };
    await file.writeAsString(jsonEncode(json));
  } catch (_) {
    // Storage refused. The list still holds for this session.
  }
}

/// Called when a tap or a scanned code proves the two phones met.
Future<Map<String, Contact>> addContact(String id, String name) async {
  final all = Map<String, Contact>.from(await loadContacts());
  // Keep the original addedAt if they were already known, so re-pairing
  // after a name change doesn't look like a brand new relationship.
  final addedAt = all[id]?.addedAt ?? DateTime.now().millisecondsSinceEpoch;
  all[id] = Contact(id: id, name: name, addedAt: addedAt);
  _cache = all;
  await _persist(all);
  return Map<String, Contact>.from(all);
}

/// They go back to being a node: still relaying, no longer someone you chat
/// to.
Future<Map<String, Contact>> removeContact(String id) async {
  final all = Map<String, Contact>.from(await loadContacts());
  all.remove(id);
  _cache = all;
  await _persist(all);
  return Map<String, Contact>.from(all);
}

/// Forget everyone. Used by the reset; drops the in-memory cache as well as
/// the file, so nothing survives a wipe.
void clearContacts() {
  _cache = {};
  () async {
    try {
      final file = await _contactsFile();
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Nothing there, or storage refused.
    }
  }();
}
