// Ported from src/components/Chip.tsx.
import 'package:flutter/material.dart';
import '../theme/echo_theme.dart';
import 'type.dart';

/// Hop state as a pill. Colour comes from the one signal scale.
class HopChip extends StatelessWidget {
  final int? hops;
  final String? via;
  final String? label;

  const HopChip({super.key, required this.hops, this.via, this.label});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    final col = hops == null ? c.dim : hops == 0 ? c.direct : c.relay;
    final text = label ?? (hops == null ? 'No route' : hops == 0 ? 'Direct' : 'Via ${via ?? 'relay'}');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: col.withAlpha(0x22), borderRadius: BorderRadius.circular(3)),
      child: MonoText(text.toUpperCase(), size: 8.5, color: col),
    );
  }
}

class CoinChip extends StatelessWidget {
  final String label;
  const CoinChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = EchoTheme.of(context).c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.coin.withAlpha(0x1F), borderRadius: BorderRadius.circular(3)),
      child: MonoText(label.toUpperCase(), size: 8.5, color: c.coin),
    );
  }
}
