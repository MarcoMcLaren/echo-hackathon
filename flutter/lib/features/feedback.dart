// Ported from src/features/feedback/api/index.ts — the haptics + speech
// wrapper backing "Read that".
//
// RN uses expo-haptics + expo-speech. This uses Flutter's built-in
// HapticFeedback (package:flutter/services.dart — no extra native module
// needed, unlike expo-haptics, which is its own package) and the flutter_tts
// plugin already used elsewhere in this port.
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// flutter_tts has no fixed max-input-length constant to mirror 1:1 — Android's
/// real per-utterance ceiling is only knowable at runtime via
/// `FlutterTts.getMaxSpeechInputLength`, and there's no such limit on iOS at
/// all. RN's own fallback constant is reused verbatim rather than guessing.
const int maxSpeechChars = 3900;

final FlutterTts _tts = FlutterTts();

/// Mirrors RN's `quietly()`: feedback must never crash the read flow.
Future<void> _quietly(Future<void> Function() run) async {
  try {
    await run();
  } catch (_) {
    // Swallowed on purpose.
  }
}

/// Stops whatever was speaking, then speaks [text]. Matches RN's speak():
/// `Speech.stop()` first, language pinned to en-US, and a wired-up error
/// handler that reports failure the same way a failed read does.
Future<void> speak(String text) async {
  await _quietly(() async {
    await _tts.stop();
    await _tts.setLanguage('en-US');
    _tts.setErrorHandler((message) => notifyFail());
    await _tts.speak(text);
  });
}

Future<void> stopSpeaking() => _quietly(() => _tts.stop());

Future<void> tick() => _quietly(() => HapticFeedback.lightImpact());

Future<void> notifyOk() => _quietly(() => HapticFeedback.mediumImpact());

Future<void> notifyFail() => _quietly(() => HapticFeedback.heavyImpact());
