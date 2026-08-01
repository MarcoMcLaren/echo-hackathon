// Ported from src/features/messaging/components/RemoveSheet.tsx.
//
// Removing someone deletes a conversation, so it asks first and says exactly
// what will happen — including that it is reversible, which is the thing
// that makes the decision easy. Bottom-sheet animation matches
// CatchMeUpSheet (see lib/screens/catch_me_up_sheet.dart) for consistency
// with the rest of the app's sheets.
import 'package:flutter/material.dart';

import '../models/types.dart';
import '../theme/echo_theme.dart';
import '../theme/palette.dart';
import 'type.dart';

class RemoveSheet extends StatefulWidget {
  final Thread thread;
  /// Wired to the store's unpair(thread.id) for a 1:1, or forgetThread(thread.id)
  /// for a group, by a later integration pass — this widget only distinguishes
  /// copy/label by thread.group and always calls this single callback.
  final VoidCallback onConfirm;
  final VoidCallback onClose;

  const RemoveSheet({super.key, required this.thread, required this.onConfirm, required this.onClose});

  @override
  State<RemoveSheet> createState() => _RemoveSheetState();
}

class _RemoveSheetState extends State<RemoveSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rise;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
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
    final isGroup = widget.thread.group;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Semantics(
              label: 'Keep this conversation',
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                  const SizedBox(height: 10),
                  DisplayText(isGroup ? 'Leave ${widget.thread.title}?' : 'Remove ${widget.thread.title}?', size: 24),
                  const SizedBox(height: 12),
                  BodyText(
                    isGroup
                        ? 'The conversation goes from this phone. The others keep theirs, and you can be added again.'
                        : 'This deletes the conversation and stops the two phones connecting. Tap or scan to pair again whenever you want.',
                    size: 13,
                    dim: Dim.two,
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: isGroup ? 'Leave group' : 'Remove',
                    child: GestureDetector(
                      onTap: widget.onConfirm,
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: touchMin),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(color: c.direct, borderRadius: BorderRadius.circular(10)),
                        child: DisplayText(isGroup ? 'Leave group' : 'Remove', size: 15, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    button: true,
                    label: 'Keep it',
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: touchMin),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(border: Border.all(color: c.hair, width: 1.5), borderRadius: BorderRadius.circular(10)),
                        child: const DisplayText('Keep it', size: 15),
                      ),
                    ),
                  ),
                  if (!isGroup) ...[
                    const SizedBox(height: 12),
                    const Center(child: MonoText('ECHOCOIN ALREADY SENT IS NOT UNDONE', size: 8.5)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
