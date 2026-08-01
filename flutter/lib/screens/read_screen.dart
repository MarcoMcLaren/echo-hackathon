// Ported from src/screens/ReadScreen.tsx.
//
// Point the phone at text, tap once, hear it read back. The round trip is
// on-device: a still-photo camera capture -> google_mlkit_text_recognition's
// on-device text recognizer -> flutter_tts. The transcript panel is there for
// sighted onlookers and for the demo; speech is the real output.
//
// Adaptation notes (RN used expo-camera + react-native-executorch's useOCR):
//
//  - expo-camera's `useCameraPermissions` hook lets RN pre-flight permission
//    status before ever touching the camera, and separately reports whether
//    the OS will still let it ask again. The `camera` plugin used here has no
//    such API: permission is requested implicitly, natively, the moment the
//    camera controller is initialized, and handed back to us as a thrown
//    `CameraException` (code `CameraAccessDenied`) if refused. So there is no
//    separate "permission" gate screen here — camera-controller init IS the
//    permission check, and a failure is shown as the "camera blocked" state
//    below. We also can't ask the OS whether it will still let us prompt
//    again (that needs `permission_handler`, which isn't a dependency here),
//    so the blocked copy always mentions both retrying and checking Settings,
//    rather than branching on a `canAskAgain` we don't have.
//  - executorch's useOCR has an explicit async "load the model" phase with a
//    download-progress percentage. google_mlkit_text_recognition's
//    `TextRecognizer` has no such phase — it's ready as soon as it's
//    constructed, with no bytes to fetch and no percentage to show. So there
//    is no "Loading model NN%" state here, and no persistent "reader
//    unavailable because the model never loaded" state distinct from a
//    camera failure: a single bad recognition is always treated as transient
//    (shown in the transcript panel as an error and spoken as "Couldn't read
//    that."), same as RN's per-read failure path. Only the camera itself
//    (permission denied, no hardware, etc.) can put this screen into the
//    persistent "unavailable, tap Retry" state.
//  - executorch's OCR gives per-word boxes with a detection score; ML Kit
//    gives per-line boxes (`TextLine`) with an Android-only `confidence`
//    (null on iOS). Speech is composed at the line level, falling back to
//    score 1.0 when ML Kit doesn't supply one — see `lib/utils/ocr_compose.dart`.
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../features/feedback.dart' as feedback;
import '../theme/echo_theme.dart';
import '../theme/palette.dart';
import '../utils/ocr_compose.dart';
import '../widgets/chrome.dart';
import '../widgets/type.dart';

const _nothing = 'No text found.';
const _broke = "Couldn't read that.";

class ReadScreen extends StatefulWidget {
  /// Lets the shell lock navigation while a read is in flight — unmounting
  /// this screen mid-capture is not something we want, even though the
  /// underlying failure mode here (a thrown platform exception, rather than
  /// executorch's `ModelGenerating`) is different from RN's.
  final ValueChanged<bool>? onBusyChange;

  const ReadScreen({super.key, this.onBusyChange});

  @override
  State<ReadScreen> createState() => _ReadScreenState();
}

class _ReadScreenState extends State<ReadScreen> {
  // Bumping this remounts _Reader, tearing down and recreating the camera
  // controller + recognizer from scratch — the most reliable way to retry a
  // hard failure. Mirrors RN's `key={attempt}` on its own Reader.
  int _attempt = 0;
  void _retry() => setState(() => _attempt++);

  @override
  Widget build(BuildContext context) {
    return _Reader(
      key: ValueKey(_attempt),
      onRetry: _retry,
      onBusyChange: widget.onBusyChange,
    );
  }
}

class _Reader extends StatefulWidget {
  final VoidCallback onRetry;
  final ValueChanged<bool>? onBusyChange;

  const _Reader({super.key, required this.onRetry, this.onBusyChange});

  @override
  State<_Reader> createState() => _ReaderState();
}

class _ReaderState extends State<_Reader> with WidgetsBindingObserver {
  CameraController? _controller;
  TextRecognizer? _recognizer;

  bool _camReady = false;
  bool _camError = false;
  bool _camPermissionDenied = false;

  bool _capturing = false;
  String? _transcript; // null = nothing read yet
  String? _error; // last read's failure, if any

  bool _latched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    unawaited(_initCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Granting permission in Android Settings doesn't remount us, so without
    // this the screen stays stuck on the blocked branch after the user
    // returns — mirrors RN's AppState listener re-checking permission.
    if (state == AppLifecycleState.resumed && _camError && !_capturing) {
      unawaited(_initCamera());
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _camReady = false;
      _camError = false;
      _camPermissionDenied = false;
    });
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final old = _controller;
      setState(() {
        _controller = controller;
        _camReady = true;
      });
      await old?.dispose();
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _camError = true;
        _camPermissionDenied = e.code == 'CameraAccessDenied';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _camError = true;
        _camPermissionDenied = false;
      });
    }
  }

  bool get _busy => _capturing;
  bool get _canRead => _camReady && !_camError && !_busy;

  void _reportBusy() => widget.onBusyChange?.call(_busy);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.onBusyChange?.call(false);
    unawaited(feedback.stopSpeaking());
    _controller?.dispose();
    _recognizer?.close();
    super.dispose();
  }

  Future<void> _onRead() async {
    if (_latched || !_canRead) return;
    final controller = _controller;
    final recognizer = _recognizer;
    if (controller == null || recognizer == null) {
      // Enabled button with no camera would otherwise be a silent dead tap.
      await feedback.notifyFail();
      await feedback.speak(_broke);
      return;
    }

    _latched = true;
    setState(() => _capturing = true);
    _reportBusy();
    try {
      await feedback.tick();
      final shot = await controller.takePicture();
      final recognized = await recognizer.processImage(InputImage.fromFilePath(shot.path));

      final boxes = <OcrTextBox>[
        for (final block in recognized.blocks)
          for (final line in block.lines)
            OcrTextBox(
              bbox: OcrBox(
                x1: line.boundingBox.left,
                y1: line.boundingBox.top,
                x2: line.boundingBox.right,
                y2: line.boundingBox.bottom,
              ),
              text: line.text,
              // Android gives a real per-line confidence; iOS (and any box
              // that comes back without one) is treated as fully trusted
              // rather than guessing at a score ML Kit never provided.
              score: line.confidence ?? 1.0,
            ),
      ];
      final text = composeSpeech(boxes, maxChars: feedback.maxSpeechChars);

      if (!mounted) return;
      setState(() {
        _transcript = text;
        _error = null;
      });
      await feedback.notifyOk();
      await feedback.speak(text.isEmpty ? _nothing : text);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = _broke);
      await feedback.notifyFail();
      await feedback.speak(_broke);
    } finally {
      _latched = false;
      if (mounted) {
        setState(() => _capturing = false);
        _reportBusy();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;

    if (_camError) {
      return Column(
        children: [
          const MeshStatusBar(right: 'CAMERA BLOCKED', state: MeshState.error),
          const EchoAppBar(title: 'Read that', sub: 'Point at text and tap to hear it'),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 260,
                      child: DisplayText(
                        'Echo needs the camera to read text',
                        size: 26,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 270,
                      child: BodyText(
                        _camPermissionDenied
                            ? 'It is used only while this screen is open. Nothing leaves the phone. If you already denied access, enable it for Echo in Android Settings › Apps › Echo › Permissions, then try again.'
                            : 'The camera could not be started on this device.',
                        size: 13,
                        dim: Dim.two,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PrimaryButton(label: 'Retry', onPressed: widget.onRetry),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final canRead = _canRead;
    final busy = _busy;

    final String buttonLabel;
    if (!_camReady) {
      buttonLabel = 'Starting camera';
    } else if (busy) {
      buttonLabel = 'Reading…';
    } else {
      buttonLabel = 'Read that';
    }

    final String statusRight = !_camReady ? 'STARTING CAMERA' : 'ON-DEVICE OCR · OFFLINE';
    final MeshState statusState = !_camReady ? MeshState.starting : MeshState.live;

    final String panelHead;
    if (_error != null) {
      panelHead = 'ERROR';
    } else if (_transcript == null) {
      panelHead = 'NOTHING READ YET';
    } else {
      panelHead = 'LAST READ';
    }

    final String panelBody;
    if (_error != null) {
      panelBody = _error!;
    } else if (_transcript == null) {
      panelBody = 'Point at a sign, a label or a page.';
    } else {
      panelBody = _transcript!.isEmpty ? _nothing : _transcript!;
    }

    return Column(
      children: [
        MeshStatusBar(right: statusRight, state: statusState),
        const EchoAppBar(title: 'Read that', sub: 'Point at text and tap to hear it'),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: c.hair),
              borderRadius: BorderRadius.circular(EchoRadius.card),
              color: Colors.black,
            ),
            clipBehavior: Clip.antiAlias,
            child: _camReady && _controller != null
                ? CameraPreview(_controller!)
                : const SizedBox.expand(),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxHeight: 148),
          decoration: BoxDecoration(
            color: c.card,
            border: Border.all(color: c.hair2),
            borderRadius: BorderRadius.circular(EchoRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              MonoText(panelHead, size: 8.5),
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 4),
                  child: BodyText(
                    panelBody,
                    size: 15,
                    dim: _transcript != null ? null : Dim.two,
                    color: _error != null ? c.direct : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Semantics(
            button: true,
            label: buttonLabel,
            enabled: canRead,
            child: GestureDetector(
              onTap: canRead ? _onRead : null,
              child: Container(
                constraints: const BoxConstraints(minHeight: 68),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: canRead ? c.ink : c.sunk,
                  borderRadius: BorderRadius.circular(EchoRadius.card),
                ),
                child: DisplayText(buttonLabel, size: 19, color: canRead ? c.paper : c.ink3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(EchoRadius.card)),
          child: DisplayText(label, size: 19, color: c.paper),
        ),
      ),
    );
  }
}
