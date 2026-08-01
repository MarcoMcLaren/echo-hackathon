// Hop state as a pill. Colour comes from the one signal scale.
// Port of src/components/Chip.tsx.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store/theme_store.dart';
import 'type.dart';

class HopChip extends StatelessWidget {
  const HopChip({super.key, required this.hops, this.via, this.label});

  /// 0 = direct, >0 = hop count via a relay, null = no route.
  final int? hops;
  final String? via;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    final col = hops == null ? c.dim : (hops == 0 ? c.direct : c.relay);
    final text =
        label ??
        (hops == null
            ? 'No route'
            : (hops == 0 ? 'Direct' : 'Via ${via ?? 'relay'}'));
    return _Chip(color: col, text: text.toUpperCase());
  }
}

class CoinChip extends StatelessWidget {
  const CoinChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ThemeStore>().colors(context);
    return _Chip(color: c.coin, text: label.toUpperCase(), alpha: 0x1F);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.color, required this.text, this.alpha = 0x22});

  final Color color;
  final String text;
  final int alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(alpha),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Mono(text, size: 8.5, color: color),
    );
  }
}
