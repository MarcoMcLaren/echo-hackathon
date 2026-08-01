// "Read that" — OCR a captured frame and hand back one speakable string.
//
// Port intent of src/features/ai/hooks/useReadText.ts, which wraps
// executorch's useOCR and composes the result with utils/ocr.ts's
// composeSpeech. This defines the contract [OcrReader] a reader must satisfy
// and the real [MlkitOcrReader], which captures a camera frame and runs
// on-device OCR over it.
import 'package:camera/camera.dart' as cam;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' as mlkit;

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

/// Captures a frame from the back camera and runs on-device text recognition
/// over it. The camera is opened lazily on first read and kept warm for the
/// next one, matching the "point and tap" flow ReadScreen drives.
///
/// The only import site for package:camera and
/// package:google_mlkit_text_recognition — both fully offline, no model
/// download.
class MlkitOcrReader implements OcrReader {
  final mlkit.TextRecognizer _recognizer = mlkit.TextRecognizer();

  cam.CameraController? _controller;
  bool _busy = false;

  Future<cam.CameraController> _ensureController() async {
    final existing = _controller;
    if (existing != null && existing.value.isInitialized) return existing;

    final cameras = await cam.availableCameras();
    final back = cameras.firstWhere(
      (c) => c.lensDirection == cam.CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = cam.CameraController(back, cam.ResolutionPreset.medium, enableAudio: false);
    await controller.initialize();
    _controller = controller;
    return controller;
  }

  @override
  Future<ReadOutcome> read(String uri) async {
    if (_busy) return const ReadSkipped();
    _busy = true;
    try {
      final controller = await _ensureController();
      final frame = await controller.takePicture();
      final recognized = await _recognizer.processImage(mlkit.InputImage.fromFilePath(frame.path));

      final boxes = [
        for (final block in recognized.blocks)
          for (final line in block.lines)
            TextBox(
              bbox: Bbox(
                x1: line.boundingBox.left,
                y1: line.boundingBox.top,
                x2: line.boundingBox.right,
                y2: line.boundingBox.bottom,
              ),
              text: line.text,
              score: line.confidence ?? 1.0,
            ),
      ];
      return ReadOk(ReadResult(text: composeSpeech(boxes), boxes: boxes));
    } catch (_) {
      return const ReadFailed();
    } finally {
      _busy = false;
    }
  }

  /// Releases the camera and recognizer. Not part of [OcrReader] — called
  /// via the provider's dispose hook in main.dart.
  Future<void> dispose() async {
    await _recognizer.close();
    await _controller?.dispose();
    _controller = null;
  }
}
