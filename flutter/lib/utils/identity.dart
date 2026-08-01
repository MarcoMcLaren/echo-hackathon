// A device id that survives restarts — ported from features/vault/api/identity.ts.
//
// Without this, every app launch mints a new identity, so the phone you were
// talking to five minutes ago comes back as a stranger and the old one lingers
// on the map as a node that will never reconnect.
//
// Uses path_provider, which is already in the build — no custom native code.
// When the vault lands this should become the public-key fingerprint instead
// of a random string, so identity and key material can't disagree.
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

const _filename = 'echo-identity';

String? _cached;

String _mint() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rand = Random();
  return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
}

/// Stable across launches. Falls back to a per-launch id if storage fails.
Future<String> deviceIdentity() async {
  final cached = _cached;
  if (cached != null) return cached;

  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_filename');

    if (await file.exists()) {
      final saved = (await file.readAsString()).trim();
      if (saved.isNotEmpty) {
        _cached = saved;
        return saved;
      }
    }

    final id = _mint();
    await file.writeAsString(id);
    _cached = id;
    return id;
  } catch (_) {
    // Storage refused. A per-launch id still works for this session; the only
    // cost is that peers see us as new after a restart.
    final id = _mint();
    _cached = id;
    return id;
  }
}
