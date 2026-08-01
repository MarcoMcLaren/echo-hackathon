// Ported from src/screens/CatchMeUpSheet.tsx (post real-LLM change).
//
// The local model summarises what you missed while you had no route. The
// model name and "nothing left this device" stay on the sheet, not buried in
// settings — the claim of on-device is worth nothing if the UI doesn't show
// it. The summary itself now comes from `ThreadSummary`, a real on-device
// LLM (see lib/features/thread_summary.dart), not a static mock.
import 'package:flutter/material.dart';
import '../features/thread_summary.dart';
import '../models/mock.dart';
import '../theme/echo_theme.dart';
import '../theme/palette.dart';
import '../widgets/type.dart';

class CatchMeUpSheet extends StatefulWidget {
  final Thread thread;
  final int unread;
  final VoidCallback onClose;

  const CatchMeUpSheet({super.key, required this.thread, required this.unread, required this.onClose});

  @override
  State<CatchMeUpSheet> createState() => _CatchMeUpSheetState();
}

class _CatchMeUpSheetState extends State<CatchMeUpSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rise;
  final _summary = ThreadSummary();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _rise = CurvedAnimation(parent: _controller, curve: const Cubic(0.2, 0.8, 0.2, 1));
    _controller.forward();
    _summary.addListener(_onSummaryChanged);
    // Run as soon as the model is in RAM; nobody wants a second button here.
    // (flutter_gemma doesn't split "load" from "generate" into separate
    // hook effects the way RN's isReady effect does — summarise() drives
    // isReady/downloadProgress itself before it starts generating, so one
    // call from initState covers both stages.) Deferred to the post-frame
    // callback because summarise() calls notifyListeners() synchronously
    // before its first await, and calling setState() mid-initState throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run();
    });
  }

  void _onSummaryChanged() {
    if (mounted) setState(() {});
  }

  void _run() => _summary.summarise(widget.thread, widget.unread);

  void _retry() => _run();

  @override
  void dispose() {
    _summary.removeListener(_onSummaryChanged);
    _summary.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    final unread = widget.unread;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Semantics(
              label: 'Close summary',
              child: Container(color: const Color.fromRGBO(13, 26, 22, 0.45)),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: _rise,
            builder: (context, child) => Opacity(
              opacity: _rise.value,
              child: Transform.translate(offset: Offset(0, 40 * (1 - _rise.value)), child: child),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
              decoration: BoxDecoration(
                color: c.card,
                border: Border.all(color: c.hair),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(EchoRadius.sheet),
                  topRight: Radius.circular(EchoRadius.sheet),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 2),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.hair, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 12),
                  MonoText('CATCH ME UP · $summaryModel', size: 10),
                  const SizedBox(height: 12),
                  DisplayText('$unread message${unread == 1 ? '' : 's'} while you were out of range.', size: 23),
                  const SizedBox(height: 12),
                  _buildBody(c),
                  MonoText(
                    'NOTHING LEFT THIS DEVICE${_summary.done && _summary.tookMs != null ? ' · ${(_summary.tookMs! / 1000).toStringAsFixed(1)} S' : ''}',
                    size: 8.5,
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: touchMin),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(10)),
                      child: DisplayText('Back to chat', size: 14, color: c.paper),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(Palette c) {
    final error = _summary.error;
    if (error != null) {
      final shown = (error.length > 120 ? error.substring(0, 120) : error).toUpperCase();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BodyText('The summary did not finish. Every message is still in the thread above.', size: 12.5, color: c.direct),
            const SizedBox(height: 10),
            MonoText(shown, size: 8.5),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _retry,
              child: Semantics(
                button: true,
                label: 'Try again',
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: touchMin),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: Border.all(color: c.hair, width: 1.5), borderRadius: BorderRadius.circular(10)),
                  child: const DisplayText('Try again', size: 14),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!_summary.isReady) {
      final pct = ((_summary.downloadProgress ?? 0) * 100).round();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.ink3)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  BodyText(
                    pct > 0 && pct < 100
                        ? 'Fetching the model once. After this it runs with no network at all.'
                        : 'Loading the model onto this phone.',
                    size: 12.5,
                    dim: Dim.two,
                  ),
                  if (pct > 0 && pct < 100) MonoText('$pct%', size: 8.5),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in _summary.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c.relay, shape: BoxShape.circle)),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: BodyText(line, size: 12.5)),
                ],
              ),
            ),
          if (_summary.isGenerating)
            Row(
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.ink3)),
                const SizedBox(width: 10),
                MonoText('READING ${widget.unread} MESSAGES', size: 8.5),
              ],
            ),
        ],
      ),
    );
  }
}
