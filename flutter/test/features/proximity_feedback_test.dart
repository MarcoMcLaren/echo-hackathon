import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/feedback/proximity_feedback.dart';
import 'package:echo/features/vision/obstacle_detector.dart';

class _FakeHaptics implements HapticOutput {
  final List<double> pulses = [];

  @override
  Future<void> pulse(double intensity) async {
    pulses.add(intensity);
  }
}

class _FakeSpeech implements SpeechOutput {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}

void main() {
  group('ProximityFeedback', () {
    test('does nothing on an empty detection list', () async {
      final haptics = _FakeHaptics();
      final speech = _FakeSpeech();
      final feedback = ProximityFeedback(haptics: haptics, speech: speech);

      await feedback.onDetections(const []);

      expect(haptics.pulses, isEmpty);
      expect(speech.spoken, isEmpty);
    });

    test(
      'pulses on every tick but only speaks once closeness moves enough',
      () async {
        final haptics = _FakeHaptics();
        final speech = _FakeSpeech();
        final feedback = ProximityFeedback(
          haptics: haptics,
          speech: speech,
          speakThreshold: 0.15,
        );

        await feedback.onDetections(const [
          Detection(label: 'chair', confidence: 0.9, closeness: 0.2),
        ]);
        await feedback.onDetections(const [
          Detection(label: 'chair', confidence: 0.9, closeness: 0.22),
        ]); // jittery, below threshold
        await feedback.onDetections(const [
          Detection(label: 'chair', confidence: 0.9, closeness: 0.6),
        ]); // moved enough

        expect(haptics.pulses, hasLength(3));
        expect(speech.spoken, hasLength(2));
        expect(speech.spoken.first, contains('ahead'));
        expect(speech.spoken.last, contains('near'));
      },
    );

    test('speaks again immediately when the obstacle label changes', () async {
      final haptics = _FakeHaptics();
      final speech = _FakeSpeech();
      final feedback = ProximityFeedback(haptics: haptics, speech: speech);

      await feedback.onDetections(const [
        Detection(label: 'chair', confidence: 0.9, closeness: 0.5),
      ]);
      await feedback.onDetections(const [
        Detection(label: 'person', confidence: 0.9, closeness: 0.5),
      ]);

      expect(speech.spoken, ['chair — near', 'person — near']);
    });

    test('picks the nearest of several simultaneous detections', () async {
      final haptics = _FakeHaptics();
      final speech = _FakeSpeech();
      final feedback = ProximityFeedback(haptics: haptics, speech: speech);

      await feedback.onDetections(const [
        Detection(label: 'table', confidence: 0.9, closeness: 0.1),
        Detection(label: 'person', confidence: 0.9, closeness: 0.9),
      ]);

      expect(haptics.pulses.single, 0.9);
      expect(speech.spoken.single, contains('person'));
    });
  });
}
