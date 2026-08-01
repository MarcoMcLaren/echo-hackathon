// Obstacle detection adapter: a stream of nearby-object detections the
// feedback feature turns into haptics + speech.
//
// Port intent of src/features/vision/hooks/useObstacles.ts (a placeholder
// upstream too — "camera frames -> executorch object detection"). The real
// implementation runs react-native-executorch's object detector over
// expo-camera frames; here we define the contract it fills and a fake that
// emits a synthetic obstacle drifting closer, so the feedback pipeline can be
// built and tested without a camera or a model.
import 'dart:async';
import 'dart:math';

/// One detected object in the camera's forward view.
class Detection {
  const Detection({
    required this.label,
    required this.confidence,
    required this.closeness,
  });

  /// COCO-style class name, e.g. "chair", "person".
  final String label;

  /// Model confidence, 0..1.
  final double confidence;

  /// Bounding-box-size proxy for distance: 0 (far) .. 1 (very close). Not a
  /// real depth measurement — see the project's honest-limitations note.
  final double closeness;
}

abstract class ObstacleDetector {
  Stream<List<Detection>> get detections;

  Future<void> start();
  Future<void> stop();
}

/// Emits one synthetic obstacle that steadily approaches, then holds, so
/// screens/tests can exercise the full "far -> close" feedback range without
/// a camera or ExecuTorch. Ticks every [tickInterval] while running.
class MockObstacleDetector implements ObstacleDetector {
  MockObstacleDetector({
    this.tickInterval = const Duration(milliseconds: 200),
    this.label = 'chair',
    this.step = 0.1,
  });

  final Duration tickInterval;
  final String label;
  final double step;

  final _controller = StreamController<List<Detection>>.broadcast();
  Timer? _timer;
  double _closeness = 0.0;

  @override
  Stream<List<Detection>> get detections => _controller.stream;

  @override
  Future<void> start() async {
    _timer?.cancel();
    _closeness = 0.0;
    _timer = Timer.periodic(tickInterval, (_) {
      _closeness = min(1.0, _closeness + step);
      _controller.add([
        Detection(label: label, confidence: 0.86, closeness: _closeness),
      ]);
    });
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
