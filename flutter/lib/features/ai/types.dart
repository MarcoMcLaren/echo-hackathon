// Dart types for OCR / scene-description results.
// Port of src/features/ai/types/index.ts.

/// Axis-aligned box in the source image's pixel coordinates.
class Bbox {
  const Bbox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;
}

/// One recognized run of text.
///
/// Structurally identical to executorch's `OCRDetection`, redeclared here on
/// purpose: it lets the pure helpers in `utils/ocr.dart` be unit-tested
/// without a native module.
class TextBox {
  const TextBox({required this.bbox, required this.text, required this.score});

  final Bbox bbox;
  final String text;
  final double score;
}
