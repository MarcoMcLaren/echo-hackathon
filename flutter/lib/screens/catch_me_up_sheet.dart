// Ported from src/screens/CatchMeUpSheet.tsx.
//
// The local model summarises what you missed while you had no route. The
// model name and "nothing left this device" stay on the sheet, not buried in
// settings — the claim of on-device is worth nothing if the UI doesn't show it.
import 'package:flutter/material.dart';
import '../models/mock.dart' as mock;
import '../theme/echo_theme.dart';
import '../theme/palette.dart';
import '../widgets/type.dart';

class CatchMeUpSheet extends StatefulWidget {
  final VoidCallback onClose;
  const CatchMeUpSheet({super.key, required this.onClose});

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
    final c = EchoTheme.of(context).c;
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
                  Container(width: 34, height: 3, margin: const EdgeInsets.only(bottom: 2), alignment: Alignment.center, decoration: BoxDecoration(color: c.hair, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  MonoText('CATCH ME UP · ${mock.summary.model}', size: 10),
                  const SizedBox(height: 12),
                  DisplayText('${mock.summary.count} messages while you were out of range.', size: 23),
                  const SizedBox(height: 12),
                  for (final p in mock.summary.points)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 38, child: Padding(padding: const EdgeInsets.only(top: 3), child: MonoText(p.k, size: 8.5))),
                          const SizedBox(width: 9),
                          Expanded(child: BodyText(p.text, size: 12.5)),
                        ],
                      ),
                    ),
                  MonoText('NOTHING LEFT THIS DEVICE · ${mock.summary.took}', size: 8.5),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 48),
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
}
