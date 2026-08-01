// Unit tests for lib/utils/ocr.dart, mirroring test/ocr.test.ts upstream:
// reading order, score filter, truncation.
import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/ai/types.dart';
import 'package:echo/utils/ocr.dart';

TextBox _box(
  String text,
  double x1,
  double y1,
  double x2,
  double y2, {
  double score = 0.9,
}) => TextBox(
  text: text,
  score: score,
  bbox: Bbox(x1: x1, y1: y1, x2: x2, y2: y2),
);

void main() {
  group('sameLine', () {
    test('groups by vertical overlap, not proximity', () {
      const a = Bbox(x1: 0, y1: 0, x2: 10, y2: 20);
      const sameRow = Bbox(x1: 50, y1: 2, x2: 60, y2: 22);
      const nextRow = Bbox(x1: 0, y1: 19, x2: 10, y2: 39);

      expect(
        sameLine(a, sameRow),
        isTrue,
        reason: 'boxes sharing most of their height',
      );
      expect(
        sameLine(a, nextRow),
        isFalse,
        reason: 'boxes touching by a sliver',
      );
    });
  });

  group('toReadingOrder', () {
    test('sorts lines top-to-bottom and boxes left-to-right', () {
      // Deliberately scrambled, the way detector output arrives.
      final boxes = [
        _box('WORLD', 60, 0, 110, 20),
        _box('AGAIN', 60, 40, 110, 60),
        _box('HELLO', 0, 2, 50, 22),
        _box('READ', 0, 41, 50, 61),
      ];

      expect(toReadingOrder(boxes).map((b) => b.text).toList(), [
        'HELLO',
        'WORLD',
        'READ',
        'AGAIN',
      ]);
    });
  });

  group('composeSpeech', () {
    test('joins reading order into one utterance', () {
      final boxes = [
        _box('WORLD', 60, 0, 110, 20),
        _box('HELLO', 0, 2, 50, 22),
      ];
      expect(composeSpeech(boxes), 'HELLO WORLD');
    });

    test('drops detections below the score floor, inclusive', () {
      final boxes = [
        _box('KEEP', 0, 0, 50, 20, score: minScore),
        _box('DROP', 60, 0, 110, 20, score: minScore - 0.01),
      ];
      expect(composeSpeech(boxes), 'KEEP');
    });

    test('returns empty string when nothing survives', () {
      expect(composeSpeech(const []), '');
      expect(composeSpeech([_box('noise', 0, 0, 10, 10, score: 0.1)]), '');
      expect(
        composeSpeech([_box('   ', 0, 0, 10, 10)]),
        '',
        reason: 'whitespace-only text',
      );
    });

    test('collapses stray whitespace inside recognized text', () {
      expect(composeSpeech([_box('  EXIT \n 12  ', 0, 0, 50, 20)]), 'EXIT 12');
    });

    test('a tall heading does not swallow adjacent rows of smaller type', () {
      // Regression: a tall heading used to overlap the rows both above and
      // below it, swallow them into one "line", and then x-sort interleaved
      // their words — "GATE 18:40 closes" instead of "GATE closes 18:40".
      final boxes = [
        _box('GATE', 0, 0, 120, 60), // one big glyph run, spans both small rows
        _box('closes', 300, 2, 380, 14),
        _box('18:40', 150, 46, 230, 58),
      ];
      expect(composeSpeech(boxes), 'GATE closes 18:40');
    });

    test('comparable heights still group into one line', () {
      final boxes = [
        _box('SECOND', 90, 1, 170, 21),
        _box('FIRST', 0, 0, 80, 20),
      ];
      expect(composeSpeech(boxes), 'FIRST SECOND');
    });

    test('an inverted bbox is normalised and still groups with its line', () {
      // y1/y2 arrive swapped; after normalising it is an ordinary 20px-tall box.
      final upright = _box('FIRST', 0, 0, 50, 20);
      const inverted = TextBox(
        text: 'SECOND',
        score: 0.9,
        bbox: Bbox(x1: 60, y1: 20, x2: 110, y2: 0),
      );
      expect(composeSpeech([inverted, upright]), 'FIRST SECOND');
    });

    test('a zero-height bbox survives and is ordered by its top edge', () {
      // Its effective height is 1, so the ratio guard keeps it out of the
      // taller box's line — it still gets spoken, in top-to-bottom position.
      const flat = TextBox(
        text: 'FLAT',
        score: 0.9,
        bbox: Bbox(x1: 0, y1: 10, x2: 50, y2: 10),
      );
      final below = _box('BELOW', 0, 40, 50, 60);
      expect(composeSpeech([below, flat]), 'FLAT BELOW');
    });

    test('applies maxChars after ordering', () {
      final boxes = [_box('BBBB', 60, 0, 110, 20), _box('AAAA', 0, 2, 50, 22)];
      expect(composeSpeech(boxes, maxCharsOverride: 6), 'AAAA');
    });
  });

  group('truncateWords', () {
    test('cuts on a word boundary', () {
      expect(
        truncateWords('one two three', 100),
        'one two three',
        reason: 'under the cap',
      );
      expect(
        truncateWords('one two three', 9),
        'one two',
        reason: 'boundary before the cap',
      );
      expect(truncateWords('', 10), '');
    });

    test('hard-cuts a single word longer than the cap', () {
      expect(truncateWords('supercalifragilistic', 5), 'super');
      expect(
        truncateWords('anything', 0),
        '',
        reason: 'a zero cap yields nothing',
      );
    });
  });
}
