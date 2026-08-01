// A small model, running here, summarising what arrived while you had no
// route. The model name and "nothing left this device" stay on the sheet
// rather than buried in settings — that claim is the reason this runs
// locally at all. Port of src/screens/CatchMeUpSheet.tsx.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/type.dart';
import '../features/ai/summarize.dart';
import '../store/mock.dart' as mock;
import '../store/theme_store.dart';
import '../styles/theme.dart' as tokens;

class CatchMeUpSheet extends StatefulWidget {
  const CatchMeUpSheet({
    super.key,
    required this.thread,
    required this.unread,
    required this.onClose,
  });

  final mock.Thread thread;
  final int unread;
  final VoidCallback onClose;

  @override
  State<CatchMeUpSheet> createState() => _CatchMeUpSheetState();
}

class _CatchMeUpSheetState extends State<CatchMeUpSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rise;

  StreamSubscription<SummaryState>? _sub;
  SummaryState _state = const SummaryState(
    lines: [],
    isReady: false,
    isGenerating: false,
    downloadProgress: 0,
    done: false,
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _rise = CurvedAnimation(parent: _controller, curve: const Cubic(0.2, 0.8, 0.2, 1));
    _controller.forward();
    // Run as soon as the widget exists; nobody wants a second button here.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted) return;
    _sub?.cancel();
    _sub = context
        .read<ThreadSummarizer>()
        .summarize(widget.thread, widget.unread)
        .listen((state) {
          if (mounted) setState(() => _state = state);
        });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    final unread = widget.unread;
    final state = _state;
    final pct = (state.downloadProgress * 100).round();

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Semantics(
              label: 'Close summary',
              child: Container(color: const Color(0x730D1A16)),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: _rise,
            builder: (context, child) => Opacity(
              opacity: _rise.value,
              child: Transform.translate(
                offset: Offset(0, 40 * (1 - _rise.value)),
                child: child,
              ),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
              decoration: BoxDecoration(
                color: c.card,
                border: Border.all(color: c.hair),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(tokens.AppRadius.sheet),
                  topRight: Radius.circular(tokens.AppRadius.sheet),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 34,
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: c.hair, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Mono('CATCH ME UP · $summaryModel'.toUpperCase(), size: 10),
                  const SizedBox(height: 12),
                  Display(
                    '$unread message${unread == 1 ? '' : 's'} while you were out of range.',
                    size: 23,
                  ),
                  const SizedBox(height: 12),
                  if (state.error != null)
                    _ErrorBody(colors: c, error: state.error!, onRetry: _start)
                  else if (!state.isReady)
                    _WaitingRow(
                      colors: c,
                      label: pct > 0 && pct < 100
                          ? 'Fetching the model once. After this it runs with no network at all.'
                          : 'Loading the model onto this phone.',
                      pct: pct > 0 && pct < 100 ? pct : null,
                    )
                  else
                    _Lines(colors: c, state: state, unread: unread),
                  const SizedBox(height: 12),
                  Mono(
                    'NOTHING LEFT THIS DEVICE'
                    '${state.done && state.tookMs != null ? ' · ${(state.tookMs! / 1000).toStringAsFixed(1)} S' : ''}',
                    size: 8.5,
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: 'Back to chat',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: tokens.touchMin),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(10)),
                        child: Display('Back to chat', size: 14, color: c.paper),
                      ),
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
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.colors, required this.error, required this.onRetry});

  final tokens.Palette colors;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Body('The summary did not finish. Every message is still in the thread above.', size: 12.5, color: c.direct),
        const SizedBox(height: 10),
        Mono(error.substring(0, error.length > 120 ? 120 : error.length).toUpperCase(), size: 8.5),
        const SizedBox(height: 10),
        Semantics(
          button: true,
          label: 'Try again',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onRetry,
            child: Container(
              constraints: const BoxConstraints(minHeight: tokens.touchMin),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: c.hair, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Display('Try again', size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _WaitingRow extends StatelessWidget {
  const _WaitingRow({required this.colors, required this.label, this.pct});

  final tokens.Palette colors;
  final String label;
  final int? pct;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: colors.ink3),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Body(label, size: 12.5, dim: 2),
              if (pct != null) Mono('$pct%', size: 8.5),
            ],
          ),
        ),
      ],
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({required this.colors, required this.state, required this.unread});

  final tokens.Palette colors;
  final SummaryState state;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in state.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: c.relay, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(child: Body(line, size: 12.5)),
              ],
            ),
          ),
        if (state.isGenerating)
          Row(
            children: [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.ink3)),
              const SizedBox(width: 10),
              Mono('READING $unread MESSAGES', size: 8.5),
            ],
          ),
      ],
    );
  }
}
