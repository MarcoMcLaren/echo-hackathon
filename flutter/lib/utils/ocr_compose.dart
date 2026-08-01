// Ported from src/utils/ocr.ts — turning OCR detections into one speakable
// sentence.
//
// RN's executorch OCR hands back per-word boxes with a detection `score`.
// google_mlkit_text_recognition (see read_screen.dart) gives us per-line boxes
// (`TextLine`) instead, with an Android-only `confidence` that is `null` on
// iOS. Rather than inventing a fake per-word heuristic ML Kit never gave us,
// `OcrTextBox.score` is meant to be filled with that confidence when present
// and `1.0` (fully trusted) when it isn't — see read_screen.dart, which does
// that mapping before calling [composeSpeech].
library;

const double kMinScore = 0.5;
const int kDefaultMaxChars = 3900;
const double kMaxLineHeightRatio = 2.5;

/// A bounding box in image coordinates. Not assumed to be normalized
/// (x1<=x2, y1<=y2) on construction — call [normalized] before measuring it.
class OcrBox {
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  const OcrBox({required this.x1, required this.y1, required this.x2, required this.y2});

  OcrBox get normalized => OcrBox(
        x1: x1 < x2 ? x1 : x2,
        x2: x1 < x2 ? x2 : x1,
        y1: y1 < y2 ? y1 : y2,
        y2: y1 < y2 ? y2 : y1,
      );

  double get _height {
    final h = y2 - y1;
    return h > 1 ? h : 1;
  }
}

/// One recognized span of text: a bounding box, the text itself, and a
/// confidence score in the same [0, 1] shape RN's `TextBox.score` used.
class OcrTextBox {
  final OcrBox bbox;
  final String text;
  final double score;

  const OcrTextBox({required this.bbox, required this.text, required this.score});
}

/// Two boxes are "the same line" if they're similar in height and their
/// vertical spans overlap by more than half the shorter box's height.
bool sameLine(OcrBox a, OcrBox b) {
  final na = a.normalized;
  final nb = b.normalized;
  final ha = na._height;
  final hb = nb._height;
  final bigger = ha > hb ? ha : hb;
  final smaller = ha < hb ? ha : hb;
  if (bigger / smaller > kMaxLineHeightRatio) return false;
  final overlapTop = na.y1 > nb.y1 ? na.y1 : nb.y1;
  final overlapBottom = na.y2 < nb.y2 ? na.y2 : nb.y2;
  final overlap = overlapBottom - overlapTop;
  return overlap > 0.5 * smaller;
}

/// Groups boxes into lines (top-to-bottom) then sorts each line left-to-right
/// — turning a bag of detections into reading order.
List<OcrTextBox> toReadingOrder(List<OcrTextBox> boxes) {
  final byTop = [...boxes]..sort((a, b) => a.bbox.normalized.y1.compareTo(b.bbox.normalized.y1));

  final lines = <List<OcrTextBox>>[];
  for (final box in byTop) {
    List<OcrTextBox>? line;
    for (final candidate in lines) {
      if (sameLine(candidate.first.bbox, box.bbox)) {
        line = candidate;
        break;
      }
    }
    if (line != null) {
      line.add(box);
    } else {
      lines.add([box]);
    }
  }

  final out = <OcrTextBox>[];
  for (final line in lines) {
    final sorted = [...line]..sort((p, q) => p.bbox.normalized.x1.compareTo(q.bbox.normalized.x1));
    out.addAll(sorted);
  }
  return out;
}

/// Cuts `text` down to `maxChars`, backing off to the last whole word rather
/// than slicing mid-word.
String truncateWords(String text, int maxChars) {
  if (maxChars <= 0) return '';
  if (text.length <= maxChars) return text;
  final cut = text.substring(0, maxChars);
  final lastSpace = cut.lastIndexOf(' ');
  return (lastSpace > 0 ? cut.substring(0, lastSpace) : cut).trimRight();
}

/// Filters low-confidence/empty boxes, puts the rest in reading order, joins
/// them into one sentence, and truncates to a speakable length.
String composeSpeech(
  List<OcrTextBox> boxes, {
  double minScore = kMinScore,
  int maxChars = kDefaultMaxChars,
}) {
  final kept = boxes.where((b) => b.score >= minScore && b.text.trim().isNotEmpty).toList();
  final text = toReadingOrder(kept)
      .map((b) => b.text.trim())
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return truncateWords(text, maxChars);
}
