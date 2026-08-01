// Headless fakes for adapters whose real implementations import a plugin
// that can't run under `flutter test` (platform channels don't exist there).
//
// These used to live in lib/ as the app's own dev-mode default; now that
// lib/main.dart wires the real plugin-backed adapters, nothing in lib/
// references them any more, so they live here as test-only support code
// shared across the test suite.
import 'package:flutter/widgets.dart';

import 'package:echo/features/ai/ocr_reader.dart';
import 'package:echo/features/ai/types.dart';
import 'package:echo/features/feedback/proximity_feedback.dart' show SpeechOutput;
import 'package:echo/features/messaging/attachments.dart';
import 'package:echo/features/messaging/events.dart';
import 'package:echo/features/vault/qr_scanner.dart';
import 'package:echo/utils/ocr.dart';

/// Silently swallows speech instead of touching a TTS plugin.
class NoOpSpeechOutput implements SpeechOutput {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}

/// Hands back a canned image (or null, if scripted that way) instead of
/// opening a native picker/camera, so the compose flow can be built and
/// tested without one.
class MockImageSource implements ImageSource {
  MockImageSource({PickedImage? next}) : _next = next ?? _defaultImage;

  static const _defaultImage = PickedImage(
    dataUri: 'data:image/jpeg;base64,ZmFrZQ==',
    bytes: 6,
  );

  /// What the next pick returns. Set to null to simulate the user backing
  /// out or denying the camera.
  PickedImage? _next;

  set next(PickedImage? image) => _next = image;

  @override
  Future<PickedImage?> pickFromLibrary() async => _next;

  @override
  Future<PickedImage?> pickFromCamera() async => _next;
}

/// Records what would have been saved instead of touching a platform
/// calendar, so tests can assert on it without a plugin channel.
class MockCalendarWriter implements CalendarWriter {
  MockCalendarWriter({this.nextOutcome = const SaveOutcome.ok()});

  /// What [save] returns the next time it is called. Defaults to success.
  SaveOutcome nextOutcome;

  final List<MeshEvent> saved = [];

  @override
  Future<SaveOutcome> save(MeshEvent event) async {
    if (nextOutcome.ok) saved.add(event);
    return nextOutcome;
  }
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

/// Stands in for the camera: a tappable placeholder that "detects" a
/// scripted payload instead of pointing a real lens at a code.
class FakeQrScanner implements QrScanner {
  FakeQrScanner({this.script = 'echo://pair?id=sipho&k=mock-peer-key&n=Sipho'});

  /// What tapping the preview reports to [onDetect].
  final String script;

  @override
  Widget preview({required ValueChanged<String> onDetect}) {
    return Semantics(
      button: true,
      label: 'Camera preview (fake)',
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('fake-qr-scanner'),
        onTap: () => onDetect(script),
        child: const ColoredBox(
          color: Color(0xFF000000),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}
