import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/ai/describe_scene.dart';
import 'package:echo/features/ai/ocr_reader.dart';
import 'package:echo/features/ai/read_text.dart';
import 'package:echo/features/ai/summarize.dart';
import 'package:echo/features/ai/types.dart';
import 'package:echo/features/vision/obstacle_detector.dart';

import '../support/demo_data.dart';
<<<<<<< HEAD

import '../support/fakes.dart';
=======
>>>>>>> 32f78fcf58440299edded6647836b26ce8c1e3bf

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
    test('streams a loading progress, then generates lines, then completes', () async {
      final summarizer = MockThreadSummarizer(
        loadDelay: Duration.zero,
        lineDelay: Duration.zero,
      );
      final thread = demoThreads.first;

      final states = await summarizer.summarize(thread, thread.unread).toList();

      expect(states.first.isReady, isFalse);
      expect(states.any((s) => s.downloadProgress == 1 && s.isReady), isTrue);
      final last = states.last;
      expect(last.done, isTrue);
      expect(last.isGenerating, isFalse);
      expect(last.lines, isNotEmpty);
      expect(last.tookMs, isNotNull);
    });

    test('the model stays warm after the first summary — no loading state on the second', () async {
      final summarizer = MockThreadSummarizer(
        loadDelay: Duration.zero,
        lineDelay: Duration.zero,
      );
      final thread = demoThreads.first;

      await summarizer.summarize(thread, thread.unread).toList();
      final states = await summarizer.summarize(thread, thread.unread).toList();

      expect(states.every((s) => s.isReady), isTrue);
    });
  });
}
