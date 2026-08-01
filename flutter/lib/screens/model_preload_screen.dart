// First-run screen: pre-download the on-device AI models over wifi so the app
// runs fully offline afterward. Vision models auto-download (small); the LLM
// is opt-in (large). Port of src/screens/ModelPreloadScreen.tsx.
//
// Not part of the tab/route flow wired in main.dart — same as the RN source,
// which defines this screen without any navigator route pointing at it yet.
// It also intentionally skips the app's theme system, matching the RN
// original (a plain white first-run screen, styled before theming applied).
import 'package:flutter/material.dart';

import '../services/models.dart';

enum _Status { idle, downloading, ready, error }

class ModelPreloadScreen extends StatelessWidget {
  const ModelPreloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 96, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Echo', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: Colors.black)),
          const SizedBox(height: 4),
          const Text('Preload AI models', style: TextStyle(fontSize: 16, color: Color(0xFF333333))),
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 24),
            child: Text(
              'Models download from Hugging Face on first use, then run 100% offline. '
              'Do this once on wifi before an offline demo.',
              style: TextStyle(fontSize: 13, color: Color(0xFF666666), height: 1.4),
            ),
          ),
          const _GroupRow(group: visionModels, auto: true),
          const _GroupRow(group: languageModel, auto: false),
        ],
      ),
    );
  }
}

class _GroupRow extends StatefulWidget {
  const _GroupRow({required this.group, required this.auto});

  final ModelGroup group;
  final bool auto;

  @override
  State<_GroupRow> createState() => _GroupRowState();
}

class _GroupRowState extends State<_GroupRow> {
  _Status _status = _Status.idle;
  double _progress = 0;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    if (widget.auto) _start();
  }

  Future<void> _start() async {
    setState(() {
      _status = _Status.downloading;
      _progress = 0;
      _errorMsg = null;
    });
    try {
      await downloadGroup(widget.group, (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (mounted) setState(() => _status = _Status.ready);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = '$e';
          _status = _Status.error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E2E2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  widget.group.label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
                ),
              ),
              const SizedBox(width: 8),
              Text(widget.group.sizeLabel, style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
            ],
          ),
          if (_status == _Status.idle)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _Button(label: 'Download', onTap: _start),
            ),
          if (_status == _Status.downloading)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text('${(_progress * 100).round()}%', style: const TextStyle(fontSize: 14, color: Color(0xFF333333))),
                ],
              ),
            ),
          if (_status == _Status.ready)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('✓ Ready — offline', style: TextStyle(color: Color(0xFF137A2B), fontWeight: FontWeight.w600)),
            ),
          if (_status == _Status.error) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Failed: $_errorMsg', style: const TextStyle(color: Color(0xFFC0392B))),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _Button(label: 'Retry', onTap: _start),
            ),
          ],
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(color: const Color(0xFF2B6CFF), borderRadius: BorderRadius.circular(8)),
          child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
