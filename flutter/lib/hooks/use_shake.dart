// Shake to take it back — ported from src/hooks/useShake.ts.
//
// Every action this triggers must also have a visible control. A shake is
// undiscoverable, and unusable for anyone who cannot shake a phone — it is a
// shortcut for people who already know it exists, never the only way through.
import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

/// Total g-force. At rest a phone reads ~1g, so this is a deliberate movement.
const _threshold = 1.7;

/// One shake is many samples over threshold — only act on the first.
const _cooldown = Duration(milliseconds: 1500);

/// Subscribe in a State's initState, call [dispose] in the State's dispose.
class ShakeDetector {
  final void Function() onShake;
  StreamSubscription<AccelerometerEvent>? _sub;
  DateTime _fired = DateTime.fromMillisecondsSinceEpoch(0);

  ShakeDetector(this.onShake) {
    try {
      _sub = accelerometerEventStream().listen((event) {
        final force = sqrt(event.x * event.x + event.y * event.y + event.z * event.z) / 9.80665;
        final now = DateTime.now();
        if (force < _threshold || now.difference(_fired) < _cooldown) return;
        _fired = now;
        onShake();
      });
    } catch (_) {
      // No accelerometer on this device or in this build. The visible
      // control still does the job.
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
