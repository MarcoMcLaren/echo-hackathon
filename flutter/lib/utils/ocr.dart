// Turning OCR detections into one speakable sentence.
//
// Pure on purpose: no Flutter, no platform channel, no executorch equivalent.
// `test/ocr_test.dart` runs this on the plain Dart VM.
//
// Port of src/utils/ocr.ts.
import '../features/ai/types.dart';

/// Below this the recognizer is guessing at noise rather than reading text.
const double minScore = 0.5;

/// Fallback cap for one utterance. Android's TextToSpeech rejects anything
/// longer than its own max input length (~4000); callers should pass the
/// platform's real limit instead of relying on this.
const int defaultMaxChars = 3900;

/// Beyond this ratio two boxes are different type sizes — a heading next to
/// body text — rather than one line. Without the check a tall box overlaps
/// rows both above and below it, swallows them into one "line", and the
/// left-to-right sort then interleaves their words.
const double maxLineHeightRatio = 2.5;

/// Detectors occasionally emit inverted or zero-height boxes; make them sane.
Bbox _norm(Bbox b) => Bbox(
  x1: b.x1 < b.x2 ? b.x1 : b.x2,
  x2: b.x1 < b.x2 ? b.x2 : b.x1,
  y1: b.y1 < b.y2 ? b.y1 : b.y2,
  y2: b.y1 < b.y2 ? b.y2 : b.y1,
);

// Floor of 1 keeps a zero-height box from producing a divide-by-zero ratio.
double _heightOf(Bbox b) {
  final h = b.y2 - b.y1;
  return h > 1 ? h : 1;
}

/// Two boxes sit on the same visual line when they are comparable in height
/// and their vertical extents overlap by more than half the shorter one. Both
/// tests are height-relative rather than a fixed pixel slack, so they hold at
/// whatever resolution the capture came in at.
bool sameLine(Bbox a, Bbox b) {
  final na = _norm(a);
  final nb = _norm(b);
  final ha = _heightOf(na);
  final hb = _heightOf(nb);

  final bigger = ha > hb ? ha : hb;
  final smaller = ha < hb ? ha : hb;
  if (bigger / smaller > maxLineHeightRatio) return false;

  final overlap =
      (na.y2 < nb.y2 ? na.y2 : nb.y2) - (na.y1 > nb.y1 ? na.y1 : nb.y1);
  return overlap > 0.5 * smaller;
}

/// Detections arrive in model order, which reads as gibberish when spoken.
/// Group them into lines, then order lines top-to-bottom and boxes within a
/// line left-to-right.
///
/// Each line is anchored on its first (topmost) box — input is sorted by
/// `y1` first, so the anchor never drifts downward as boxes are added.
List<TextBox> toReadingOrder(List<TextBox> boxes) {
  final byTop = [...boxes]
    ..sort((a, b) => _norm(a.bbox).y1.compareTo(_norm(b.bbox).y1));

  final lines = <List<TextBox>>[];
  for (final box in byTop) {
    List<TextBox>? line;
    for (final l in lines) {
      if (sameLine(l.first.bbox, box.bbox)) {
        line = l;
        break;
      }
    }
    if (line != null) {
      line.add(box);
    } else {
      lines.add([box]);
    }
  }

  return [
    for (final line in lines)
      ...([...line]
        ..sort((p, q) => _norm(p.bbox).x1.compareTo(_norm(q.bbox).x1))),
  ];
}

/// Cut at the last word boundary that fits, so TTS never clips mid-word.
String truncateWords(String text, int maxChars) {
  if (maxChars <= 0) return '';
  if (text.length <= maxChars) return text;

  final cut = text.substring(0, maxChars);
  final lastSpace = cut.lastIndexOf(' ');
  // A single word longer than the cap has no boundary to fall back on.
  return (lastSpace > 0 ? cut.substring(0, lastSpace) : cut).trimRight();
}

/// Drop noise, put what's left in reading order, join it into one utterance.
/// Returns `''` when nothing survives — the caller says "No text found."
String composeSpeech(
  List<TextBox> boxes, {
  double? minScoreOverride,
  int? maxCharsOverride,
}) {
  final floor = minScoreOverride ?? minScore;
  final cap = maxCharsOverride ?? defaultMaxChars;

  final kept = boxes
      .where((b) => b.score >= floor && b.text.trim().isNotEmpty)
      .toList();

  final text = toReadingOrder(
    kept,
  ).map((b) => b.text.trim()).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  return truncateWords(text, cap);
}
