// "Read that" — point the phone at text, tap once, hear it read back.
//
// The whole round trip is on-device: a captured frame -> on-device OCR -> OS
// text-to-speech. Speech is the real output; the transcript panel is there
// for sighted onlookers and for the demo.
//
// No camera plugin is wired into this build — same constraint TapScreen's
// ScanMode documents — so "Read that" simulates a capture and feeds it to
// the OcrReader adapter directly, exactly the way ScanMode simulates a scan.
// Port of src/screens/ReadScreen.tsx.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/chrome.dart' show MeshState, MeshStatus, EchoAppBar;
import '../components/type.dart';
import '../features/ai/ocr_reader.dart';
import '../features/feedback/proximity_feedback.dart';
import '../store/theme_store.dart';
import '../styles/theme.dart' as tokens;

const _nothing = 'No text found.';
const _broke = "Couldn't read that.";

class ReadScreen extends StatefulWidget {
  const ReadScreen({super.key, this.onBusyChange});

  /// Lets the shell lock navigation while a read is in flight.
  final ValueChanged<bool>? onBusyChange;

  @override
  State<ReadScreen> createState() => _ReadScreenState();
}

class _ReadScreenState extends State<ReadScreen> {
  bool _busy = false;
  String? _transcript;
  String? _error;

  // A field, not a check re-entered per tap: two taps in one frame both see
  // the same busy state.
  bool _latch = false;

  @override
  void dispose() {
    widget.onBusyChange?.call(false);
    super.dispose();
  }

  void _setBusy(bool busy) {
    if (_busy == busy) return;
    setState(() => _busy = busy);
    widget.onBusyChange?.call(busy);
  }

  Future<void> _onRead() async {
    if (_latch || _busy) return;
    _latch = true;
    _setBusy(true);
    try {
      final haptics = context.read<HapticOutput>();
      final speech = context.read<SpeechOutput>();
      final reader = context.read<OcrReader>();
      await haptics.pulse(0.15); // shutter confirmation

      final outcome = await reader.read('captured-frame');
      switch (outcome) {
        case ReadOk(:final result):
          setState(() {
            _error = null;
            _transcript = result.text;
          });
          await haptics.pulse(0.5);
          await speech.speak(result.text.isEmpty ? _nothing : result.text);
        case ReadFailed():
          setState(() => _error = _broke);
          await haptics.pulse(0.9);
          await speech.speak(_broke);
        case ReadSkipped():
          break;
      }
    } finally {
      _latch = false;
      if (mounted) _setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);

    final String panelHead;
    final String panelBody;
    if (_error != null) {
      panelHead = 'ERROR';
      panelBody = _error!;
    } else if (_transcript == null) {
      panelHead = 'NOTHING READ YET';
      panelBody = 'Point at a sign, a label or a page.';
    } else {
      panelHead = 'LAST READ';
      panelBody = _transcript!.isEmpty ? _nothing : _transcript!;
    }

    return Column(
      children: [
        MeshStatus(
          right: _busy ? 'READING…' : 'ON-DEVICE OCR · OFFLINE',
          state: MeshState.live,
        ),
        const EchoAppBar(title: 'Read that', sub: 'Point at text and tap to hear it'),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: c.hair),
              borderRadius: BorderRadius.circular(tokens.AppRadius.card),
            ),
            alignment: Alignment.center,
            child: const Mono('NO CAMERA ON THIS BUILD', size: 8.5, color: Colors.white54),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxHeight: 148),
          decoration: BoxDecoration(
            color: c.card,
            border: Border.all(color: c.hair2),
            borderRadius: BorderRadius.circular(tokens.AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Mono(panelHead, size: 8.5),
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  child: Body(panelBody, size: 15, dim: _transcript == null ? 2 : null, color: _error != null ? c.direct : null),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Semantics(
            button: true,
            enabled: !_busy,
            label: _busy ? 'Reading…' : 'Read that',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: _busy ? null : _onRead,
              child: Container(
                constraints: const BoxConstraints(minHeight: 68),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _busy ? c.sunk : c.ink,
                  borderRadius: BorderRadius.circular(tokens.AppRadius.card),
                ),
                child: Display(_busy ? 'Reading…' : 'Read that', size: 19, color: _busy ? c.ink3 : c.paper),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
