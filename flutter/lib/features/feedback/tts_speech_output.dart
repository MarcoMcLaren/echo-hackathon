// Offline, on-device text-to-speech — the real SpeechOutput.
//
// flutter_tts wraps each platform's own TTS engine (Android's
// TextToSpeech), so speech works with no network and no model download, same
// as SystemHapticOutput's relationship to package:flutter/services.dart.
//
// The only import site for package:flutter_tts.
import 'package:flutter_tts/flutter_tts.dart';

import 'proximity_feedback.dart' show SpeechOutput;

class TtsSpeechOutput implements SpeechOutput {
  final FlutterTts _tts = FlutterTts();

  @override
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}
