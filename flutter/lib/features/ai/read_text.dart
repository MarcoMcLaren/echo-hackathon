// "Read that" OCR adapter, spoken by the feedback feature.
//
// Port intent of src/features/ai/hooks/useReadText.ts (a placeholder upstream
// too — "OCR a frame and return recognized text"). The real implementation
// runs react-native-executorch's useOCR over a camera frame; this defines the
// contract and a fake with canned results for headless use.
abstract class TextReader {
  /// Recognizes text in the current camera frame. Returns null if nothing
  /// legible was found — never throws on a blank/blurry frame.
  Future<String?> readText();
}

/// Cycles through a few canned reads so a demo/test can see more than one
/// outcome, including the "nothing legible" case.
class MockTextReader implements TextReader {
  MockTextReader({List<String?>? script})
    : _script = script ?? const ['EXIT', 'Platform 3 — Cape Town', null];

  final List<String?> _script;
  int _i = 0;

  @override
  Future<String?> readText() async {
    final result = _script[_i % _script.length];
    _i++;
    return result;
  }
}
