import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/ai/describe_scene.dart';
import 'package:echo/features/ai/read_text.dart';
import 'package:echo/features/ai/summarize.dart';
import 'package:echo/features/vision/obstacle_detector.dart';
import 'package:echo/store/mock.dart' as mock;

void main() {
  group('MockTextReader', () {
    test(
      'cycles through its script, including the "nothing legible" case',
      () async {
        final reader = MockTextReader(script: const ['A', null, 'B']);
        expect(await reader.readText(), 'A');
        expect(await reader.readText(), isNull);
        expect(await reader.readText(), 'B');
        expect(await reader.readText(), 'A'); // wraps around
      },
    );
  });

  group('MockSceneDescriber', () {
    final describer = MockSceneDescriber();

    test('describes an empty scene as clear', () async {
      expect(
        await describer.describeScene(const []),
        contains('Nothing obstructing'),
      );
    });

    test('names the single nearest obstacle with a distance word', () async {
      final text = await describer.describeScene(const [
        Detection(label: 'chair', confidence: 0.9, closeness: 0.8),
      ]);
      expect(text, contains('chair'));
      expect(text, contains('very close'));
    });

    test('leads with the nearest of several obstacles', () async {
      final text = await describer.describeScene(const [
        Detection(label: 'table', confidence: 0.9, closeness: 0.2),
        Detection(label: 'person', confidence: 0.9, closeness: 0.9),
      ]);
      expect(text, startsWith('A person'));
      expect(text, contains('table'));
    });
  });

  group('MockThreadSummarizer', () {
    test('tags the demo summary with the actual message count', () async {
      final summarizer = MockThreadSummarizer();
      final messages = mock.threads.first.messages;

      final summary = await summarizer.summarize(messages);

      expect(summary.count, messages.length);
      expect(summary.points, isNotEmpty);
    });
  });
}
