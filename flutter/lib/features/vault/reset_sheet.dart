// Wiping the phone is not undoable, so it says exactly what goes and asks
// twice — once by opening this, once by pressing the red button. The second
// press is the one that means it. Port of
// src/features/vault/components/ResetSheet.tsx.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/type.dart';
import '../../store/theme_store.dart';
import '../../styles/theme.dart' as tokens;

class ResetSheet extends StatefulWidget {
  const ResetSheet({super.key, required this.onCancel, required this.onConfirm});

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  State<ResetSheet> createState() => _ResetSheetState();
}

class _ResetSheetState extends State<ResetSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rise;
  bool _armed = false;

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
    final armed = _armed;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onCancel,
            child: Semantics(
              label: 'Keep everything',
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
                  const Display('Reset this phone?', size: 26),
                  const SizedBox(height: 12),
                  Body(
                    'Your name, your key, your contacts and every conversation go. This '
                    'phone gets a brand new identity, so to everyone who paired with it '
                    'you become a stranger — they will have to add you again.',
                    size: 13,
                    dim: 2,
                  ),
                  const SizedBox(height: 12),
                  const Mono('· NAME AND KEY REPLACED', size: 8.5),
                  const SizedBox(height: 4),
                  const Mono('· ALL CONTACTS FORGOTTEN', size: 8.5),
                  const SizedBox(height: 4),
                  const Mono('· ALL MESSAGES AND ECHOCOIN HISTORY GONE', size: 8.5),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: armed ? 'Yes, erase everything' : 'Reset',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () {
                        if (armed) {
                          widget.onConfirm();
                        } else {
                          setState(() => _armed = true);
                        }
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: tokens.touchMin),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: armed ? c.direct : Colors.transparent,
                          border: armed ? null : Border.all(color: c.direct, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Display(
                          armed ? 'Yes, erase everything' : 'Reset',
                          size: 15,
                          color: armed ? Colors.white : c.direct,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    button: true,
                    label: 'Keep everything',
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
                        child: const Display('Keep everything', size: 15),
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
