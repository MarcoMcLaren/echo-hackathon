// Screen chrome: safe-area screen wrapper, mesh status line, app bar, and
// bottom tab nav. Port of src/components/Chrome.tsx.
//
// Named `AppTab`/`EchoAppBar` rather than the RN source's `Tab`/`AppBar` —
// both collide with widgets Flutter's own material.dart already exports.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/theme_store.dart';
import '../styles/theme.dart' as tokens;
import 'type.dart';

/// Screen background + top safe area. Every screen wraps its content in this.
class Screen extends StatelessWidget {
  const Screen({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    return ColoredBox(
      color: c.paper,
      child: SafeArea(bottom: false, child: child),
    );
  }
}

enum MeshState { off, starting, live, error }

/// The mesh states its own conditions at the top of every screen. No clock —
/// the real one is two millimetres above it.
class MeshStatus extends StatelessWidget {
  const MeshStatus({
    super.key,
    this.right = 'NO SIM · WI-FI OFF · BLE ON',
    this.state = MeshState.live,
    this.onPress,
  });

  final String right;
  final MeshState state;
  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    final dot = switch (state) {
      MeshState.live => c.direct,
      MeshState.starting => c.relay,
      MeshState.off || MeshState.error => c.dim,
    };
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          Flexible(
            child: Mono(
              right,
              size: 9,
              color: state == MeshState.error ? c.direct : null,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
    if (onPress == null) return body;
    return Semantics(
      button: true,
      label: 'Mesh ${state.name}. $right',
      excludeSemantics: true,
      child: GestureDetector(onTap: onPress, child: body),
    );
  }
}

/// Screen header: back chevron, title + optional caption, optional right slot.
class EchoAppBar extends StatelessWidget {
  const EchoAppBar({
    super.key,
    required this.title,
    this.sub,
    this.onBack,
    this.right,
  });

  final String title;
  final String? sub;
  final VoidCallback? onBack;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    final onBack = this.onBack;
    final right = this.right;
    final sub = this.sub;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.hair2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBack != null)
            Semantics(
              button: true,
              label: 'Back',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onBack,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: tokens.touchMin,
                    minHeight: tokens.touchMin,
                  ),
                  alignment: Alignment.centerLeft,
                  child: const Display('‹', size: 22, dim: 2),
                ),
              ),
            ),
          if (onBack != null) const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Display(title, size: 21, maxLines: 1),
                if (sub != null) Mono(sub.toUpperCase(), size: 9, maxLines: 1),
              ],
            ),
          ),
          if (right != null) ...[const SizedBox(width: 10), right],
        ],
      ),
    );
  }
}

/// The four tabs of the app shell — reach (mesh contacts), wallet, tap
/// (meet), read (on-device OCR).
enum AppTab { reach, wallet, tap, read }

class _NavItem {
  const _NavItem(this.tab, this.glyph, this.label);
  final AppTab tab;
  final String glyph;
  final String label;
}

const _navItems = [
  _NavItem(AppTab.reach, '◎', 'REACH'),
  _NavItem(AppTab.wallet, '◍', 'WALLET'),
  _NavItem(AppTab.tap, '⌁', 'MEET'),
  _NavItem(AppTab.read, '⌾', 'READ'),
];

class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.tab, required this.onTab, this.disabled = false});

  final AppTab tab;
  final ValueChanged<AppTab> onTab;

  /// Set while a screen is doing work that must not be interrupted by
  /// unmount (ReadScreen mid-capture). The active tab stays pressable so a
  /// lock never looks like a freeze.
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.hair2)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final item in _navItems)
              Expanded(
                child: _NavButton(
                  item: item,
                  selected: item.tab == tab,
                  locked: disabled && item.tab != tab,
                  onTap: () => onTab(item.tab),
                  colors: c,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.locked,
    required this.onTap,
    required this.colors,
  });

  final _NavItem item;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;
  final tokens.Palette colors;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? colors.ink : colors.ink3;
    return Semantics(
      selected: selected,
      button: true,
      enabled: !locked,
      label: item.label,
      excludeSemantics: true,
      child: Opacity(
        opacity: locked ? 0.4 : 1,
        child: InkWell(
          onTap: locked ? null : onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: tokens.touchMin),
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: selected ? colors.direct : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Display(item.glyph, size: 16, color: ink),
                const SizedBox(height: 1),
                Mono(item.label, size: 8.5, color: ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
