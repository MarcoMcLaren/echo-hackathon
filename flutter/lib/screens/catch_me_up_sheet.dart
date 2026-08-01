// The local model summarises what you missed while you had no route. The
// model name and "nothing left this device" stay on the sheet, not buried in
// settings — the claim of on-device is worth nothing if the UI doesn't show
// it. Port of src/screens/CatchMeUpSheet.tsx.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/type.dart';
import '../store/mock.dart' as mock;
import '../store/theme_store.dart';
import '../styles/theme.dart' as tokens;

class CatchMeUpSheet extends StatefulWidget {
  const CatchMeUpSheet({super.key, required this.summary, required this.onClose});

  /// Resolved by the on-device summarizer adapter (features/ai/summarize.dart)
  /// over the thread's messages — kept as a Future here so the sheet can show
  /// a brief "summarizing" state rather than pretending the model is instant.
  final Future<mock.Summary> summary;
  final VoidCallback onClose;

  @override
  State<CatchMeUpSheet> createState() => _CatchMeUpSheetState();
}

class _CatchMeUpSheetState extends State<CatchMeUpSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rise;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _rise = CurvedAnimation(parent: _controller, curve: const Cubic(0.2, 0.8, 0.2, 1));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);

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
                  FutureBuilder<mock.Summary>(
                    future: widget.summary,
                    builder: (context, snapshot) {
                      final summary = snapshot.data;
                      if (summary == null) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: c.ink2),
                              ),
                              const SizedBox(width: 10),
                              const Mono('SUMMARIZING ON THIS PHONE…', size: 9),
                            ],
                          ),
                        );
                      }
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Mono('CATCH ME UP · ${summary.model.toUpperCase()}', size: 10),
                          const SizedBox(height: 12),
                          Display('${summary.count} messages while you were out of range.', size: 23),
                          const SizedBox(height: 12),
                          for (final p in summary.points)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 38,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Mono(p.k, size: 8.5),
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(child: Body(p.text, size: 12.5)),
                                ],
                              ),
                            ),
                          Mono('NOTHING LEFT THIS DEVICE · ${summary.took}', size: 8.5),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: 'Back to chat',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.ink,
                          borderRadius: BorderRadius.circular(10),
                        ),
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
