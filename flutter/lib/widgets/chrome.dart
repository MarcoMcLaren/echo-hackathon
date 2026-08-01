// Ported from src/components/Chrome.tsx.
import 'package:flutter/material.dart';
import '../theme/echo_theme.dart';
import '../theme/palette.dart';
import 'type.dart';

enum MeshState { off, starting, live, error }

/// The mesh states its own conditions at the top of every screen. No clock —
/// the real one is two millimetres above it.
class MeshStatusBar extends StatelessWidget {
  final String right;
  final MeshState state;
  final VoidCallback? onPress;

  const MeshStatusBar({
    super.key,
    this.right = 'NO SIM · WI-FI OFF · BLE ON',
    this.state = MeshState.live,
    this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    final dot = state == MeshState.live
        ? c.direct
        : state == MeshState.starting
            ? c.relay
            : c.dim;

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: MonoText(
              right,
              size: 9,
              color: state == MeshState.error ? c.direct : null,
              maxLines: 1,
              style: const TextStyle(),
            ),
          ),
        ],
      ),
    );

    if (onPress == null) return body;
    return Semantics(
      button: true,
      label: 'Mesh ${state.name}. $right',
      child: GestureDetector(onTap: onPress, child: body),
    );
  }
}

class EchoAppBar extends StatelessWidget {
  final String title;
  final String? sub;
  final VoidCallback? onBack;
  final Widget? right;

  const EchoAppBar({super.key, required this.title, this.sub, this.onBack, this.right});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.hair2, width: 1))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBack != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Semantics(
                button: true,
                label: 'Back',
                child: GestureDetector(
                  onTap: onBack,
                  child: SizedBox(
                    width: 22,
                    child: DisplayText('‹', size: 22, dim: Dim.two),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DisplayText(title, size: 21, maxLines: 1),
                if (sub != null)
                  MonoText(sub!.toUpperCase(), size: 9, maxLines: 1),
              ],
            ),
          ),
          if (right != null) Padding(padding: const EdgeInsets.only(left: 4), child: right),
        ],
      ),
    );
  }
}

enum EchoTab { reach, wallet, tap }

class BottomNav extends StatelessWidget {
  final EchoTab tab;
  final ValueChanged<EchoTab> onTab;

  const BottomNav({super.key, required this.tab, required this.onTab});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    const items = [
      (id: EchoTab.reach, glyph: '◎', label: 'REACH'),
      (id: EchoTab.wallet, glyph: '◍', label: 'WALLET'),
      (id: EchoTab.tap, glyph: '⌁', label: 'MEET'),
    ];

    return Container(
      decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.hair2, width: 1))),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final it in items)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: it.id == tab,
                  label: it.label,
                  child: GestureDetector(
                    onTap: () => onTab(it.id),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: touchMin),
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: it.id == tab ? c.direct : Colors.transparent, width: 2)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DisplayText(it.glyph, size: 16, color: it.id == tab ? c.ink : c.ink3),
                          const SizedBox(height: 1),
                          MonoText(it.label, size: 8.5, color: it.id == tab ? c.ink : c.ink3),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
