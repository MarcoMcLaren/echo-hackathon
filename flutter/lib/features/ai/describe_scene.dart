// "What's around me?" scene-description adapter, built from the vision
// feature's detections and spoken by the feedback feature.
//
// Port intent of src/features/ai/hooks/useDescribeScene.ts (a placeholder
// upstream too — "feed detections to the LLM"). The real implementation runs
// react-native-executorch's useLLM over the current detection list; this
// defines the contract and a fake that composes a plain-English sentence
// from labels so it works without a model loaded.
import '../vision/obstacle_detector.dart';

abstract class SceneDescriber {
  Future<String> describeScene(List<Detection> detections);
}

class MockSceneDescriber implements SceneDescriber {
  @override
  Future<String> describeScene(List<Detection> detections) async {
    if (detections.isEmpty) return 'Nothing obstructing you right now.';

    final ordered = [...detections]
      ..sort((a, b) => b.closeness.compareTo(a.closeness));
    final nearest = ordered.first;
    final distance = nearest.closeness > 0.7
        ? 'very close'
        : nearest.closeness > 0.35
        ? 'nearby'
        : 'ahead';

    if (ordered.length == 1) {
      return 'A ${nearest.label} $distance.';
    }
    final others = ordered.skip(1).map((d) => d.label).toSet().join(', ');
    return 'A ${nearest.label} $distance, and $others further off.';
  }
}
