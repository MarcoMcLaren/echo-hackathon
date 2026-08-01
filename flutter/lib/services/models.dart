// Mock stand-in for the on-device model download pipeline described in the
// project brief (react-native-executorch fetching SSDLite/COCO + an on-device
// LLM from Hugging Face over wifi, then running fully offline). No ExecuTorch
// equivalent is wired into this Flutter build yet, so this simulates progress
// with a timer instead of a real network fetch — same shape, so a real
// implementation drops in behind [downloadGroup] without touching the screen.
import 'dart:async';

class ModelGroup {
  const ModelGroup({required this.label, required this.sizeLabel});

  final String label;
  final String sizeLabel;
}

const visionModels = ModelGroup(label: 'Object detection (SSDLite / COCO)', sizeLabel: '~28 MB');
const languageModel = ModelGroup(label: 'On-device LLM (scene + thread summaries)', sizeLabel: '~1.2 GB');

const _steps = 10;
const _stepDuration = Duration(milliseconds: 80);

/// Simulates a chunked download, reporting progress from 0 to 1.
Future<void> downloadGroup(ModelGroup group, void Function(double progress) onProgress) async {
  for (var i = 1; i <= _steps; i++) {
    await Future.delayed(_stepDuration);
    onProgress(i / _steps);
  }
}
