// "Read that" — OCR a captured frame and hand back one speakable string.
//
// Port intent of src/features/ai/hooks/useReadText.ts, which wraps
// executorch's useOCR and composes the result with utils/ocr.ts's
// composeSpeech. The real implementation runs a native OCR model over a
// camera frame; this defines the contract [OcrReader] it must satisfy and a
// fake with canned detections for headless use.
import '../../utils/ocr.dart';
import 'types.dart';

class ReadResult {
  const ReadResult({required this.text, required this.boxes});

  /// `''` means the read ran fine but found nothing.
  final String text;
  final List<TextBox> boxes;
}

sealed class ReadOutcome {
  const ReadOutcome();
}

/// A read ran. `result.text` is `''` when it found nothing.
class ReadOk extends ReadOutcome {
  const ReadOk(this.result);

  final ReadResult result;
}

/// The recognizer rejected the frame, or the models aren't usable.
class ReadFailed extends ReadOutcome {
  const ReadFailed();
}

/// Refused before doing any work — not ready, or one already in flight.
class ReadSkipped extends ReadOutcome {
  const ReadSkipped();
}

abstract class OcrReader {
  /// OCRs the image at `uri`. Never throws; see [ReadOutcome].
  Future<ReadOutcome> read(String uri);
}

/// Cycles through a few canned detection sets so a demo/test can see more
/// than one outcome, including the "nothing legible" case.
class MockOcrReader implements OcrReader {
  MockOcrReader({List<List<TextBox>>? script})
    : _script = script ?? _defaultScript;

  static final _defaultScript = <List<TextBox>>[
    [
      const TextBox(
        bbox: Bbox(x1: 0, y1: 0, x2: 120, y2: 40),
        text: 'EXIT',
        score: 0.95,
      ),
    ],
    [
      const TextBox(
        bbox: Bbox(x1: 0, y1: 0, x2: 200, y2: 30),
        text: 'Platform 3',
        score: 0.9,
      ),
      const TextBox(
        bbox: Bbox(x1: 0, y1: 40, x2: 220, y2: 70),
        text: 'Cape Town',
        score: 0.9,
      ),
    ],
    const <TextBox>[], // nothing legible
  ];

  final List<List<TextBox>> _script;
  int _i = 0;

  @override
  Future<ReadOutcome> read(String uri) async {
    final boxes = _script[_i % _script.length];
    _i++;
    return ReadOk(ReadResult(text: composeSpeech(boxes), boxes: boxes));
  }
}
