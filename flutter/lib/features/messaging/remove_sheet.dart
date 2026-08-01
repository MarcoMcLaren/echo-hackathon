// Removing someone deletes a conversation, so it asks first and says exactly
// what will happen — including that it is reversible, which is the thing
// that makes the decision easy. Port of
// src/features/messaging/components/RemoveSheet.tsx.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/type.dart';
import '../../store/theme_store.dart';
import '../../store/types.dart';
import '../../styles/theme.dart' as tokens;

class RemoveSheet extends StatefulWidget {
  const RemoveSheet({super.key, required this.thread, required this.onCancel, required this.onConfirm});

  final Thread thread;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

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
    final c = context.watch<ThemeStore>().colors(context);
    final isGroup = widget.thread.group;
    final title = widget.thread.title;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onCancel,
            child: Semantics(
              label: 'Keep this conversation',
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
              child: Transform.translate(offset: Offset(0, 40 * (1 - _rise.value)), child: child),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                  Display(isGroup ? 'Leave $title?' : 'Remove $title?', size: 24),
                  const SizedBox(height: 12),
                  Body(
                    isGroup
                        ? 'The conversation goes from this phone. The others keep theirs, '
                              'and you can be added again.'
                        : 'This deletes the conversation and stops the two phones '
                              'connecting. Tap or scan to pair again whenever you want.',
                    size: 13,
                    dim: 2,
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: isGroup ? 'Leave group' : 'Remove',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: widget.onConfirm,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: tokens.touchMin),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.direct, borderRadius: BorderRadius.circular(10)),
                        child: Display(isGroup ? 'Leave group' : 'Remove', size: 15, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    button: true,
                    label: 'Keep it',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: widget.onCancel,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: tokens.touchMin),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: c.hair, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Display('Keep it', size: 15),
                      ),
                    ),
                  ),
                  if (!isGroup) ...[
                    const SizedBox(height: 8),
                    const Center(child: Mono('ECHOCOIN ALREADY SENT IS NOT UNDONE', size: 8.5)),
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
