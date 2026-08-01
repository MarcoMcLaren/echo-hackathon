// Ported from src/features/vault/components/ResetSheet.tsx.
//
// Wiping the phone is not undoable, so it says exactly what goes and asks
// twice — once by opening this, once by pressing the red button. The second
// press is the one that means it. Animation/structure matches
// CatchMeUpSheet: a scrim behind a bottom sheet that rises and fades in.
import 'package:flutter/material.dart';
import '../theme/echo_theme.dart';
import '../theme/palette.dart';
import 'type.dart';

class ResetSheet extends StatefulWidget {
  final VoidCallback onConfirm;
  final VoidCallback onClose;

  const ResetSheet({super.key, required this.onConfirm, required this.onClose});

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

  void _press() {
    if (_armed) {
      widget.onConfirm();
    } else {
      setState(() => _armed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    final armed = _armed;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Semantics(
              label: 'Keep everything',
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
                  const SizedBox(height: 12),
                  const DisplayText('Reset this phone?', size: 26),
                  const SizedBox(height: 12),
                  const BodyText(
                    'Your name, your key, your contacts and every conversation go. This phone gets a brand new '
                    'identity, so to everyone who paired with it you become a stranger — they will have to add '
                    'you again.',
                    size: 13,
                    dim: Dim.two,
                  ),
                  const SizedBox(height: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MonoText('· NAME AND KEY REPLACED', size: 8.5),
                      SizedBox(height: 4),
                      MonoText('· ALL CONTACTS FORGOTTEN', size: 8.5),
                      SizedBox(height: 4),
                      MonoText('· ALL MESSAGES AND ECHOCOIN HISTORY GONE', size: 8.5),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: armed ? 'Yes, erase everything' : 'Reset',
                    child: GestureDetector(
                      onTap: _press,
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: touchMin),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: armed ? c.direct : Colors.transparent,
                          border: armed ? null : Border.all(color: c.direct, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DisplayText(
                          armed ? 'Yes, erase everything' : 'Reset',
                          size: 15,
                          color: armed ? Colors.white : c.direct,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: 'Keep everything',
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: touchMin),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          border: Border.all(color: c.hair, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const DisplayText('Keep everything', size: 15),
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
