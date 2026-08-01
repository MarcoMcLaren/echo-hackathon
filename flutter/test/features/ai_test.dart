import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/ai/describe_scene.dart';
import 'package:echo/features/ai/ocr_reader.dart';
import 'package:echo/features/ai/read_text.dart';
import 'package:echo/features/ai/summarize.dart';
import 'package:echo/features/ai/types.dart';
import 'package:echo/features/vision/obstacle_detector.dart';
import 'package:echo/store/mock.dart' as mock;

void main() {
  group('MockOcrReader', () {
    test(
      'composes each canned detection set into speech, including nothing legible',
      () async {
        final reader = MockOcrReader();

        final first = await reader.read('frame-1') as ReadOk;
        expect(first.result.text, 'EXIT');
        expect(first.result.boxes, isNotEmpty);

        final second = await reader.read('frame-2') as ReadOk;
        expect(second.result.text, 'Platform 3 Cape Town');

        final third = await reader.read('frame-3') as ReadOk;
        expect(third.result.text, '', reason: 'ran fine, found nothing');
      },
    );

    test(
      'a custom script is honoured and composed the same way as the default',
      () async {
        final reader = MockOcrReader(
          script: [
            [
              const TextBox(
                bbox: Bbox(x1: 0, y1: 0, x2: 10, y2: 10),
                text: 'HI',
                score: 0.9,
              ),
            ],
          ],
        );
        final outcome = await reader.read('frame') as ReadOk;
        expect(outcome.result.text, 'HI');
      },
    );
  });

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
