// Proximity -> haptics + speech: turns the nearest obstacle into a pulse the
// user can feel and, when it changes enough to matter, a spoken label.
//
// Port intent of src/features/feedback/hooks/useProximityFeedback.ts (a
// placeholder upstream too — "nearest obstacle -> haptic pulse rate + spoken
// label"). Haptics use Flutter's real HapticFeedback (no plugin needed, no
// hardware assumptions beyond what every phone has); speech is a no-op stub
// behind an interface until a TTS plugin (the expo-speech equivalent) is
// added to pubspec.yaml.
import 'package:flutter/services.dart';

import '../vision/obstacle_detector.dart';

abstract class SpeechOutput {
  Future<void> speak(String text);
  Future<void> stop();
}

/// No TTS plugin is wired into this build yet, so speech is silently
/// swallowed rather than crashing the feedback pipeline. Swap for a real
/// implementation (flutter_tts or similar) without touching call sites.
class NoOpSpeechOutput implements SpeechOutput {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}

abstract class HapticOutput {
  /// Fires one pulse. [intensity] is 0 (barely there) .. 1 (as strong as the
  /// hardware allows) — the adapter maps that onto whatever discrete levels
  /// the platform actually exposes.
  Future<void> pulse(double intensity);
}

/// The only import site for package:flutter/services.dart's HapticFeedback.
class SystemHapticOutput implements HapticOutput {
  @override
  Future<void> pulse(double intensity) async {
    if (intensity >= 0.66) {
      await HapticFeedback.heavyImpact();
    } else if (intensity >= 0.33) {
      await HapticFeedback.mediumImpact();
    } else {
      await HapticFeedback.lightImpact();
    }
  }
}

/// Debounces speech so a jittery detection stream doesn't narrate every tick
/// — only pulses on every detection, but speaks again only once closeness (or
/// the obstacle itself) has moved enough to be worth interrupting the user
/// for.
class ProximityFeedback {
  ProximityFeedback({
    required this.haptics,
    required this.speech,
    this.speakThreshold = 0.15,
  });

  final HapticOutput haptics;
  final SpeechOutput speech;
  final double speakThreshold;

  String? _lastLabel;
  double? _lastSpokenCloseness;

  Future<void> onDetections(List<Detection> detections) async {
    if (detections.isEmpty) return;

    final nearest = detections.reduce(
      (a, b) => a.closeness > b.closeness ? a : b,
    );
    await haptics.pulse(nearest.closeness);

    final lastCloseness = _lastSpokenCloseness;
    final changedEnough =
        nearest.label != _lastLabel ||
        lastCloseness == null ||
        (nearest.closeness - lastCloseness).abs() >= speakThreshold;
    if (!changedEnough) return;

    await speech.speak(
      '${nearest.label} — ${_distanceWord(nearest.closeness)}',
    );
    _lastLabel = nearest.label;
    _lastSpokenCloseness = nearest.closeness;
  }

  String _distanceWord(double closeness) {
    if (closeness > 0.7) return 'close';
    if (closeness > 0.35) return 'near';
    return 'ahead';
  }
}
